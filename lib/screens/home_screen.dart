import 'package:flutter/material.dart';
import 'dart:io';
import '../models/cattle.dart';
import 'cattle_detail_screen.dart';
import 'add_cattle_screen.dart';
import '../database/database_helper.dart';
import '../widgets/unit_display_widget.dart';
import '../widgets/custom_search_bar.dart';
import '../utils/theme_config.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Cattle> cattleList = [];
  List<Cattle> filteredCattleList = []; // รายการโคที่ผ่านการกรอง
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _loadCattleList();
    
    // เพิ่ม listener สำหรับช่องค้นหา
    _searchController.addListener(_filterCattleList);
  }

  // ฟังก์ชันกรองรายการโค
  void _filterCattleList() {
    String searchTerm = _searchController.text.toLowerCase().trim();
    
    if (searchTerm.isEmpty) {
      setState(() {
        filteredCattleList = cattleList;
        _isSearching = false;
      });
      return;
    }
    
    setState(() {
      _isSearching = true;
      filteredCattleList = cattleList.where((cattle) {
        return cattle.name.toLowerCase().contains(searchTerm) || 
               cattle.cattleNumber.toLowerCase().contains(searchTerm);
      }).toList();
    });
  }

  // เคลียร์ช่องค้นหา
  void _clearSearch() {
    _searchController.clear();
    setState(() {
      filteredCattleList = cattleList;
      _isSearching = false;
    });
  }

  Future<void> _loadCattleList() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cattle = await _dbHelper.getAllCattle();
      setState(() {
        cattleList = cattle;
        filteredCattleList = cattle; // ตั้งค่าเริ่มต้นให้ filteredCattleList เท่ากับ cattleList
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading cattle: $e');
      setState(() {
        _isLoading = false;
      });
      
      // แสดงข้อความผิดพลาด
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('รายการโค'),
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(0), // ปรับให้เป็น 0 เพื่อให้แอปบาร์เป็นเส้นตรง
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(75.0),
          child: Container(
            padding: const EdgeInsets.only(bottom: 12.0),
            color: AppTheme.primaryColor, // เปลี่ยนเป็น color แทน decoration
            child: CustomSearchBar(
              controller: _searchController,
              hintText: 'ค้นหาโคจากชื่อหรือหมายเลข...',
              isSearching: _isSearching,
              onClear: _clearSearch,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _navigateToAddCattle(context);
        },
        label: const Text('เพิ่มโคใหม่'),
        icon: const Icon(Icons.add),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: AppTheme.primaryColor),
            )
          : filteredCattleList.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isSearching ? Icons.search_off : Icons.pets,
                        size: 80,
                        color: AppTheme.primaryColor.withOpacity(0.4),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _isSearching 
                            ? 'ไม่พบโคที่ค้นหา'
                            : 'ไม่มีรายการโค',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkColor,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _isSearching
                            ? 'ลองค้นหาด้วยคำอื่นหรือเพิ่มโคใหม่'
                            : 'เริ่มต้นเพิ่มข้อมูลโคของคุณ',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      if (!_isSearching) const SizedBox(height: 24),
                      if (!_isSearching)
                        ElevatedButton.icon(
                          onPressed: () {
                            _navigateToAddCattle(context);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('เพิ่มโคใหม่'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                        ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadCattleList,
                  color: AppTheme.primaryColor,
                  child: ListView.builder(
                    padding: const EdgeInsets.only(bottom: 80),  // ให้พื้นที่สำหรับ FAB
                    itemCount: filteredCattleList.length,
                    itemBuilder: (context, index) {
                      final cattle = filteredCattleList[index];
                      return CattleListItem(
                        cattle: cattle,
                        onDelete: () {
                          _deleteCattle(cattle.id);
                        },
                        onTap: () {
                          _navigateToCattleDetail(cattle);
                        },
                      );
                    },
                  ),
                ),
    );
  }

  void _navigateToAddCattle(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddCattleScreen()),
    );

    if (result != null && result is Cattle) {
      // โหลดข้อมูลใหม่จากฐานข้อมูล
      _loadCattleList();
      
      // แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เพิ่มข้อมูลโค "${result.name}" เรียบร้อยแล้ว'),
          backgroundColor: AppTheme.successColor,
        ),
      );
    }
  }

  Future<void> _navigateToCattleDetail(Cattle cattle) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CattleDetailScreen(cattle: cattle),
      ),
    );
    
    // ถ้ามีการเปลี่ยนแปลงข้อมูล (เช่น แก้ไขหรือลบ)
    if (result == true) {
      // โหลดข้อมูลใหม่จากฐานข้อมูล
      _loadCattleList();
    }
  }

  Future<void> _deleteCattle(String id) async {
    // แสดงข้อความยืนยันการลบ
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: const Text('คุณต้องการลบรายการโคนี้หรือไม่?'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
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
        await _dbHelper.deleteCattle(id);
        // โหลดข้อมูลใหม่
        await _loadCattleList();
        // แสดงข้อความแจ้งเตือน
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('ลบข้อมูลโคเรียบร้อยแล้ว'),
            backgroundColor: AppTheme.successColor,
          ),
        );
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filterCattleList);
    _searchController.dispose();
    super.dispose();
  }
}

class CattleListItem extends StatelessWidget {
  final Cattle cattle;
  final VoidCallback onDelete;
  final VoidCallback onTap;

  const CattleListItem({
    Key? key,
    required this.cattle,
    required this.onDelete,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(cattle.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: AppTheme.errorColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      onDismissed: (direction) {
        onDelete();
      },
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('ยืนยันการลบ'),
            content: Text('คุณต้องการลบ "${cattle.name}" หรือไม่?'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('ลบ', style: TextStyle(color: AppTheme.errorColor)),
              ),
            ],
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primaryColor.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            splashColor: AppTheme.primaryColor.withOpacity(0.1),
            highlightColor: AppTheme.primaryColor.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  _buildCattleAvatar(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cattle.name,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDarkColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.tag,
                              size: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cattle.cattleNumber,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.pets,
                              size: 14,
                              color: AppTheme.textSecondaryColor,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              cattle.breed,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                            if (cattle.color != null && cattle.color!.isNotEmpty) ...[
                              Text(
                                ' • ',
                                style: TextStyle(
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                              Text(
                                cattle.color!,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      WeightDisplay(
                        weight: cattle.estimatedWeight,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDate(cattle.lastUpdated),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCattleAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.3),
          width: 2,
        ),
      ),
      child: ClipOval(
        child: cattle.imageUrl.startsWith('assets/')
            ? Image.asset(
                cattle.imageUrl,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(cattle.imageUrl),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: AppTheme.cardColor,
                    child: Icon(
                      Icons.pets,
                      color: AppTheme.primaryColor.withOpacity(0.3),
                      size: 30,
                    ),
                  );
                },
              ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}