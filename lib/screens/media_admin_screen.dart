import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/theme.dart';

/// ✅ صفحة إدارة الإعلام (للمدير/المتحكم فقط)
///    إدارة أخبار وشروحات الشركة المعروضة في قسم "إعلام"
class MediaAdminScreen extends StatefulWidget {
  const MediaAdminScreen({super.key});
  @override
  State<MediaAdminScreen> createState() => _MediaAdminScreenState();
}

class _MediaAdminScreenState extends State<MediaAdminScreen> {
  static const String _kProxy ='https://fawori.ahmdkaka1997.workers.dev/';
  static const String _kPath = 'assets/data/media.json';

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await http
          .get(Uri.parse(
              'https://raw.githubusercontent.com/AHMEDBRZAN/FAWORI-V1/main/$_kPath?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final j = jsonDecode(r.body);
        if (j is List) {
          setState(() {
            _items = j
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList();
          });
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _save() async {
    setState(() => _saving = true);
    try {
      final r = await http
          .post(
            Uri.parse(_kProxy),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'path': _kPath,
              'content': base64Encode(utf8.encode(jsonEncode(_items))),
            }),
          )
          .timeout(const Duration(seconds: 25));
      if (mounted) setState(() => _saving = false);
      return r.statusCode == 200 || r.statusCode == 201;
    } catch (_) {
      if (mounted) setState(() => _saving = false);
      return false;
    }
  }

  Future<void> _editDialog([Map<String, dynamic>? item]) async {
    final s = context.read<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final titleCtrl = TextEditingController(text: item?['title'] ?? '');
    final subCtrl = TextEditingController(text: item?['sub'] ?? '');
    final imgCtrl = TextEditingController(text: item?['image'] ?? '');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dark ? const Color(0xFF1E1E28) : Colors.white,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
            item == null
                ? (s.isArabic ? 'إضافة خبر إعلامي' : 'Add media post')
                : (s.isArabic ? 'تعديل الخبر' : 'Edit post'),
            style: const TextStyle(
                color: Color(0xFF6A3AC7), fontWeight: FontWeight.w900)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleCtrl,
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.ink),
                decoration: InputDecoration(
                  hintText: s.isArabic ? 'العنوان الرئيسي' : 'Main title',
                  prefixIcon: const Icon(Icons.campaign_rounded,
                      color: Color(0xFF6A3AC7)),
                  filled: true,
                  fillColor: dark
                      ? const Color(0xFF26262E)
                      : const Color(0xFFFFFDF9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: subCtrl,
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.ink),
                decoration: InputDecoration(
                  hintText: s.isArabic ? 'السطر الثانوي' : 'Subtitle',
                  prefixIcon: const Icon(Icons.short_text_rounded,
                      color: Color(0xFF6A3AC7)),
                  filled: true,
                  fillColor: dark
                      ? const Color(0xFF26262E)
                      : const Color(0xFFFFFDF9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: imgCtrl,
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.ink),
                decoration: InputDecoration(
                  hintText: s.isArabic
                      ? 'رابط الصورة (اختياري)'
                      : 'Image URL (optional)',
                  prefixIcon: const Icon(Icons.image_outlined,
                      color: Color(0xFF6A3AC7)),
                  filled: true,
                  fillColor: dark
                      ? const Color(0xFF26262E)
                      : const Color(0xFFFFFDF9),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A3AC7),
                foregroundColor: Colors.white),
            onPressed: () {
              if (titleCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx, true);
            },
            child: Text(s.isArabic ? 'حفظ' : 'Save'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      if (item == null) {
        _items.insert(0, {
          'id': '${DateTime.now().millisecondsSinceEpoch}',
          'title': titleCtrl.text.trim(),
          'sub': subCtrl.text.trim(),
          'image': imgCtrl.text.trim(),
          'date': DateTime.now().toIso8601String().substring(0, 10),
        });
      } else {
        item['title'] = titleCtrl.text.trim();
        item['sub'] = subCtrl.text.trim();
        item['image'] = imgCtrl.text.trim();
      }
    });
    final done = await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(done
              ? (s.isArabic ? '✅ تم الحفظ والنشر' : 'Saved')
              : (s.isArabic ? '❌ فشل الحفظ' : 'Save failed')),
          backgroundColor: done ? Colors.green : Colors.red));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> item) async {
    final s = context.read<AppSettings>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(s.isArabic ? 'حذف الخبر' : 'Delete post',
            style: const TextStyle(
                color: Colors.red, fontWeight: FontWeight.w900)),
        content: Text(
            s.isArabic
                ? 'سيُحذف الخبر نهائياً من قسم الإعلام.'
                : 'Post will be removed from media section.',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.isArabic ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _items.remove(item));
    final done = await _save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(done
              ? (s.isArabic ? '🗑️ تم الحذف والنشر' : 'Deleted')
              : (s.isArabic ? '❌ فشل الحذف' : 'Delete failed')),
          backgroundColor: done ? Colors.green : Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'إدارة الإعلام' : 'Media management'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.all(14),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFF6A3AC7))),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF6A3AC7),
        foregroundColor: Colors.white,
        onPressed: () => _editDialog(),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.isArabic ? 'خبر جديد' : 'New post'),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF6A3AC7)))
          : RefreshIndicator(
              onRefresh: _load,
              color: const Color(0xFF6A3AC7),
              child: _items.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Column(
                            children: [
                              const Icon(Icons.campaign_rounded,
                                  size: 64, color: Color(0xFF6A3AC7)),
                              const SizedBox(height: 12),
                              Text(
                                  s.isArabic
                                      ? 'لا توجد أخبار إعلامية بعد'
                                      : 'No media posts yet',
                                  style: TextStyle(
                                      color: dark
                                          ? Colors.grey.shade400
                                          : Colors.grey.shade600,
                                      fontWeight: FontWeight.w800)),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _items.length,
                      itemBuilder: (ctx, i) {
                        final it = _items[i];
                        final img = '${it['image'] ?? ''}';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                const Color(0xFF6A3AC7)
                                    .withAlpha(dark ? 40 : 22),
                                const Color(0xFF2E7CF6)
                                    .withAlpha(dark ? 18 : 10),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                                color: const Color(0xFF6A3AC7)
                                    .withAlpha(70)),
                          ),
                          child: ListTile(
                            leading: img.isNotEmpty
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(img,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorBuilder: (c, o, st) =>
                                            const Icon(
                                                Icons.campaign_rounded,
                                                color: Color(0xFF6A3AC7),
                                                size: 30)),
                                  )
                                : Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF6A3AC7)
                                          .withAlpha(30),
                                      borderRadius:
                                          BorderRadius.circular(12),
                                    ),
                                    child: const Icon(
                                        Icons.campaign_rounded,
                                        color: Color(0xFF6A3AC7),
                                        size: 26),
                                  ),
                            title: Text('${it['title'] ?? ''}',
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: dark
                                        ? Colors.white
                                        : AppColors.ink)),
                            subtitle: Text('${it['sub'] ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: dark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600,
                                    fontSize: 12)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit_rounded,
                                      color: AppColors.teal, size: 20),
                                  onPressed: () => _editDialog(it),
                                ),
                                IconButton(
                                  icon: const Icon(
                                      Icons.delete_outline_rounded,
                                      color: Colors.red,
                                      size: 20),
                                  onPressed: () => _confirmDelete(it),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
    );
  }
}
