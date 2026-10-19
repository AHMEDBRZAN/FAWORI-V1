import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_settings.dart';
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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  /// ✅ مزامنة النقاط/الرصيد مع طريقة بطاقة المحفظة (صافي المشتريات)
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
        });
      }
    } catch (_) {}
  }

  String _roleAr(String r) {
    if (r == 'agent') return 'وكيل';
    if (r == 'tech') return 'صباغ';
    if (r == 'admin') return 'مدير';
    return 'عميل';
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

  Widget _settingRow(BuildContext context,
      {required IconData icon,
      required String label,
      Color? iconColor,
      Widget? trailing,
      VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: iconColor ?? AppColors.orange, size: 22),
            const SizedBox(width: 12),
            Expanded(
                child: Text(label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 15))),
            if (trailing != null)
              trailing
            else
              Icon(Icons.chevron_left_rounded,
                  color: Colors.grey.shade500, size: 20),
          ],
        ),
      ),
    );
  }

  /// ✅ بطاقة محفظة متدرجة (نفس تصميم المحفظة بالضبط)
  Widget _stat(String label, int value, Color c, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: <Color>[c, c.withAlpha(210)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: c.withAlpha(80),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(40),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 10),
          Text(fmtThousands(value),
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.3)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: Colors.white.withAlpha(220),
                  fontSize: 12,
                  fontWeight: FontWeight.w700)),
        ],
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
    // 🚪 الضيف: صفحة دخول كاملة (شعار كبير + زر تفاعلي)
    // ==================================================
    if (isGuest) {
      return Scaffold(
        backgroundColor:
            dark ? const Color(0xFF141419) : const Color(0xFFFFF8F1),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, cons) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: cons.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      // ✅ شعار فاوري كبير بهالة متوهجة
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
                            s.isArabic ? 'شركة فاوِري' : 'FAWORI Co.',
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
                      // ✅ زر تسجيل دخول كبير تفاعلي
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
    // 👤 المستخدم المسجل: الصفحة الأصلية كاملة
    // ==================================================
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(s.isArabic ? 'ملف الشخصي' : 'Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 12),
          Center(
            child: Stack(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    color: AppColors.orange.withAlpha(25),
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.orange, width: 2),
                  ),
                  child: Icon(Icons.person_rounded,
                      size: 56, color: AppColors.orange),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: AppColors.teal,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.photo_camera_rounded,
                        size: 16, color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              u?.name ?? (s.isArabic ? 'ضيف' : 'Guest'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${s.isArabic ? _roleAr(u!.role) : u.role}${u.phone.isNotEmpty ? ' • ${u.phone}' : ''}',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                  child: _stat(
                      s.isArabic ? 'نقطة' : 'points',
                      _pts,
                      AppColors.orange,
                      Icons.emoji_events_rounded)),
              const SizedBox(width: 12),
              Expanded(
                  child: _stat(
                      s.isArabic ? 'رصيد مخزن' : 'stored',
                      _st,
                      AppColors.teal,
                      Icons.account_balance_wallet_rounded)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.orange.withAlpha(40)),
            ),
            child: Column(
              children: [
                _settingRow(
                  context,
                  icon: Icons.language_rounded,
                  iconColor: AppColors.teal,
                  label: s.isArabic ? 'اللغة' : 'Language',
                  trailing: Text(
                    s.isArabic ? 'English' : 'عربي',
                    style: const TextStyle(
                        color: AppColors.teal, fontWeight: FontWeight.w800),
                  ),
                  onTap: () => s.toggleLanguage(),
                ),
                Divider(height: 1, color: Colors.grey.withAlpha(40)),
                _settingRow(
                  context,
                  icon: s.isDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  label: s.isArabic ? 'الوضع الداكن' : 'Dark mode',
                  trailing: Switch(
                    value: s.isDark,
                    onChanged: (_) => s.toggleDark(),
                  ),
                ),
                Divider(height: 1, color: Colors.grey.withAlpha(40)),
                _settingRow(
                  context,
                  icon: Icons.receipt_long_rounded,
                  iconColor: AppColors.orange,
                  label: s.isArabic ? 'سجل الطلبات' : 'Orders history',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const OrdersHistoryScreen())),
                ),
                Divider(height: 1, color: Colors.grey.withAlpha(40)),
                _settingRow(
                  context,
                  icon: Icons.info_outline_rounded,
                  iconColor: AppColors.teal,
                  label: s.isArabic ? 'حول التطبيق' : 'About',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AboutScreen())),
                ),
                Divider(height: 1, color: Colors.grey.withAlpha(40)),
                _settingRow(
                  context,
                  icon: Icons.logout_rounded,
                  iconColor: Colors.red,
                  label: s.isArabic ? 'تسجيل الخروج' : 'Logout',
                  trailing: const SizedBox.shrink(),
                  onTap: () => _logout(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              s.isArabic ? 'الإصدار 1.0.0' : 'Version 1.0.0',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
          ),
          const SizedBox(height: 4),
          Center(
            child: Text(
              s.isArabic ? 'شركة فاوري' : 'FAWORI Co.',
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
