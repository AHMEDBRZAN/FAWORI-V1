import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/theme.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phone = TextEditingController();
  final _pass = TextEditingController();
  final _phoneFocus = FocusNode();
  final _passFocus = FocusNode();
  late final AnimationController _glow = AnimationController(
      vsync: this, duration: const Duration(seconds: 7))
    ..repeat();
  bool _busy = false;
  String? _err;
  bool _obscure = true;
  bool _open = false;

  @override
  void dispose() {
    _glow.dispose();
    _phone.dispose();
    _pass.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  void _go() {
    if (!mounted) return;
    _phoneFocus.unfocus();
    _passFocus.unfocus();
    Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const MainScreen()), (r) => false);
  }

  Future<void> _login() async {
    if (_busy || !mounted) return;
    final settings = context.read<AppSettings>();
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final ph = _phone.text.trim();
      final pw = _pass.text.trim();
      if (ph.isEmpty || pw.isEmpty) {
        setState(() {
          _busy = false;
          _err = settings.isArabic
              ? 'أدخل الهاتف وكلمة المرور'
              : 'Enter phone & password';
        });
        return;
      }
      final ok = await settings.loginWithFirebase(ph, pw);
      if (!ok) {
        setState(() {
          _busy = false;
          _err = settings.isArabic
              ? 'بيانات الدخول غير صحيحة'
              : 'Invalid credentials';
        });
        return;
      }
      _go();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = settings.isArabic ? 'تعذر الدخول: $e' : 'Login failed: $e';
        });
      }
    }
  }

  Future<void> _guest() async {
    if (_busy || !mounted) return;
    final settings = context.read<AppSettings>();
    setState(() => _busy = true);
    try {
      await settings.loginAsGuest();
      _go();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _err = settings.isArabic ? 'تعذر دخول الضيف: $e' : 'Guest failed: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final bool dark = settings.isDark;
    final bool ar = settings.isArabic;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? const <Color>[Color(0xFF141419), Color(0xFF1B1B21)]
                : const <Color>[Color(0xFFFFF8F1), Color(0xFFFDEFDE)],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              Positioned(
                top: 16,
                left: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF26262E) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.orange.withAlpha(60)),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.orange.withAlpha(20),
                          blurRadius: 8),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                        dark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        color: AppColors.orange,
                        size: 22),
                    onPressed: () =>
                        context.read<AppSettings>().toggleDark(),
                  ),
                ),
              ),
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                                color: AppColors.orange.withAlpha(90),
                                blurRadius: 26,
                                offset: const Offset(0, 10)),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.asset('assets/images/logo.webp',
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                              errorBuilder: (c, o, st) => Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(colors: <Color>[
                                        Color(0xFFFFA500),
                                        Color(0xFFFF8C00)
                                      ]),
                                    ),
                                    child: const Center(
                                      child: Text('FAWORI',
                                          style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900)),
                                    ),
                                  )),
                        ),
                      ),
                      const SizedBox(height: 26),
                      AnimatedBuilder(
                        animation: _glow,
                        builder: (context, child) => CustomPaint(
                          painter: _GlowBorderPainter(
                              angle: _glow.value * 2 * math.pi, dark: dark),
                          child: child,
                        ),
                        child: Container(
                          margin: const EdgeInsets.all(7),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF1E1E28)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () =>
                                    setState(() => _open = !_open),
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 13),
                                  decoration: BoxDecoration(
                                    color: dark
                                        ? Colors.black.withAlpha(60)
                                        : const Color(0xFFFAF6EF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: AppColors.orange
                                            .withAlpha(50)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: AppColors.orange
                                              .withAlpha(30),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: AppColors.orange
                                                    .withAlpha(120),
                                                blurRadius: 8),
                                          ],
                                        ),
                                        child: const Icon(
                                            Icons.login_rounded,
                                            color: AppColors.orange,
                                            size: 15),
                                      ),
                                      const SizedBox(width: 10),
                                      ShaderMask(
                                        shaderCallback: (Rect r) =>
                                            const LinearGradient(colors: <Color>[
                                              AppColors.orange,
                                              Color(0xFFF26B0F)
                                            ]).createShader(r),
                                        child: Text(
                                            ar ? 'تسجيل الدخول' : 'LOGIN',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 2)),
                                      ),
                                      const SizedBox(width: 10),
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color:
                                              AppColors.teal.withAlpha(30),
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                                color: AppColors.teal
                                                    .withAlpha(120),
                                                blurRadius: 8),
                                          ],
                                        ),
                                        child: const Icon(
                                            Icons.favorite_rounded,
                                            color: AppColors.teal,
                                            size: 15),
                                      ),
                                      const Spacer(),
                                      AnimatedRotation(
                                        turns: _open ? 0.5 : 0,
                                        duration:
                                            const Duration(milliseconds: 400),
                                        child: Icon(
                                            Icons.expand_more_rounded,
                                            color: dark
                                                ? Colors.grey.shade400
                                                : Colors.grey.shade600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              AnimatedSize(
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                                child: _open
                                    ? Padding(
                                        padding:
                                            const EdgeInsets.only(top: 18),
                                        child: Column(
                                          children: [
                                            TextField(
                                              controller: _phone,
                                              focusNode: _phoneFocus,
                                              keyboardType:
                                                  TextInputType.phone,
                                              textInputAction:
                                                  TextInputAction.next,
                                              onSubmitted: (_) =>
                                                  _passFocus.requestFocus(),
                                              style: TextStyle(
                                                  color: dark
                                                      ? Colors.white
                                                      : AppColors.ink),
                                              decoration: InputDecoration(
                                                hintText: ar
                                                    ? 'رقم الهاتف'
                                                    : 'Phone',
                                                filled: true,
                                                fillColor: dark
                                                    ? const Color(0xFF26262E)
                                                    : const Color(0xFFFAFAFA),
                                                prefixIcon: const Icon(
                                                    Icons.phone_rounded,
                                                    color: AppColors.orange),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30)),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                  borderSide: BorderSide(
                                                      color: AppColors.orange
                                                          .withAlpha(90)),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                  borderSide: const BorderSide(
                                                      color: AppColors.teal,
                                                      width: 2),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 14),
                                            TextField(
                                              controller: _pass,
                                              focusNode: _passFocus,
                                              obscureText: _obscure,
                                              textInputAction:
                                                  TextInputAction.done,
                                              onSubmitted: (_) => _login(),
                                              style: TextStyle(
                                                  color: dark
                                                      ? Colors.white
                                                      : AppColors.ink),
                                              decoration: InputDecoration(
                                                hintText: ar
                                                    ? 'كلمة المرور'
                                                    : 'Password',
                                                filled: true,
                                                fillColor: dark
                                                    ? const Color(0xFF26262E)
                                                    : const Color(0xFFFAFAFA),
                                                prefixIcon: const Icon(
                                                    Icons.lock_rounded,
                                                    color: AppColors.orange),
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                      _obscure
                                                          ? Icons
                                                              .visibility_off_rounded
                                                          : Icons
                                                              .visibility_rounded,
                                                      color: Colors
                                                          .grey.shade500),
                                                  onPressed: () => setState(
                                                      () => _obscure =
                                                          !_obscure),
                                                ),
                                                border: OutlineInputBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30)),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                  borderSide: BorderSide(
                                                      color: AppColors.orange
                                                          .withAlpha(90)),
                                                ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          30),
                                                  borderSide: const BorderSide(
                                                      color: AppColors.teal,
                                                      width: 2),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 18),
                                            Container(
                                              width: double.infinity,
                                              height: 52,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                    colors: <Color>[
                                                      AppColors.orange,
                                                      Color(0xFFF26B0F)
                                                    ]),
                                                borderRadius:
                                                    BorderRadius.circular(30),
                                                boxShadow: [
                                                  BoxShadow(
                                                      color: AppColors.orange
                                                          .withAlpha(110),
                                                      blurRadius: 18,
                                                      offset: const Offset(
                                                          0, 8)),
                                                ],
                                              ),
                                              child: ElevatedButton(
                                                style: ElevatedButton
                                                    .styleFrom(
                                                  backgroundColor:
                                                      Colors.transparent,
                                                  shadowColor:
                                                      Colors.transparent,
                                                  foregroundColor:
                                                      Colors.white,
                                                  shape:
                                                      RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            30),
                                                  ),
                                                ),
                                                onPressed:
                                                    _busy ? null : _login,
                                                child: _busy
                                                    ? const SizedBox(
                                                        width: 22,
                                                        height: 22,
                                                        child: CircularProgressIndicator(
                                                            strokeWidth: 2.5,
                                                            color: Colors
                                                                .white),
                                                      )
                                                    : Text(
                                                        ar
                                                            ? 'دخول'
                                                            : 'Sign In',
                                                        style: const TextStyle(
                                                            fontSize: 16,
                                                            fontWeight:
                                                                FontWeight
                                                                    .w900)),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                TextButton(
                                                  onPressed: _busy
                                                      ? null
                                                      : _guest,
                                                  child: Text(
                                                      ar
                                                          ? 'دخول كضيف'
                                                          : 'Enter as guest',
                                                      style: const TextStyle(
                                                          color:
                                                              AppColors.teal,
                                                          fontWeight:
                                                              FontWeight.w800,
                                                          fontSize: 13)),
                                                ),
                                              ],
                                            ),
                                            if (_err != null) ...[
                                              const SizedBox(height: 8),
                                              Container(
                                                padding:
                                                    const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.red
                                                      .withAlpha(20),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          12),
                                                  border: Border.all(
                                                      color: Colors.red
                                                          .withAlpha(60)),
                                                ),
                                                child: Text(_err!,
                                                    style: const TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 12),
                                                    textAlign:
                                                        TextAlign.center),
                                              ),
                                            ],
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Text(
                          ar
                              ? 'شركة فاوِري — جودة تدوم'
                              : 'FAWORI Co. — Quality that lasts',
                          style: TextStyle(
                              color: dark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlowBorderPainter extends CustomPainter {
  final double angle;
  final bool dark;
  _GlowBorderPainter({required this.angle, required this.dark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, size.height - 8);
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(24));

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = AppColors.orange.withAlpha(dark ? 80 : 60);
    canvas.drawRRect(rrect, base);

    final gradient = SweepGradient(
      startAngle: angle,
      endAngle: angle + 2 * math.pi,
      colors: const <Color>[
        Color(0xFFFF8C00),
        Colors.transparent,
        AppColors.teal,
        Colors.transparent,
        Color(0xFFFF8C00),
      ],
      stops: const <double>[0.0, 0.25, 0.5, 0.75, 1.0],
    );
    final shader = gradient.createShader(rect);

    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
          ..shader = shader);

    canvas.drawRRect(
        rrect,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..shader = shader);
  }

  @override
  bool shouldRepaint(covariant _GlowBorderPainter old) =>
      old.angle != angle || old.dark != dark;
}
