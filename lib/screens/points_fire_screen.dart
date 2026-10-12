import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/repositories/user_repo.dart';
import '../core/store_service.dart';
import '../core/theme.dart';

String fmtThousands(num n) {
  final s = n.toInt().toString();
  final buf = StringBuffer();
  int count = 0;
  for (int i = s.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0 && s[i] != '-') buf.write(',');
    buf.write(s[i]);
    count++;
  }
  return buf.toString().split('').reversed.join('');
}

class PointsFireScreen extends StatefulWidget {
  const PointsFireScreen({super.key});
  @override
  State<PointsFireScreen> createState() => _PointsFireScreenState();
}

class _PointsFireScreenState extends State<PointsFireScreen> {
  List<AppUser> _users = [];
  final Map<String, int> _pts = {};
  final Map<String, int> _st = {};
  final Map<String, List<Invoice>> _byUser = {};
  Set<String> _delIds = {};
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final users = await userRepo.listUsers();
      final invs = await StoreService.loadInvoices();
      final rets = await OrdersService.loadReturns();
      final delSnap =
          await FirebaseFirestore.instance.collection('inv_del').get();
      final del = delSnap.docs.map((d) => d.id).toSet();

      final pts = <String, int>{};
      final st = <String, int>{};
      final byUser = <String, List<Invoice>>{};
      for (final i in invs) {
        if (del.contains(i.id)) continue;
        pts[i.userId] = (pts[i.userId] ?? 0) + i.points;
        st[i.userId] = (st[i.userId] ?? 0) + i.stored;
        byUser.putIfAbsent(i.userId, () => []).add(i);
      }
      for (final r in rets) {
        final uid = '${r['userId'] ?? ''}';
        pts[uid] = (pts[uid] ?? 0) - ((r['points'] as num?)?.toInt() ?? 0);
        st[uid] = (st[uid] ?? 0) - ((r['stored'] as num?)?.toInt() ?? 0);
      }
      
