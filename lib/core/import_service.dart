import 'dart:convert';

import 'package:http/http.dart' as http;

/// ✅ خدمة الفواتير التاريخية v2 (مواد فاوري فقط + كاش ذكي)
class ImportService {
  static const String _raw =
      'https://raw.githubusercontent.com/AHMEDBRZAN/FAWORI-V1/main';
  static const String _site = 'https://ahmedbrzan.github.io/FAWORI-V1';

  static List<Map<String, dynamic>>? _cache;
  static String? _cacheVersion;
  static Map<String, List<Map<String, dynamic>>>? _byCustomer;

  /// ✅ تطبيع الاسم: إزالة الأرقام والرموز والمسافات الزائدة
  static String normalizeName(String n) {
    var s = n.replaceAll(RegExp(r'[0-9]+'), ' ');
    s = s.replaceAll(RegExp(r'[\\/|•\-.(),]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  static Future<Map<String, dynamic>?> _fetchJson() async {
    for (final base in const [_raw, _site]) {
      try {
        final r = await http
            .get(Uri.parse(
                '$base/assets/data/imported_invoices.json?t=${DateTime.now().millisecondsSinceEpoch}'))
            .timeout(const Duration(seconds: 30));
        if (r.statusCode == 200) {
          return jsonDecode(r.body) as Map<String, dynamic>;
        }
      } catch (_) {}
    }
    return null;
  }

  /// ✅ قراءة الملف مع كاش يتحدث تلقائياً عند رفع نسخة جديدة
  static Future<List<Map<String, dynamic>>> loadImported() async {
    final j = await _fetchJson();
    if (j == null) return _cache ?? const [];
    final ver = '${j['meta'] is Map ? (j['meta'] as Map)['version'] ?? '' : ''}';
    if (_cache != null && _cacheVersion == ver && ver.isNotEmpty) {
      return _cache!;
    }
    final list = (j['invoices'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    // ✅ تنظيف دفاعي: تاريخ معه وقت ← يُفصل | رقم معه .0 ← يُحذف
    for (final inv in list) {
      var d = '${inv['date'] ?? ''}';
      if (d.contains(' ')) {
        final parts = d.split(' ');
        inv['date'] = parts[0];
        final t = '${inv['time'] ?? ''}';
        if (t.isEmpty || t == '00:00:00') {
          inv['time'] = parts.length > 1 ? parts[1] : '';
        }
      }
      var no = '${inv['legacy_no'] ?? ''}';
      if (no.endsWith('.0')) no = no.substring(0, no.length - 2);
      inv['legacy_no'] = no;
    }
    _cache = list;
    _cacheVersion = ver;
    final m = <String, List<Map<String, dynamic>>>{};
    for (final inv in list) {
      final key = normalizeName('${inv['customer_name'] ?? ''}');
      if (key.isEmpty) continue;
      m.putIfAbsent(key, () => []).add(inv);
    }
    _byCustomer = m;
    return list;
  }

  /// ✅ فواتير عميل بالاسم (مطابقة بعد التطبيع + جزئية احتياطية)
  static Future<List<Map<String, dynamic>>> historyFor(
      String userName) async {
    await loadImported();
    final key = normalizeName(userName);
    if (key.isEmpty || _byCustomer == null) return const [];
    final exact = _byCustomer![key];
    if (exact != null && exact.isNotEmpty) return exact;
    for (final e in _byCustomer!.entries) {
      if (e.key.isNotEmpty &&
          (e.key.contains(key) || key.contains(e.key))) {
        return e.value;
      }
    }
    return const [];
  }

  /// ✅ نسخة متزامنة (بعد التحميل) — لصفحة المدير
  static List<Map<String, dynamic>> historyForSync(String userName) {
    final key = normalizeName(userName);
    if (key.isEmpty || _byCustomer == null) return const [];
    final exact = _byCustomer![key];
    if (exact != null && exact.isNotEmpty) return exact;
    for (final e in _byCustomer!.entries) {
      if (e.key.isNotEmpty &&
          (e.key.contains(key) || key.contains(e.key))) {
        return e.value;
      }
    }
    return const [];
  }

  /// ✅ صافي مواد فاوري (موجب شراء / سالب مرتجع)
  static int historyNet(List<Map<String, dynamic>> hist) {
    double sum = 0;
    for (final h in hist) {
      sum += (h['total'] as num?)?.toDouble() ?? 0;
    }
    return sum.toInt();
  }
}
