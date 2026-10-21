import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/app_settings.dart';
import 'core/favorites.dart';
import 'core/firebase_options.dart';
import 'core/messenger.dart';
import 'core/theme.dart';
import 'screens/login_screen.dart';
import 'screens/main_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // ✅ نُظهر الشعار فوراً قبل تهيئة Firebase الثقيلة
  runApp(const _BootApp());
}

class _BootApp extends StatefulWidget {
  const _BootApp();
  @override
  State<_BootApp> createState() => _BootAppState();
}

class _BootAppState extends State<_BootApp> {
  bool _ready = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (mounted) setState(() => _ready = true);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_err != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF26B0F),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Text(
                'تعذّرت تهيئة الخدمة.\nتحقّق من الاتصال ثم أعد الفتح.\n\n$_err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, height: 1.6),
              ),
            ),
          ),
        ),
      );
    }
    if (!_ready) {
      // ✅ الشعار يظهر خلال ملّي ثوانٍ أثناء تهيئة Firebase
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          backgroundColor: const Color(0xFFF26B0F),
          body: const _SplashBody(),
        ),
      );
    }
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppSettings()),
        ChangeNotifierProvider(create: (_) => Favorites()),
      ],
      child: const FaworiApp(),
    );
  }
}

/// ✅ محتوى الشعار المشترك (بدون Scaffold — يُلفّ حسب الحاجة)
class _SplashBody extends StatelessWidget {
  const _SplashBody();
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            Color(0xFFFFA149),
            Color(0xFFF98A2B),
            Color(0xFFF26B0F),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: <double>[0.0, 0.55, 1.0],
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: const Color(0xFF111111),
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withAlpha(80),
                      blurRadius: 40,
                      offset: const Offset(0, 12)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(33),
                child: Image.asset(
                  'assets/images/logo.webp',
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (c, o, st) => const Center(
                    child: Text('FAWORI',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w900)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                  strokeWidth: 3, color: Color(0xFF3B1A00)),
            ),
          ],
        ),
      ),
    );
  }
}

class FaworiApp extends StatelessWidget {
  const FaworiApp({super.key});
  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    return MaterialApp(
      title: 'FAWORI',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: messengerKey,
      themeMode: s.isDark ? ThemeMode.dark : ThemeMode.light,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: const _Gate(),
      builder: (context, child) => Directionality(
        textDirection: s.isArabic ? TextDirection.rtl : TextDirection.ltr,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}

class _Gate extends StatefulWidget {
  const _Gate();
  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    final st = context.read<AppSettings>();
    // ✅ استعادة فورية من التخزين المحلي — بدون انتظار الشبكة
    try {
      await st.restoreLocal();
    } catch (_) {}
    if (mounted) setState(() => _ready = true);
    // ✅ التحديث الشبكي في الخلفية بعد بناء الواجهة
    unawaited(st.restoreSession());
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    if (_ready) {
      return s.isLoggedIn ? const MainScreen() : const LoginScreen();
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF26B0F),
      body: const _SplashBody(),
    );
  }
}
