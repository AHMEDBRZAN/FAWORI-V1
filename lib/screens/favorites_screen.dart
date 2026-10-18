import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/orders_service.dart';
import '../core/repositories/favorites_repo.dart';
import '../core/repositories/product_repo.dart';
import '../core/theme.dart';

/// ✅ شاشة المفضلة
class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});
  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  List<String> _ids = [];
  List<FireProduct> _all = [];
  List<FireProduct> _items = [];
  StreamSubscription<List<String>>? _sub;
  StreamSubscription<List<FireProduct>>? _subP;

  @override
  void initState() {
    super.initState();
    final uid = context.read<AppSettings>().user?.id ?? '';
    _sub = favoritesRepo.stream(uid).listen((ids) {
      if (!mounted) return;
      setState(() {
        _ids = ids;
        _filter();
      });
    });
    _subP = productRepo.stream().listen((all) {
      if (!mounted) return;
      setState(() {
        _all = all;
        _filter();
      });
    });
  }

  void _filter() {
    _items = _all.where((p) => _ids.contains(p.id)).toList();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subP?.cancel();
    super.dispose();
  }

  Future<void> _addCart(FireProduct p) async {
    final s = context.read<AppSettings>();
    final uid = s.user?.id ?? '';
    if (uid.isEmpty) return;
    await OrdersService.addToCart(uid, p.id, p.name, '', p.brand, 1);
    if (mounted) {
      showAppSnack(context, s.isArabic ? 'أُضيف إلى السلة' : 'Added to cart',
          color: const Color(0xFF0D9668),
          icon: Icons.add_shopping_cart_rounded);
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
        title: Text(s.isArabic ? 'المفضلة' : 'Favorites',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
      ),
      body: _items.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.favorite_border_rounded,
                      size: 90, color: Colors.red.withAlpha(90)),
                  const SizedBox(height: 14),
                  Text(
                      s.isArabic
                          ? 'لا توجد منتجات مفضلة'
                          : 'No favorite products',
                      style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                      s.isArabic
                          ? 'اضغط القلب على أي منتج لحفظه هنا'
                          : 'Tap the heart on any product to save it here',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _items.length,
              itemBuilder: (ctx, i) {
                final p = _items[i];
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.withAlpha(50)),
                  ),
                  child: Row(
                    children: [
                      p.image.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.network(p.image,
                                  width: 52,
                                  height: 52,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, o, st) => const Icon(
                                      Icons.format_paint_rounded,
                                      color: AppColors.orange,
                                      size: 26)),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: AppColors.orange.withAlpha(30),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.format_paint_rounded,
                                  color: AppColors.orange, size: 26),
                            ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(p.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                    color:
                                        dark ? Colors.white : AppColors.ink)),
                            const SizedBox(height: 3),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text(fmtThousands(p.price),
                                  style: const TextStyle(
                                      color: AppColors.teal,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12)),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: () => _addCart(p),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.teal.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.add_shopping_cart_rounded,
                              color: AppColors.teal, size: 18),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () =>
                            favoritesRepo.toggle(s.user?.id ?? '', p.id),
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: Colors.red.withAlpha(20),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.favorite_rounded,
                              color: Colors.red, size: 18),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
