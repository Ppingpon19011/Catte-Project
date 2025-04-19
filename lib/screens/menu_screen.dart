import 'package:flutter/material.dart';
import '../screens/add_cattle_screen.dart';
import '../screens/settings_screen.dart';

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
            icon: Icons.history,
            title: 'ประวัติการประมาณน้ำหนัก',
            onTap: () {
              // นำทางไปยังหน้าประวัติ
              _showFeatureNotAvailable(context);
            },
          ),
          MenuTile(
            icon: Icons.add_circle,
            title: 'เพิ่มโคใหม่',
            onTap: () {
              // นำทางไปยังหน้าเพิ่มโคใหม่
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => AddCattleScreen(),
                ),
              );
            },
          ),
          MenuTile(
            icon: Icons.bar_chart,
            title: 'รายงานและสถิติ',
            onTap: () {
              // นำทางไปยังหน้ารายงาน
              _showFeatureNotAvailable(context);
            },
          ),
          MenuTile(
            icon: Icons.info,
            title: 'วิธีการใช้งาน',
            onTap: () {
              // นำทางไปยังหน้าวิธีการใช้งาน
              _showFeatureNotAvailable(context);
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
          Divider(),
          MenuTile(
            icon: Icons.contact_support,
            title: 'ติดต่อเรา',
            onTap: () {
              // แสดงข้อมูลติดต่อ
              _showContactInfo(context);
            },
          ),
          MenuTile(
            icon: Icons.privacy_tip,
            title: 'นโยบายความเป็นส่วนตัว',
            onTap: () {
              // แสดงนโยบายความเป็นส่วนตัว
              _showFeatureNotAvailable(context);
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
            _contactRow(Icons.phone, 'โทรศัพท์', '02-XXX-XXXX'),
            SizedBox(height: 12),
            _contactRow(Icons.email, 'อีเมล', 'info@cattleapp.co.th'),
            SizedBox(height: 12),
            _contactRow(Icons.location_on, 'ที่อยู่', '123 ถนนสุขุมวิท แขวงคลองตัน เขตคลองเตย กรุงเทพฯ 10110'),
            SizedBox(height: 12),
            _contactRow(Icons.language, 'เว็บไซต์', 'www.cattleapp.co.th'),
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
        Icon(icon, size: 20, color: Colors.green),
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