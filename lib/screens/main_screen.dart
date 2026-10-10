import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/guest_guard.dart';
import '../core/theme.dart';
import 'admin_users.dart';
import 'home_screen.dart';
import 'media_admin_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';
import 'simple_screens.dart';

const double _kBarH = 62;
const double _kStackH = 84;
const double _kCircle = 54;
const double _kR = _kBarH / 2;
const double _kNotchW = 26;
const double _kNotchS = 6;
const double _kNotchD = 38;

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});
  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _idx = 0;

  void _onTab(int i, bool isGuest, bool isArabic, int totalTabs) {
    if (isGuest && i == 2) {
      GuestGuard.lock(
        context,
        title: isArabic ? 'المحفظة مقفلة 🔒' : 'Wallet locked 🔒',
        message: isArabic
            ? 'سجل دخولك أولاً واشتري مواد فاوري لتربح النقاط'
            : 'Sign in first and buy Fawori products to earn points',
        onLogin: () => setState(() => _idx = totalTabs - 1),
        loginLabel: isArabic ? 'تسجيل الدخول' : 'Sign in',
      );
      return;
    }
    setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final bool isAdmin = s.isAdmin || s.isImageAdmin;
    final bool isController = s.isController;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    // ✅ بناء القوائم حسب الدور
    final screens = <Widget>[];
    final icons = <IconData>[];
    final labels = <String>[];

    // التبويب 0: الرئيسية
    screens.add(HomeScreen(onOpenProducts: () => setState(() => _idx = 1)));
    icons.add(Icons.home_rounded);
    labels.add(s.isArabic ? 'الرئيسية' : 'Home');

    // التبويب 1: المنتجات
    screens.add(const ProductsScreen());
    icons.add(Icons.grid_view_rounded);
    labels.add(s.isArabic ? 'المنتجات' : 'Products');

    // التبويب 2: المحفظة
    screens.add(const WalletScreen());
    icons.add(Icons.account_balance_wallet_rounded);
    labels.add(s.isArabic
        ? (isAdmin ? 'النقاط والرصيد' : 'المحفظة')
        : (isAdmin ? 'Points' : 'Wallet'));

    // التبويب 3: المستخدمون (للمتحكم والمدير)
    if (isAdmin) {
      screens.add(const AdminUsersPage());
      icons.add(Icons.person_add_alt_1_rounded);
      labels.add(s.isArabic ? 'المستخدمون' : 'Users');
    } else {
      screens.add(const FavoritesScreen());
      icons.add(Icons.favorite_rounded);
      labels.add(s.isArabic ? 'المفضلة' : 'Favorites');
    }

    // التبويب 4: الإدارة (للمتحكم فقط) أو إدارة الإعلام (للمدير) أو الملف الشخصي
    if (isController) {
      screens.add(const AdminCodeView());
      icons.add(Icons.code_rounded);
      labels.add(s.isArabic ? 'الإدارة' : 'Admin');
    } else if (isAdmin) {
      screens.add(const MediaAdminScreen());
      icons.add(Icons.campaign_rounded);
      labels.add(s.isArabic ? 'إدارة الإعلام' : 'Media');
    } else {
      screens.add(const ProfileScreen());
      icons.add(Icons.person_rounded);
      labels.add(s.isArabic ? 'ملف شخصي' : 'Profile');
    }

    // التبويب 5: الملف الشخصي (للمتحكم والمدير)
    if (isAdmin) {
      screens.add(const ProfileScreen());
      icons.add(Icons.person_rounded);
      labels.add(s.isArabic ? 'ملف شخصي' : 'Profile');
    }

    final totalTabs = screens.length;

    return Scaffold(
      extendBody: true,
      body: IndexedStack(index: _idx, children: screens),
      bottomNavigationBar: _FancyBottomNav(
        index: _idx,
        dark: dark,
        icons: icons,
        labels: labels,
        onTap: (i) => _onTab(i, s.isGuest, s.isArabic, totalTabs),
      ),
    );
  }
}

class _FancyBottomNav extends StatefulWidget {
  final int index;
  final bool dark;
  final List<IconData> icons;
  final List<String> labels;
  final ValueChanged<int> onTap;
  const _FancyBottomNav({
    required this.index,
    required this.dark,
    required this.icons,
    required this.labels,
    required this.onTap,
  });
  @override
  State<_FancyBottomNav> createState() => _FancyBottomNavState();
}

