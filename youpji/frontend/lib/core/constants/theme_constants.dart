import 'package:flutter/material.dart';

/// Ocean Mist 雾海蓝设计规范 (对齐 ui-prototype-v2.html)
class AppTheme {
  // 色彩调色板
  static const Color primaryBlue = Color(0xFF06425C); // 主题海蓝
  static const Color cyan = Color(0xFF4A90A4);        // 辅助青色
  static const Color sageAccent = Color(0xFFA8D5BA);  // 质感松石绿
  static const Color creamBg = Color(0xFFF4F1DE);     // 米白背景
  static const Color warmAccent = Color(0xFFE07A5F);  // 暖橙提示色
  static const Color darkInk = Color(0xFF14171E);     // 主文字色
  static const Color mutedGray = Color(0xFF7C7A72);   // 辅助副字色
  static const Color cardBg = Colors.white;

  // 验证状态徽章颜色
  static const Color verifiedGreen = Color(0xFF2F6F5E);
  static const Color pendingYellow = Color(0xFFC97B3F);
  static const Color unverifiedGray = Color(0xFF9E9E9E);
  static const Color dangerRed = Color(0xFFB06367);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: creamBg,
      primaryColor: primaryBlue,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryBlue,
        primary: primaryBlue,
        secondary: cyan,
        surface: cardBg,
        error: dangerRed,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        titleTextStyle: TextStyle(
          color: darkInk,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: IconThemeData(color: darkInk),
      ),
      cardTheme: CardTheme(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE9E3D6)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
