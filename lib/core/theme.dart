import 'package:flutter/material.dart';

/// ✅ ملاحظة متدرجة موحّدة لكل النظام (تظهر أسفل عائمه ومنسقة)
void showAppSnack(BuildContext context, String msg,
    {Color color = const Color(0xFF0D9668),
    IconData icon = Icons.check_circle_rounded}) {
  ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
            BoxShadow(
                color: color.withAlpha(80),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13)),
            ),
          ],
        ),
      ),
    ),
  );
}

class AppColors {
  static const Color orange = Color(0xFFE8A33D);
  static const Color teal = Color(0xFF3EC6C0);
  static const Color red = Color(0xFFE5484D);
  static const Color darkBg = Color(0xFF141419);
  static const Color darkCard = Color(0xFF1B1B21);
  static const Color lightBg = Color(0xFFE7EAEF);
  static const Color lightCard = Color(0xFFF4F6F9);
  static const Color ink = Color(0xFF23405C);
}

class AppTheme {
  static ThemeData dark() => ThemeData(
        brightness: Brightness.dark,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: AppColors.darkBg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.orange,
          secondary: AppColors.teal,
          surface: AppColors.darkCard,
        ),
        dividerColor: const Color(0xFF2A2A33),
        cardColor: AppColors.darkCard,
      );

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        fontFamily: 'Cairo',
        scaffoldBackgroundColor: AppColors.lightBg,
        colorScheme: const ColorScheme.light(
          primary: AppColors.orange,
          secondary: AppColors.teal,
          surface: AppColors.lightCard,
          onSurface: AppColors.ink,
        ),
        dividerColor: const Color(0xFFD9DEE5),
        cardColor: AppColors.lightCard,
        splashColor: AppColors.orange.withAlpha(20),
        highlightColor: AppColors.orange.withAlpha(15),
      );

  static Color border(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF2A2A33)
          : const Color(0xFFD9DEE5);

  static Color text(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : AppColors.ink;
}
