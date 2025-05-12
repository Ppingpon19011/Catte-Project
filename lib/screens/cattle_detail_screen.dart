import 'package:flutter/material.dart';
import 'dart:io';
import '../models/cattle.dart';
import 'weight_estimate_screen.dart';
import 'edit_cattle_screen.dart';
import 'growth_chart_screen.dart'; // เพิ่ม import หน้ากราฟการเจริญเติบโต
import '../database/database_helper.dart';
import '../widgets/detail_row.dart';
import '../widgets/unit_display_widget.dart';
import '../utils/theme_config.dart';
import 'package:flutter_svg/flutter_svg.dart';

class CattleDetailScreen extends StatefulWidget {
  final Cattle cattle;

  const CattleDetailScreen({Key? key, required this.cattle}) : super(key: key);

  @override
  _CattleDetailScreenState createState() => _CattleDetailScreenState();
}

class _CattleDetailScreenState extends State<CattleDetailScreen> {
  late Cattle _cattle;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _cattle = widget.cattle;
    _refreshCattleData();
  }

  Future<void> _refreshCattleData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final updatedCattle = await _dbHelper.getCattleById(_cattle.id);
      if (updatedCattle != null) {
        setState(() {
          _cattle = updatedCattle;
        });
      }
    } catch (e) {
      print('Error refreshing cattle data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildCattleImage() {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.2),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        child: _cattle.imageUrl.startsWith('assets/')
            ? Image.asset(
                _cattle.imageUrl,
                fit: BoxFit.cover,
                height: 250,
                width: double.infinity,
              )
            : Image.file(
                File(_cattle.imageUrl),
                fit: BoxFit.cover,
                height: 250,
                width: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  print('Error loading image: $error');
                  return Container(
                    height: 250,
                    width: double.infinity,
                    color: AppTheme.cardColor,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.broken_image,
                          size: 64,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 8),
                        Text(
                          'ไม่สามารถโหลดรูปภาพได้',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  // ฟังก์ชันสำหรับการไปยังหน้าแก้ไข
  Future<void> _navigateToEditScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditCattleScreen(cattle: _cattle),
      ),
    );
    
    if (result != null && result is Cattle) {
      // อัปเดตข้อมูลโคในหน้ารายละเอียด
      setState(() {
        _cattle = result;
      });
      
      // แสดงข้อความแจ้งเตือน
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตข้อมูลโคเรียบร้อยแล้ว'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }
    }
  }
  
  // ฟังก์ชันสำหรับการลบโค
  Future<void> _deleteCattle() async {
    // แสดงข้อความยืนยันการลบ
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบโค "${_cattle.name}" ใช่หรือไม่? การกระทำนี้ไม่สามารถเรียกคืนได้'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('ลบ', style: TextStyle(color: AppTheme.errorColor)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      setState(() {
        _isLoading = true;
      });

      try {
        // ลบข้อมูลจากฐานข้อมูล
        await _dbHelper.deleteCattle(_cattle.id);
        
        // แสดงข้อความแจ้งเตือน
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ลบข้อมูลโคเรียบร้อยแล้ว'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          
          // กลับไปยังหน้ารายการโค
          Navigator.pop(context, true); // ส่ง true กลับไปบอกว่ามีการลบโค
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาด: $e'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

// แก้ไขฟังก์ชัน _navigateToWeightEstimateScreen
Future<void> _navigateToWeightEstimateScreen() async {
  try {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WeightEstimateScreen(cattle: _cattle), // ตรวจสอบชื่อคลาส
      ),
    );
    
    if (result == true) {
      await _refreshCattleData();
    }
  } catch (e) {
    print('Error navigating to weight estimate screen: $e');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการเปิดหน้าประมาณน้ำหนัก: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }
}

  // ฟังก์ชันนำทางไปหน้ากราฟการเจริญเติบโต
  void _navigateToGrowthChartScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GrowthChartScreen(cattle: _cattle),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_cattle.name),
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _navigateToEditScreen,
          ),
        ],
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : RefreshIndicator(
              onRefresh: _refreshCattleData,
              color: AppTheme.primaryColor,
              child: SingleChildScrollView(
                physics: AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildCattleImage(),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    SvgPicture.asset(
                                      'assets/icons/cow_head.svg',
                                      width: 14,
                                      height: 14,
                                      color: AppTheme.textSecondaryColor,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _cattle.breed,
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryColor.withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _cattle.gender == 'เพศผู้' ? Icons.male : Icons.female,
                                      size: 18,
                                      color: AppTheme.primaryColor,
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      _cattle.gender,
                                      style: TextStyle(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 24),
                          Text(
                            'รายละเอียดโค',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDarkColor,
                            ),
                          ),
                          SizedBox(height: 16),
                          
                          // ข้อมูลทั่วไป
                          _buildSectionHeader('ข้อมูลทั่วไป'),
                          DetailRow(title: 'ชื่อ', value: _cattle.name),
                          DetailRow(title: 'หมายเลขโค', value: _cattle.cattleNumber),
                          DetailRow(title: 'สายพันธุ์', value: _cattle.breed),
                          // เพิ่มการแสดงสีของโค
                          DetailRow(title: 'สี', value: _cattle.color ?? '-'),
                          DetailRow(title: 'เพศ', value: _cattle.gender),
                          DetailRow(title: 'วันเกิด', value: _formatDate(_cattle.birthDate)),
                          
                          SizedBox(height: 20),
                          // ข้อมูลสายพันธุ์
                          _buildSectionHeader('ข้อมูลสายพันธุ์'),
                          DetailRow(title: 'หมายเลขพ่อพันธุ์', value: _cattle.fatherNumber.isEmpty ? '-' : _cattle.fatherNumber),
                          DetailRow(title: 'หมายเลขแม่พันธุ์', value: _cattle.motherNumber.isEmpty ? '-' : _cattle.motherNumber),
                          
                          SizedBox(height: 20),
                          // ข้อมูลการเป็นเจ้าของ
                          _buildSectionHeader('ข้อมูลการเป็นเจ้าของ'),
                          DetailRow(title: 'ชื่อผู้เลี้ยง', value: _cattle.breeder),
                          DetailRow(title: 'เจ้าของปัจจุบัน', value: _cattle.currentOwner),
                          
                          SizedBox(height: 20),
                          // ข้อมูลน้ำหนัก
                          _buildSectionHeader('ข้อมูลน้ำหนัก'),
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppTheme.primaryColor.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'น้ำหนักโดยประมาณ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: AppTheme.primaryDarkColor,
                                      ),
                                    ),
                                    WeightDisplay(
                                      weight: _cattle.estimatedWeight,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: AppTheme.primaryDarkColor,
                                    ),
                                  ],
                                ),
                                SizedBox(height: 8),
                                Divider(thickness: 1, color: AppTheme.dividerColor),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'อัปเดตล่าสุด',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                    Text(
                                      _formatDate(_cattle.lastUpdated),
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          
                          SizedBox(height: 32),
                          ElevatedButton.icon(
                            onPressed: _navigateToWeightEstimateScreen, // ใช้ฟังก์ชันที่แก้ไขแล้ว
                            icon: Icon(Icons.camera_alt),
                            label: Text('ประมาณน้ำหนักด้วยภาพถ่าย'),
                            style: ElevatedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _navigateToGrowthChartScreen, // ใช้ฟังก์ชันที่แก้ไขแล้ว
                            icon: Icon(Icons.trending_up),
                            label: Text('กราฟการเจริญเติบโต'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          
                          // เพิ่มปุ่มลบโปรไฟล์โค
                          SizedBox(height: 24),
                          Divider(color: AppTheme.dividerColor),
                          SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _deleteCattle, // ใช้ฟังก์ชันที่มีอยู่
                            icon: Icon(Icons.delete_forever, color: AppTheme.errorColor),
                            label: Text('ลบโปรไฟล์โค', style: TextStyle(color: AppTheme.errorColor)),
                            style: OutlinedButton.styleFrom(
                              minimumSize: Size(double.infinity, 50),
                              side: BorderSide(color: AppTheme.errorColor),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10.0),
                              ),
                            ),
                          ),
                          SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
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
          Divider(
            thickness: 1, 
            color: AppTheme.dividerColor,
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}