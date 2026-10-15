import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/repositories/product_repo.dart';
import '../core/theme.dart';
import '../data/sample_data.dart';

const String _kProxyBase = 'https://fawori.ahmdkaka1997.workers.dev';
const String _kProxy = '$_kProxyBase/put';
const String _kImgBase =
    'https://raw.githubusercontent.com/AHMEDBRZAN/FAWORI-V1/main/';

/// ✅ نافذة قص الصورة قبل الرفع
class _CropDialog extends StatefulWidget {
  final String srcUrl;
  final Uint8List bytes;
  const _CropDialog(this.srcUrl, this.bytes);
  @override
  State<_CropDialog> createState() => _CropDialogState();
}

class _CropDialogState extends State<_CropDialog> {
  static const double _S = 280;
  double _z = 1;
  double _dx = 0;
  double _dy = 0;
  double _rw = _S;
  double _rh = _S;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  Future<void> _decode() async {
    try {
      final img = html.ImageElement()..src = widget.srcUrl;
      await img.onLoad.first;
      final w = img.naturalWidth.toDouble();
      final h = img.naturalHeight.toDouble();
      final s = _S / w > _S / h ? _S / w : _S / h;
      if (!mounted) return;
      setState(() {
        _rw = w * s;
        _rh = h * s;
      });
    } catch (_) {}
  }

  void _clamp() {
    final mx = (_rw * _z - _S) / 2;
    final my = (_rh * _z - _S) / 2;
    _dx = _dx.clamp(-mx, mx);
    _dy = _dy.clamp(-my, my);
  }

