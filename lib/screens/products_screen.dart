import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_settings.dart';
import '../core/guest_guard.dart';
import '../core/orders_service.dart';
import '../core/theme.dart';
import '../data/sample_data.dart';
import '../core/repositories/favorites_repo.dart';
import '../core/repositories/product_repo.dart';
import '../widgets/pressable.dart';
import 'cart_screen.dart';
import 'login_screen.dart';
import 'product_detail_screen.dart';

/// ✅ أسماء الأقسام وألوانها المميزة
class _BrandCfg {
  final String key;
  final String ar;
  final String en;
  final Color color;
  final IconData icon;
  const _BrandCfg(this.key, this.ar, this.en, this.color, this.icon);
}

const List<_BrandCfg> _brands = <_BrandCfg>[
  _BrandCfg('fawori', 'فاوري', 'Fawori', Color(0xFFFF8C00), Icons.format_paint_rounded),
  _BrandCfg('isomat', 'آيزومات', 'Isomat', Color(0xFF2196F3), Icons.water_drop_rounded),
  _BrandCfg('cadence', 'كادينز', 'Cadence', Color(0xFF9C27B0), Icons.palette_rounded),
  _BrandCfg('sibax', 'سيباكس', 'Sibax', Color(0xFFC8961E), Icons.build_rounded),
];

const String _siteBase = 'https://ahmedbrzan.github.io/FAWORI';

