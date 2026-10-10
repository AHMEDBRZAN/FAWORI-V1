import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/repositories/orders_repo.dart';
import '../core/theme.dart';

/// تنسيق الأرقام بفواصل (مثل 125000 → 125,000)
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

class OrdersFireScreen extends StatefulWidget {
  const OrdersFireScreen({super.key});
  @override
  State<OrdersFireScreen> createState() => _OrdersFireScreenState();
}

class _OrdersFireScreenState extends State<OrdersFireScreen> {
  List<FireOrder> _all = [];
  bool _loading = true;
  String? _err;
  String _filter = 'all';

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
      final list = await ordersRepo.list();
      if (mounted) setState(() => _all = list);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<FireOrder> get _shown => _filter == 'all'
      ? _all
      : _all.where((o) => o.status == _filter).toList();

  int get _pendingCount =>
      _all.where((o) => o.status == 'pending').length;

  Future<void> _setStatus(FireOrder o, String st) async {
    try {
      await ordersRepo.setStatus(o.id, st);
      if (mounted) {
        _snack(context, st == 'accepted' ? '✅ تم القبول' : 'تم الرفض',
            st == 'accepted' ? Colors.green : Colors.red);
        _load();
      }
    } catch (e) {
      if (mounted) _snack(context, 'فشل: $e', Colors.red);
    }
  }

