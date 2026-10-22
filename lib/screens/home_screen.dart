import 'dart:async';
import 'dart:convert';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/guest_guard.dart';
import '../core/orders_service.dart';
import '../core/store_service.dart';
import '../core/theme.dart';
import '../widgets/fawori_logo.dart';
import '../widgets/gifts_view.dart';
import '../widgets/pressable.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'orders_screen.dart';
import 'products_screen.dart';
import 'profile_screen.dart';

const String _base = 'https://ahmedbrzan.github.io/FAWORI';
const int _kPages = 10000;
const int _kStart = 1000;

final String _cacheBuster = DateTime.now().millisecondsSinceEpoch.toString();
String _imgUrl(String p) => '$_base/assets/$p?t=$_cacheBuster';

class _AdvancedImageCache {
  final Map<String, ImageProvider> _cache = {};
  ImageProvider getProvider(String url) {
    if (_cache.containsKey(url)) return _cache[url]!;
    final provider = NetworkImage(url);
    _cache[url] = provider;
    return provider;
  }
}

final _AdvancedImageCache _imgCache = _AdvancedImageCache();

// ✅ روابط الاستفسارات (عدّلها هنا وقتما تشاء)
const String _kInstagram = 'https://www.instagram.com/';
const String _kFacebook = 'https://www.facebook.com/';
const String _kWhatsapp = 'https://wa.me/9647803827260';

Future<Map<String, dynamic>> _loadImgs() async {
  try {
    final r = await http.get(Uri.parse(
        '$_base/assets/assets/data/images.json?t=$_cacheBuster'));
    if (r.statusCode == 200) return Map<String, dynamic>.from(jsonDecode(r.body));
  } catch (_) {}
  return {};
}

const List<String> _companyKeys = ['fawori', 'isomat', 'cadence', 'sibax'];
const Map<String, String> _companyAr = {
  'fawori': 'فاوري',
  'isomat': 'آيزومات',
  'cadence': 'كادينز',
  'sibax': 'سيباكس',
};
const Map<String, String> _companyEn = {
  'fawori': 'FAWORI',
  'isomat': 'ISOMAT',
  'cadence': 'CADENCE',
  'sibax': 'SIBAX',
};
const Map<String, Color> _companyColor = {
  'fawori': AppColors.orange,
  'isomat': Color(0xFFE5484D),
  'cadence': Color(0xFF9B59B6),
  'sibax': Color(0xFFC8961E),
};
const Map<String, IconData> _companyIcon = {
  'fawori': Icons.inventory_2_rounded,
  'isomat': Icons.grid_view_rounded,
  'cadence': Icons.palette_rounded,
  'sibax': Icons.build_rounded,
};