  Future<String> _export() async {
    final img = html.ImageElement()..src = widget.srcUrl;
    await img.onLoad.first;
    final W = img.naturalWidth.toDouble();
    final H = img.naturalHeight.toDouble();
    final s = _S / W > _S / H ? _S / W : _S / H;
    final ds = s * _z;
    final destW = W * ds;
    final destH = H * ds;
    final destX = _S / 2 - destW / 2 + _dx;
    final destY = _S / 2 - destH / 2 + _dy;
    final srcX = (0 - destX) / ds;
    final srcY = (0 - destY) / ds;
    final srcW = _S / ds;
    final srcH = _S / ds;
    const int out = 600;
    final canvas = html.CanvasElement(width: out, height: out);
    canvas.context2D.drawImageScaledFromSource(
        img, srcX, srcY, srcW, srcH, 0, 0, out, out);
    var url = canvas.toDataUrl('image/webp', 0.85);
    if (!url.startsWith('data:image/webp')) {
      url = canvas.toDataUrl('image/jpeg', 0.85);
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onPanUpdate: (d) => setState(() {
              _dx += d.delta.dx;
              _dy += d.delta.dy;
              _clamp();
            }),
            child: Container(
              width: _S,
              height: _S,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white, width: 2),
              ),
              clipBehavior: Clip.hardEdge,
              child: Stack(
                children: [
                  Positioned(
                    left: _S / 2 - _rw / 2 + _dx,
                    top: _S / 2 - _rh / 2 + _dy,
                    child: Transform.scale(
                      scale: _z,
                      child: Image.network(widget.srcUrl,
                          width: _rw,
                          height: _rh,
                          fit: BoxFit.fill,
                          errorBuilder: (c, o, st) => const Center(
                              child: Icon(Icons.image_not_supported_outlined,
                                  color: Colors.white54, size: 60))),
                    ),
                  ),
                  Center(
                    child: Icon(Icons.crop_free_rounded,
                        color: Colors.white.withAlpha(90), size: _S - 40),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.zoom_out_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _z = (_z / 1.25).clamp(1.0, 4.0);
                  _clamp();
                }),
              ),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.zoom_in_rounded, color: Colors.white),
                onPressed: () => setState(() {
                  _z = (_z * 1.25).clamp(1.0, 4.0);
                  _clamp();
                }),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء',
                    style: TextStyle(color: Colors.white70)),
              ),
              const SizedBox(width: 20),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white),
                onPressed: () async {
                  final url = await _export();
                  if (context.mounted) Navigator.pop(context, url);
                },
                child: const Text('قص ورفع'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ✅ شاشة إدارة المنتجات (مدير ومتحكم)
class ProductAdminScreen extends StatefulWidget {
  const ProductAdminScreen({super.key});
  @override
  State<ProductAdminScreen> createState() => _ProductAdminScreenState();
}

class _ProductAdminScreenState extends State<ProductAdminScreen> {
  List<FireProduct> _items = [];
  bool _loading = true;
  String _q = '';
  final _qCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final list = await productRepo.list();
      if (mounted) setState(() => _items = list);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _deleteImageFromRepo(String url) async {
    const marker = '/assets/data/img/';
    final i = url.indexOf(marker);
    if (i < 0) return false;
    final path = url.substring(i + 1);
    final r = await http
        .post(Uri.parse('$_kProxyBase/delete'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'path': path}))
        .timeout(const Duration(seconds: 30));
    if (r.statusCode != 200 && r.statusCode != 201) {
      throw Exception('delete ${r.statusCode}: ${r.body}');
    }
    return true;
  }

  Future<String> _uploadImage(
      void Function(bool) busy, void Function(String) status) async {
    final picker = html.FileUploadInputElement()..accept = 'image/*';
    status('جارٍ فتح نافذة الاختيار...');
    html.document.body!.append(picker);
    picker.click();
    try {
      await picker.onChange.first.timeout(const Duration(seconds: 90));
    } catch (_) {}
    picker.remove();
    final file = picker.files?.first;
    if (file == null) {
      status('لم يتم اختيار صورة');
      return '';
    }
    status('تم اختيار الصورة — جارٍ القراءة...');
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoadEnd.first.timeout(const Duration(seconds: 30));
    final res = reader.result;
    if (res == null) {
      throw Exception('تعذر قراءة الصورة من الجهاز — جرب صورة JPG أو PNG');
    }
    final srcUrl = '$res';
    status('جارٍ فتح نافذة القص...');
    final bytes = base64Decode(srcUrl.split(',').last);
    final cropped = await showDialog<String>(
        context: context, builder: (_) => _CropDialog(srcUrl, bytes));
    if (cropped == null || cropped.isEmpty) {
      status('أُلغي القص — لا رفع');
      return '';
    }
    final base64Part = cropped.split(',').last;
    if (base64Part.length > 950 * 1024) {
      throw Exception('الصورة كبيرة جداً حتى بعد القص — قلص التكبير');
    }
    busy(true);
    status('جارٍ الرفع إلى المستودع...');
    final ext = cropped.startsWith('data:image/webp') ? 'webp' : 'jpg';
    final path =
        'assets/data/img/p_${DateTime.now().millisecondsSinceEpoch}.$ext';
    try {
      final r = await http
          .post(Uri.parse(_kProxy),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'path': path, 'content': base64Part}))
          .timeout(const Duration(seconds: 40));
      if (r.statusCode != 200 && r.statusCode != 201) {
        throw Exception('upload ${r.statusCode}');
      }
      return '$_kImgBase$path';
    } finally {
      busy(false);
    }
  }

  Future<void> _migrate(AppSettings s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isArabic ? 'ترحيل الكتالوج' : 'Migrate catalog'),
        content: Text(s.isArabic
            ? 'سيرحل كل منتجات الكتالوج إلى Firestore دفعة واحدة. التكرار آمن بدون تكرار بيانات.'
            : 'Migrate all catalog products to Firestore. Safe to repeat.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isArabic ? 'ابدأ' : 'Start')),
        ],
      ),
    );
    if (ok != true) return;
    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(
            child: CircularProgressIndicator(color: AppColors.teal)));
    String report = '';
    try {
      final items = sampleData
          .map((p) => FireProduct(
                id: p.id,
                name: p.name,
                brand: p.brand,
                description: p.description,
                image: p.image,
                category: p.category,
                price: p.price,
              ))
          .toList();
      await productRepo.importMany(items);
      report = '✅ تم ترحيل ${items.length} منتج';
    } catch (e) {
      report = 'فشل الترحيل:\n$e';
    }
    if (mounted) Navigator.pop(context);
    if (mounted) {
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Text(s.isArabic ? 'نتيجة الترحيل' : 'Result'),
                content: SelectableText(report),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(s.isArabic ? 'إغلاق' : 'Close')),
                ],
              ));
    }
    _load();
  }

  Future<void> _edit([FireProduct? p]) async {
    final s = context.read<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final nameC = TextEditingController(text: p?.name ?? '');
    final brandC = TextEditingController(text: p?.brand ?? '');
    final catC = TextEditingController(text: p?.category ?? '');
    final priceC = TextEditingController(text: p == null ? '' : '${p.price}');
    final descC = TextEditingController(text: p?.description ?? '');
    final imgC = TextEditingController(text: p?.image ?? '');
    bool uploading = false;
    String uploadStatus = '';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: dark ? const Color(0xFF1E1E28) : Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
              p == null
                  ? (s.isArabic ? 'منتج جديد' : 'New product')
                  : (s.isArabic ? 'تعديل المنتج' : 'Edit product'),
              style: const TextStyle(
                  color: AppColors.teal, fontWeight: FontWeight.w900)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _fld(nameC, s.isArabic ? 'اسم المنتج' : 'Name',
                    Icons.format_paint_rounded, AppColors.orange, dark),
                const SizedBox(height: 10),
                _fld(brandC, s.isArabic ? 'الماركة' : 'Brand',
                    Icons.branding_watermark_rounded, AppColors.teal, dark),
                const SizedBox(height: 10),
                _fld(catC, s.isArabic ? 'الفئة' : 'Category',
                    Icons.category_rounded, const Color(0xFF9B59B6), dark),
                const SizedBox(height: 10),
                _fld(priceC, s.isArabic ? 'السعر (دينار)' : 'Price',
                    Icons.payments_rounded, AppColors.orange, dark,
                    kt: TextInputType.number),
                const SizedBox(height: 10),
                _fld(descC, s.isArabic ? 'الوصف (اختياري)' : 'Description',
                    Icons.notes_rounded, AppColors.teal, dark),
                const SizedBox(height: 10),
                _fld(imgC, s.isArabic ? 'رابط الصورة' : 'Image URL',
                    Icons.link_rounded, const Color(0xFF9B59B6), dark),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF9B59B6),
                        foregroundColor: Colors.white),
                    onPressed: uploading
                        ? null
                        : () async {
                            setSt(() => uploadStatus = '');
                            try {
                              final url = await _uploadImage(
                                (v) => setSt(() => uploading = v),
                                (t) => setSt(() => uploadStatus = t),
                              );
                              if (url.isNotEmpty) {
                                imgC.text = url;
                                setSt(() =>
                                    uploadStatus = '✅ نجح الرفع — الرابط في الحقل');
                              }
                            } catch (e) {
                              setSt(() => uploading = false);
                              setSt(() => uploadStatus = '❌ فشل الرفع');
                              if (ctx.mounted) {
                                showDialog(
                                    context: ctx,
                                    builder: (d) => AlertDialog(
                                          title: const Text('فشل الرفع'),
                                          content: SelectableText('$e'),
                                          actions: [
                                            TextButton(
                                                onPressed: () =>
                                                    Navigator.pop(d),
                                                child: const Text('إغلاق')),
                                          ],
                                        ));
                              }
                            }
                          },
                    icon: uploading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.cloud_upload_rounded, size: 18),
                    label: Text(s.isArabic
                        ? 'رفع صورة من الجهاز'
                        : 'Upload image'),
                  ),
                ),
                if (uploadStatus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(uploadStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: uploadStatus.startsWith('✅')
                              ? Colors.green
                              : uploadStatus.startsWith('❌')
                                  ? Colors.red
                                  : const Color(0xFF9B59B6))),
                ],
                if (imgC.text.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(imgC.text,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (c, o, st) => const Icon(
                            Icons.broken_image_rounded,
                            size: 40,
                            color: Colors.red)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red)),
                      onPressed: () async {
                        final url = imgC.text.trim();
                        final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (d) => AlertDialog(
                                  title: const Text('حذف الصورة'),
                                  content: Text(url.contains('/assets/data/img/')
                                      ? 'سيُحذف الملف من المستودع نهائياً ويفرغ حقل الرابط.'
                                      : 'سيُفرغ حقل الرابط فقط (الرابط خارجي).'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(d, false),
                                        child: const Text('إلغاء')),
                                    ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.red),
                                        onPressed: () => Navigator.pop(d, true),
                                        child: const Text('حذف')),
                                  ],
                                ));
                        if (confirm != true) return;
                        if (url.contains('/assets/data/img/')) {
                          setSt(() =>
                              uploadStatus = 'جارٍ حذف الملف من المستودع...');
                          try {
                            final done = await _deleteImageFromRepo(url);
                            setSt(() => uploadStatus = done
                                ? '✅ حُذفت الصورة من المستودع'
                                : '❌ فشل الحذف من المستودع');
                          } catch (e) {
                            setSt(() => uploadStatus = '❌ فشل الحذف: $e');
                          }
                        } else {
                          setSt(() => uploadStatus = '✅ أُفرغ حقل الرابط');
                        }
                        imgC.text = '';
                      },
                      icon: const Icon(Icons.delete_forever_rounded, size: 18),
                      label: const Text('حذف الصورة'),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white),
              onPressed: () {
                if (nameC.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              child: Text(s.isArabic ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final id = p?.id ?? 'p_${DateTime.now().millisecondsSinceEpoch}';
    await productRepo.save(FireProduct(
      id: id,
      name: nameC.text.trim(),
      brand: brandC.text.trim(),
      description: descC.text.trim(),
      image: imgC.text.trim(),
      category: catC.text.trim(),
      price: int.tryParse(priceC.text.replaceAll(',', '')) ?? 0,
    ));
    _load();
  }

  Future<void> _delete(FireProduct p) async {
    final s = context.read<AppSettings>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isArabic ? 'حذف المنتج' : 'Delete product',
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.w900)),
        content: Text(s.isArabic
            ? 'سيُحذف "${p.name}" من قائمة المنتجات نهائياً.'
            : 'Delete "${p.name}" permanently?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(s.isArabic ? 'حذف' : 'Delete')),
        ],
      ),
    );
    if (ok != true) return;
    await productRepo.delete(p.id);
    _load();
  }

  Widget _fld(TextEditingController c, String hint, IconData icon, Color ic,
      bool dark,
      {TextInputType? kt}) {
    return TextField(
      controller: c,
      keyboardType: kt,
      selectionControls: materialTextSelectionControls,
      onTap: () {
        c.selection =
            TextSelection(baseOffset: 0, extentOffset: c.text.length);
      },
      style: TextStyle(color: dark ? Colors.white : AppColors.ink),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle:
            TextStyle(color: dark ? Colors.grey.shade500 : Colors.grey.shade400),
        prefixIcon: Icon(icon, color: ic, size: 20),
        filled: true,
        fillColor: dark ? const Color(0xFF26262E) : const Color(0xFFFFFDF9),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final q = _q.trim().toLowerCase();
    final shown = q.isEmpty
        ? _items
        : _items
            .where((p) =>
                p.name.toLowerCase().contains(q) ||
                p.brand.toLowerCase().contains(q) ||
                p.category.toLowerCase().contains(q))
            .toList();

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'إدارة المنتجات' : 'Products admin',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            tooltip: s.isArabic ? 'ترحيل الكتالوج' : 'Migrate catalog',
            icon: const Icon(Icons.cloud_upload_rounded,
                color: Color(0xFF9B59B6)),
            onPressed: () => _migrate(s),
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100),
        child: FloatingActionButton.extended(
          backgroundColor: AppColors.teal,
          foregroundColor: Colors.white,
          onPressed: () => _edit(),
          icon: const Icon(Icons.add_rounded),
          label: Text(s.isArabic ? 'منتج جديد' : 'New product'),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.teal))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: TextField(
                    controller: _qCtrl,
                    selectionControls: materialTextSelectionControls,
                    onChanged: (v) => setState(() => _q = v),
                    style: TextStyle(
                        color: dark ? Colors.white : AppColors.ink),
                    decoration: InputDecoration(
                      hintText: s.isArabic
                          ? 'بحث: اسم / ماركة / فئة'
                          : 'Search: name / brand / category',
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.orange),
                      filled: true,
                      fillColor:
                          dark ? const Color(0xFF1E1E28) : Colors.white,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Text('${shown.length}',
                          style: const TextStyle(
                              color: AppColors.orange,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(width: 6),
                      Text(s.isArabic ? 'منتج' : 'products',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 140),
                    itemCount: shown.length,
                    itemBuilder: (ctx, i) {
                      final p = shown[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: dark ? const Color(0xFF1E1E28) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.teal.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            p.image.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(p.image,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, o, st) =>
                                            const Icon(
                                                Icons.format_paint_rounded,
                                                color: AppColors.orange,
                                                size: 26)),
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color:
                                          AppColors.orange.withAlpha(30),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.format_paint_rounded,
                                        color: AppColors.orange,
                                        size: 26),
                                  ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(p.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 13,
                                          color: dark
                                              ? Colors.white
                                              : AppColors.ink)),
                                  const SizedBox(height: 3),
                                  Text(
                                      '${p.brand}${p.category.isEmpty ? '' : ' • ${p.category}'}',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text('${p.price}',
                                  style: const TextStyle(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12)),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _edit(p),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: AppColors.teal.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.edit_rounded,
                                    color: AppColors.teal, size: 18),
                              ),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => _delete(p),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.delete_outline_rounded,
                                    color: Colors.red, size: 18),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
