import 'package:flutter/material.dart';
// ลบ import นี้ออกชั่วคราว
// import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/home_screen.dart';
import 'screens/menu_screen.dart';
import 'utils/theme_config.dart';  // นำเข้าไฟล์ธีมที่สร้างขึ้น

void main() {
  runApp(CattleWeightApp());
}

class CattleWeightApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'แอปประมาณน้ำหนักโคด้วยภาพถ่าย',
      theme: AppTheme.lightTheme,  // ใช้ธีมที่กำหนดไว้
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
      
      // ลบส่วน localization ออกชั่วคราว
      // localizationsDelegates: [
      //   GlobalMaterialLocalizations.delegate,
      //   GlobalWidgetsLocalizations.delegate,
      //   GlobalCupertinoLocalizations.delegate,
      // ],
      // supportedLocales: [
      //   Locale('en', 'US'), // English
      //   Locale('th', 'TH'), // Thai
      // ],
      // locale: Locale('th', 'TH'), // ตั้งเป็นภาษาไทยเป็นค่าเริ่มต้น
    );
  }
}

class MainScreen extends StatefulWidget {
  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;
  final List<Widget> _screens = [
    HomeScreen(),
    MenuScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_filled),  // เปลี่ยนไอคอนให้สวยขึ้น
            label: 'รายการโค',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.menu),
            label: 'เมนู',
          ),
        ],
      ),
    );
  }
}