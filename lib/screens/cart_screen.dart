import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/theme.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});
  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  List<CartItem> _items = [];
  bool _loading = true;
  bool _busy = false;

  Future<void> _writeChain = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _load() async {
    final s = context.read<AppSettings>();
    try {
      final cart = await OrdersService.loadCart(s.user?.id ?? '');
      if (mounted) {
        setState(() {
          _items = cart;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    final s = context.read<AppSettings>();
    final snapshot = List<CartItem>.from(_items);
    _writeChain = _writeChain
        .then((_) => OrdersService.saveCart(s.user?.id ?? '', snapshot));
    await _writeChain;
  }

  Future<void> _chg(int i, int d) async {
    setState(() {
      _items[i].qty = (_items[i].qty + d).clamp(1, 99);
    });
    await _save();
  }

  Future<void> _remove(int i) async {
    setState(() => _items.removeAt(i));
    await _save();
  }

  /// ✅ نافذة تأكيد الشراء الاحترافية المتدرجة
  Future<void> _confirmCheckout() async {
    final s = context.read<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    if (_items.isEmpty) return;

    final totalQty = _items.fold<int>(0, (p, c) => p + c.qty);

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF1E1E28) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(dark ? 120 : 80),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ===== رأس متدرج برتقالي =====
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 22),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[Color(0xFFFF8C00), Color(0xFFF26B0F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withAlpha(40),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                          Icons.shopping_cart_checkout_rounded,
                          color: Colors.white,
                          size: 32),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.isArabic ? 'تأكيد الشراء' : 'Confirm purchase',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // ===== المحتوى =====
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      s.isArabic
                          ? 'هل تريد إرسال طلبك إلى الإدارة للمراجعة؟'
                          : 'Do you want to send your order to admin for review?',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: dark ? Colors.white : AppColors.ink,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ===== جدول مواد السلة (ت | اسم المادة | العدد) =====
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: AppColors.orange.withAlpha(70)),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.orange,
                                  AppColors.orange.withAlpha(200),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                    width: 26,
                                    child: Text(
                                        s.isArabic ? 'ت' : '#',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11))),
                                Expanded(
                                  child: Text(
                                      s.isArabic ? 'اسم المادة' : 'Item name',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 11)),
                                ),
                                SizedBox(
                                    width: 40,
                                    child: Text(
                                        s.isArabic ? 'العدد' : 'Qty',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11))),
                              ],
                            ),
                          ),
                          ConstrainedBox(
                            constraints:
                                const BoxConstraints(maxHeight: 300),
                            child: SingleChildScrollView(
                              child: Column(
                                children: [
                                  for (int i = 0; i < _items.length; i++)
                                    Container(
                                      width: double.infinity,
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8),
                                      color: i.isOdd
                                          ? AppColors.orange
                                              .withAlpha(dark ? 18 : 14)
                                          : Colors.transparent,
                                      child: Row(
                                        children: [
                                          SizedBox(
                                              width: 26,
                                              child: Text('${i + 1}',
                                                  textAlign:
                                                      TextAlign.center,
                                                  style: TextStyle(
                                                      color: dark
                                                          ? Colors.grey
                                                              .shade300
                                                          : Colors.grey
                                                              .shade700,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                      fontSize: 11))),
                                          Expanded(
                                            child: Text(_items[i].name,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                textAlign: TextAlign.center,
                                                style: TextStyle(
                                                    color: dark
                                                        ? Colors.white
                                                        : AppColors.ink,
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    fontSize: 11)),
                                          ),
                                          SizedBox(
                                              width: 40,
                                              child: Text(
                                                  '${_items[i].qty}',
                                                  textAlign:
                                                      TextAlign.center,
                                                  style: const TextStyle(
                                                      color: AppColors
                                                          .orange,
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      fontSize: 12))),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          // ===== صف المجموع (داخل الجدول) =====
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 9),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: <Color>[
                                  AppColors.orange
                                      .withAlpha(dark ? 70 : 40),
                                  AppColors.orange
                                      .withAlpha(dark ? 35 : 20),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 26),
                                Expanded(
                                  child: Text(
                                      s.isArabic ? 'مجموع' : 'Total',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                          color: dark
                                              ? Colors.white
                                              : AppColors.ink,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12)),
                                ),
                                SizedBox(
                                    width: 40,
                                    child: Text('$totalQty',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: AppColors.orange,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 13))),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Divider(
                        height: 1,
                        color: AppColors.orange
                            .withAlpha(dark ? 60 : 80)),
                    const SizedBox(height: 16),
                    _summaryRow(
                        Icons.payments_outlined,
                        s.isArabic ? 'السعر' : 'Price',
                        s.isArabic ? 'يُحدد بالإدارة' : 'Set by admin',
                        AppColors.orange,
                        dark),
                  ],
                ),
              ),

              // ===== الأزرار =====
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: dark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          s.isArabic ? 'إلغاء' : 'Cancel',
                          style: TextStyle(
                            color: dark
                                ? Colors.grey.shade300
                                : Colors.grey.shade700,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 3,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: <Color>[
                              Color(0xFF0D9668),
                              Color(0xFF0AA87A)
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF0AA87A)
                                  .withAlpha(90),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded,
                                  size: 20),
                              const SizedBox(width: 6),
                              Text(
                                s.isArabic ? 'تأكيد الشراء' : 'Confirm',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed == true) {
      await _checkout();
    }
  }

  Widget _summaryRow(
      IconData icon, String label, String value, Color color, bool dark) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: color.withAlpha(25),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: dark ? Colors.white : AppColors.ink,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w900,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Future<void> _checkout() async {
    final s = context.read<AppSettings>();
    if (_items.isEmpty) return;
    setState(() => _busy = true);
    try {
      await _writeChain;
      final captured = List<CartItem>.from(_items);
      setState(() {
        _items = [];
      });
      await OrdersService.clearCart(s.user?.id ?? '');

      final now = DateTime.now();
      final order = Order(
        id: '${now.millisecondsSinceEpoch}',
        userId: s.user?.id ?? '',
        userName: s.user?.name ?? '',
        userRole: s.user?.role ?? '',
        date:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        items: captured
            .map((e) => OrderItem(name: e.name, qty: e.qty))
            .toList(),
        invoiceNo: '',
      );
      await OrdersService.submitOrder(order);
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context,
            s.isArabic ? 'تم إرسال الطلب إلى الإدارة' : 'Order sent to admin',
            color: const Color(0xFF0D9668), icon: Icons.send_rounded);
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        showAppSnack(context, 'فشل: $e',
            color: Colors.red, icon: Icons.error_outline_rounded);
      }
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
        title: Text(s.isArabic ? 'السلة' : 'Cart'),
        actions: [
          if (_items.isNotEmpty)
            IconButton(
              tooltip: s.isArabic ? 'إفراغ السلة' : 'Clear cart',
              icon: const Icon(Icons.delete_sweep_rounded, color: Colors.red),
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(s.isArabic ? 'إفراغ السلة' : 'Clear cart'),
                    content: Text(s.isArabic
                        ? 'هل تريد حذف كل العناصر من السلة؟'
                        : 'Remove all items from cart?'),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: Text(s.isArabic ? 'إفراغ' : 'Clear')),
                    ],
                  ),
                );
                if (confirm == true) {
                  setState(() => _items = []);
                  await _save();
                }
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? Center(
                  child: Text(
                      s.isArabic ? 'السلة فارغة' : 'Cart is empty',
                      style: TextStyle(color: Colors.grey.shade500)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    for (int i = 0; i < _items.length; i++) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: dark
                              ? const Color(0xFF1E1E28)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.orange.withAlpha(60)),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(_items[i].name,
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                            ),
                            IconButton(
                              icon: const Icon(Icons.remove_circle_outline,
                                  color: AppColors.orange),
                              onPressed: _items[i].qty > 1
                                  ? () => _chg(i, -1)
                                  : null,
                            ),
                            Text('${_items[i].qty}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 15)),
                            IconButton(
                              icon: const Icon(Icons.add_circle_outline,
                                  color: AppColors.orange),
                              onPressed: () => _chg(i, 1),
                            ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _remove(i),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                            colors: <Color>[
                              AppColors.orange.withAlpha(dark ? 40 : 25),
                              Theme.of(context).colorScheme.surface
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: AppColors.orange.withAlpha(70)),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Text(
                                  s.isArabic
                                      ? 'السعر الإجمالي'
                                      : 'Total',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                              const Spacer(),
                              Text(
                                  s.isArabic
                                      ? 'يُحدد من الإدارة'
                                      : 'Set by admin',
                                  style: const TextStyle(
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                  s.isArabic
                                      ? 'نقاط هذه الفاتورة'
                                      : 'Invoice points',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                              const Spacer(),
                              const Text('—',
                                  style: TextStyle(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Text(
                                  s.isArabic
                                      ? 'الرصيد المتبقي'
                                      : 'Remaining',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                              const Spacer(),
                              const Text('—',
                                  style: TextStyle(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 15)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: <Color>[
                            Color(0xFFE8A33C),
                            Color(0xFFF26B0F)
                          ]),
                          borderRadius: BorderRadius.circular(14)),
                      child: SizedBox(
                        height: 54,
                        width: double.infinity,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white),
                          onPressed: _busy ? null : _confirmCheckout,
                          child: _busy
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : Text(
                                  s.isArabic ? 'إتمام الشراء' : 'Checkout',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}
