import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/repositories/orders_repo.dart';
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

class OrdersFireScreen extends StatefulWidget {
  const OrdersFireScreen({super.key});
  @override
  State<OrdersFireScreen> createState() => _OrdersFireScreenState();
}

class _OrdersFireScreenState extends State<OrdersFireScreen> {
  String _filter = 'all';
  int _lastPendingCount = -1;
  bool _firstLoad = true;

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
        title: Text(s.isArabic ? 'الطلبات' : 'Orders',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: dark ? Colors.white : AppColors.ink)),
      ),
      body: StreamBuilder<List<FireOrder>>(
        stream: ordersRepo.stream(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Text('${snap.error}',
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final all = snap.data ?? [];
          final pendingNow =
              all.where((o) => o.status == 'pending').length;

          if (_lastPendingCount >= 0 &&
              pendingNow > _lastPendingCount &&
              !_firstLoad &&
              s.isAdmin) {
            final diff = pendingNow - _lastPendingCount;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(
                      s.isArabic
                          ? '🔔 وصل $diff طلب جديد!'
                          : '🔔 $diff new order(s)!',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900)),
                  backgroundColor: const Color(0xFFF26B0F),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 3),
                ));
              }
            });
          }
          _lastPendingCount = pendingNow;
          _firstLoad = false;

          final shown = _filter == 'all'
              ? all
              : all.where((o) => o.status == _filter).toList();

          return RefreshIndicator(
            onRefresh: () async {},
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                    const Spacer(),
                    if (pendingNow > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text('$pendingNow',
                                style: const TextStyle(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                if (shown.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 60),
                    child: Center(
                      child: Text(s.isArabic ? 'لا توجد طلبات' : 'No orders',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  )
                else
                  for (final o in shown)
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
                              color: _statusColor(o.status).withAlpha(70)),
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
                              child: const Icon(Icons.shopping_bag_rounded,
                                  color: Colors.white, size: 20),
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
                                  Text(
                                      '${o.items.length} ${s.isArabic ? 'مادة' : 'items'} • ${o.date}',
                                      style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
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
          );
        },
      ),
    );
  }

  Future<void> _setStatus(FireOrder o, String st) async {
    try {
      await ordersRepo.setStatus(o.id, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(st == 'accepted' ? '✅ تم القبول' : 'تم الرفض',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          backgroundColor: st == 'accepted' ? Colors.green : Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل: $e'),
          backgroundColor: Colors.red,
        ));
      }
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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('تم الحذف',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w800)),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('فشل: $e'),
          backgroundColor: Colors.red,
        ));
      }
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
              Text('${o.date}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _infoTile(
                      icon: Icons.receipt_long_rounded,
                      label: s.isArabic ? 'رقم الفاتورة' : 'Invoice No.',
                      value: o.invoiceNo.isEmpty ? '—' : o.invoiceNo,
                      color: const Color(0xFF9B59B6),
                      dark: dark,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _infoTile(
                      icon: Icons.payments_rounded,
                      label: s.isArabic ? 'إجمالي السعر' : 'Total',
                      value: fmtThousands(o.total),
                      color: AppColors.orange,
                      dark: dark,
                    ),
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

  Widget _infoTile({
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 10)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value,
                textAlign: TextAlign.left,
                style: TextStyle(
                    color: dark ? Colors.white : AppColors.ink,
                    fontWeight: FontWeight.w900,
                    fontSize: 14)),
          ),
        ],
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
}