/// ✅ ملاحظة متدرجة عائمة أسفل
void _gradSnack(BuildContext context, String msg, Color color, IconData icon) {
  ScaffoldMessenger.of(context).clearSnackBars();
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      margin: const EdgeInsets.all(12),
      padding: EdgeInsets.zero,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 2),
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[color, color.withAlpha(200)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(color: color.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProductsScreen extends StatefulWidget {
  final String? initialBrand;
  const ProductsScreen({super.key, this.initialBrand});
  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  int _cartCount = 0;
  String _q = '';
  String? _focusBrand;
  Map<String, String> _prodImg = <String, String>{};
  List<Product> _products = [];
  bool _loadingProducts = true;
  String? _catFilter;
  Set<String> _favIds = {};
  StreamSubscription<List<FireProduct>>? _sub;
  StreamSubscription<List<String>>? _subF;
  final _qCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();

  Future<void> _loadCachedProducts() async {
    try {
      final p = await SharedPreferences.getInstance();
      final cached = p.getStringList('products_cache');
      if (cached == null || cached.isEmpty) return;
      if (!mounted) return;
      setState(() {
        _products = cached
            .map((line) {
              try {
                final m = Map<String, dynamic>.from(jsonDecode(line));
                return Product(
                  id: '${m['id'] ?? ''}',
                  name: '${m['name'] ?? ''}',
                  brand: '${m['brand'] ?? ''}',
                  description: '${m['description'] ?? ''}',
                  image: '${m['image'] ?? ''}',
                  category: '${m['category'] ?? ''}',
                  price: (m['price'] as num?)?.toInt() ?? 0,
                );
              } catch (_) {
                return null;
              }
            })
            .whereType<Product>()
            .toList();
        _loadingProducts = false;
      });
    } catch (_) {}
  }

  Future<void> _saveProductsCache(List<Product> list) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList(
          'products_cache',
          list
              .map((e) => jsonEncode({
                    'id': e.id,
                    'name': e.name,
                    'brand': e.brand,
                    'description': e.description,
                    'image': e.image,
                    'category': e.category,
                    'price': e.price,
                  }))
              .toList());
    } catch (_) {}
  }

  Future<void> _loadProducts() async {
    try {
      final fire = await productRepo.list().timeout(const Duration(seconds: 8));
      if (!mounted) return;
      final list = fire
          .map((f) => Product(
                id: f.id,
                name: f.name,
                brand: f.brand,
                description: f.description,
                image: f.image,
                category: f.category,
                price: f.price,
              ))
          .toList();
      _saveProductsCache(list);
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    } catch (_) {
      // ✅ سقوط احتياطي للكتالوج المحلي عند فشل الاتصال
      if (!mounted) return;
      setState(() {
        _products = sampleData;
        _loadingProducts = false;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _refreshCount();
    _loadProdImages();
    _loadCachedProducts();
    _loadProducts();
    _sub = productRepo.stream().listen((fire) {
      if (!mounted) return;
      final list = fire
          .map((f) => Product(
                id: f.id,
                name: f.name,
                brand: f.brand,
                description: f.description,
                image: f.image,
                category: f.category,
                price: f.price,
              ))
          .toList();
      _saveProductsCache(list);
      setState(() {
        _products = list;
        _loadingProducts = false;
      });
    });
    _subF = favoritesRepo
        .stream(context.read<AppSettings>().user?.id ?? '')
        .listen((ids) {
      if (!mounted) return;
      setState(() => _favIds = ids.toSet());
    });
    if (widget.initialBrand != null && _brands.any((b) => b.key == widget.initialBrand)) {
      _focusBrand = widget.initialBrand;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollCtrl.hasClients) {
          _scrollCtrl.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _subF?.cancel();
    _qCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _refreshCount() async {
    final s = context.read<AppSettings>();
    try {
      final cart = await OrdersService.loadCart(s.user?.id ?? '');
      if (mounted) {
        setState(() => _cartCount = cart.fold(0, (p, c) => p + c.qty));
      }
    } catch (_) {}
  }

  Future<void> _loadProdImages() async {
    for (final path in const <String>['assets/data/images.json', 'assets/assets/data/images.json']) {
      try {
        final r = await http
            .get(Uri.parse('$_siteBase/$path?t=${DateTime.now().millisecondsSinceEpoch}'))
            .timeout(const Duration(seconds: 5));
        if (r.statusCode == 200) {
          final m = Map<String, dynamic>.from(jsonDecode(r.body));
          final g = m['products'];
          if (g is Map && mounted) {
            setState(() => _prodImg = Map<String, String>.from(g));
            return;
          }
        }
      } catch (_) {}
    }
  }

  String _imgOf(Product p) {
    final mapped = _prodImg[p.id];
    if (mapped != null && mapped.isNotEmpty) {
      return '$_siteBase/assets/$mapped';
    }
    return p.image;
  }

  Future<void> _addToCart(Product p, int qty) async {
    final s = context.read<AppSettings>();
    final uid = s.user?.id ?? '';
    if (uid.isEmpty || s.isGuest) {
      if (mounted) {
        _gradSnack(context, s.isArabic ? 'سجّل الدخول أولاً للشراء' : 'Login first to buy', Colors.red, Icons.lock_rounded);
      }
      return;
    }
    await OrdersService.addToCart(uid, p.id, p.name, '', p.brand, qty);
    await _refreshCount();
    if (mounted) {
      _gradSnack(context,
          s.isArabic ? 'أُضيف إلى السلة : $qty ${p.name}' : 'Added : $qty ${p.name}',
          const Color(0xFF0D9668), Icons.add_shopping_cart_rounded);
    }
  }

  Future<void> _openCart() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const CartScreen()));
    await _refreshCount();
  }

  Future<void> _openDetail(Product p) async {
    final s = context.read<AppSettings>();
    final canBuy = s.user != null && s.user!.role != 'guest';
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => ProductDetailScreen(product: p, canBuy: canBuy, onAdd: (q) => _addToCart(p, q))));
    await _refreshCount();
  }

  Widget _chip(String label, String? key, Color c) {
    final active = _focusBrand == key;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: () => setState(() {
              _focusBrand = key;
              _catFilter = null;
            }),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: active ? c : c.withAlpha(20),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.withAlpha(active ? 200 : 80)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : c,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ),
      ),
    );
  }

  Widget _catChip(String label, String? v) {
    final active = _catFilter == v;
    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: InkWell(
        onTap: () => setState(() => _catFilter = v),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: active ? AppColors.orange : AppColors.orange.withAlpha(18),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: AppColors.orange.withAlpha(active ? 200 : 70)),
          ),
          child: Text(label,
              style: TextStyle(
                  color: active ? Colors.white : AppColors.orange,
                  fontWeight: FontWeight.w800,
                  fontSize: 11)),
        ),
      ),
    );
  }

  _BrandCfg _brandCfg(String key) => _brands.firstWhere((b) => b.key == key);

  bool _catOk(Product p) {
    if (_catFilter == null) return true;
    return p.category.trim() == _catFilter;
  }

  List<String> _categories() {
    final pool = _focusBrand == null
        ? _products
        : _products.where((p) => p.brand == _focusBrand).toList();
    final set = <String>{};
    for (final p in pool) {
      final c = p.category.trim();
      if (c.isNotEmpty) set.add(c);
    }
    return set.toList()..sort();
  }

  List<Product> _filterBrand(String brandKey) {
    final base = _products.where((p) => p.brand == brandKey && _catOk(p));
    if (_q.trim().isEmpty) return base.toList();
    final q = _q.trim().toLowerCase();
    return base.where((p) => p.name.toLowerCase().contains(q) || p.description.toLowerCase().contains(q)).toList();
  }

  List<Product> _suggestions() {
    final q = _q.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return _products
        .where((p) => p.name.toLowerCase().contains(q) && _catOk(p))
        .take(8)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'المنتجات' : 'Products',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: dark ? Colors.white : AppColors.ink)),
        actions: [
          IconButton(
            onPressed: () {
              if (s.isGuest) {
                GuestGuard.lock(
                  context,
                  title: s.isArabic ? 'السلة مقفلة 🔒' : 'Cart locked 🔒',
                  message: s.isArabic
                      ? 'متاحة للمستخدمين المسجلين فقط. سجل دخولك لتتمكن من إضافة المنتجات وطلبها'
                      : 'Available for registered users only. Sign in to add and order products',
                  onLogin: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const LoginScreen())),
                  loginLabel: s.isArabic ? 'سجل دخولك الآن' : 'Sign in now',
                );
                return;
              }
              _openCart();
            },
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart_outlined, color: AppColors.orange, size: 24),
                if (_cartCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text('$_cartCount',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      body: _loadingProducts
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : RefreshIndicator(
              onRefresh: () async {
                await _loadProducts();
                await _loadProdImages();
              },
              color: AppColors.orange,
              child: ListView(
                controller: _scrollCtrl,
                padding: const EdgeInsets.all(16),
                children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: LinearGradient(
                colors: dark ? <Color>[const Color(0xFF1E1E28), const Color(0xFF26262E)] : <Color>[Colors.white, const Color(0xFFFFF8F1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: AppColors.orange.withAlpha(60), width: 1.2),
            ),
            child: TextField(
              controller: _qCtrl,
              selectionControls: materialTextSelectionControls,
              magnifierConfiguration: TextMagnifierConfiguration.disabled,
              onTap: () {
                _qCtrl.selection = TextSelection(
                    baseOffset: 0, extentOffset: _qCtrl.text.length);
              },
              onChanged: (v) => setState(() => _q = v),
              style: TextStyle(color: dark ? Colors.white : AppColors.ink, fontSize: 15),
              decoration: InputDecoration(
                hintText: s.isArabic ? 'ابحث عن مادة...' : 'Search product...',
                hintStyle: TextStyle(color: dark ? Colors.grey.shade500 : Colors.grey.shade400),
                prefixIcon: const Icon(Icons.search_rounded, color: AppColors.orange),
                suffixIcon: _q.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: Colors.red, size: 18),
                        onPressed: () {
                          _qCtrl.clear();
                          setState(() => _q = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _chip(s.isArabic ? 'الكل' : 'All', null, AppColors.teal),
                for (final b in _brands)
                  _chip(s.isArabic ? b.ar : b.en, b.key, b.color),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _catChip(s.isArabic ? 'كل الأنواع' : 'All types', null),
                for (final c in _categories()) _catChip(c, c),
              ],
            ),
          ),
          if (_suggestions().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.teal.withAlpha(80)),
              ),
              child: Column(
                children: [
                  for (final p in _suggestions())
                    InkWell(
                      onTap: () => _openDetail(p),
                      borderRadius: BorderRadius.circular(14),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            const Icon(Icons.search_rounded,
                                size: 16, color: AppColors.teal),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                            ),
                            Directionality(
                              textDirection: TextDirection.ltr,
                              child: Text('${p.price}',
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.orange,
                                      fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          if (_focusBrand != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: <Color>[_brandCfg(_focusBrand!).color, _brandCfg(_focusBrand!).color.withAlpha(220)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(color: _brandCfg(_focusBrand!).color.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(_brandCfg(_focusBrand!).icon, color: Colors.white, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.isArabic
                            ? '${_brandCfg(_focusBrand!).ar} — ${_filterBrand(_focusBrand!).length} مادة'
                            : '${_brandCfg(_focusBrand!).en} — ${_filterBrand(_focusBrand!).length} items',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Colors.white),
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _focusBrand = null),
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.apps_rounded, size: 16, color: Colors.white),
                            const SizedBox(width: 4),
                            Text(s.isArabic ? 'كل الأقسام' : 'All',
                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          for (final b in (_focusBrand == null ? _brands : _brands.where((x) => x.key == _focusBrand).toList()))
            _buildSection(b, dark, s),
                ],
              ),
            ),
    );
  }

  Widget _buildSection(_BrandCfg b, bool dark, AppSettings s) {
    final items = _filterBrand(b.key);
    if (items.isEmpty && _q.trim().isNotEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[b.color, b.color.withAlpha(220)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(color: b.color.withAlpha(80), blurRadius: 12, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              children: [
                Icon(b.icon, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(s.isArabic ? b.ar : b.en,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text('${items.length} ${s.isArabic ? 'مادة' : 'items'}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 30),
              decoration: BoxDecoration(
                color: dark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: b.color.withAlpha(40)),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(b.icon, color: b.color.withAlpha(80), size: 48),
                    const SizedBox(height: 8),
                    Text(s.isArabic ? 'لا توجد منتجات' : 'No products',
                        style: TextStyle(color: dark ? Colors.grey.shade400 : Colors.grey.shade600, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.85,
              ),
              itemCount: items.length,
              itemBuilder: (context, i) {
                final p = items[i];
                return Stack(
                  children: [
                    Pressable(
                      onTap: () => _openDetail(p),
                      child: Container(
                        height: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: dark
                                ? <Color>[const Color(0xFF1E1E28), const Color(0xFF26262E)]
                                : <Color>[Colors.white, const Color(0xFFFFF8F1)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: b.color.withAlpha(50)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(dark ? 50 : 10), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Builder(builder: (context) {
                                final url = _imgOf(p);
                                if (url.isEmpty) {
                                  return Center(child: Icon(b.icon, size: 46, color: b.color));
                                }
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.contain,
                                    width: double.infinity,
                                    cacheWidth: 320,
                                    gaplessPlayback: true,
                                    loadingBuilder: (c, child, prog) => prog == null
                                        ? child
                                        : Center(child: Icon(b.icon, size: 40, color: b.color.withAlpha(120))),
                                    errorBuilder: (c, e, st) => Center(child: Icon(b.icon, size: 46, color: b.color)),
                                  ),
                                );
                              }),
                            ),
                            const SizedBox(height: 12),
                            Text(p.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: dark ? Colors.white : AppColors.ink)),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: b.color.withAlpha(25),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(s.isArabic ? b.ar : b.en,
                                  style: TextStyle(color: b.color, fontSize: 10, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!s.isGuest)
                      PositionedDirectional(
                        top: 10,
                        end: 10,
                        child: InkWell(
                          onTap: () => favoritesRepo.toggle(
                              context.read<AppSettings>().user?.id ?? '',
                              p.id),
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: dark
                                  ? const Color(0xFF1E1E28)
                                  : Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                    color:
                                        Colors.black.withAlpha(dark ? 60 : 20),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2)),
                              ],
                            ),
                            child: Icon(
                                _favIds.contains(p.id)
                                    ? Icons.favorite_rounded
                                    : Icons.favorite_border_rounded,
                                color: Colors.red,
                                size: 18),
                          ),
                        ),
                      ),
                    if (!s.isGuest)
                      PositionedDirectional(
                        bottom: 10,
                        end: 10,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _addToCart(p, 1),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(colors: <Color>[b.color, b.color.withAlpha(220)]),
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(color: b.color.withAlpha(90), blurRadius: 10, offset: const Offset(0, 3)),
                                ],
                              ),
                              child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}
