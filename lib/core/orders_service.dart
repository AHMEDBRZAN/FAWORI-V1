import 'package:cloud_firestore/cloud_firestore.dart';
import 'repositories/invoice_repo.dart';
import 'repositories/orders_repo.dart';
import 'repositories/user_repo.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'store_service.dart';

const String _raw = 'https://raw.githubusercontent.com/AHMEDBRZAN/FAWORI-V1/main';
const String _site = 'https://ahmedbrzan.github.io/FAWORI-V1';
const String kOrdersPath = 'assets/data/orders.json';
const int kPointUnit = 125000;
const String kWriteProxy = 'https://fawori.ahmdkaka1997.workers.dev/put';

String fmtThousands(num n) {
  final bool neg = n < 0;
  final s = n.abs().toStringAsFixed(0);
  final out = StringBuffer();
  int c = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    out.write(s[i]);
    c++;
    if (c % 3 == 0 && i != 0) out.write(',');
  }
  final res = out.toString().split('').reversed.join();
  return neg ? '-$res' : res;
}

class CartItem {
  final String id, name, image, brand;
  int qty;
  CartItem(
      {required this.id,
      required this.name,
      required this.image,
      required this.brand,
      this.qty = 1});
  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'image': image, 'brand': brand, 'qty': qty};
  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
      id: j['id'] ?? '',
      name: j['name'] ?? '',
      image: j['image'] ?? '',
      brand: j['brand'] ?? '',
      qty: (j['qty'] as num?)?.toInt() ?? 1);
}

class OrderItem {
  final String name;
  final int qty;
  OrderItem({required this.name, required this.qty});
  Map<String, dynamic> toJson() => {'name': name, 'qty': qty};
  factory OrderItem.fromJson(Map<String, dynamic> j) =>
      OrderItem(name: j['name'] ?? '', qty: (j['qty'] as num?)?.toInt() ?? 1);
}

class Order {
  final String id, userId, userName, userRole, date;
  final List<OrderItem> items;
  String status;
  double total;
  double points;
  double stored;
  String invoiceNo;
  Order({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.date,
    required this.items,
    this.status = 'pending',
    this.total = 0,
    this.points = 0,
    this.stored = 0,
    this.invoiceNo = '',
  });
  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'userName': userName,
        'userRole': userRole,
        'date': date,
        'items': items.map((e) => e.toJson()).toList(),
        'status': status,
        'total': total,
        'points': points,
        'stored': stored,
        'invoiceNo': invoiceNo,
      };
  factory Order.fromJson(Map<String, dynamic> j) => Order(
        id: j['id'] ?? '',
        userId: j['userId'] ?? '',
        userName: j['userName'] ?? '',
        userRole: j['userRole'] ?? '',
        date: j['date'] ?? '',
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => OrderItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        status: j['status'] ?? 'pending',
        total: (j['total'] as num?)?.toDouble() ?? 0,
        points: (j['points'] as num?)?.toDouble() ?? 0,
        stored: (j['stored'] as num?)?.toDouble() ?? 0,
        invoiceNo: j['invoiceNo'] ?? '',
      );
}

