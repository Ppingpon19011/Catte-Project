import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme_config.dart';

class SettingsScreen extends StatefulWidget {
  @override
  _SettingsScreenState createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // คีย์สำหรับเก็บค่าใน SharedPreferences
  static const String LENGTH_UNIT_KEY = 'length_unit';
  static const String WEIGHT_UNIT_KEY = 'weight_unit';

  // ค่าเริ่มต้น
  String _selectedLengthUnit = 'เซนติเมตร';
  String _selectedWeightUnit = 'กิโลกรัม';
  
  // ตัวเลือกหน่วยวัด
  final List<String> _lengthUnits = ['เซนติเมตร', 'นิ้ว'];
  final List<String> _weightUnits = ['กิโลกรัม', 'ปอนด์'];
  
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // โหลดค่าการตั้งค่าจาก SharedPreferences
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final prefs = await SharedPreferences.getInstance();
      
      setState(() {
        _selectedLengthUnit = prefs.getString(LENGTH_UNIT_KEY) ?? 'เซนติเมตร';
        _selectedWeightUnit = prefs.getString(WEIGHT_UNIT_KEY) ?? 'กิโลกรัม';
        _isLoading = false;
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดการตั้งค่า: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  // บันทึกค่าการตั้งค่าลงใน SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(LENGTH_UNIT_KEY, _selectedLengthUnit);
      await prefs.setString(WEIGHT_UNIT_KEY, _selectedWeightUnit);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกการตั้งค่าเรียบร้อยแล้ว'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกการตั้งค่า: $e');
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกการตั้งค่า'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('ตั้งค่า'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : SafeArea(
              child: SingleChildScrollView(  // เพิ่ม SingleChildScrollView ตรงนี้
                physics: AlwaysScrollableScrollPhysics(),  // ทำให้สามารถเลื่อนได้เสมอแม้เนื้อหาจะไม่เกินหน้าจอ
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // หน่วยวัดความยาว
                      _buildSectionHeader('หน่วยวัดความยาว'),
                      _buildSettingItem(
                        title: 'หน่วยวัด',
                        subtitle: 'สำหรับการวัดขนาดร่างกายโค',
                        options: _lengthUnits,
                        selectedValue: _selectedLengthUnit,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedLengthUnit = value;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 24),
                      
                      // หน่วยวัดน้ำหนัก
                      _buildSectionHeader('หน่วยวัดน้ำหนัก'),
                      _buildSettingItem(
                        title: 'หน่วยน้ำหนัก',
                        subtitle: 'สำหรับการแสดงค่าน้ำหนักโค',
                        options: _weightUnits,
                        selectedValue: _selectedWeightUnit,
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedWeightUnit = value;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 32),
                      
                      // ปุ่มบันทึกการตั้งค่า
                      Container(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            await _saveSettings();
                          },
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            'บันทึกการตั้งค่า',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 16),
                      // ปุ่มรีเซ็ตเป็นค่าเริ่มต้น
                      Container(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedLengthUnit = 'เซนติเมตร';
                              _selectedWeightUnit = 'กิโลกรัม';
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10.0),
                            ),
                            padding: EdgeInsets.symmetric(vertical: 15),
                          ),
                          child: Text(
                            'รีเซ็ตเป็นค่าเริ่มต้น',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      
                      SizedBox(height: 24),
                      // ข้อมูลเพิ่มเติม
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.dividerColor)
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: AppTheme.primaryColor,
                                  size: 20,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'หมายเหตุ:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: AppTheme.primaryDarkColor,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              'การเปลี่ยนหน่วยวัดจะมีผลกับการแสดงผลในแอปพลิเคชันเท่านั้น ข้อมูลที่บันทึกในระบบยังคงใช้หน่วยมาตรฐาน (เซนติเมตร/กิโลกรัม)',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // เพิ่มพื้นที่ว่างด้านล่างเพื่อให้สามารถเลื่อนเห็นเนื้อหาส่วนล่างได้ง่ายขึ้น
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 20,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDarkColor,
                ),
              ),
            ],
          ),
          SizedBox(height: 6),
          Divider(thickness: 1, color: AppTheme.dividerColor),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required String title,
    required String subtitle,
    required List<String> options,
    required String selectedValue,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkColor,
            ),
          ),
          SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
          SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.dividerColor),
              borderRadius: BorderRadius.circular(8),
            ),
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                border: InputBorder.none,
              ),
              value: selectedValue,
              icon: Icon(Icons.arrow_drop_down, color: AppTheme.primaryColor),
              dropdownColor: Colors.white,
              style: TextStyle(color: AppTheme.primaryDarkColor, fontSize: 16),
              isExpanded: true,  // เพิ่ม property นี้เพื่อให้ dropdown ขยายเต็มความกว้าง
              items: options.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ],
      ),
    );
  }
}