/// 🚀 شاشة «ترقبوا التحديث القادم»
class _ComingSoonScreen extends StatelessWidget {
  const _ComingSoonScreen();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'إعلام' : 'Media'),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? <Color>[const Color(0xFF1A1A21), const Color(0xFF23232B)]
                : <Color>[const Color(0xFFFFF8F1), const Color(0xFFFDEFDE)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ✅ دائرة متدرجة تحتوي الأيقونة
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF6A11CB),
                          Color(0xFF2575FC),
                          Color(0xFF1E3C72),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6A11CB).withAlpha(100),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.campaign_rounded,
                        color: Colors.white, size: 70),
                  ),
                  const SizedBox(height: 28),
                  // ✅ عنوان كبير بتدرج برتقالي
                  ShaderMask(
                    shaderCallback: (Rect r) =>
                        const LinearGradient(colors: <Color>[
                          AppColors.orange,
                          Color(0xFFF26B0F)
                        ]).createShader(r),
                    child: Text(
                        s.isArabic
                            ? 'ترقبوا التحديث القادم'
                            : 'Stay tuned for next update',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(height: 16),
                  // ✅ سطر تشجيعي
                  Text(
                      s.isArabic
                          ? 'نعمل على محتوى إعلامي جديد\nيخص شركتنا وشركائنا'
                          : 'We are preparing new media content\nabout our company and partners',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: dark
                              ? Colors.grey.shade400
                              : Colors.grey.shade700,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 1.6)),
                  const SizedBox(height: 28),
                  // ✅ بطاقة معلومات متدرجة
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFF6A11CB),
                          Color(0xFF2575FC),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF2575FC).withAlpha(80),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.new_releases_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  s.isArabic
                                      ? 'شروحات فيديو'
                                      : 'Video tutorials',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.article_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  s.isArabic
                                      ? 'مقالات ونشرات'
                                      : 'Articles & newsletters',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            const Icon(Icons.event_rounded,
                                color: Colors.white, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  s.isArabic
                                      ? 'فعاليات ومعارض'
                                      : 'Events & exhibitions',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenProducts;
  const HomeScreen({super.key, this.onOpenProducts});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final PageController _ctrl = PageController(initialPage: _kStart);
  Timer? _timer;
  int _idx = 0;
  List<String> _homeImages = [];
  Map<String, String> _brandMap = {};
  int _customerNotifs = 0;

  static const List<String> _defaultBanners = <String>[
    'assets/images/BB-1.webp',
    'assets/images/BB-2.webp',
    'assets/images/BB-3.webp',
    'assets/images/BB-4.webp',
    'assets/images/BB-5.webp',
  ];

  int get _count =>
      _homeImages.isNotEmpty ? _homeImages.length : _defaultBanners.length;

  @override
  void initState() {
    super.initState();
    _loadImages();
    _startAuto();
    _loadCustomerNotifs();
  }

  Future<void> _loadCustomerNotifs() async {
    final s = context.read<AppSettings>();
    if (s.isGuest) return;
    try {
      final n = await OrdersService.unseenCustomerNotifs(s.user?.id ?? '');
      if (mounted) setState(() => _customerNotifs = n);
    } catch (_) {}
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _loadImages() async {
    final m = await _loadImgs();
    if (mounted) {
      setState(() {
        _homeImages = List<String>.from(m['home'] ?? []);
        _brandMap = Map<String, String>.from(m['brands'] ?? {});
      });
      for (final img in _homeImages.take(5)) {
        precacheImage(NetworkImage(_imgUrl(img)), context);
      }
      for (final img in _brandMap.values) {
        if (img.isNotEmpty) precacheImage(NetworkImage(_imgUrl(img)), context);
      }
    }
  }

  void _startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (!mounted || !_ctrl.hasClients) return;
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
    });
  }

  Future<void> _uploadBrand(String key) async {
    String tk = await ImagesService.resolveToken();
    if (tk.isEmpty) {
      final t = await ImagesService.askGitHubToken(context);
      if (t == null) return;
      tk = t;
    }
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 80, maxWidth: 600);
    if (f == null) return;
    final bytes = await f.readAsBytes();
    try {
      final path = 'assets/images/brand_$key.webp';
      await ImagesService.putBytes(path, bytes, tk, 'brand $key');
      await ImagesService.setMapping('brands', key, path, tk);
      final m = await _loadImgs();
      if (mounted) {
        setState(() {
          _brandMap = Map<String, String>.from(m['brands'] ?? {});
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('✅ تم رفع صورة $key')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('فشل الرفع: $e')));
      }
    }
  }

  void _openSettings(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSt) {
          final s2 = ctx.watch<AppSettings>();
          return AlertDialog(
            backgroundColor: Theme.of(context).colorScheme.surface,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.settings_rounded,
                    color: AppColors.orange),
                const SizedBox(width: 8),
                Text(s2.isArabic ? 'الإعدادات' : 'Settings',
                    style:
                        const TextStyle(fontWeight: FontWeight.w900)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          s2.isArabic ? 'الوضع الداكن' : 'Dark mode',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: s2.isDark,
                      activeColor: AppColors.orange,
                      onChanged: (_) {
                        s2.toggleDark();
                        setSt(() {});
                      },
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          s2.isArabic ? 'اللغة الإنجليزية' : 'Arabic',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700)),
                    ),
                    Switch(
                      value: !s2.isArabic,
                      activeColor: AppColors.orange,
                      onChanged: (_) {
                        s2.toggleLanguage();
                        setSt(() {});
                      },
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(s2.isArabic ? 'إغلاق' : 'Close',
                    style: const TextStyle(color: AppColors.orange)),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppSettings s) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                  s.isArabic ? 'تسجيل الخروج' : 'Logout',
                  style: const TextStyle(
                      color: Colors.red, fontWeight: FontWeight.w900)),
            ),
          ],
        ),
        content: Text(
            s.isArabic
                ? 'هل تريد تسجيل الخروج من حساب ${s.user?.name ?? ''}؟'
                : 'Do you want to logout from ${s.user?.name ?? ''}?',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.isArabic ? 'إلغاء' : 'Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(ctx);
              s.logout();
              // ✅ انتقال صريح لشاشة الدخول (مدير + مستخدم)
              Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (r) => false);
            },
            child: Text(s.isArabic ? 'خروج' : 'Logout'),
          ),
        ],
      ),
    );
  }

  Widget _socialBtn({
    required IconData icon,
    required List<Color> colors,
    required String url,
  }) {
    return InkWell(
      onTap: () => html.window.open(url, '_blank'),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: colors.first.withAlpha(90),
                blurRadius: 10,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 22),
      ),
    );
  }

  Widget _buildDrawer(AppSettings s, bool dark) {
    return Drawer(
      width: 280,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: dark
                ? <Color>[const Color(0xFF23232B), const Color(0xFF1A1A21)]
                : <Color>[const Color(0xFFFFF8F1), const Color(0xFFFDEFDE)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: <Color>[Color(0xFFFF8C00), Color(0xFFF26B0F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.orange.withAlpha(90),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset('assets/images/logo.webp',
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (c, o, st) =>
                              const FaworiLogo(size: 92)),
                    ),
                    const SizedBox(height: 10),
                    Text(s.isArabic ? 'شركة فاوري' : 'FAWORI Co.',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // ✅ الملف الشخصي (للمدير/المتحكم فقط)
                    if (s.isAdmin || s.isImageAdmin)
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const ProfileScreen()));
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: dark
                                ? const Color(0xFF26262E)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: AppColors.orange.withAlpha(70)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  color: AppColors.orange),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    s.isArabic ? 'الملف الشخصي' : 'Profile',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: dark
                                            ? Colors.white
                                            : AppColors.ink)),
                              ),
                              const Icon(Icons.chevron_left_rounded,
                                  color: AppColors.orange),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // ✅ فكرة التطبيق
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const AboutScreen()));
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              dark ? const Color(0xFF26262E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border:
                              Border.all(color: AppColors.teal.withAlpha(70)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_outline_rounded,
                                color: AppColors.teal),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  s.isArabic ? 'فكرة التطبيق' : 'App idea',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                            ),
                            const Icon(Icons.chevron_left_rounded,
                                color: AppColors.teal),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _openSettings(context);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color:
                              dark ? const Color(0xFF26262E) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: AppColors.orange.withAlpha(70)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.settings_rounded,
                                color: AppColors.orange),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                  s.isArabic ? 'الإعدادات' : 'Settings',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: dark
                                          ? Colors.white
                                          : AppColors.ink)),
                            ),
                            const Icon(Icons.chevron_left_rounded,
                                color: AppColors.orange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ✅ زر تسجيل الخروج
                    if (!s.isGuest)
                      InkWell(
                        onTap: () {
                          Navigator.pop(context);
                          _confirmLogout(context, s);
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: <Color>[
                                Colors.red.withAlpha(dark ? 60 : 25),
                                Colors.red.withAlpha(dark ? 30 : 12),
                              ],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border:
                                Border.all(color: Colors.red.withAlpha(90)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red.withAlpha(30),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.logout_rounded,
                                    color: Colors.red, size: 18),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                    s.isArabic
                                        ? 'تسجيل الخروج'
                                        : 'Logout',
                                    style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.red.shade700)),
                              ),
                              const Icon(Icons.chevron_left_rounded,
                                  color: Colors.red),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[
                            AppColors.orange,
                            Color(0xFFF26B0F)
                          ],
                        ),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(s.isArabic ? 'للاستفسارات' : 'Inquiries',
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: dark ? Colors.white : AppColors.ink)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _socialBtn(
                    icon: Icons.photo_camera_rounded,
                    colors: const <Color>[
                      Color(0xFF833AB4),
                      Color(0xFFE1306C),
                      Color(0xFFF77737)
                    ],
                    url: _kInstagram,
                  ),
                  const SizedBox(width: 14),
                  _socialBtn(
                    icon: Icons.facebook_rounded,
                    colors: const <Color>[
                      Color(0xFF1877F2),
                      Color(0xFF0E5AA7)
                    ],
                    url: _kFacebook,
                  ),
                  const SizedBox(width: 14),
                  _socialBtn(
                    icon: Icons.chat_bubble_rounded,
                    colors: const <Color>[
                      Color(0xFF25D366),
                      Color(0xFF128C7E)
                    ],
                    url: _kWhatsapp,
                  ),
                ],
              ),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  children: [
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    ShaderMask(
                      shaderCallback: (Rect r) =>
                          const LinearGradient(colors: <Color>[
                        AppColors.orange,
                        Color(0xFFF26B0F)
                      ]).createShader(r),
                      child: Text(
                          s.isArabic
                              ? 'برمجة شركة فاوري'
                              : 'Programmed by FAWORI Co.',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _banner(int real) {
    String url;
    if (_homeImages.isNotEmpty) {
      url = _imgUrl(_homeImages[real % _homeImages.length]);
    } else {
      url = _imgUrl(_defaultBanners[real % _defaultBanners.length]);
    }
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.orange.withAlpha(20),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Image(
          image: _imgCache.getProvider(url),
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          gaplessPlayback: true,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: AppColors.orange.withAlpha(20),
              child: const Center(child: FaworiLogo(size: 60)),
            );
          },
          errorBuilder: (context, error, stackTrace) =>
              const Center(child: FaworiLogo(size: 60)),
        ),
      ),
    );
  }

  Widget _gradText(String t, double size) {
    return ShaderMask(
      shaderCallback: (Rect r) =>
          const LinearGradient(colors: <Color>[AppColors.orange, Color(0xFFF26B0F)])
              .createShader(r),
      child: Text(t,
          style: TextStyle(
              fontSize: size, fontWeight: FontWeight.w900, color: Colors.white)),
    );
  }

  Widget _secTitle(String t) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[AppColors.orange, Color(0xFFF26B0F)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Text(t,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _quick(IconData ic, String label, Color c, VoidCallback? onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[c.withAlpha(40), Theme.of(context).colorScheme.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: c.withAlpha(100), width: 1.5),
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: <Color>[c, c.withAlpha(180)]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(ic, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            ),
            Icon(Icons.chevron_left_rounded, color: c, size: 22),
          ],
        ),
      ),
    );
  }

  /// 📢 بطاقة قسم «إعلام» — تدرج بنفسجي-أزرق متلاشي مع ظل ناعم
  Widget _media(IconData ic, String label, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: <Color>[
              Color(0xFF6A11CB),
              Color(0xFF2575FC),
              Color(0xFF1E3C72),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: <double>[0.0, 0.55, 1.0],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF6A11CB).withAlpha(90),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: <Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(40),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withAlpha(80)),
              ),
              child: Icon(ic, color: Colors.white, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                      context.watch<AppSettings>().isArabic
                          ? 'ترقبوا التحديث القادم'
                          : 'Stay tuned for the next update',
                      style: TextStyle(
                          color: Colors.white.withAlpha(200),
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_left_rounded,
                color: Colors.white, size: 26),
          ],
        ),
      ),
    );
  }

  Widget _companyText(String key, Color c) {
    return Container(
      color: c.withAlpha(20),
      child: Center(
        child: Text(_companyEn[key] ?? key,
            style: TextStyle(color: c, fontSize: 20, fontWeight: FontWeight.w900)),
      ),
    );
  }

  Widget _fadedImage(String key, String? img, Color c, bool isAdmin) {
    final Color surface = Theme.of(context).colorScheme.surface;
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          (img != null && img.isNotEmpty)
              ? Image(
                  image: _imgCache.getProvider(_imgUrl(img)),
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (c2, o, st) => _companyText(key, c),
                )
              : _companyText(key, c),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 0.95,
                colors: <Color>[Colors.transparent, surface.withAlpha(210)],
                stops: const <double>[0.55, 1.0],
              ),
            ),
          ),
          if (isAdmin)
            Positioned(
              bottom: 8,
              right: 8,
              child: InkWell(
                onTap: () => _uploadBrand(key),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.photo_camera_rounded,
                      size: 18, color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _company(String key, bool isAdmin) {
    final Color c = _companyColor[key] ?? AppColors.orange;
    final String? img = _brandMap[key];
    final AppSettings s = context.watch<AppSettings>();
    final String name = s.isArabic ? (_companyAr[key] ?? key) : (_companyEn[key] ?? key);
    return Pressable(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ProductsScreen(initialBrand: key))),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <Color>[c.withAlpha(30), Theme.of(context).colorScheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withAlpha(80), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: c.withAlpha(30), blurRadius: 14, offset: const Offset(0, 6)),
          ],
        ),
        child: Column(
          children: <Widget>[
            Expanded(child: _fadedImage(key, img, c, isAdmin)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Icon(_companyIcon[key] ?? Icons.store_rounded, color: c, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(name,
                        style: TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14, color: c)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppSettings s = context.watch<AppSettings>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool isAdmin = s.isImageAdmin;

    return Directionality(
      textDirection: s.isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        drawer: _buildDrawer(s, dark),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: dark
                  ? const <Color>[Color(0xFF23232B), Color(0xFF2B2B34)]
                  : const <Color>[Color(0xFFFFF8F1), Color(0xFFFDEFDE)],
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Builder(
                      builder: (bctx) => InkWell(
                        onTap: () => Scaffold.of(bctx).openDrawer(),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: <Color>[AppColors.orange, Color(0xFFF26B0F)]),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.asset('assets/images/logo.webp',
                                width: 44, height: 44, fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (c, o, st) =>
                                    const FaworiLogo(size: 44)),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: _gradText(s.tr('appName'), 18)),
                    // 🔔 الجرس + شارة غير المقروء (مدير ومستخدم)
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        IconButton(
                          icon: Icon(Icons.notifications_none_rounded,
                              color: s.isGuest
                                  ? Colors.grey
                                  : AppColors.orange),
                          onPressed: () async {
                            if (s.isGuest) {
                              GuestGuard.lock(
                                context,
                                title: s.isArabic
                                    ? 'الإشعارات مقفلة 🔒'
                                    : 'Notifications locked 🔒',
                                message: s.isArabic
                                    ? 'سجل دخولك أولاً لتتمكن من مشاهدة إشعاراتك وطلباتك'
                                    : 'Sign in first to view your notifications and orders',
                                onLogin: () => Navigator.of(context)
                                    .push(MaterialPageRoute(
                                        builder: (_) => const LoginScreen())),
                                loginLabel: s.isArabic
                                    ? 'سجل دخولك الآن'
                                    : 'Sign in now',
                              );
                              return;
                            }
                            await OrdersService.markCustomerNotifsSeen(s.user?.id ?? '');
                            if (mounted) setState(() => _customerNotifs = 0);
                            if (mounted) {
                              await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => const OrdersScreen()));
                              await _loadCustomerNotifs();
                            }
                          },
                        ),
                        if (!s.isGuest && (s.unseenCount + _customerNotifs) > 0)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                  color: Colors.red, shape: BoxShape.circle),
                              child: Text('${s.unseenCount + _customerNotifs}',
                                  style: const TextStyle(
                                      color: Colors.white, fontSize: 10)),
                            ),
                          ),
                        if (s.isGuest)
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GuestGuard.badge(size: 13),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: _kPages,
                    onPageChanged: (int i) {
                      setState(() {
                        _idx = i % _count;
                      });
                    },
                    itemBuilder: (BuildContext c, int i) => _banner(i),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_count, (int i) {
                    final bool active = i == _idx;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: active ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        gradient: active
                            ? const LinearGradient(colors: <Color>[
                                AppColors.orange, Color(0xFFF26B0F)
                              ])
                            : null,
                        color: active ? null : Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),
                _secTitle(s.isArabic ? 'الوصول السريع' : 'Quick access'),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _quick(
                        Icons.inventory_2_rounded,
                        s.isArabic ? 'المنتجات' : 'Products',
                        AppColors.orange,
                        widget.onOpenProducts,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _quick(
                            Icons.redeem_rounded,
                            s.isArabic ? 'الهدايا' : 'Gifts',
                            s.isGuest ? Colors.grey : AppColors.teal,
                            () {
                              if (s.isGuest) {
                                GuestGuard.lock(
                                  context,
                                  title: s.isArabic
                                      ? 'الهدايا مقفلة 🔒'
                                      : 'Gifts locked 🔒',
                                  message: s.isArabic
                                      ? 'متاحة للمستخدمين المسجلين فقط. سجل دخولك لتتمكن من استبدال نقاطك بالهدايا'
                                      : 'Available for registered users only. Sign in to redeem your points for gifts',
                                  onLogin: () => Navigator.of(context)
                                      .push(MaterialPageRoute(
                                          builder: (_) => const LoginScreen())),
                                  loginLabel: s.isArabic
                                      ? 'سجل دخولك الآن'
                                      : 'Sign in now',
                                );
                                return;
                              }
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => Scaffold(
                                            appBar: AppBar(
                                                title: Text(s.isArabic
                                                    ? 'الهدايا'
                                                    : 'Gifts')),
                                            body: const GiftsView(),
                                          )));
                            },
                          ),
                          if (s.isGuest)
                            Positioned(
                              right: -2,
                              top: -2,
                              child: GuestGuard.badge(size: 18),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                // ✅ قسم «إعلام» الجديد
                _secTitle(s.isArabic ? 'إعلام' : 'Media'),
                _media(
                  Icons.campaign_rounded,
                  s.isArabic ? 'أخبار وشروحات الشركة' : 'Company news & guides',
                  () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const _ComingSoonScreen())),
                ),
                const SizedBox(height: 26),
                _secTitle(s.isArabic ? 'الشركات' : 'Companies'),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.85,
                  children: <Widget>[
                    for (final key in _companyKeys) _company(key, isAdmin),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
