import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
import '../core/images_service.dart';
import '../core/orders_service.dart';
import '../core/theme.dart';
import 'about_screen.dart';
import 'login_screen.dart';
import 'orders_history_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});
  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _synced = false;
  int _pts = 0;
  int _st = 0;
  bool _avatarBusy = false;
  String? _avatarUrl;
  int _avatarBuster = 0;

  static const String _base = 'https://ahmedbrzan.github.io/FAWORI-V1';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  /// ✅ مزامنة النقاط/الرصيد — نفس منطق المحفظة تماماً
  Future<void> _sync() async {
    if (_synced) return;
    _synced = true;
    final s = context.read<AppSettings>();
    final uid = s.user?.id ?? '';
    if (uid.isEmpty || s.isGuest) return;
    try {
      await OrdersService.recalcUserTotals(uid);
      await s.refreshUser();
    } catch (_) {}
    try {
      final invs = await OrdersService.loadInvoicesFiltered();
      final rets = await OrdersService.loadReturnsFiltered();
      int sales = 0;
      int ret = 0;
      for (final i in invs) {
        if (i.userId == uid) {
          if (i.type == 'sale') {
            sales += i.total.toInt();
          } else if (i.type == 'return') {
            ret += i.total.toInt().abs();
          }
        }
      }
      for (final r in rets) {
        if (r['userId'] == uid) {
          ret += ((r['total'] as num?)?.toInt() ?? 0).abs();
        }
      }
      final net = (sales - ret).clamp(0, 999999999);
      if (mounted) {
        setState(() {
          _pts = net ~/ kPointUnit;
          _st = net % kPointUnit;
          _avatarUrl = '$_base/assets/images/avatars/avatar_$uid.webp';
        });
      }
    } catch (_) {}
  }

  /// ✅ رفع صورة شخصية وحفظها في المستودع
  Future<void> _uploadAvatar() async {
    final s = context.read<AppSettings>();
    final uid = s.user?.id ?? '';
    if (uid.isEmpty) return;
    String tk = await ImagesService.resolveToken();
    if (tk.isEmpty) {
      final t = await ImagesService.askGitHubToken(context);
      if (t == null) return;
      tk = t;
    }
    try {
      final f = await ImagePicker().pickImage(
          source: ImageSource.gallery, imageQuality: 82, maxWidth: 600);
      if (f == null) return;
      setState(() => _avatarBusy = true);
      final bytes = await f.readAsBytes();
      final path = 'assets/images/avatars/avatar_$uid.webp';
      await ImagesService.putBytes(path, bytes, tk, 'avatar $uid');
      if (mounted) {
        setState(() {
          _avatarBusy = false;
          _avatarBuster++;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.isArabic
              ? '✅ تم حفظ الصورة الشخصية'
              : '✅ Avatar saved'),
          backgroundColor: AppColors.teal,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _avatarBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(s.isArabic
              ? 'فشل الرفع: $e'
              : 'Upload failed: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ));
      }
    }
  }

  String _roleAr(String r) {
    switch (r) {
      case 'agent':
        return 'وكيل';
      case 'tech':
        return 'صباغ';
      case 'admin':
        return 'مدير';
      case 'ctrl':
        return 'متحكم';
      default:
        return 'عميل';
    }
  }

  String _roleEn(String r) {
    switch (r) {
      case 'agent':
        return 'Agent';
      case 'tech':
        return 'Painter';
      case 'admin':
        return 'Admin';
      case 'ctrl':
        return 'Controller';
      default:
        return 'Client';
    }
  }

  Color _roleColor(String r) {
    switch (r) {
      case 'ctrl':
        return const Color(0xFFB71C1C);
      case 'admin':
        return Colors.red;
      case 'agent':
        return const Color(0xFF9B59B6);
      case 'tech':
        return AppColors.orange;
      default:
        return AppColors.teal;
    }
  }

  void _logout(BuildContext context) {
    final s = context.read<AppSettings>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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

  /// ✅ بطاقة النقاط / الرصيد بنفس لغة المحفظة
  Widget _statCard(String label, int value, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[c, c.withAlpha(200)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: c.withAlpha(70),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(35),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white.withAlpha(70)),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 10),
          Text(
            fmtThousands(value),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(230),
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ صف الإعدادات مع أيقونة متدرجة
  Widget _settingRow({
    required IconData icon,
    required String label,
    required List<Color> iconGrad,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: iconGrad,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: iconGrad.first.withAlpha(60),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
            if (trailing != null)
              trailing
            else
              const Icon(Icons.chevron_left_rounded,
                  color: Colors.grey, size: 22),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppSettings>();
    final u = s.user;
    final bool isGuest = u == null || u.role == 'guest';
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    // ==================================================
    // 🚪 الضيف: صفحة دخول كاملة
    // ==================================================
    if (isGuest) {
      return Scaffold(
        backgroundColor: dark
            ? const Color(0xFF141419)
            : const Color(0xFFFFF8F1),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, cons) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: cons.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: <Color>[
                              AppColors.orange.withAlpha(70),
                              AppColors.orange.withAlpha(0),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(34),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.orange.withAlpha(110),
                                  blurRadius: 40,
                                  offset: const Offset(0, 14),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(34),
                              child: Image.asset(
                                'assets/images/logo.webp',
                                fit: BoxFit.cover,
                                gaplessPlayback: true,
                                errorBuilder: (c, o, st) => const Center(
                                  child: Text('FAWORI',
                                      style: TextStyle(
                                          color: AppColors.orange,
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 26),
                      ShaderMask(
                        shaderCallback: (Rect r) => const LinearGradient(
                                colors: <Color>[
                                  AppColors.teal,
                                  AppColors.orange
                                ]).createShader(r),
                        child: Text(
                            s.isArabic ? 'شركة فاوري' : 'FAWORI Co.',
                            style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                      ),
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                            s.isArabic
                                ? 'سجّل دخولك لمتابعة نقاطك ومشترياتك'
                                : 'Sign in to track your points & purchases',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: dark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade600,
                                fontSize: 14,
                                fontWeight: FontWeight.w600)),
                      ),
                      const Spacer(flex: 2),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                        child: Container(
                          width: double.infinity,
                          height: 58,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                                colors: <Color>[
                                  AppColors.orange,
                                  Color(0xFFF26B0F)
                                ]),
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                  color: AppColors.orange.withAlpha(110),
                                  blurRadius: 22,
                                  offset: const Offset(0, 10)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18)),
                            ),
                            onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const LoginScreen())),
                            icon: const Icon(Icons.login_rounded, size: 22),
                            label: Text(
                                s.isArabic ? 'تسجيل الدخول' : 'Sign in',
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900)),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Text(
                            s.isArabic
                                ? 'نقاطك ومشترياتك بانتظارك ⭐'
                                : 'Your points & purchases await ⭐',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(flex: 1),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // ==================================================
    // 👑 المستخدم المسجل: تصميم ملكي احترافي
    // ==================================================
    final net = _pts * kPointUnit + _st;
    final storedMod = net % kPointUnit;
    final remaining = kPointUnit - storedMod;
    final progress = storedMod / kPointUnit;
    final roleColor = _roleColor(u!.role);

    return Scaffold(
      backgroundColor: dark
          ? const Color(0xFF141419)
          : const Color(0xFFFFF8F1),
      body: CustomScrollView(
        slivers: [
          // ── الترويسة المتدرجة مع شعار فاوري ──
          SliverToBoxAdapter(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  height: 240,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: <Color>[
                        AppColors.orange,
                        const Color(0xFFF26B0F),
                        const Color(0xFFE8A33C),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      stops: const <double>[0.0, 0.55, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.orange.withAlpha(120),
                        blurRadius: 30,
                        offset: const Offset(0, 14),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.pop(context),
                                icon: const Icon(
                                    Icons.arrow_back_rounded,
                                    color: Colors.white,
                                    size: 26),
                              ),
                              const Spacer(),
                              // ✅ شعار فاوري
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(30),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                      color: Colors.white.withAlpha(70)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ClipRRect(
                                      borderRadius:
                                          BorderRadius.circular(6),
                                      child: Image.asset(
                                          'assets/images/logo.webp',
                                          width: 22,
                                          height: 22,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                                  Icons.store_rounded,
                                                  color: Colors.white,
                                                  size: 18)),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'FAWORI',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          ShaderMask(
                            shaderCallback: (Rect r) =>
                                const LinearGradient(colors: <Color>[
                                  Colors.white,
                                  Color(0xFFFFF8F1),
                                ]).createShader(r),
                            child: Text(
                              s.isArabic ? 'ملف الشخصي' : 'Profile',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                ),
                // ✅ دائرة الصورة الشخصية تتجاوز حافة الترويسة
                Positioned(
                  left: 0,
                  right: 0,
                  top: 170,
                  child: Center(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // الهالة المتوهجة
                        Container(
                          width: 130,
                          height: 130,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: <Color>[
                                Colors.white.withAlpha(80),
                                Colors.white.withAlpha(0),
                              ],
                            ),
                          ),
                        ),
                        // الدائرة الخارجية
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: dark
                                    ? const Color(0xFF141419)
                                    : const Color(0xFFFFF8F1),
                                width: 5),
                            boxShadow: [
                              BoxShadow(
                                color: roleColor.withAlpha(100),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // المحتوى (صورة أو افتراضي)
                              Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: <Color>[
                                      roleColor.withAlpha(60),
                                      roleColor.withAlpha(30),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                ),
                                child: ClipOval(
                                  child: _avatarUrl != null
                                      ? Image.network(
                                          '$_avatarUrl?b=$_avatarBuster',
                                          width: 110,
                                          height: 110,
                                          fit: BoxFit.cover,
                                          gaplessPlayback: true,
                                          loadingBuilder:
                                              (c, child, progress) {
                                            if (progress == null) {
                                              return child;
                                            }
                                            return Center(
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: roleColor,
                                                value: progress
                                                            .expectedTotalBytes !=
                                                        null
                                                    ? progress
                                                            .cumulativeBytesLoaded /
                                                        progress
                                                            .expectedTotalBytes!
                                                    : null,
                                              ),
                                            );
                                          },
                                          errorBuilder: (_, __, ___) =>
                                              Center(
                                            child: Text(
                                              u.name.isNotEmpty
                                                  ? u.name[0].toUpperCase()
                                                  : '?',
                                              style: TextStyle(
                                                color: roleColor,
                                                fontSize: 42,
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                          ),
                                        )
                                      : Center(
                                          child: Text(
                                            u.name.isNotEmpty
                                                ? u.name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              color: roleColor,
                                              fontSize: 42,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              // ✅ طبقة تحميل الصورة عند الضغط
                              if (_avatarBusy)
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black.withAlpha(140),
                                  ),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 30,
                                      height: 30,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.5,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _avatarBusy ? null : _uploadAvatar,
                                  customBorder: const CircleBorder(),
                                  child: Container(
                                    width: 110,
                                    height: 110,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: LinearGradient(
                                        colors: <Color>[
                                          Colors.black.withAlpha(0),
                                          Colors.black.withAlpha(100),
                                        ],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        stops: const <double>[0.6, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // ✅ زر الكاميرا
                        Positioned(
                          bottom: 2,
                          right: 2,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _avatarBusy ? null : _uploadAvatar,
                              customBorder: const CircleBorder(),
                              child: Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: <Color>[
                                      AppColors.teal,
                                      Color(0xFF0AA87A),
                                    ],
                                  ),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: dark
                                          ? const Color(0xFF141419)
                                          : const Color(0xFFFFF8F1),
                                      width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.teal.withAlpha(120),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.photo_camera_rounded,
                                    size: 16, color: Colors.white),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── المحتوى الرئيسي ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 16),
              child: Column(
                children: [
                  // الاسم والدور
                  Text(
                    u.name.isEmpty ? (s.isArabic ? 'عميل' : 'Client') : u.name,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: dark ? Colors.white : AppColors.ink,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          roleColor.withAlpha(40),
                          roleColor.withAlpha(20),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: roleColor.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.badge_rounded,
                            size: 13, color: roleColor),
                        const SizedBox(width: 5),
                        Text(
                          s.isArabic ? _roleAr(u.role) : _roleEn(u.role),
                          style: TextStyle(
                            color: roleColor,
                            fontWeight: FontWeight.w900,
                            fontSize: 12,
                          ),
                        ),
                        if (u.phone.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 1,
                            height: 10,
                            color: roleColor.withAlpha(100),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            u.phone,
                            style: TextStyle(
                              color: roleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── بطاقة النقاط والرصيد (نفس لغة المحفظة) ──
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          Color(0xFFF26B0F),
                          Color(0xFFE8A33C),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orange.withAlpha(100),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withAlpha(35),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                  Icons.monetization_on_rounded,
                                  color: Colors.white,
                                  size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.isArabic ? 'رصيدي' : 'My balance',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              fmtThousands(_pts),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 36,
                                fontWeight: FontWeight.w900,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Text(
                                s.isArabic ? 'نقطة' : 'points',
                                style: TextStyle(
                                  color: Colors.white.withAlpha(220),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress.clamp(0.0, 1.0),
                            minHeight: 8,
                            backgroundColor: Colors.white.withAlpha(60),
                            valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Row(
                                children: [
                                  Text(
                                    '${s.isArabic ? 'رصيد مخزن' : 'Stored'}: ',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha(230),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Directionality(
                                    textDirection: TextDirection.ltr,
                                    child: Text(
                                      fmtThousands(storedMod),
                                      style: TextStyle(
                                        color: Colors.white.withAlpha(230),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              '${s.isArabic ? 'متبقي' : 'Remaining'} ${fmtThousands(remaining)}',
                              style: TextStyle(
                                color: Colors.white.withAlpha(230),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // بطاقتان صغيرتان داخل البطاقة الكبيرة
                        Row(
                          children: [
                            Expanded(
                              child: _statCard(
                                s.isArabic ? 'نقاط' : 'Points',
                                _pts,
                                AppColors.orange,
                                Icons.emoji_events_rounded,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: _statCard(
                                s.isArabic ? 'رصيد مخزن' : 'Stored',
                                _st,
                                AppColors.teal,
                                Icons.account_balance_wallet_rounded,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── الإعدادات ببطاقات منفصلة ──
                  Container(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF1E1E28)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                          color: AppColors.orange.withAlpha(dark ? 30 : 50)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(dark ? 60 : 18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _settingRow(
                          icon: Icons.language_rounded,
                          label: s.isArabic ? 'اللغة' : 'Language',
                          iconGrad: const <Color>[
                            AppColors.teal,
                            Color(0xFF0AA87A)
                          ],
                          trailing: Text(
                            s.isArabic ? 'English' : 'عربي',
                            style: const TextStyle(
                                color: AppColors.teal,
                                fontWeight: FontWeight.w900,
                                fontSize: 13),
                          ),
                          onTap: () => s.toggleLanguage(),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.withAlpha(dark ? 30 : 40)),
                        _settingRow(
                          icon: s.isDark
                              ? Icons.dark_mode_rounded
                              : Icons.light_mode_rounded,
                          label: s.isArabic ? 'الوضع الداكن' : 'Dark mode',
                          iconGrad: const <Color>[
                            Color(0xFF6A11CB),
                            Color(0xFF2575FC),
                          ],
                          trailing: Switch(
                            value: s.isDark,
                            activeColor: AppColors.orange,
                            onChanged: (_) => s.toggleDark(),
                          ),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.withAlpha(dark ? 30 : 40)),
                        _settingRow(
                          icon: Icons.receipt_long_rounded,
                          label: s.isArabic ? 'سجل الطلبات' : 'Orders history',
                          iconGrad: const <Color>[
                            AppColors.orange,
                            Color(0xFFF26B0F)
                          ],
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const OrdersHistoryScreen())),
                        ),
                        Divider(
                            height: 1,
                            color: Colors.grey.withAlpha(dark ? 30 : 40)),
                        _settingRow(
                          icon: Icons.info_outline_rounded,
                          label: s.isArabic ? 'حول التطبيق' : 'About',
                          iconGrad: const <Color>[
                            AppColors.teal,
                            Color(0xFF0AA87A)
                          ],
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AboutScreen())),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── زر تسجيل الخروج ──
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: <Color>[
                          Colors.red.withAlpha(dark ? 50 : 25),
                          Colors.red.withAlpha(dark ? 30 : 15),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: Colors.red.withAlpha(100)),
                    ),
                    child: InkWell(
                      onTap: () => _logout(context),
                      borderRadius: BorderRadius.circular(22),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(30),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.logout_rounded,
                                  color: Colors.red, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              s.isArabic ? 'تسجيل الخروج' : 'Logout',
                              style: const TextStyle(
                                color: Colors.red,
                                fontWeight: FontWeight.w900,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── التذييل ──
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ShaderMask(
                        shaderCallback: (Rect r) => const LinearGradient(
                                colors: <Color>[
                                  AppColors.orange,
                                  Color(0xFFF26B0F)
                                ]).createShader(r),
                        child: const Text(
                          'FAWORI',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 13,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '• 1.0.0',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
