import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/theme.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});
  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = [];
  bool _loading = true;
  String? _err;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final s = context.read<AppSettings>();
      final uid = s.user?.id ?? '';
      final all = await OrdersService.loadOrders();
      final mine = all.where((o) => o.userId == uid).toList();
      mine.sort((a, b) => _ts(b).compareTo(_ts(a)));
      if (mounted) setState(() => _orders = mine);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _ts(Order o) =>
      DateTime.tryParse(o.date)?.millisecondsSinceEpoch ??
      (int.tryParse(o.id) ?? 0);

  String _ref(Order o) => o.invoiceNo.isNotEmpty
      ? o.invoiceNo
      : '#${o.id.length > 6 ? o.id.substring(o.id.length - 6) : o.id}';

  ({String label, Color color, IconData icon}) _statusOf(Order o, bool ar) {
    switch (o.status) {
      case 'accepted':
        return (
          label: ar ? 'مقبول' : 'Accepted',
          color: AppColors.teal,
          icon: Icons.check_circle_rounded
        );
      case 'completed':
        return (
          label: ar ? 'مكتمل' : 'Completed',
          color: AppColors.teal,
          icon: Icons.verified_rounded
        );
      case 'rejected':
        return (
          label: ar ? 'مرفوض' : 'Rejected',
          color: Colors.red,
          icon: Icons.cancel_rounded
        );
      case 'returned':
        return (
          label: ar ? 'مرتجع' : 'Returned',
          color: const Color(0xFF9B59B6),
          icon: Icons.assignment_return_rounded
        );
      default:
        return (
          label: ar ? 'قيد المراجعة' : 'Pending',
          color: AppColors.orange,
          icon: Icons.hourglass_top_rounded
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      backgroundColor:
          dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  IconButton(
                      onPressed: _load,
                      icon: const Icon(Icons.refresh_rounded,
                          color: AppColors.orange)),
                  Expanded(
                    child: Text(
                      s.isArabic ? 'سجل الطلبات' : 'Orders history',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_forward_rounded)),
                ],
              ),
            ),
            if (_loading)
              const Expanded(
                  child: Center(child: CircularProgressIndicator()))
            else if (_err != null)
              Expanded(
                  child: Center(
                      child:
                          Text(_err!, style: const TextStyle(color: Colors.red))))
            else if (_orders.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                          s.isArabic
                              ? 'لا توجد طلبات بعد'
                              : 'No orders yet',
                          style: TextStyle(color: Colors.grey.shade500)),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: _orders.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _card(_orders[i], s, dark),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _card(Order o, AppSettings s, bool dark) {
    final st = _statusOf(o, s.isArabic);
    final pieces = o.items.fold<int>(0, (a, it) => a + it.qty);
    final hasMoney = o.total > 0;
    final hasPoints = o.points > 0;
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: st.color.withAlpha(70)),
        boxShadow: [
          BoxShadow(
              color: st.color.withAlpha(dark ? 30 : 18),
              blurRadius: 12,
              offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: [st.color, st.color.withAlpha(170)]),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(st.icon, color: Colors.white, size: 14),
                      const SizedBox(width: 5),
                      Text(st.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(_ref(o),
                          style: TextStyle(
                              color: dark ? Colors.white : AppColors.ink,
                              fontWeight: FontWeight.w900,
                              fontSize: 14)),
                    ),
                    const SizedBox(height: 2),
                    Directionality(
                      textDirection: TextDirection.ltr,
                      child: Text(o.date,
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withAlpha(dark ? 25 : 35)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
            child: Column(
              children: [
                for (final it in o.items)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withAlpha(25),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Directionality(
                            textDirection: TextDirection.ltr,
                            child: Text('${it.qty}×',
                                style: const TextStyle(
                                    color: AppColors.orange,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 11)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(it.name,
                              style: TextStyle(
                                  color:
                                      dark ? Colors.white : AppColors.ink,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13)),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, color: Colors.grey.withAlpha(dark ? 25 : 35)),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Row(
              children: [
                _foot(s.isArabic ? 'القطع' : 'Pieces', '$pieces',
                    AppColors.orange),
                if (hasMoney) ...[
                  const SizedBox(width: 10),
                  _foot(s.isArabic ? 'المبلغ' : 'Total',
                      fmtThousands(o.total), AppColors.teal),
                ],
                if (hasPoints) ...[
                  const SizedBox(width: 10),
                  _foot(s.isArabic ? 'النقاط' : 'Points',
                      '+${o.points.toInt()}', const Color(0xFF9B59B6)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _foot(String label, String value, Color c) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    // ✅ نص أسود غامق (أبيض في الوضع الداكن للقراءة)
    final Color txt = dark ? Colors.white : const Color(0xFF1A1A1A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: c.withAlpha(22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.withAlpha(70)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: TextStyle(
                  color: txt, fontSize: 10, fontWeight: FontWeight.w800)),
          const SizedBox(width: 6),
          Directionality(
            textDirection: TextDirection.ltr,
            child: Text(value,
                style: TextStyle(
                    color: txt, fontSize: 12, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}
