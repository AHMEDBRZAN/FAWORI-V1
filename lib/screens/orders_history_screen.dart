import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/repositories/orders_repo.dart';
import '../core/theme.dart';

class OrdersHistoryScreen extends StatefulWidget {
  const OrdersHistoryScreen({super.key});
  @override
  State<OrdersHistoryScreen> createState() => _OrdersHistoryScreenState();
}

class _OrdersHistoryScreenState extends State<OrdersHistoryScreen> {
  List<Order> _orders = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = context.read<AppSettings>();
    final uid = s.user?.id ?? '';
    if (uid.isEmpty) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    try {
      // ✅ قراءة من Firestore أولاً ثم السقوط إلى JSON
      List<Order> all = [];
      try {
        final fireOrders = await ordersRepo.list().timeout(const Duration(seconds: 5));
        all = fireOrders.map((f) => Order(
          id: f.id,
          userId: f.userId,
          userName: f.userName,
          userRole: f.userRole,
          date: f.date,
          invoiceNo: f.invoiceNo,
          status: f.status,
          total: f.total,
          items: f.items.map((it) => OrderItem(name: it.name, qty: it.qty)).toList(),
        )).toList();
      } catch (_) {}
      if (all.isEmpty) {
        all = await OrdersService.loadOrders();
      }
      final mine = all.where((o) => o.userId == uid).toList()
        ..sort((a, b) => b.id.compareTo(a.id));
      if (mounted) {
        setState(() {
          _orders = mine;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _statusAr(String status) {
    switch (status) {
      case 'pending':
        return 'قيد المراجعة';
      case 'approved':
        return 'مقبول';
      case 'rejected':
        return 'مرفوض';
      case 'completed':
        return 'مكتمل';
      default:
        return status;
    }
  }

  String _statusEn(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'rejected':
        return 'Rejected';
      case 'completed':
        return 'Completed';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.orange;
      case 'approved':
      case 'completed':
        return const Color(0xFF0D9668);
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'pending':
        return Icons.hourglass_empty_rounded;
      case 'approved':
        return Icons.check_circle_outline_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.help_outline_rounded;
    }
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
        title: Text(s.isArabic ? 'سجل الطلبات' : 'Orders history',
            style:
                const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : _orders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long_outlined,
                          size: 90, color: AppColors.orange.withAlpha(90)),
                      const SizedBox(height: 14),
                      Text(s.isArabic ? 'لا توجد طلبات سابقة' : 'No orders yet',
                          style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w900,
                              fontSize: 16)),
                      const SizedBox(height: 6),
                      Text(
                          s.isArabic
                              ? 'ابدأ بالتسوق وستظهر طلباتك هنا'
                              : 'Start shopping and your orders will appear here',
                          style: TextStyle(
                              color: Colors.grey.shade500, fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (ctx, i) {
                    final o = _orders[i];
                    final totalQty =
                        o.items.fold<int>(0, (p, c) => p + c.qty);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: dark ? const Color(0xFF1E1E28) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: AppColors.orange.withAlpha(60)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(7),
                                decoration: BoxDecoration(
                                  color: _statusColor(o.status).withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(_statusIcon(o.status),
                                    color: _statusColor(o.status), size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        '#${o.id.substring(o.id.length - 6)}',
                                        style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            fontSize: 14,
                                            color: dark
                                                ? Colors.white
                                                : AppColors.ink)),
                                    const SizedBox(height: 2),
                                    Text(o.date,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade500)),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _statusColor(o.status).withAlpha(20),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                    s.isArabic
                                        ? _statusAr(o.status)
                                        : _statusEn(o.status),
                                    style: TextStyle(
                                        color: _statusColor(o.status),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Divider(
                              height: 1,
                              color: AppColors.orange.withAlpha(40)),
                          const SizedBox(height: 10),
                          for (final item in o.items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(item.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: dark
                                                ? Colors.grey.shade300
                                                : AppColors.ink)),
                                  ),
                                  const SizedBox(width: 8),
                                  Text('×${item.qty}',
                                      style: const TextStyle(
                                          color: AppColors.orange,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12)),
                                ],
                              ),
                            ),
                          const SizedBox(height: 10),
                          Divider(
                              height: 1,
                              color: AppColors.orange.withAlpha(40)),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  s.isArabic ? 'إجمالي القطع' : 'Total items',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w700)),
                              Directionality(
                                textDirection: TextDirection.ltr,
                                child: Text('$totalQty',
                                    style: const TextStyle(
                                        color: AppColors.orange,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 14)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
