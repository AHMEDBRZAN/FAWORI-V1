import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/repositories/product_repo.dart';
import '../core/store_service.dart';
import '../core/theme.dart';
import '../data/sample_data.dart';

class ProductDetailScreen extends StatefulWidget {
  final Product product;
  final bool canBuy;
  final Function(int) onAdd;
  const ProductDetailScreen({
    super.key,
    required this.product,
    required this.canBuy,
    required this.onAdd,
  });
  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _qty = 1;
  bool _busy = false;
  String _desc = '';
  String _imgPath = '';
  List<FireProduct> _similar = [];

  static const String _rawBase =
      'https://raw.githubusercontent.com/AHMEDBRZAN/FAWORI-V1/main';
  static const String _siteBase = 'https://ahmedbrzan.github.io/FAWORI-V1';

  @override
  void initState() {
    super.initState();
    _loadExtra();
    _loadSimilar();
  }

  Future<void> _loadSimilar() async {
    try {
      final all = await productRepo.list().timeout(const Duration(seconds: 5));
      final p = widget.product;
      final sim = all
          .where((f) =>
              f.id != p.id &&
              (f.brand == p.brand ||
                  (p.category.isNotEmpty && f.category == p.category)))
          .take(6)
          .toList();
      if (mounted) setState(() => _similar = sim);
    } catch (_) {}
  }