class OrdersService {
  static Future<void> _putJson(String path, dynamic data) async {
    // ✅ لقطة حماية: نسخة كاملة من آخر نشر للطلبات
    if (path == kOrdersPath && data is List) {
      _ordersCache = null; // ✅ إبطال الكاش عند النشر
      final m = <String, dynamic>{
        for (final e in data.whereType<Map>()) '${e['id']}': e,
      };
      await _savePushSnapshot(m);
    }
    final body = jsonEncode({
      'path': path,
      'content': base64Encode(utf8.encode(jsonEncode(data))),
    });
    // ✅ مهلة 25 ثانية + إعادة محاولة واحدة (يمنع التعليق للأبد)
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        final r = await http
            .post(
              Uri.parse(kWriteProxy),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )
            .timeout(const Duration(seconds: 25));
        if (r.statusCode == 200 || r.statusCode == 201) return;
        if (attempt == 1) throw Exception('PUT ${r.statusCode}');
      } catch (e) {
        if (attempt == 1) rethrow;
        await Future.delayed(const Duration(seconds: 2));
      }
    }
  }

  static Future<dynamic> _fetchJson(String path) async {
    try {
      final r = await http
          .get(Uri.parse(
              '$_raw/$path?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    try {
      final r = await http
          .get(Uri.parse(
              '$_site/assets/$path?t=${DateTime.now().millisecondsSinceEpoch}'))
          .timeout(const Duration(seconds: 5));
      if (r.statusCode == 200) return jsonDecode(r.body);
    } catch (_) {}
    return [];
  }

  static Future<List<CartItem>> loadCart(String uid) async {
    try {
      final p = await SharedPreferences.getInstance();
      final s = p.getString('cart_$uid');
      if (s == null || s.isEmpty) return [];
      final List<dynamic> l = jsonDecode(s) as List<dynamic>;
      return l.map((e) => CartItem.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveCart(String uid, List<CartItem> items) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
        'cart_$uid', jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  static Future<void> clearCart(String uid) async {
    final p = await SharedPreferences.getInstance();
    await p.remove('cart_$uid');
  }

  /// ✅ إضافة مركزية متسلسلة: قراءة حديثة + كتابة مؤمّنة ضد التعارض
  static Future<void> _cartChain = Future<void>.value();
  static Future<void> addToCart(String uid, String id, String name,
      String image, String brand, int qty) async {
    _cartChain = _cartChain.then((_) async {
      final cart = await loadCart(uid);
      final exist = cart.where((c) => c.id == id).toList();
      if (exist.isNotEmpty) {
        exist.first.qty += qty;
      } else {
        cart.add(CartItem(
            id: id, name: name, image: image, brand: brand, qty: qty));
      }
      await saveCart(uid, cart);
    });
    await _cartChain;
  }

  // ====================================================
  // 🚀 طبقة محلية: إخفاء/تحديث فوري قبل وصول السيرفر
  // ====================================================
  static const String _kTombKey = 'orders_tombstones';
  static const String _kStatusKey = 'orders_status_override';

  static Future<Map<String, int>> _loadTombs() async {
    final p = await SharedPreferences.getInstance();
    final m = <String, int>{};
    for (final e in (p.getStringList(_kTombKey) ?? [])) {
      final i = e.lastIndexOf('|');
      if (i > 0) {
        m[e.substring(0, i)] = int.tryParse(e.substring(i + 1)) ?? 0;
      }
    }
    return m;
  }

  static Future<void> _saveTombs(Map<String, int> m) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    m.removeWhere((_, exp) => exp < now);
    final p = await SharedPreferences.getInstance();
    await p.setStringList(
        _kTombKey, m.entries.map((e) => '${e.key}|${e.value}').toList());
  }

  static Future<void> _markTomb(String id) async {
    _ordersCache = null; // ✅ إبطال الكاش
    final m = await _loadTombs();
    m[id] = DateTime.now().millisecondsSinceEpoch + 86400000;
    await _saveTombs(m);
  }

  static Future<Map<String, String>> _loadOverrides() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kStatusKey);
    if (s == null || s.isEmpty) return {};
    try {
      return Map<String, String>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveOverrides(Map<String, String> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStatusKey, jsonEncode(m));
  }

  static const String _kStatusTimesKey = 'orders_status_times';

  static Future<Map<String, int>> _loadStatusTimes() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kStatusTimesKey);
    if (s == null || s.isEmpty) return {};
    try {
      final m = jsonDecode(s) as Map;
      return m.map((k, v) => MapEntry('$k', (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveStatusTimes(Map<String, int> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kStatusTimesKey, jsonEncode(m));
  }

  // ====================================================
  // 📸 لقطة آخر نشر: حماية المبالغ/الفواتير غير الملتحقة
  // ====================================================
  static const String _kPushSnapKey = 'orders_last_push_snapshot';

  static Future<Map<String, dynamic>> _loadPushSnapshot() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kPushSnapKey);
    if (s == null || s.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  static Future<void> _savePushSnapshot(Map<String, dynamic> m) async {
    // ✅ احتفظ بآخر 60 طلباً فقط (حدّ التخزين)
    final keys = m.keys.toList();
    if (keys.length > 60) {
      for (final k in keys.take(keys.length - 60)) {
        m.remove(k);
      }
    }
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPushSnapKey, jsonEncode(m));
  }

  static Future<void> _saveOverride(String id, String status) async {
    _ordersCache = null; // ✅ إبطال الكاش
    final m = await _loadOverrides();
    m[id] = status;
    await _saveOverrides(m);
    final t = await _loadStatusTimes();
    t[id] = DateTime.now().millisecondsSinceEpoch;
    await _saveStatusTimes(t);
  }

  static List<Order>? _ordersCache;
  static int _ordersCacheAt = 0;
  static Future<List<Order>> loadOrders({bool force = false}) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (!force && _ordersCache != null && now - _ordersCacheAt < 8000) {
      return List<Order>.from(_ordersCache!);
    }
    final d = await _fetchJson(kOrdersPath);
    List<Order> list = [];
    if (d is List) {
      final seen = <String>{};
      for (final e in d) {
        final o = Order.fromJson(e as Map<String, dynamic>);
        if (seen.contains(o.id)) continue; // ✅ إخفاء السطر المكرر
        seen.add(o.id);
        list.add(o);
      }
    }
    // ✅ دمج طلبات Firestore مع إزالة التكرار بالمعرّف
    try {
      final fire = await ordersRepo.list().timeout(const Duration(seconds: 5));
      final ids = list.map((o) => o.id).toSet();
      for (final f in fire) {
        if (!ids.contains(f.id)) {
          list.add(Order(
            id: f.id,
            userId: f.userId,
            userName: f.userName,
            userRole: f.userRole,
            date: f.date,
            invoiceNo: f.invoiceNo,
            status: f.status,
            total: f.total,
            items: f.items
                .map((it) => OrderItem(name: it.name, qty: it.qty))
                .toList(),
          ));
        }
      }
    } catch (_) {}
    // ✅ دمج الطلبات المحلية المرسلة حديثاً (تظهر فوراً)
    try {
      final local = await loadSubmittedLocal();
      final ids2 = list.map((o) => o.id).toSet();
      for (final o in local) {
        if (!ids2.contains(o.id)) list.add(o);
      }
    } catch (_) {}
    try {
      // ✅ إخفاء المحذوف محلياً + تنظيف السجل عند تطابق السيرفر
      final tombs = await _loadTombs();
      if (tombs.isNotEmpty) {
        final serverIds = list.map((o) => o.id).toSet();
        tombs.removeWhere((id, _) => !serverIds.contains(id));
        await _saveTombs(tombs);
        list.removeWhere((o) => tombs.containsKey(o.id));
      }
      // ✅ تطبيق الحالة المحلية فوراً + مسحها عند لحاق السيرفر
      final ov = await _loadOverrides();
      if (ov.isNotEmpty) {
        bool changed = false;
        final snap = await _loadPushSnapshot();
        for (final o in list) {
          final st = ov[o.id];
          if (st != null) {
            // ✅ استكمل السعر/الفاتورة/النقاط من لقطة آخر نشر
            final sn = snap[o.id];
            if (sn is Map) {
              o.total = (sn['total'] as num?)?.toDouble() ?? o.total;
              o.invoiceNo = '${sn['invoiceNo'] ?? ''}';
              o.points = (sn['points'] as num?)?.toDouble() ?? o.points;
              o.stored = (sn['stored'] as num?)?.toDouble() ?? o.stored;
            }
            // ✅ لا تُزل الحماية إلا بعد لحاق الحالة والسعر معاً
            final serverOk = o.status == st &&
                (sn == null ||
                    ((sn['total'] as num?)?.toDouble() ?? -1) == o.total);
            if (serverOk) {
              ov.remove(o.id);
              changed = true;
            } else {
              o.status = st;
            }
          }
        }
        if (changed) {
          await _saveOverrides(ov);
          final t = await _loadStatusTimes();
          t.removeWhere((id, _) => !ov.containsKey(id));
          await _saveStatusTimes(t);
        }
      }
    } catch (_) {}
    _ordersCache = List<Order>.from(list);
    _ordersCacheAt = DateTime.now().millisecondsSinceEpoch;
    return list;
  }

  // ====================================================
  // 🆕 طلبات مُرسَلة حديثاً (تظهر فوراً قبل لحاق السيرفر)
  // ====================================================
  static const String _kSubmittedKey = 'submitted_orders_local';

  /// ✅ حفظ الطلب محلياً ليظهر فوراً في "قيد المراجعة"
  static Future<void> _saveSubmittedLocal(Order o) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSubmittedKey);
    final List<dynamic> list =
        raw == null || raw.isEmpty ? [] : (jsonDecode(raw) as List);
    // تجنب التكرار
    list.removeWhere((e) => e is Map && e['id'] == o.id);
    list.insert(0, o.toJson());
    await p.setString(_kSubmittedKey, jsonEncode(list));
  }

  /// ✅ قراءة الطلبات المحلية (لدمجها مع طلبات السيرفر)
  static Future<List<Order>> loadSubmittedLocal() async {
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString(_kSubmittedKey);
      if (raw == null || raw.isEmpty) return [];
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((e) => Order.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  /// ✅ حذف الطلبات المحلية التي وصلت للسيرفر
  static Future<void> cleanMergedSubmitted(Set<String> serverIds) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kSubmittedKey);
    if (raw == null || raw.isEmpty) return;
    final list = jsonDecode(raw) as List;
    final before = list.length;
    list.removeWhere((e) => e is Map && serverIds.contains(e['id']));
    if (list.length != before) {
      if (list.isEmpty) {
        await p.remove(_kSubmittedKey);
      } else {
        await p.setString(_kSubmittedKey, jsonEncode(list));
      }
    }
  }

  static Future<void> submitOrder(Order o) async {
    // ✅ كتابة مباشرة إلى Firestore
    try {
      await ordersRepo.add(FireOrder(
        id: o.id,
        userId: o.userId,
        userName: o.userName,
        userRole: o.userRole,
        phone: '',
        date: o.date,
        status: o.status,
        total: o.total,
        invoiceNo: o.invoiceNo ?? '',
        items: o.items
            .map((it) => FireOrderItem(name: it.name, qty: it.qty))
            .toList(),
      ));
    } catch (_) {}
    // ✅ 1) حفظ فوري محلياً ← يظهر فوراً في "قيد المراجعة"
    await _saveSubmittedLocal(o);
    // ✅ 2) إرسال للمستودع بالخلفية
    try {
      final list = await loadOrders();
      list.removeWhere((x) => x.id == o.id); // ✅ منع التكرار
      list.add(o);
      await _putJson(kOrdersPath, list.map((e) => e.toJson()).toList());
    } catch (_) {
      // الإرسال فشل ← الطلب يبقى محلياً حتى المحاولة التالية
    }
  }

  static Future<void> updateOrder(Order o) async {
    await _saveOverride(o.id, o.status); // ✅ الحالة تتحدث فوراً محلياً
    final list = await loadOrders();
    list.removeWhere((x) => x.id == o.id); // ✅ منع التكرار
    list.add(o);
    await _putJson(kOrdersPath, list.map((e) => e.toJson()).toList());
  }

  static Future<void> deleteOrder(String id) async {
    await _markTomb(id); // ✅ إخفاء فوري محلياً قبل إرسال الحذف
    final list = await loadOrders();
    list.removeWhere((x) => x.id == id);
    await _putJson(kOrdersPath, list.map((e) => e.toJson()).toList());
  }

  // ====================================================
  // 🗑 Tombstones للفواتير/المرتجعات: إخفاء فوري + حذف بالخلفية
  // ====================================================
  static const String _kInvTombKey = 'inv_tombstones';
  static const String _kRetTombKey = 'ret_tombstones';
static const String _kInvPatchKey = 'inv_patches_local';
  static const String _kRetPatchKey = 'ret_patches_local';
  static Future<Set<String>> _loadSet(String key) async {
    final p = await SharedPreferences.getInstance();
    return (p.getStringList(key) ?? []).toSet();
  }

  static Future<void> _saveSet(String key, Set<String> v) async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(key, v.toList());
  }

  /// ✅ طوابع الحذف للقراءة الموحّدة من كل الشاشات
  static Future<Set<String>> invoiceTombs() => _loadSet(_kInvTombKey);
  static Future<Set<String>> returnTombs() => _loadSet(_kRetTombKey);

  static Future<void> markInvoiceDeleted(String id) async {
    final s = await _loadSet(_kInvTombKey);
    s.add(id);
    await _saveSet(_kInvTombKey, s);
  }

  static Future<Map<String, Map<String, dynamic>>> _loadInvPatches() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kInvPatchKey);
    if (s == null || s.isEmpty) return {};
    try {
      final raw = jsonDecode(s) as Map;
      return raw.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveInvPatches(Map<String, Map<String, dynamic>> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kInvPatchKey, jsonEncode(m));
  }

  static Future<Map<String, Map<String, dynamic>>> _loadRetPatches() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kRetPatchKey);
    if (s == null || s.isEmpty) return {};
    try {
      final raw = jsonDecode(s) as Map;
      return raw.map((k, v) => MapEntry('$k', Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> _saveRetPatches(Map<String, Map<String, dynamic>> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kRetPatchKey, jsonEncode(m));
  }

  static Future<void> markInvoicePatched(
      String id, Map<String, dynamic> patch) async {
    final m = await _loadInvPatches();
    m[id] = patch;
    await _saveInvPatches(m);
  }

  static Future<void> markReturnPatched(
      String id, Map<String, dynamic> patch) async {
    final m = await _loadRetPatches();
    m[id] = patch;
    await _saveRetPatches(m);
  }
static const String _kHistTombKey = 'hist_tombstones';
  static const String _kHistPatchKey = 'hist_patches_local';

  static Future<Set<String>> loadHistTombs() async =>
      _loadSet(_kHistTombKey);

  static Future<void> markHistDeleted(String key) async {
    final s = await _loadSet(_kHistTombKey);
    s.add(key);
    await _saveSet(_kHistTombKey, s);
  }

  static Future<Map<String, Map<String, dynamic>>> loadHistPatches() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kHistPatchKey);
    if (s == null || s.isEmpty) return {};
    try {
      final raw = jsonDecode(s) as Map;
      return raw.map((k, v) =>
          MapEntry('$k', Map<String, dynamic>.from(v as Map)));
    } catch (_) {
      return {};
    }
  }

  static Future<void> markHistPatched(
      String key, Map<String, dynamic> patch) async {
    final p = await SharedPreferences.getInstance();
    final m = await loadHistPatches();
    m[key] = patch;
    await p.setString(_kHistPatchKey, jsonEncode(m));
  }

  static Future<void> publishInvoicePatch(String id) async {
    final patches = await _loadInvPatches();
    final p = patches[id];
    if (p == null) return;
    final invs = await _fetchJson('assets/data/invoices.json');
    if (invs is List) {
      final i = invs.indexWhere((e) => e is Map && e['id'] == id);
      if (i >= 0) {
        final m = Map<String, dynamic>.from(invs[i] as Map);
        m.addAll(p);
        invs[i] = m;
        await _putJson('assets/data/invoices.json', invs);
        patches.remove(id);
        await _saveInvPatches(patches);
        final uid = '${m['userId'] ?? ''}';
        if (uid.isNotEmpty) {
          await recalcUserTotals(uid, invoices: invs);
        }
      }
    }
  }

  static Future<void> publishReturnPatch(String id, bool legacy) async {
    final patches = await _loadRetPatches();
    final p = patches[id];
    if (p == null) return;
    if (legacy) {
      final invs = await _fetchJson('assets/data/invoices.json');
      if (invs is List) {
        final i = invs.indexWhere((e) => e is Map && e['id'] == id);
        if (i >= 0) {
          final m = Map<String, dynamic>.from(invs[i] as Map);
          m.addAll(p);
          invs[i] = m;
          await _putJson('assets/data/invoices.json', invs);
          patches.remove(id);
          await _saveRetPatches(patches);
        }
      }
    } else {
      final rets = await loadReturns();
      final i = rets.indexWhere((e) => '${e['id']}' == id);
      if (i >= 0) {
        rets[i].addAll(p);
        await _putJson('assets/data/returns.json', rets);
        patches.remove(id);
        await _saveRetPatches(patches);
      }
    }
  }
  static Future<void> markReturnDeleted(String id) async {
    final s = await _loadSet(_kRetTombKey);
    s.add(id);
    await _saveSet(_kRetTombKey, s);
  }

  // ====================================================
  // 👤 طوابع حذف المستخدمين: إخفاء فوري + حذف بالخلفية
  // ====================================================
  static const String _kUserTombKey = 'user_tombstones';

  static Future<void> markUserDeleted(String id) async {
    final s = await _loadSet(_kUserTombKey);
    s.add(id);
    await _saveSet(_kUserTombKey, s);
  }

  static Future<void> markOrderDeleted(String id) async {
    await _markTomb(id);
  }

  static const String _kUserPatchKey = 'user_patches_local';

  static Future<Map<String, dynamic>> _loadUserPatches() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kUserPatchKey);
    if (s == null || s.isEmpty) return {};
    try {
      return Map<String, dynamic>.from(jsonDecode(s) as Map);
    } catch (_) {
      return {};
    }
  }

  /// ✅ حفظ تعديل محلي (يظهر فوراً ويُنى تلقائياً عند لحاق السيرفر)
  static Future<void> markUserPatched(
      String id, Map<String, dynamic> patch) async {
    final p = await SharedPreferences.getInstance();
    final m = await _loadUserPatches();
    m[id] = patch;
    await p.setString(_kUserPatchKey, jsonEncode(m));
  }

  /// ✅ المستخدمون: استبعاد المحذوفين + تطبيق التعديلات المحلية
  static Future<List<User>> loadUsersFiltered() async {
    final list = await StoreService.loadUsers();
    final tombs = await _loadSet(_kUserTombKey);
    if (tombs.isNotEmpty) {
      final ids = list.map((e) => e.id).toSet();
      tombs.removeWhere((id) => !ids.contains(id));
      await _saveSet(_kUserTombKey, tombs);
      list.removeWhere((e) => tombs.contains(e.id));
    }
    final patches = await _loadUserPatches();
    if (patches.isNotEmpty) {
      bool cleaned = false;
      for (final u in list) {
        final pt = patches[u.id];
        if (pt is! Map) continue;
        final cur = u.toJson();
        bool matches = true;
        pt.forEach((k, v) {
          if ('${cur[k] ?? ''}' != '${v ?? ''}') matches = false;
        });
        if (matches) {
          // ✅ السيرفر لحق ← نظّف الرقعة
          patches.remove(u.id);
          cleaned = true;
        } else {
          // ✅ طبّق التعديل المحلي فوراً
          u.name = '${pt['name'] ?? u.name}';
          u.phone = '${pt['phone'] ?? u.phone}';
          u.password = '${pt['password'] ?? u.password}';
          u.role = '${pt['role'] ?? u.role}';
          u.points = (pt['points'] as num?)?.toInt() ?? u.points;
          u.stored = (pt['stored'] as num?)?.toInt() ?? u.stored;
        }
      }
      patches.removeWhere((id, _) => !list.any((u) => u.id == id));
      if (cleaned || patches.isEmpty) {
        final p = await SharedPreferences.getInstance();
        await p.setString(_kUserPatchKey, jsonEncode(patches));
      }
    }
    return list;
  }

  static Future<List<Invoice>> loadInvoicesFiltered() async {
    final list = await StoreService.loadInvoices();
    // ✅ دمج فوري من ثلاث مصادر: Firestore + محلي + JSON (لا يعتمد على loadOrders)
    final tombs0 = await _loadSet(_kInvTombKey);
    final onlineIds = <String>{};
    try {
      final ids = list.map((e) => e.id).toSet();
      // 1) طلبات Firestore المقبولة مباشرة
      List<Order> fireOrders = [];
      try {
        final fo = await ordersRepo.list().timeout(const Duration(seconds: 5));
        fireOrders = fo
            .map((f) => Order(
                  id: f.id,
                  userId: f.userId,
                  userName: f.userName,
                  userRole: f.userRole,
                  date: f.date,
                  invoiceNo: f.invoiceNo,
                  status: f.status,
                  total: f.total,
                  items: f.items
                      .map((it) => OrderItem(name: it.name, qty: it.qty))
                      .toList(),
                ))
            .toList();
      } catch (_) {}
      // 2) الطلبات المقبولة محلياً (ظهرت فوراً عند القبول)
      List<Order> localOrders = [];
      try {
        localOrders = await loadSubmittedLocal();
      } catch (_) {}
      // 3) الطلبات من JSON
      List<Order> jsonOrders = [];
      try {
        final d = await _fetchJson(kOrdersPath);
        if (d is List) {
          jsonOrders = d
              .map((e) => Order.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {}

      // دمج الكل بدون تكرار
      final all = <Order>[...fireOrders, ...localOrders, ...jsonOrders];
      final seen = <String>{};
      for (final o in all) {
        if (seen.contains(o.id)) continue;
        seen.add(o.id);
        if (o.status != 'accepted' && o.status != 'completed') continue;
        onlineIds.add(o.id);
        if (tombs0.contains(o.id)) continue;
        if (ids.contains(o.id)) continue;
        list.add(Invoice(
          id: o.id,
          userId: o.userId,
          no: o.invoiceNo,
          date: o.date,
          total: o.total,
          points: o.points.toInt(),
          stored: o.stored.toInt(),
          type: 'sale',
          source: 'online',
          items: o.items
              .map((e) => InvoiceItem(name: e.name, price: 0, qty: e.qty))
              .toList(),
        ));
      }
    } catch (_) {}
    final tombs = await _loadSet(_kInvTombKey);
    if (tombs.isNotEmpty) {
      list.removeWhere((e) => tombs.contains(e.id));
      // ✅ تنظيف رجعي مرة واحدة فقط وبالتوازي (لا يبطئ كل فتح)
      final p = await SharedPreferences.getInstance();
      final done = (p.getStringList('inv_fire_cleaned') ?? []).toSet();
      final pending = tombs.where((id) => !done.contains(id)).toList();
      if (pending.isNotEmpty) {
        try {
          await Future.wait([
            for (final id in pending)
              invoiceRepo.delete(id).catchError((_) {})
          ]);
        } catch (_) {}
        done.addAll(pending);
        await p.setStringList('inv_fire_cleaned', done.toList());
      }
    }
    // ✅ تطبيق التعديلات المحلية على الفواتير
    final patches = await _loadInvPatches();
    if (patches.isNotEmpty) {
      for (int i = 0; i < list.length; i++) {
        final p = patches[list[i].id];
        if (p != null) {
          list[i] = Invoice(
            id: list[i].id,
            userId: list[i].userId,
            no: '${p['no'] ?? list[i].no}',
            date: '${p['date'] ?? list[i].date}',
            total: (p['total'] as num?)?.toDouble() ?? list[i].total,
            points: (p['points'] as num?)?.toInt() ?? list[i].points,
            stored: (p['stored'] as num?)?.toInt() ?? list[i].stored,
            type: list[i].type,
            items: list[i].items,
            legacyNo: list[i].legacyNo,
            customerName: list[i].customerName,
            cashier: list[i].cashier,
            time: list[i].time,
            source: list[i].source,
          );
        }
      }
    }
    return list;
  }

  static Future<List<Map<String, dynamic>>> loadReturnsFiltered() async {
    final list = await loadReturns();
    final tombs = await _loadSet(_kRetTombKey);
    if (tombs.isNotEmpty) {
      list.removeWhere((e) => tombs.contains('${e['id']}'));
      final p = await SharedPreferences.getInstance();
      final done = (p.getStringList('ret_fire_cleaned') ?? []).toSet();
      final pending = tombs.where((id) => !done.contains(id)).toList();
      if (pending.isNotEmpty) {
        try {
          await Future.wait([
            for (final id in pending)
              returnsRepo.delete(id).catchError((_) {})
          ]);
        } catch (_) {}
        done.addAll(pending);
        await p.setStringList('ret_fire_cleaned', done.toList());
      }
    }
    // ✅ تطبيق التعديلات المحلية على المرتجعات
    final patches = await _loadRetPatches();
    if (patches.isNotEmpty) {
      for (int i = 0; i < list.length; i++) {
        final id = '${list[i]['id']}';
        final p = patches[id];
        if (p != null) {
          list[i] = Map<String, dynamic>.from(list[i])
            ..['total'] = p['total'] ?? list[i]['total']
            ..['points'] = p['points'] ?? list[i]['points']
            ..['stored'] = p['stored'] ?? list[i]['stored']
            ..['date'] = p['date'] ?? list[i]['date']
            ..['no'] = p['no'] ?? list[i]['no'];
        }
      }
    }
    return list;
  }

  /// ✅ فك تعليق المزامنة: إعادة نشر بعد دقيقتين، وتحرير إجباري بعد 4 دقائق
  static Future<String> resolveStaleSync() async {
    final ov = await _loadOverrides();
    if (ov.isEmpty) return 'ok';
    final t = await _loadStatusTimes();
    final now = DateTime.now().millisecondsSinceEpoch;
    int maxAge = 0;
    for (final id in ov.keys) {
      final age = now - (t[id] ?? now);
      if (age > maxAge) maxAge = age;
    }
    if (maxAge < 120000) return 'waiting';
    if (maxAge < 240000) {
      // ✅ إعادة محاولة واحدة كل 60 ثانية فقط (منع تكرار النشر)
      final p = await SharedPreferences.getInstance();
      final last = p.getInt('sync_last_retry_ms') ?? 0;
      if (now - last < 60000) return 'retry_wait';
      await p.setInt('sync_last_retry_ms', now);
      try {
        final list = await loadOrders();
        await _putJson(kOrdersPath, list.map((e) => e.toJson()).toList());
        return 'retry';
      } catch (_) {
        return 'retry_failed';
      }
    }
    // ✅ بعد 4 دقائق: محاولة نشر أخيرة كاملة ثم تحرير إجباري
    try {
      final list = await loadOrders();
      await _putJson(kOrdersPath, list.map((e) => e.toJson()).toList());
    } catch (_) {}
    await _saveOverrides({});
    await _saveStatusTimes({});
    final p2 = await SharedPreferences.getInstance();
    await p2.remove('sync_since_ms');
    await p2.remove('sync_name');
    return 'cleared';
  }

  /// ✅ هل توجد عملية لم تصل للسيرفر بعد؟ (حذف/حالة معلّقة محلياً)
  static Future<bool> hasPendingSync() async {
    final ov = await _loadOverrides();
    if (ov.isNotEmpty) return true;
    final tombs = await _loadTombs();
    return tombs.isNotEmpty;
  }

  /// ✅ حساب نقاط ورصيد وبيانات محفظة المستخدم — نفس مصدر المحفظة الأصلي
  static Future<({int points, int stored, List<Invoice> invoices, List<Map<String, dynamic>> returns})>
      computeUserWallet(String uid) async {
    // 1) توحيد حسابات الهاتف (حساب العميل + أي حساب بنفس الرقم)
    final ids = <String>{uid};
    try {
      String ph = '';
      final jsonUsers = await StoreService.loadUsers();
      for (final x in jsonUsers) {
        if (x.id == uid) ph = x.phone.trim();
      }
      if (ph.isEmpty) {
        try {
          for (final x in await userRepo.listUsers()) {
            if (x.id == uid) ph = x.phone.trim();
          }
        } catch (_) {}
      }
      if (ph.isNotEmpty) {
        for (final x in jsonUsers) {
          if (x.phone.trim() == ph) ids.add(x.id);
        }
        try {
          for (final x in await userRepo.listUsers()) {
            if (x.phone.trim() == ph) ids.add(x.id);
          }
        } catch (_) {}
      }
    } catch (_) {}

    // 2) ✅ الفواتير من Firestore مباشرة مع الطوابع (نفس منطق المحفظة الأصلي)
    final invTombs = await _loadSet(_kInvTombKey);
    final fireInvs = (await invoiceRepo.list())
        .where((f) => !invTombs.contains(f.id))
        .toList();
    final invs = fireInvs
        .where((f) => ids.contains(f.userId) && f.type != 'return')
        .map((f) => Invoice(
              id: f.id,
              userId: f.userId,
              no: f.no,
              date: f.date,
              total: f.total,
              points: f.points,
              stored: f.stored,
              type: f.type,
              items: f.items
                  .map((it) => InvoiceItem.fromJson(it.toMap()))
                  .toList(),
              legacyNo: f.legacyNo,
              customerName: f.customerName,
              cashier: f.cashier,
              time: f.time,
              source: f.source,
            ))
        .toList();

    // 3) ✅ المرتجعات من Firestore مباشرة مع الطوابع
    final retTombs = await _loadSet(_kRetTombKey);
    final fireRets = (await returnsRepo.list())
        .where((f) => !retTombs.contains(f.id))
        .toList();
    final rets = <Map<String, dynamic>>[
      ...fireRets
          .where((f) => ids.contains(f.userId))
          .map((f) => <String, dynamic>{
                'id': f.id,
                'orderId': f.orderId,
                'userId': f.userId,
                'date': f.date,
                'no': f.no,
                'purchaseNo': f.purchaseNo,
                'total': f.total,
                'points': f.points,
                'stored': f.stored,
                'items': f.items.map((it) => it.toMap()).toList(),
                'legacy': false,
              }),
      ...fireInvs
          .where((f) => ids.contains(f.userId) && f.type == 'return')
          .map((f) => <String, dynamic>{
                'id': f.id,
                'orderId': '',
                'userId': f.userId,
                'date': f.date,
                'no': f.no,
                'purchaseNo': f.legacyNo,
                'total': -f.total.abs().toInt(),
                'points': -f.points.abs(),
                'stored': -f.stored.abs(),
                'items': f.items.map((it) => it.toMap()).toList(),
                'legacy': true,
              }),
    ];

    // 4) حساب النقاط والرصيد بنفس منطق المحفظة (صافي المشتريات)
    int sales = 0;
    int retTotal = 0;
    for (final i in invs) {
      if (i.type == 'sale') {
        sales += i.total.toInt();
      } else if (i.type == 'return') {
        retTotal += i.total.toInt().abs();
      }
    }
    for (final r in rets) {
      retTotal += ((r['total'] as num?)?.toInt() ?? 0).abs();
    }
    final net = (sales - retTotal).clamp(0, 999999999);
    return (
      points: net ~/ kPointUnit,
      stored: net % kPointUnit,
      invoices: invs,
      returns: rets,
    );
  }


  /// ✅ إعادة احتساب نقاط/رصيد مستخدم من صافي المشتريات (شراء − مرتجع)
  static Future<void> recalcUserTotals(String userId,
      {List<dynamic>? invoices}) async {
    final invs = invoices ?? await _fetchJson('assets/data/invoices.json');
    if (invs is! List) return;
    // ✅ دمج الطلبات المقبولة مباشرة من Firestore + المحلي (لا JSON)
    try {
      final tombsR = await _loadSet(_kInvTombKey);
      invs.removeWhere((e) => e is Map && tombsR.contains('${e['id']}'));
      final ids = invs.whereType<Map>().map((e) => '${e['id']}').toSet();
      // طلبات Firestore مباشرة
      List<Order> fireOrders = [];
      try {
        final fo = await ordersRepo.list().timeout(const Duration(seconds: 5));
        fireOrders = fo
            .map((f) => Order(
                  id: f.id,
                  userId: f.userId,
                  userName: f.userName,
                  userRole: f.userRole,
                  date: f.date,
                  invoiceNo: f.invoiceNo,
                  status: f.status,
                  total: f.total,
                  items: f.items
                      .map((it) => OrderItem(name: it.name, qty: it.qty))
                      .toList(),
                ))
            .toList();
      } catch (_) {}
      // الطلبات المحلية الفورية
      List<Order> localOrders = [];
      try {
        localOrders = await loadSubmittedLocal();
      } catch (_) {}
      final all = <Order>[...fireOrders, ...localOrders];
      final seen = <String>{};
      for (final o in all) {
        if (seen.contains(o.id)) continue;
        seen.add(o.id);
        if (tombsR.contains(o.id)) continue;
        if (o.userId != userId) continue;
        if (o.status != 'accepted' && o.status != 'completed') continue;
        if (ids.contains(o.id)) continue;
        invs.add({
          'id': o.id,
          'userId': o.userId,
          'date': o.date,
          'type': 'sale',
          'no': o.invoiceNo,
          'total': o.total,
          'points': o.points.toInt(),
          'stored': o.stored.toInt(),
          'source': 'online',
        });
      }
    } catch (_) {}
    int sales = 0;
    int rets = 0;
    for (final i in invs) {
      if (i is Map && i['userId'] == userId) {
        if (i['type'] == 'sale') {
          sales += ((i['total'] as num?)?.toInt() ?? 0);
        } else if (i['type'] == 'return') {
          rets += ((i['total'] as num?)?.toInt() ?? 0).abs();
        }
      }
    }
    final retList = await loadReturns();
    for (final r in retList) {
      if (r['userId'] == userId) {
        rets += ((r['total'] as num?)?.toInt() ?? 0).abs();
      }
    }
    final net = (sales - rets).clamp(0, 999999999);
    final pts = net ~/ kPointUnit;
    final st = net % kPointUnit;
    final users = await _fetchJson('assets/data/users.json');
    if (users is List) {
      bool ch = false;
      for (final u in users) {
        if (u is Map && u['id'] == userId) {
          u['points'] = pts;
          u['stored'] = st;
          ch = true;
        }
      }
      if (ch) await _putJson('assets/data/users.json', users);
    }
  }

  static Future<List<Map<String, dynamic>>> loadReturns() async {
    final d = await _fetchJson('assets/data/returns.json');
    if (d is List) {
      return d.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    }
    return [];
  }

  static Future<void> deleteInvoice(String id) async {
    await markInvoiceDeleted(id); // ✅ إخفاء فوري محلياً قبل دفع الحذف
    // ✅ حذف من Firestore حتى لا تعود الفاتورة عند أي ترحيل
    try {
      await invoiceRepo.delete(id);
    } catch (_) {}
    // ✅ حذف مرتجعاتها من مجموعة المرتجعات في Firestore
    try {
      final fireRets = await returnsRepo.list();
      for (final r in fireRets.where((x) => x.orderId == id)) {
        await returnsRepo.delete(r.id);
      }
    } catch (_) {}
    final invs = await _fetchJson('assets/data/invoices.json');
    String uid = '';
    if (invs is List) {
      for (final i in invs) {
        if (i is Map && i['id'] == id) {
          uid = '${i['userId'] ?? ''}';
          break;
        }
      }
      invs.removeWhere((i) => i is Map && i['id'] == id);
      await _putJson('assets/data/invoices.json', invs);
    }
    final rets = await loadReturns();
    if (rets.isNotEmpty) {
      rets.removeWhere((r) => r['orderId'] == id);
      await _putJson('assets/data/returns.json', rets);
    }
    if (uid.isNotEmpty) await recalcUserTotals(uid);
  }

  static Future<void> deleteReturn(String id) async {
    await markReturnDeleted(id); // ✅ إخفاء فوري محلياً قبل دفع الحذف
    // ✅ حذف المرتجع من Firestore حتى لا يعود عند الترحيل
    try {
      await returnsRepo.delete(id);
    } catch (_) {}
    final rets = await loadReturns();
    String uid = '';
    for (final r in rets) {
      if (r['id'] == id) {
        uid = '${r['userId'] ?? ''}';
        break;
      }
    }
    rets.removeWhere((r) => r['id'] == id);
    await _putJson('assets/data/returns.json', rets);
    if (uid.isNotEmpty) await recalcUserTotals(uid);
  }

  static Future<void> deleteUserAll(String userId) async {
    await markUserDeleted(userId); // ✅ إخفاء فوري محلياً
    // ✅ حذف من Firestore حتى لا يعود الحساب من هناك أبداً
    try {
      final db = FirebaseFirestore.instance;
      final invSnap = await db
          .collection('invoices')
          .where('userId', isEqualTo: userId)
          .get();
      final retSnap = await db
          .collection('returns')
          .where('userId', isEqualTo: userId)
          .get();
      final ordSnap = await db
          .collection('orders')
          .where('userId', isEqualTo: userId)
          .get();
      WriteBatch? batch;
      int n = 0;
      for (final d in [...invSnap.docs, ...retSnap.docs, ...ordSnap.docs]) {
        batch ??= db.batch();
        batch.delete(d.reference);
        n++;
        if (n >= 400) {
          await batch.commit();
          batch = null;
          n = 0;
        }
      }
      if (batch != null) await batch.commit();
      await db.collection('users').doc(userId).delete();
    } catch (_) {}
    final users = await _fetchJson('assets/data/users.json');
    if (users is List) {
      users.removeWhere((u) => u is Map && u['id'] == userId);
      await _putJson('assets/data/users.json', users);
    }
    final invs = await _fetchJson('assets/data/invoices.json');
    if (invs is List) {
      invs.removeWhere((i) => i is Map && i['userId'] == userId);
      await _putJson('assets/data/invoices.json', invs);
    }
    final rets = await _fetchJson('assets/data/returns.json');
    if (rets is List) {
      rets.removeWhere((r) => r is Map && r['userId'] == userId);
      await _putJson('assets/data/returns.json', rets);
    }
    final orders = await loadOrders();
    orders.removeWhere((o) => o.userId == userId);
    await _putJson(kOrdersPath, orders.map((e) => e.toJson()).toList());
  }

  static Future<void> patchUser(
      String id, Map<String, dynamic> patch) async {
    final users = await _fetchJson('assets/data/users.json');
    if (users is List) {
      final i = users.indexWhere((u) => u is Map && u['id'] == id);
      if (i >= 0) {
        final m = Map<String, dynamic>.from(users[i] as Map);
        m.addAll(patch);
        users[i] = m;
        await _putJson('assets/data/users.json', users);
      }
    }
  }

  static Future<void> addUserRaw(Map<String, dynamic> entry) async {
    final users = await _fetchJson('assets/data/users.json');
    if (users is List) {
      users.add(entry);
      await _putJson('assets/data/users.json', users);
    } else {
      await _putJson('assets/data/users.json', [entry]);
    }
  }

  static Future<void> acceptOrder(Order o) async {
    o.points = (o.total ~/ kPointUnit).toDouble();
    o.stored = (o.total % kPointUnit).toDouble();
    o.status = 'accepted';
    await updateOrder(o);

    // ✅ كتابة الفاتورة في Firestore مباشرة (تظهر فوراً بدون ترحيل)
    try {
      await invoiceRepo.upsert(FireInvoice(
        id: o.id,
        userId: o.userId,
        date: o.date,
        type: 'sale',
        no: o.invoiceNo,
        total: o.total,
        points: o.points.toInt(),
        stored: o.stored.toInt(),
        source: 'online',
        items: o.items
            .map((it) => FireInvoiceItem(name: it.name, qty: it.qty))
            .toList(),
      ));
    } catch (_) {}

    List<dynamic>? invList;
    final invs = await _fetchJson('assets/data/invoices.json');
    invList = invs is List ? invs : null;
    if (invs is List) {
      invs.add({
        'id': o.id,
        'userId': o.userId,
        'date': o.date,
        'type': 'sale',
        'no': o.invoiceNo,
        'total': o.total,
        'points': o.points.toInt(),
        'stored': o.stored.toInt(),
        'source': 'online',
        'items': o.items
            .map((e) => {'name': e.name, 'price': 0, 'qty': e.qty})
            .toList(),
      });
      await _putJson('assets/data/invoices.json', invs);
    }

    await recalcUserTotals(o.userId, invoices: invList);
  }

  static Future<void> rejectOrder(Order o) async {
    o.status = 'rejected';
    await updateOrder(o);
  }

  static Future<void> markReturned(
    Order o, {
    List<OrderItem>? returnedItems,
    double? customTotal,
    String? customInvoiceNo,
  }) async {
    final items = returnedItems ?? o.items;
    final total = customTotal ?? o.total;
    final invNo = customInvoiceNo ?? '';
    final pts = (total ~/ kPointUnit).toInt();
    final st = (total % kPointUnit).toInt();

    final invs = await _fetchJson('assets/data/invoices.json');
    if (invs is List) {
      final idx = invs.indexWhere(
          (i) => i is Map && i['id'] == o.id && i['type'] == 'sale');
      if (idx >= 0) {
        final sale = Map<String, dynamic>.from(invs[idx] as Map);
        final saleItems = List<Map<String, dynamic>>.from(
            (sale['items'] as List? ?? [])
                .map((e) => Map<String, dynamic>.from(e as Map)));
        for (final ret in items) {
          final match =
              saleItems.where((si) => si['name'] == ret.name).toList();
          if (match.isNotEmpty) {
            match.first['qty'] =
                ((match.first['qty'] as num?)?.toInt() ?? 0) - ret.qty;
          }
        }
        saleItems.removeWhere(
            (si) => ((si['qty'] as num?)?.toInt() ?? 0) <= 0);
        final oldTotal = ((sale['total'] as num?)?.toDouble() ?? 0);
        final newTotal =
            (oldTotal - total).clamp(0.0, double.infinity).toInt();
        sale['items'] = saleItems;
        sale['total'] = newTotal;
        sale['points'] = newTotal ~/ kPointUnit;
        sale['stored'] = newTotal % kPointUnit;
        invs[idx] = sale;
        await _putJson('assets/data/invoices.json', invs);
      }
    }

    final retId = '${o.id}_ret_${DateTime.now().millisecondsSinceEpoch}';
    // ✅ كتابة المرتجع في Firestore مباشرة (يظهر فوراً بدون ترحيل)
    try {
      await returnsRepo.upsert(FireReturn(
        id: retId,
        orderId: o.id,
        userId: o.userId,
        date: DateTime.now().toString().substring(0, 10),
        no: invNo,
        purchaseNo: o.invoiceNo,
        total: total.toInt(),
        points: pts,
        stored: st,
        items: items
            .map((it) => FireInvoiceItem(name: it.name, qty: it.qty))
            .toList(),
      ));
    } catch (_) {}
    final rets = await loadReturns();
    rets.add({
      'id': retId,
      'orderId': o.id,
      'userId': o.userId,
      'date': DateTime.now().toString().substring(0, 10),
      'no': invNo,
      'purchaseNo': o.invoiceNo,
      'total': total.toInt(),
      'points': pts,
      'stored': st,
      'items': items
          .map((e) => {'name': e.name, 'qty': e.qty})
          .toList(),
    });
    await _putJson('assets/data/returns.json', rets);
    await recalcUserTotals(o.userId);
  }

  /// ✅ عدد إشعارات العميل غير المقروءة (حالة تغيّرت منذ آخر مشاهدة)
  static Future<int> unseenCustomerNotifs(String uid) async {
    if (uid.isEmpty) return 0;
    final p = await SharedPreferences.getInstance();
    Map<String, dynamic> seen = {};
    try {
      seen = Map<String, dynamic>.from(
          jsonDecode(p.getString('home_seen_status') ?? '{}') as Map);
    } catch (_) {}
    final orders = await loadOrders();
    int n = 0;
    for (final o in orders) {
      if (o.userId != uid) continue;
      if (o.status != 'accepted' && o.status != 'rejected') continue;
      if ('${seen[o.id] ?? ''}' != o.status) n++;
    }
    return n;
  }

  /// ✅ تعليم كل إشعارات العميل كمقروءة
  static Future<void> markCustomerNotifsSeen(String uid) async {
    if (uid.isEmpty) return;
    final orders = await loadOrders();
    final m = <String, dynamic>{};
    for (final o in orders) {
      if (o.userId == uid) m[o.id] = o.status;
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('home_seen_status', jsonEncode(m));
  }

  static Future<bool> convertStoredToPoints(String userId) async {
    final invs = await _fetchJson('assets/data/invoices.json');
    if (invs is! List) return false;
    int net = 0;
    int existing = 0;
    for (final i in invs) {
      if (i is Map && i['userId'] == userId) {
        net += ((i['stored'] as num?)?.toInt() ?? 0);
        if (i['type'] == 'stored_point') existing++;
      }
    }
    final rets = await loadReturns();
    for (final r in rets) {
      if (r['userId'] == userId) {
        net -= ((r['stored'] as num?)?.toInt() ?? 0);
      }
    }
    final gross = net + existing * kPointUnit;
    final times = gross ~/ kPointUnit;
    if (times <= existing) return false;
    for (int k = existing; k < times; k++) {
      invs.add({
        'id': '${userId}_sp_$k',
        'userId': userId,
        'date': DateTime.now().toString().substring(0, 10),
        'type': 'stored_point',
        'no': 'SP-${k + 1}',
        'total': kPointUnit,
        'points': 1,
        'stored': -kPointUnit,
        'items': const [],
      });
    }
    await _putJson('assets/data/invoices.json', invs);
    return true;
  }
}
