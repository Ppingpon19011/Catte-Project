import 'package:flutter/material.dart';
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
      title: 'ประมาณน้ำหนักโค',
      theme: AppTheme.lightTheme,  // ใช้ธีมที่กำหนดไว้
      home: MainScreen(),
      debugShowCheckedModeBanner: false,
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
            icon: Icon(Icons.home_filled),  // เปลี่ยนไอคอนให้สวยงามขึ้น
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