  void _shareProduct() {
    final p = widget.product;
    final url = 'https://fawori-company.web.app/#/product/${p.id}';
    final text =
        '${p.name} - ${fmtThousands(p.price)} د.ع\n$p.url';
    // نسخ الرابط للحافظة
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تم نسخ رابط المنتج'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<dynamic> _fetchJson(String path) async {
    try {
      final r = await http
          .get(Uri.parse(
              '$_rawBase/$path?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    try {
      final r = await http
          .get(Uri.parse(
              '$_siteBase/$path?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return null;
  }

  Future<void> _loadExtra() async {
    String desc = '';
    String img = '';
    try {
      final e = await _fetchJson('assets/data/products_extra.json');
      if (e is Map) {
        final item = e[widget.product.id];
        if (item is Map) desc = '${item['desc'] ?? ''}';
      }
    } catch (_) {}
    try {
      var m = await _fetchJson('assets/data/images.json');
      m ??= await _fetchJson('assets/assets/data/images.json');
      if (m is Map) {
        final g = m['products'];
        if (g is Map) img = '${g[widget.product.id] ?? ''}';
      }
    } catch (_) {}
    if (mounted) {
      setState(() {
        _desc = desc;
        _imgPath = img;
      });
    }
  }

  Future<void> _openEdit() async {
    final s = context.read<AppSettings>();
    final descCtrl = TextEditingController(text: _effectiveDesc);
    List<int>? picked;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) => AlertDialog(
          backgroundColor: Theme.of(context).colorScheme.surface,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.edit_rounded, color: AppColors.orange),
              const SizedBox(width: 8),
              Expanded(
                child: Text(s.isArabic ? 'تعديل المنتج' : 'Edit product',
                    style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () async {
                    final f = await ImagePicker().pickImage(
                        source: ImageSource.gallery,
                        imageQuality: 80,
                        maxWidth: 800);
                    if (f == null) return;
                    picked = await f.readAsBytes();
                    setSt(() {});
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: double.infinity,
                    height: 130,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(20),
                      borderRadius: BorderRadius.circular(16),
                      border:
                          Border.all(color: AppColors.orange.withAlpha(80)),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (picked != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.memory(Uint8List.fromList(picked!),
                                fit: BoxFit.cover),
                          )
                        else if (_effectiveImg.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(_effectiveImg,
                                fit: BoxFit.cover,
                                errorBuilder: (c, o, st) => const Icon(
                                    Icons.image_outlined,
                                    size: 40,
                                    color: AppColors.orange)),
                          )
                        else
                          const Center(
                              child: Icon(Icons.add_photo_alternate_rounded,
                                  size: 40, color: AppColors.orange)),
                        Positioned(
                          bottom: 6,
                          right: 6,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: AppColors.orange,
                                borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.photo_camera_rounded,
                                size: 14, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                    s.isArabic
                        ? (_effectiveDesc.isEmpty
                            ? 'إضافة وصف'
                            : 'تغيير الوصف')
                        : (_effectiveDesc.isEmpty
                            ? 'Add description'
                            : 'Change description'),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                TextField(
                  controller: descCtrl,
                  maxLines: 3,
                  style: TextStyle(
                      color: Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : AppColors.ink),
                  decoration: InputDecoration(
                    hintText: s.isArabic
                        ? 'اكتب وصف المنتج هنا...'
                        : 'Write product description...',
                    filled: true,
                    fillColor: AppColors.orange.withAlpha(12),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.orange,
                  foregroundColor: Colors.white),
              onPressed: () async {
                Navigator.pop(ctx);
                await _saveEdit(descCtrl.text.trim(), picked);
              },
              child: Text(s.isArabic ? 'حفظ' : 'Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEdit(String desc, List<int>? bytes) async {
    final s = context.read<AppSettings>();
    String tk = await ImagesService.resolveToken();
    if (tk.isEmpty) {
      final t = await ImagesService.askGitHubToken(context);
      if (t == null) return;
      tk = t;
    }
    try {
      if (bytes != null) {
        final path = 'assets/images/prod_${widget.product.id}.webp';
        await ImagesService.putBytes(path, bytes, tk, 'product image');
        await ImagesService.setMapping(
            'products', widget.product.id, path, tk);
      }
      final cur = await _fetchJson('assets/data/products_extra.json');
      final map =
          cur is Map ? Map<String, dynamic>.from(cur) : <String, dynamic>{};
      map[widget.product.id] = {'desc': desc};
      await ImagesService.putBytes(
          'assets/data/products_extra.json',
          utf8.encode(jsonEncode(map)),
          tk,
          'product desc ${widget.product.id}');
      if (mounted) {
        setState(() => _desc = desc);
        await _loadExtra();
        showAppSnack(
            context,
            s.isArabic ? 'تم حفظ تعديلات المنتج' : 'Product updated',
            color: const Color(0xFF0D9668),
            icon: Icons.save_rounded);
      }
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'فشل الحفظ: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _add() async {
    final s = context.read<AppSettings>();
    if (!widget.canBuy) {
      showAppSnack(
          context,
          s.isArabic ? 'سجّل الدخول أولاً للشراء' : 'Login first to buy',
          color: Colors.red,
          icon: Icons.lock_rounded);
      return;
    }
    if (_busy) return;
    setState(() => _busy = true);
    await widget.onAdd(_qty);
    if (!mounted) return;
    setState(() => _busy = false);
    if (mounted) Navigator.pop(context);
  }

  // ============================================================
  // 🎯 منطق أولوية المحتوى (الأفضل أولاً)
  // ============================================================
  String get _effectiveDesc =>
      widget.product.description.isNotEmpty ? widget.product.description : _desc;

  String get _effectiveImg {
    if (widget.product.image.isNotEmpty) return widget.product.image;
    if (_imgPath.isNotEmpty) return '$_siteBase/assets/$_imgPath';
    return '';
  }

  /// 🔍 استخراج المواصفات من الوصف (الأسطر التي تبدأ بـ emoji)
  List<Map<String, String>> _parseSpecs(String desc) {
    final specs = <Map<String, String>>[];
    final lines = desc.split('\n');
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      // سطر يبدأ بـ emoji + نص + : + قيمة
      final m = RegExp(r'^([\u{1F300}-\u{1FAFF}▦✨⏱📦💧])\s*([^:]+?):\s*(.+)$',
              unicode: true)
          .firstMatch(t);
      if (m != null) {
        specs.add({
          'icon': m.group(1)!,
          'label': m.group(2)!.trim(),
          'value': m.group(3)!.trim(),
        });
      }
    }
    return specs;
  }

  /// 📝 فقرة الوصف (بدون سطور المواصفات)
  String _cleanDesc(String desc) {
    final lines = desc.split('\n');
    final clean = <String>[];
    for (final line in lines) {
      final t = line.trim();
      if (t.isEmpty) continue;
      if (RegExp(r'^[\u{1F300}-\u{1FAFF}▦✨⏱📦💧]', unicode: true)
          .hasMatch(t)) {
        continue; // تخطي سطور المواصفات
      }
      clean.add(t);
    }
    return clean.join('\n\n');
  }

  /// 🎨 لون لكل نوع مواصفة
  Color _specColor(String icon) {
    if (icon.contains('⏱')) return AppColors.orange;
    if (icon.contains('▦')) return AppColors.teal;
    if (icon.contains('✨')) return const Color(0xFF9B59B6);
    if (icon.contains('📦')) return const Color(0xFF0D9668);
    if (icon.contains('💧')) return const Color(0xFF2196F3);
    return AppColors.orange;
  }

  /// 🏷 بطاقة مواصفة واحدة
  Widget _specTile(Map<String, String> spec, bool dark) {
    final c = _specColor(spec['icon']!);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[c.withAlpha(dark ? 50 : 30), c.withAlpha(10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withAlpha(80)),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c.withAlpha(30),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(spec['icon']!, style: const TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(spec['label']!,
                style: TextStyle(
                    color: dark ? Colors.grey.shade300 : AppColors.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5)),
          ),
          Text(spec['value']!,
              style: TextStyle(
                  color: c, fontWeight: FontWeight.w900, fontSize: 13)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool isController = s.user?.id == 'ctrl';
    final p = widget.product;
    final desc = _effectiveDesc;
    final img = _effectiveImg;
    final specs = _parseSpecs(desc);
    final cleanDesc = _cleanDesc(desc);

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      body: CustomScrollView(
        slivers: [
          // ═══════════════════════════════════════════════
          // 🖼 صورة كبيرة قابلة للطي
          // ═══════════════════════════════════════════════
          SliverAppBar(
            expandedHeight: 320,
            pinned: true,
            backgroundColor:
                dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: dark
                    ? Colors.black.withAlpha(120)
                    : Colors.white.withAlpha(220),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(40), blurRadius: 8),
                ],
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_rounded,
                    color: dark ? Colors.white : AppColors.ink),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: dark
                      ? Colors.black.withAlpha(120)
                      : Colors.white.withAlpha(220),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withAlpha(40), blurRadius: 8),
                  ],
                ),
                child: IconButton(
                  tooltip: s.isArabic ? 'مشاركة' : 'Share',
                  icon: Icon(Icons.share_rounded,
                      color: dark ? Colors.white : AppColors.ink, size: 20),
                  onPressed: _shareProduct,
                ),
              ),
              if (isController)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.orange.withAlpha(80),
                          blurRadius: 10),
                    ],
                  ),
                  child: IconButton(
                    tooltip: s.isArabic ? 'تعديل المنتج' : 'Edit product',
                    icon: const Icon(Icons.edit_rounded,
                        color: Colors.white, size: 20),
                    onPressed: _openEdit,
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: dark
                        ? <Color>[
                            const Color(0xFF1E1E28),
                            const Color(0xFF141419)
                          ]
                        : <Color>[Colors.white, const Color(0xFFFFF8F1)],
                  ),
                ),
                child: img.isNotEmpty
                    ? Image.network(img,
                        fit: BoxFit.contain,
                        gaplessPlayback: true,
                        loadingBuilder: (c, child, prog) => prog == null
                            ? child
                            : const Center(
                                child: CircularProgressIndicator(
                                    color: AppColors.orange)),
                        errorBuilder: (c, e, st) => const Center(
                            child: Icon(Icons.format_paint_rounded,
                                size: 80, color: AppColors.orange)))
                    : const Center(
                        child: Icon(Icons.format_paint_rounded,
                            size: 80, color: AppColors.orange)),
              ),
            ),
          ),

          // ═══════════════════════════════════════════════
          // 📋 محتوى الصفحة
          // ═══════════════════════════════════════════════
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ✅ شارة الماركة + الاسم
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.teal.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(p.brand.toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.teal,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                            letterSpacing: 1)),
                  ),
                  const SizedBox(height: 8),
                  Text(p.name,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          height: 1.3,
                          color: dark ? Colors.white : AppColors.ink)),

                  const SizedBox(height: 14),

                  // ═══════════════════════════════════════════════
                  // 💰 سعر الشراء
                  // ═══════════════════════════════════════════════
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          AppColors.orange.withAlpha(dark ? 50 : 30),
                          AppColors.orange.withAlpha(dark ? 20 : 12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.orange.withAlpha(80)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withAlpha(40),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.payments_rounded,
                              color: AppColors.orange, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                              s.isArabic ? 'سعر الشراء' : 'Purchase price',
                              style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: dark ? Colors.white : AppColors.ink)),
                        ),
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: Text(fmtThousands(p.price),
                              style: const TextStyle(
                                  color: AppColors.orange,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 20)),
                        ),
                        Text(s.isArabic ? ' د.ع' : ' IQD',
                            style: TextStyle(
                                color: AppColors.orange.withAlpha(180),
                                fontWeight: FontWeight.w700,
                                fontSize: 12)),
                      ],
                    ),
                  ),

                  // ═══════════════════════════════════════════════
                  // 📝 الوصف
                  // ═══════════════════════════════════════════════
                  if (cleanDesc.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppColors.orange,
                                Color(0xFFF26B0F)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(s.isArabic ? 'الوصف' : 'Description',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: dark ? Colors.white : AppColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(cleanDesc,
                        style: TextStyle(
                            height: 1.7,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: dark
                                ? Colors.grey.shade300
                                : AppColors.ink)),
                  ],

                  // ═══════════════════════════════════════════════
                  // 🔬 المواصفات الفنية
                  // ═══════════════════════════════════════════════
                  if (specs.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                AppColors.teal,
                                Color(0xFF0D9668)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                            s.isArabic
                                ? 'المواصفات الفنية'
                                : 'Specifications',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: dark ? Colors.white : AppColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Column(
                      children: [
                        for (int i = 0; i < specs.length; i++) ...[
                          _specTile(specs[i], dark),
                          if (i < specs.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    ),
                  ],

                  const SizedBox(height: 24),

                  // ═══════════════════════════════════════════════
                  // 🛒 عداد الكمية + زر الإضافة
                  // ═══════════════════════════════════════════════
                  if (widget.canBuy) ...[
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E1E28) : Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border:
                            Border.all(color: AppColors.orange.withAlpha(50)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(s.isArabic ? 'الكمية' : 'Quantity',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: dark
                                          ? Colors.grey.shade300
                                          : AppColors.ink)),
                              const SizedBox(width: 20),
                              InkWell(
                                onTap: () => setState(
                                    () => _qty = (_qty - 1).clamp(1, 99)),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: _qty > 1
                                        ? AppColors.orange.withAlpha(30)
                                        : Colors.grey.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(Icons.remove_rounded,
                                      color: _qty > 1
                                          ? AppColors.orange
                                          : Colors.grey,
                                      size: 22),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.orange.withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text('$_qty',
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                        color: dark
                                            ? Colors.white
                                            : AppColors.ink)),
                              ),
                              const SizedBox(width: 14),
                              InkWell(
                                onTap: () => setState(
                                    () => _qty = (_qty + 1).clamp(1, 99)),
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: AppColors.orange.withAlpha(30),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Icon(Icons.add_rounded,
                                      color: AppColors.orange, size: 22),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Container(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFFFA500),
                                    Color(0xFFF26B0F)
                                  ]),
                              borderRadius: BorderRadius.circular(14),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.orange.withAlpha(100),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6)),
                              ],
                            ),
                            child: SizedBox(
                              height: 54,
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    shadowColor: Colors.transparent,
                                    foregroundColor: Colors.white),
                                onPressed: _busy ? null : _add,
                                icon: _busy
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white))
                                    : const Icon(
                                        Icons.add_shopping_cart_rounded,
                                        size: 22),
                                label: Text(
                                    s.isArabic
                                        ? 'أضف إلى السلة'
                                        : 'Add to cart',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 16)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],

                  // ═══════════════════════════════════════════════
                  // 🎯 منتجات مشابهة
                  // ═══════════════════════════════════════════════
                  if (_similar.isNotEmpty) ...[
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: <Color>[
                                Color(0xFF9B59B6),
                                Color(0xFF8E44AD)
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(s.isArabic ? 'منتجات مشابهة' : 'Similar products',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: dark ? Colors.white : AppColors.ink)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 180,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _similar.length,
                        itemBuilder: (ctx, i) {
                          final sp = _similar[i];
                          final spImg = sp.image.isNotEmpty ? sp.image : '';
                          return GestureDetector(
                            onTap: () {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ProductDetailScreen(
                                    product: Product(
                                      id: sp.id,
                                      name: sp.name,
                                      brand: sp.brand,
                                      description: sp.description,
                                      image: sp.image,
                                      category: sp.category,
                                      price: sp.price,
                                    ),
                                    canBuy: widget.canBuy,
                                    onAdd: widget.onAdd,
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              width: 140,
                              margin: const EdgeInsetsDirectional.only(end: 12),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF1E1E28)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: AppColors.orange.withAlpha(50)),
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withAlpha(dark ? 40 : 10),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3)),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: ClipRRect(
                                      borderRadius: const BorderRadius.vertical(
                                          top: Radius.circular(16)),
                                      child: spImg.isNotEmpty
                                          ? Image.network(spImg,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              errorBuilder: (c, o, st) =>
                                                  Center(
                                                      child: Icon(
                                                          Icons
                                                              .format_paint_rounded,
                                                          color: AppColors.orange,
                                                          size: 32)))
                                          : Center(
                                              child: Icon(
                                                  Icons.format_paint_rounded,
                                                  color: AppColors.orange,
                                                  size: 32)),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Padding(
                                      padding: const EdgeInsets.all(10),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(sp.name,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w800,
                                                  height: 1.2,
                                                  color: dark
                                                      ? Colors.white
                                                      : AppColors.ink)),
                                          Directionality(
                                            textDirection: TextDirection.ltr,
                                            child: Text(fmtThousands(sp.price),
                                                style: const TextStyle(
                                                    color: AppColors.orange,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 13)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