      // ✅ قراءة النقاط والرصيد كما في الصفحة القديمة تماماً
      try {
        final oldUsers = await StoreService.loadUsers();
        final byPhone = <String, User>{};
        for (final ou in oldUsers) {
          byPhone[ou.phone.trim()] = ou;
        }
        for (final u in users) {
          final ou = byPhone[u.phone.trim()];
          if (ou != null) {
            pts[u.id] = ou.points;
            st[u.id] = ou.stored;
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _users = users;
          _delIds = del;
          _pts.clear();
          _pts.addAll(pts);
          _st.clear();
          _st.addAll(st);
          _byUser.clear();
          _byUser.addAll(byUser);
        });
      }
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _delInvoice(Invoice i) async {
    final s = context.read<AppSettings>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isArabic ? 'حذف الفاتورة' : 'Delete invoice'),
        content: Text(s.isArabic
            ? 'سيُحذف أثر هذه الفاتورة من النقاط والرصيد فقط. لن يُحذف حساب المستخدم.'
            : 'Only invoice effect on points will be removed. Account stays.'),
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
    try {
      await FirebaseFirestore.instance
          .collection('inv_del')
          .doc(i.id)
          .set({'userId': i.userId, 'at': DateTime.now().toIso8601String()});
      if (mounted) {
        _snack(context, 'تم حذف أثر الفاتورة', Colors.green);
        _load();
      }
    } catch (e) {
      if (mounted) _snack(context, 'فشل: $e', Colors.red);
    }
  }

  void _snack(BuildContext c, String msg, Color color) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w800)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  String _roleLabel(String r, bool ar) {
    switch (r) {
      case 'ctrl':
        return ar ? 'متحكم' : 'Controller';
      case 'admin':
        return ar ? 'مدير' : 'Admin';
      case 'agent':
        return ar ? 'وكيل' : 'Agent';
      case 'tech':
        return ar ? 'صباغ' : 'Painter';
      case 'guest':
        return ar ? 'ضيف' : 'Guest';
      default:
        return ar ? 'عميل' : 'Client';
    }
  }

  Color _roleColor(String r) {
    switch (r) {
      case 'ctrl':
        return const Color(0xFFB71C1C);
      case 'admin':
        return Colors.red;
      case 'agent':
        return const Color(0xFF9B59B6);
      case 'tech':
        return AppColors.orange;
      default:
        return AppColors.teal;
    }
  }

  void _details(AppUser u) {
    final s = context.read<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final invs = _byUser[u.id] ?? const <Invoice>[];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: dark ? const Color(0xFF1E1E28) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _roleColor(u.role).withAlpha(dark ? 40 : 22),
                  borderRadius: BorderRadius.circular(14),
                  border:
                      Border.all(color: _roleColor(u.role).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        color: _roleColor(u.role), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(u.name,
                          style: TextStyle(
                              color: dark ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w900)),
                    ),
                    Text(_roleLabel(u.role, s.isArabic),
                        style: TextStyle(
                            color: _roleColor(u.role),
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _statTile(
                        icon: Icons.stars_rounded,
                        label: s.isArabic ? 'النقاط' : 'Points',
                        value: '${_pts[u.id] ?? 0}',
                        color: AppColors.orange,
                        dark: dark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _statTile(
                        icon: Icons.inventory_2_rounded,
                        label: s.isArabic ? 'المخزن' : 'Stored',
                        value: '${_st[u.id] ?? 0}',
                        color: AppColors.teal,
                        dark: dark),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withAlpha(dark ? 30 : 18),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.withAlpha(70)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        color: Colors.amber, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                          s.isArabic
                              ? 'الحذف هنا يحذف الفواتير فقط ولا يحذف الحساب'
                              : 'Delete here removes invoices only',
                          style: const TextStyle(
                              color: Colors.amber,
                              fontWeight: FontWeight.w800,
                              fontSize: 10)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (invs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 30),
                  child: Center(
                    child: Text(s.isArabic ? 'لا فواتير' : 'No invoices',
                        style: TextStyle(color: Colors.grey.shade500)),
                  ),
                )
              else
                for (final i in invs)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF26262E)
                          : const Color(0xFFFFFDF9),
                      borderRadius: BorderRadius.circular(14),
                      border:
                          Border.all(color: AppColors.orange.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('فاتورة ${i.no}',
                                  style: TextStyle(
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 13)),
                              const SizedBox(height: 4),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text(
                                    '${fmtThousands(i.total)}  |  +${i.points}  |  +${i.stored}',
                                    style: TextStyle(
                                        color: Colors.grey.shade600,
                                        fontSize: 11)),
                              ),
                            ],
                          ),
                        ),
                        if (s.isAdmin)
                          InkWell(
                            onTap: () {
                              Navigator.pop(context);
                              _delInvoice(i);
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(20),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.delete_rounded,
                                  color: Colors.red, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool dark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(dark ? 30 : 18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withAlpha(70)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w800,
                      fontSize: 10)),
            ],
          ),
          const SizedBox(height: 6),
          Text(value,
              style: TextStyle(
                  color: dark ? Colors.white : AppColors.ink,
                  fontWeight: FontWeight.w900,
                  fontSize: 16)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'النقاط والرصيد' : 'Points & balance',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : AppColors.ink)),
        actions: [
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _err != null
              ? Center(
                  child: Text('$_err',
                      style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                    itemCount: _users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, idx) {
                      final u = _users[idx];
                      final color = _roleColor(u.role);
                      return InkWell(
                        onTap: () => _details(u),
                        borderRadius: BorderRadius.circular(18),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF1E1E28)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: color.withAlpha(70)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(colors: <Color>[
                                    color,
                                    color.withAlpha(170)
                                  ]),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.person_rounded,
                                    color: Colors.white, size: 22),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(u.name,
                                        style: TextStyle(
                                            color: dark
                                                ? Colors.white
                                                : AppColors.ink,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14)),
                                    const SizedBox(height: 3),
                                    Text(u.phone,
                                        style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 11)),
                                  ],
                                ),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text('${_pts[u.id] ?? 0}',
                                      style: const TextStyle(
                                          color: AppColors.orange,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text('${_st[u.id] ?? 0}',
                                      style: const TextStyle(
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15)),
                                ],
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