class _FancyBottomNavState extends State<_FancyBottomNav>
    with SingleTickerProviderStateMixin {
  late int _prev;
  bool _press = false;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _prev = widget.index;
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 430));
    _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant _FancyBottomNav old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _prev = old.index;
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.dark;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final totalTabs = widget.icons.length;
    
    return Padding(
      padding: EdgeInsets.fromLTRB(
          18, 0, 18, MediaQuery.of(context).padding.bottom + 10),
      child: LayoutBuilder(
        builder: (context, cons) {
          final W = cons.maxWidth;
          const double pad = 14;
          final slotInner = (W - pad * 2) / totalTabs;
          double centerOf(int i) {
            final c = pad + slotInner * i + slotInner / 2;
            return rtl ? W - c : c;
          }

          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) {
              final t = Curves.easeOutBack.transform(_c.value);
              final cx = centerOf(_prev) +
                  (centerOf(widget.index) - centerOf(_prev)) * t;
              return SizedBox(
                height: _kStackH,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: CustomPaint(
                        size: Size(W, _kBarH),
                        painter: _BarPainter(cx: cx, dark: dark),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 8,
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 4,
                          decoration: BoxDecoration(
                            color: dark
                                ? Colors.white.withAlpha(28)
                                : Colors.black.withAlpha(22),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pad,
                      right: pad,
                      bottom: 0,
                      child: SizedBox(
                        height: _kBarH,
                        child: Row(
                          children: List.generate(totalTabs, (i) {
                            final active = widget.index == i;
                            return Expanded(
                              child: _NavInk(
                                onTap: () => widget.onTap(i),
                                tooltip: widget.labels[i],
                                child: AnimatedOpacity(
                                  duration: const Duration(milliseconds: 200),
                                  opacity: active ? 0 : 1,
                                  child: Icon(
                                    widget.icons[i],
                                    size: 23,
                                    color: dark
                                        ? Colors.grey.shade300
                                        : const Color(0xFF3F3F4A),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                    Positioned(
                      left: cx - _kCircle / 2,
                      top: _kStackH - _kBarH - _kCircle / 2 + 8,
                      child: GestureDetector(
                        onTapDown: (_) => setState(() => _press = true),
                        onTapUp: (_) => setState(() => _press = false),
                        onTapCancel: () => setState(() => _press = false),
                        onTap: () => widget.onTap(widget.index),
                        child: Tooltip(
                          message: widget.labels[widget.index],
                          child: AnimatedScale(
                            scale: (_press ? 0.9 : 1) *
                                (1 +
                                    0.14 *
                                        math.sin(math.pi *
                                            _c.value.clamp(0.0, 1.0))),
                            duration: const Duration(milliseconds: 130),
                            curve: Curves.easeOut,
                            child: Container(
                              width: _kCircle,
                              height: _kCircle,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: <Color>[
                                    Color(0xFFFFA500),
                                    Color(0xFFF26B0F),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF26B0F)
                                        .withAlpha(dark ? 150 : 120),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: const Color(0xFFFFA500)
                                        .withAlpha(70),
                                    blurRadius: 36,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Icon(
                                  widget.icons[widget.index],
                                  key: ValueKey<int>(widget.index),
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _NavInk extends StatelessWidget {
  final VoidCallback onTap;
  final String tooltip;
  final Widget child;
  const _NavInk(
      {required this.onTap, required this.tooltip, required this.child});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(_kR),
        child: SizedBox(
          height: _kBarH,
          child: Center(child: child),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double cx;
  final bool dark;
  _BarPainter({required this.cx, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final W = size.width;
    const top = 0.0;
    final lx = cx - _kNotchW - _kNotchS;
    final rx = cx + _kNotchW + _kNotchS;

    double capYLeft(double x) {
      if (x >= _kR) return top;
      final dx = _kR - x;
      if (dx >= _kR) return top + _kR;
      return top + _kR - math.sqrt(_kR * _kR - dx * dx);
    }

    double capYRight(double x) {
      if (x <= W - _kR) return top;
      final dx = x - (W - _kR);
      if (dx >= _kR) return top + _kR;
      return top + _kR - math.sqrt(_kR * _kR - dx * dx);
    }

    final ly = capYLeft(lx);
    final ry = capYRight(rx);

    final p = Path()..moveTo(0, top + _kR);
    if (lx >= _kR) {
      p.quadraticBezierTo(0, top, _kR, top);
      p.lineTo(lx, top);
    } else {
      p.quadraticBezierTo(0, ly, lx, ly);
    }
    p.quadraticBezierTo(
        cx - _kNotchW + 4, ly + 4, cx - _kNotchW + 6, _kNotchD * 0.5);
    p.quadraticBezierTo(cx - _kNotchW * 0.4, _kNotchD, cx, _kNotchD);
    p.quadraticBezierTo(cx + _kNotchW * 0.4, _kNotchD, cx + _kNotchW - 6,
        _kNotchD * 0.5);
    p.quadraticBezierTo(cx + _kNotchW - 4, ry + 4, rx, ry);
    if (rx <= W - _kR) {
      p.lineTo(W - _kR, top);
      p.quadraticBezierTo(W, top, W, top + _kR);
    } else {
      p.quadraticBezierTo(W, ry, W, top + _kR);
    }
    p.quadraticBezierTo(W, top + _kBarH, W - _kR, top + _kBarH);
    p.lineTo(_kR, top + _kBarH);
    p.quadraticBezierTo(0, top + _kBarH, 0, top + _kR);
    p.close();

    canvas.drawShadow(p, Colors.black.withAlpha(90), 14, true);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: dark
            ? const <Color>[Color(0xFF24242E), Color(0xFF191920)]
            : const <Color>[Colors.white, Color(0xFFF4F4F8)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, top, W, _kBarH));
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.cx != cx || old.dark != dark;
}
