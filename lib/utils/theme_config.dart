import 'package:flutter/material.dart';

class AppTheme {
  // สีหลักของแอปพลิเคชัน
  static const Color primaryColor = Color(0xFF8B4513); // สีน้ำตาลไม้ 8B4513
  static const Color primaryDarkColor = Color(0xFF582C0D); // สีน้ำตาลเข้ม 582C0D
  static const Color accentColor = Color(0xFFAB6832); // สีน้ำตาลอ่อนเพื่อเพิ่มความหลากหลาย
  static const Color backgroundColor = Colors.white; // สีพื้นหลัง - ขาว
  
  // สีสำหรับองค์ประกอบต่างๆ
  static const Color cardColor = Color(0xFFF9F5F0); // สีครีมอ่อนสำหรับการ์ด
  static const Color dividerColor = Color(0xFFE0D2C3); // สีสำหรับเส้นแบ่ง
  static const Color textPrimaryColor = Color(0xFF333333); // สีข้อความหลัก
  static const Color textSecondaryColor = Color(0xFF666666); // สีข้อความรอง
  static const Color successColor = Color(0xFF4CAF50); // สีเขียวสำหรับสถานะสำเร็จ
  static const Color errorColor = Color(0xFFE53935); // สีแดงสำหรับสถานะผิดพลาด

  // กำหนด MaterialColor จาก primaryColor สำหรับใช้ใน ThemeData
  static MaterialColor createMaterialColor(Color color) {
    List<double> strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    Map<int, Color> swatch = <int, Color>{};
    final int r = color.red;
    final int g = color.green;
    final int b = color.blue;

    for (var strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }
    return MaterialColor(color.value, swatch);
  }

  // ธีมหลักของแอปพลิเคชัน
  static ThemeData lightTheme = ThemeData(
    primarySwatch: createMaterialColor(primaryColor), // ย้ายมาที่นี่ ถูกต้องแล้ว
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: cardColor,
    dividerColor: dividerColor,
    hoverColor: errorColor,
    appBarTheme: const AppBarTheme(
      color: primaryColor,
      elevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(color: textPrimaryColor),
      displayMedium: TextStyle(color: textPrimaryColor),
      displaySmall: TextStyle(color: textPrimaryColor),
      headlineMedium: TextStyle(color: textPrimaryColor),
      headlineSmall: TextStyle(color: textPrimaryColor),
      titleLarge: TextStyle(color: textPrimaryColor),
      titleMedium: TextStyle(color: textPrimaryColor),
      titleSmall: TextStyle(color: textSecondaryColor),
      bodyLarge: TextStyle(color: textPrimaryColor),
      bodyMedium: TextStyle(color: textSecondaryColor),
    ),
    buttonTheme: ButtonThemeData(
      buttonColor: primaryColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8.0),
      ),
      textTheme: ButtonTextTheme.primary,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: Colors.white, backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor, 
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        side: const BorderSide(color: primaryColor, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: Colors.white,
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: primaryColor, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8.0),
        borderSide: const BorderSide(color: errorColor),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
    ),
    cardTheme: CardTheme(
      color: cardColor,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: primaryColor,
      unselectedItemColor: Colors.grey,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    tabBarTheme: const TabBarTheme(
      labelColor: Colors.white,
      unselectedLabelColor: Colors.white70,
      indicatorSize: TabBarIndicatorSize.tab,
      indicator: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.white, width: 3.0),
        ),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
    ), 
    colorScheme: ColorScheme.fromSwatch().copyWith(
      primary: primaryColor,
      secondary: accentColor,
      surface: cardColor,
      onSurface: textPrimaryColor,
      background: backgroundColor,
      onBackground: textPrimaryColor,
      error: errorColor,
    ),
  );
}