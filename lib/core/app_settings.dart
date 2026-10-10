import 'dart:async';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'messenger.dart';
import 'orders_service.dart';
import 'store_service.dart';
import 'repositories/user_repo.dart' as repo;

class AppSettings extends ChangeNotifier {
  bool _isArabic = true;
  bool _isDark = false;
  bool _isImageAdmin = false;
  User? _user;

  Timer? _pollTimer;
  int _lastPending = -1;
  int _ordersVersion = 0;
  String _lastSig = '';
  int pendingCount = 0;

  // ✅ صمام أمان ضد التعليق عند النقر المتكرر
  int _lastTickMs = 0;
  bool _ticking = false;

  Set<String> _seenIds = {};
  bool _seenLoaded = false;
  int unseenCount = 0;

  bool _listenersAttached = false;

  bool get isArabic => _isArabic;
  bool get isDark => _isDark;
  bool get isImageAdmin => _isImageAdmin;
  bool get isLoggedIn => _user != null;

  /// المتحكم: أعلى صلاحيات في النظام
  bool get isController => _user?.role == 'ctrl';

  /// المدير أو المتحكم
  bool get isAdmin => _user?.role == 'admin' || _user?.role == 'ctrl';

  bool get isGuest => _user == null || _user!.role == 'guest';
  User? get user => _user;
  int get points => _user?.points ?? 0;
  int get stored => _user?.stored ?? 0;
  int get ordersVersion => _ordersVersion;

  String get _seenKey => 'seen_${_user?.id ?? ''}';

  void applyInitial({required bool dark, required bool arabic}) {
    _isDark = dark;
    _isArabic = arabic;
  }

  String tr(String key) {
    const Map<String, Map<String, String>> strings = {
      'appName': {'ar': 'شركة فاوري', 'en': 'FAWORI'},
      'settings': {'ar': 'الإعدادات', 'en': 'Settings'},
      'language': {'ar': 'اللغة', 'en': 'Language'},
      'about': {'ar': 'حول التطبيق', 'en': 'About'},
      'logout': {'ar': 'تسجيل الخروج', 'en': 'Logout'},
      'home': {'ar': 'الرئيسية', 'en': 'Home'},
      'products': {'ar': 'المنتجات', 'en': 'Products'},
      'wallet': {'ar': 'المحفظة', 'en': 'Wallet'},
      'favorites': {'ar': 'المفضلة', 'en': 'Favorites'},
      'profile': {'ar': 'ملف الشخصي', 'en': 'Profile'},
      'invoices': {'ar': 'الفواتير', 'en': 'Invoices'},
      'gifts': {'ar': 'الهدايا', 'en': 'Gifts'},
    };
    final m = strings[key];
    if (m == null) return key;
    return _isArabic ? (m['ar'] ?? key) : (m['en'] ?? key);
  }

  List<String> _relevantIds(List<Order> orders) {
    if (_user == null) return const [];
    if (isAdmin) {
      return orders
          .where((o) => o.status == 'pending')
          .map((o) => o.id)
          .toList();
    }
    return orders
        .where((o) => o.userId == _user!.id && o.status != 'pending')
        .map((o) => o.id)
        .toList();
  }

  void startOrderPolling() {
    _pollTimer?.cancel();
    _pollTimer =
        Timer.periodic(const Duration(seconds: 5), (_) => _pollTick());

    if (!_listenersAttached) {
      _listenersAttached = true;
      html.document.addEventListener('visibilitychange', (_) {
        if (html.document.visibilityState == 'visible') _pollTick();
      });
      html.window.addEventListener('focus', (_) => _pollTick());
      html.document.addEventListener('click', (_) => _pollTick());
      html.document.addEventListener('keydown', (_) => _pollTick());
    }

    _pollTick();
  }