  Future<void> _delete(FireOrder o) async {
    final s = context.read<AppSettings>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.isArabic ? 'حذف الطلب' : 'Delete order'),
        content: Text(s.isArabic
            ? 'سيُحذف طلب ${o.userName} نهائياً.'
            : 'Delete order of ${o.userName}?'),
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
      await ordersRepo.remove(o.id);
      if (mounted) {
        _snack(context, 'تم الحذف', Colors.green);
        _load();
      }
    } catch (e) {
      if (mounted) _snack(context, 'فشل: $e', Colors.red);
    }
  }

  void _details(FireOrder o) {
    final s = context.read<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
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
                  color: _statusColor(o.status).withAlpha(dark ? 40 : 22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: _statusColor(o.status).withAlpha(80)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.person_rounded,
                        color: _statusColor(o.status), size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(o.userName,
                          style: TextStyle(
                              color: dark ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w900)),
                    ),
                    Text(_statusLabel(o.status, s.isArabic),
                        style: TextStyle(
                            color: _statusColor(o.status),
                            fontWeight: FontWeight.w900,
                            fontSize: 12)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Text('${o.date}',
                        style: TextStyle(
                            color: Colors.grey.shade500, fontSize: 12)),
                  ),
                  Directionality(
                    textDirection: TextDirection.ltr,
                    child: Text(fmtThousands(o.total),
                        style: const TextStyle(
                            color: AppColors.orange,
                            fontWeight: FontWeight.w900,
                            fontSize: 16)),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.orange.withAlpha(60)),
                  borderRadius: BorderRadius.circular(14),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 12),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(colors: <Color>[
                          Color(0xFFFF8C00),
                          Color(0xFFF26B0F)
                        ]),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(s.isArabic ? 'المادة' : 'Item',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12))),
                          SizedBox(
                              width: 56,
                              child: Text(s.isArabic ? 'العدد' : 'Qty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12))),
                        ],
                      ),
                    ),
                    for (int i = 0; i < o.items.length; i++)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 12),
                        color: i.isOdd
                            ? (dark
                                ? Colors.white.withAlpha(8)
                                : Colors.black.withAlpha(6))
                            : Colors.transparent,
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(o.items[i].name,
                                    style: TextStyle(
                                        color: dark
                                            ? Colors.white
                                            : AppColors.ink,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12))),
                            SizedBox(
                                width: 56,
                                child: Center(
                                  child: Text('${o.items[i].qty}',
                                      style: const TextStyle(
                                          color: AppColors.teal,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12)),
                                )),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (s.isAdmin) ...[
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.teal,
                            foregroundColor: Colors.white),
                        onPressed: o.status == 'pending'
                            ? () {
                                Navigator.pop(context);
                                _setStatus(o, 'accepted');
                              }
                            : null,
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: Text(s.isArabic ? 'قبول' : 'Accept'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white),
                        onPressed: o.status == 'pending'
                            ? () {
                                Navigator.pop(context);
                                _setStatus(o, 'rejected');
                              }
                            : null,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        label: Text(s.isArabic ? 'رفض' : 'Reject'),
                      ),
                    ),
                  ],
                ),
                if (s.isController) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade800,
                          foregroundColor: Colors.white),
                      onPressed: () {
                        Navigator.pop(context);
                        _delete(o);
                      },
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: Text(s.isArabic ? 'حذف الطلب' : 'Delete order'),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Color _statusColor(String st) {
    switch (st) {
      case 'pending':
        return AppColors.orange;
      case 'accepted':
        return AppColors.teal;
      case 'rejected':
        return Colors.red;
      case 'returned':
        return const Color(0xFF9B59B6);
      default:
        return Colors.grey;
    }
  }

  String _statusLabel(String st, bool ar) {
    switch (st) {
      case 'pending':
        return ar ? 'قيد الانتظار' : 'Pending';
      case 'accepted':
        return ar ? 'مقبول' : 'Accepted';
      case 'rejected':
        return ar ? 'مرفوض' : 'Rejected';
      case 'returned':
        return ar ? 'مرتجع' : 'Returned';
      default:
        return st;
    }
  }

  void _snack(BuildContext c, String msg, Color color) {
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
    ));
  }

  Widget _chip(String label, String value, Color c) {
    final active = _filter == value;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: () => setState(() => _filter = value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: active
                ? LinearGradient(colors: <Color>[c, c.withAlpha(180)])
                : null,
            color: active ? null : c.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withAlpha(active ? 180 : 80)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : c,
                  fontWeight: FontWeight.w900,
                  fontSize: 11)),
        ),
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
        title: Row(
          children: [
            Expanded(
              child: Text(s.isArabic ? 'الطلبات' : 'Orders',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : AppColors.ink)),
            ),
            if (_pendingCount > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange.withAlpha(30),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$_pendingCount',
                    style: const TextStyle(
                        color: AppColors.orange, fontWeight: FontWeight.w900)),
              ),
          ],
        ),
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
                  child: Text('$_err', style: const TextStyle(color: Colors.red)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Row(
                        children: [
                          _chip(s.isArabic ? 'الكل' : 'All', 'all',
                              AppColors.orange),
                          _chip(s.isArabic ? 'انتظار' : 'Pending', 'pending',
                              AppColors.orange),
                          _chip(s.isArabic ? 'مقبول' : 'Accepted', 'accepted',
                              AppColors.teal),
                          _chip(s.isArabic ? 'مرفوض' : 'Rejected', 'rejected',
                              Colors.red),
                        ],
                      ),
                      const SizedBox(height: 14),
                      if (_shown.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 60),
                          child: Center(
                            child: Text(
                                s.isArabic ? 'لا توجد طلبات' : 'No orders',
                                style: TextStyle(color: Colors.grey.shade500)),
                          ),
                        )
                      else
                        for (final o in _shown)
                          InkWell(
                            onTap: () => _details(o),
                            borderRadius: BorderRadius.circular(18),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: dark
                                    ? const Color(0xFF1E1E28)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                    color: _statusColor(o.status)
                                        .withAlpha(70)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(colors: <Color>[
                                        _statusColor(o.status),
                                        _statusColor(o.status).withAlpha(160)
                                      ]),
                                      borderRadius: BorderRadius.circular(13),
                                    ),
                                    child: const Icon(
                                        Icons.shopping_bag_rounded,
                                        color: Colors.white,
                                        size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(o.userName,
                                            style: TextStyle(
                                                color: dark
                                                    ? Colors.white
                                                    : AppColors.ink,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14)),
                                        const SizedBox(height: 3),
                                        Text('${o.items.length} ${s.isArabic ? 'مادة' : 'items'} • ${o.date}',
                                            style: TextStyle(
                                                color: Colors.grey.shade500,
                                                fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.end,
                                    children: [
                                      Directionality(
                                        textDirection: TextDirection.ltr,
                                        child: Text(fmtThousands(o.total),
                                            style: const TextStyle(
                                                color: AppColors.orange,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 14)),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(_statusLabel(o.status, s.isArabic),
                                          style: TextStyle(
                                              color: _statusColor(o.status),
                                              fontWeight: FontWeight.w800,
                                              fontSize: 10)),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                    ],
                  ),
                ),
    );
  }
}
