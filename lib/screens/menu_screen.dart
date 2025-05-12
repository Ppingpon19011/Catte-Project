import 'package:flutter/material.dart';
import '../screens/settings_screen.dart';
import '../screens/reports_screen.dart'; // นำเข้าไฟล์รายงานที่เพิ่งสร้าง
import '../screens/user_guide_screen.dart'; // นำเข้าไฟล์วิธีการใช้งานที่เพิ่งสร้าง

class MenuScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('เมนู'),
      ),
      body: ListView(
        children: [
          
          MenuTile(
            icon: Icons.bar_chart,
            title: 'รายงานและสถิติ',
            onTap: () {
              // นำทางไปยังหน้ารายงาน (ที่เพิ่งสร้าง)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReportsScreen(),
                ),
              );
            },
          ),
          MenuTile(
            icon: Icons.info,
            title: 'วิธีการใช้งาน',
            onTap: () {
              // นำทางไปยังหน้าวิธีการใช้งาน (ที่เพิ่งสร้าง)
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => UserGuideScreen(),
                ),
              );
            },
          ),
          MenuTile(
            icon: Icons.settings,
            title: 'ตั้งค่า',
            onTap: () {
              // นำทางไปยังหน้าตั้งค่า
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SettingsScreen(),
                ),
              );
            },
          ),
          
          MenuTile(
            icon: Icons.contact_support,
            title: 'ติดต่อเรา',
            onTap: () {
              // แสดงข้อมูลติดต่อ
              _showContactInfo(context);
            },
          ),
        ],
      ),
    );
  }

  void _showFeatureNotAvailable(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('แจ้งเตือน'),
        content: Text('ฟีเจอร์นี้อยู่ระหว่างการพัฒนา จะเปิดให้ใช้งานเร็วๆ นี้'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  void _showContactInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ติดต่อเรา'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _contactRow(Icons.phone, 'โทรศัพท์', '098-487-7913'),
            SizedBox(height: 12),
            _contactRow(Icons.email, 'อีเมล', 'warodompph@gmail.com'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: Text('ปิด'),
          ),
        ],
      ),
    );
  }

  Widget _contactRow(IconData icon, String title, String content) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color.fromARGB(255, 255, 213, 0)),
        SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(content),
            ],
          ),
        ),
      ],
    );
  }
}

class MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const MenuTile({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: Theme.of(context).primaryColor,
        size: 28,
      ),
      title: Text(
        title,
        style: TextStyle(fontSize: 16),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}