  Future<void> _pollTick() async {
    if (_user == null || _user!.role == 'guest') return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_ticking || now - _lastTickMs < 3000) return;
    _lastTickMs = now;
    _ticking = true;
    try {
      final created = await OrdersService.convertStoredToPoints(_user!.id);
      await OrdersService.resolveStaleSync();
      final orders = await OrdersService.loadOrders();
      final pending = orders.where((o) => o.status == 'pending').length;
      pendingCount = pending;

      final relevant = _relevantIds(orders).toSet();
      if (!_seenLoaded) {
        _seenLoaded = true;
        final p = await SharedPreferences.getInstance();
        _seenIds = (p.getStringList(_seenKey) ?? []).toSet();
        if (_seenIds.isEmpty) {
          _seenIds = Set<String>.from(relevant);
          await p.setStringList(_seenKey, _seenIds.toList());
        }
      }
      unseenCount = relevant.difference(_seenIds).length;

      if (isAdmin && _lastPending >= 0 && pending > _lastPending) {
        final diff = pending - _lastPending;
        final pendingSorted = orders
            .where((o) => o.status == 'pending')
            .toList()
          ..sort((a, b) =>
              (int.tryParse(b.id) ?? 0).compareTo(int.tryParse(a.id) ?? 0));
        for (int i = 0; i < diff && i < pendingSorted.length; i++) {
          _seenIds.remove(pendingSorted[i].id);
        }
        unseenCount = relevant.difference(_seenIds).length;
        if (unseenCount < diff) unseenCount = diff;
        messengerKey.currentState
          ?..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(_isArabic
                ? '🔔 وصل $diff طلب جديد!'
                : '🔔 $diff new order(s)!'),
            backgroundColor: const Color(0xFFF26B0F),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ));
      }
      _lastPending = pending;

      final mine = orders
          .where((o) => o.userId == _user!.id)
          .map((o) => o.status)
          .join(',');
      final sig = '$pending|${orders.length}|$unseenCount|$mine';
      if (created || sig != _lastSig) {
        _lastSig = sig;
        _ordersVersion++;
        if (created) {
          await refreshUser();
        }
        notifyListeners();
      }
    } catch (_) {
    } finally {
      _ticking = false;
    }
  }

  Future<void> markAllSeen() async {
    if (_user == null || _user!.role == 'guest') return;
    try {
      final orders = await OrdersService.loadOrders();
      final rel = _relevantIds(orders).toSet();
      final p = await SharedPreferences.getInstance();
      final seen = (p.getStringList(_seenKey) ?? []).toSet();
      seen.addAll(rel);
      if (seen.length > 400) {
        final active = orders.map((o) => o.id).toSet();
        seen.retainWhere(active.contains);
      }
      _seenIds = seen;
      _seenLoaded = true;
      await p.setStringList(_seenKey, seen.toList());
      unseenCount = 0;
      notifyListeners();
    } catch (_) {}
  }

  User _toUser(repo.AppUser au) {
    return User(
      id: au.id,
      name: au.name,
      role: au.role,
      phone: au.phone,
      password: '',
      points: au.points,
      stored: au.stored,
    );
  }

  Future<User> _withInvoiceTotals(User base) async {
    try {
      final invs = await StoreService.loadInvoices();
      final rets = await OrdersService.loadReturns();
      int pts = 0;
      int st = 0;
      for (final i in invs) {
        if (i.userId == base.id) {
          pts += i.points;
          st += i.stored;
        }
      }
      for (final r in rets) {
        if (r['userId'] == base.id) {
          pts -= ((r['points'] as num?)?.toInt() ?? 0);
          st -= ((r['stored'] as num?)?.toInt() ?? 0);
        }
      }
      return User(
        id: base.id,
        name: base.name,
        role: base.role,
        phone: base.phone,
        password: base.password,
        points: pts,
        stored: st,
      );
    } catch (_) {
      return base;
    }
  }

  void toggleLanguage() {
    _isArabic = !_isArabic;
    _savePrefs();
    notifyListeners();
  }

  void toggleDark() {
    _isDark = !_isDark;
    _savePrefs();
    notifyListeners();
  }

  void toggleImageAdmin() {
    _isImageAdmin = !_isImageAdmin;
    notifyListeners();
  }

  void setImageAdmin(bool v) {
    _isImageAdmin = v;
    notifyListeners();
  }

  /// إنشاء حساب المتحكم الأساسي تلقائياً عند أول دخول
  Future<repo.AppUser?> _ensureController() async {
    try {
      return await repo.userRepo.login('19972000', 'ad1234');
    } catch (_) {
      try {
        final created =
            await repo.userRepo.register('19972000', 'المتحكم', 'ad1234');
        if (created == null) return null;
        final ctrl = repo.AppUser(
          id: created.id,
          phone: '19972000',
          name: 'المتحكم',
          role: 'ctrl',
          points: 0,
          stored: 0,
        );
        await repo.userRepo.save(ctrl);
        return ctrl;
      } catch (_) {
        return null;
      }
    }
  }

  /// دخول عادي + بوابة المتحكم الأساسية
  Future<bool> loginWithFirebase(String phone, String password) async {
    try {
      repo.AppUser? au;
      if (phone.trim() == '19972000' && password == 'ad1234') {
        au = await _ensureController();
      } else {
        au = await repo.userRepo.login(phone, password);
      }
      if (au == null) return false;
      _user = await _withInvoiceTotals(_toUser(au));
      _isImageAdmin = isAdmin;
      _seenLoaded = false;
      _seenIds = {};
      await _savePrefs();
      startOrderPolling();
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  /// دعم للشاشات القديمة حتى نستبدلها
  Future<void> loginAsAdmin() async {
    final au = await _ensureController();
    if (au != null) {
      _user = await _withInvoiceTotals(_toUser(au));
    } else {
      _user = User(
        id: 'admin_001',
        name: 'المدير',
        role: 'admin',
        phone: '0000000000',
        password: 'admin',
      );
    }
    _isImageAdmin = true;
    _seenLoaded = false;
    _seenIds = {};
    await _savePrefs();
    startOrderPolling();
    notifyListeners();
  }

  Future<void> loginAsGuest() async {
    try {
      final au = await repo.userRepo.guest();
      _user = _toUser(au);
    } catch (_) {
      _user = User(
        id: 'guest_${DateTime.now().millisecondsSinceEpoch}',
        name: 'ضيف',
        role: 'guest',
      );
    }
    _isImageAdmin = false;
    unseenCount = 0;
    await _savePrefs();
    notifyListeners();
  }

  Future<void> guestLogin() => loginAsGuest();

  Future<void> loginAsUser(User u) async {
    try {
      final au = repo.AppUser(
        id: u.id,
        phone: u.phone,
        name: u.name,
        role: u.role,
        points: u.points,
        stored: u.stored,
      );
      await repo.userRepo.save(au);
    } catch (_) {}
    _user = await _withInvoiceTotals(u);
    _isImageAdmin = isAdmin;
    _seenLoaded = false;
    _seenIds = {};
    await _savePrefs();
    startOrderPolling();
    notifyListeners();
  }

  void syncUser(User u) {
    _user = u;
    notifyListeners();
  }

  Future<void> refreshUser() async {
    if (_user == null) return;
    try {
      final au = await repo.userRepo.restore();
      if (au != null) {
        _user = await _withInvoiceTotals(_toUser(au));
        await _savePrefs();
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> addPoints(int delta) async {
    if (_user == null) return;
    final newUser = User(
      id: _user!.id,
      name: _user!.name,
      role: _user!.role,
      phone: _user!.phone,
      password: _user!.password,
      points: _user!.points + delta,
      stored: _user!.stored,
    );
    _user = newUser;
    try {
      await repo.userRepo.save(repo.AppUser(
        id: newUser.id,
        phone: newUser.phone,
        name: newUser.name,
        role: newUser.role,
        points: newUser.points,
        stored: newUser.stored,
      ));
    } catch (_) {}
    await _savePrefs();
    notifyListeners();
  }

  Future<void> addStored(int delta) async {
    if (_user == null) return;
    final newUser = User(
      id: _user!.id,
      name: _user!.name,
      role: _user!.role,
      phone: _user!.phone,
      password: _user!.password,
      points: _user!.points,
      stored: _user!.stored + delta,
    );
    _user = newUser;
    try {
      await repo.userRepo.save(repo.AppUser(
        id: newUser.id,
        phone: newUser.phone,
        name: newUser.name,
        role: newUser.role,
        points: newUser.points,
        stored: newUser.stored,
      ));
    } catch (_) {}
    await _savePrefs();
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await repo.userRepo.logout();
    } catch (_) {}
    _user = null;
    _isImageAdmin = false;
    _pollTimer?.cancel();
    _lastPending = -1;
    _seenLoaded = false;
    _seenIds = {};
    unseenCount = 0;
    _savePrefs();
    notifyListeners();
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('isArabic', _isArabic);
    await p.setBool('isDark', _isDark);
    if (_user != null) {
      await p.setString('userId', _user!.id);
      await p.setString('userName', _user!.name);
      await p.setString('userRole', _user!.role);
    } else {
      await p.remove('userId');
      await p.remove('userName');
      await p.remove('userRole');
    }
  }

  Future<void> restoreSession() async {
    final p = await SharedPreferences.getInstance();
    _isArabic = p.getBool('isArabic') ?? true;
    _isDark = p.getBool('isDark') ?? false;
    final role = p.getString('userRole') ?? '';

    if (role == 'guest') {
      await p.remove('userId');
      await p.remove('userName');
      await p.remove('userRole');
      notifyListeners();
      return;
    }

    try {
      final au = await repo.userRepo.restore();
      if (au != null && au.role != 'guest') {
        _user = await _withInvoiceTotals(_toUser(au));
        _isImageAdmin = isAdmin;
        startOrderPolling();
      } else {
        await p.remove('userId');
        await p.remove('userName');
        await p.remove('userRole');
      }
    } catch (_) {
      await p.remove('userId');
      await p.remove('userName');
      await p.remove('userRole');
    }
    notifyListeners();
  }
}
