import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import '../models/cattle.dart';
import '../models/weight_record.dart';
import '../database/database_helper.dart';
import '../utils/theme_config.dart';
import '../widgets/custom_card.dart';
import '../widgets/common_widgets.dart';
import '../widgets/unit_display_widget.dart';
import '../utils/reports_screen_chart_painters.dart';

// คลาสเก็บข้อมูลการกระจายน้ำหนัก
class WeightDistribution {
  final double startWeight;
  final double endWeight;
  final int count;
  
  WeightDistribution({
    required this.startWeight,
    required this.endWeight,
    required this.count,
  });
}

class AppLifecycleObserver extends WidgetsBindingObserver {
  final Function() onResume;
  
  AppLifecycleObserver({required this.onResume});
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      onResume();
    }
  }
}

class ReportsScreen extends StatefulWidget {
  @override
  _ReportsScreenState createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Cattle> _cattleList = [];
  List<WeightRecord> _allWeightRecords = [];
  bool _isLoading = true;
  

  // สถิติทั่วไป
  int _totalCattle = 0;
  double _averageWeight = 0.0;
  double _maxWeight = 0.0;
  Cattle? _heaviestCattle;
  
  // ข้อมูลการเติบโต
  Map<String, double> _averageGrowthRates = {};
  
  // ข้อมูลสำหรับกราฟแยกตามสายพันธุ์
  Map<String, List<double>> _weightByBreed = {};
  
  // ข้อมูลช่วงน้ำหนัก
  List<WeightDistribution> _weightDistribution = [];
  
  // สำหรับควบคุม Tab
  late TabController _tabController;

  // เพิ่มตัวแปรสำหรับ StreamController - ประกาศอย่างถูกต้อง
  late StreamController<bool> _dataChangeStreamController;
  late Stream<bool> _dataChangeStream;
  StreamSubscription<bool>? _dataChangeSubscription;
  
  // เพิ่มตัวแปรสำหรับ Observer
  AppLifecycleObserver? _lifecycleObserver;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    
    // สร้าง StreamController และ Stream
    _dataChangeStreamController = StreamController<bool>.broadcast();
    _dataChangeStream = _dataChangeStreamController.stream;
    
    // เริ่มฟังการเปลี่ยนแปลงข้อมูล
    _setupDataChangeListener();
    
    // โหลดข้อมูลครั้งแรก
    _loadData();
    
    // ตั้งค่าการรับฟังการเปลี่ยนแปลงจากฐานข้อมูล
    _setupDatabaseListener();
    
    // เพิ่มการรีเฟรชเมื่อหน้านี้กลับมาอยู่ foreground
    _lifecycleObserver = AppLifecycleObserver(onResume: () {
      if (mounted) {
        _loadData();
      }
    });
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    if (_dataChangeSubscription != null) {
      _dataChangeSubscription!.cancel();
    }
    _dataChangeStreamController.close();
    
    // ลบ observer เมื่อไม่ใช้งาน
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
    }
    
    super.dispose();
  }

  // ตั้งค่าการฟังการเปลี่ยนแปลงข้อมูล
  void _setupDataChangeListener() {
    _dataChangeSubscription = _dataChangeStream.listen((refresh) {
      if (refresh && mounted) {
        _loadData();
      }
    });
  }

  // ตั้งค่าการฟังการเปลี่ยนแปลงจากฐานข้อมูล
  void _setupDatabaseListener() {
    // เพิ่ม listener สำหรับการเปลี่ยนแปลงข้อมูล
    _dbHelper.addChangeListener(() {
      // เมื่อมีการเปลี่ยนแปลงข้อมูล ให้แจ้งเตือน Stream
      if (!_dataChangeStreamController.isClosed) {
        _dataChangeStreamController.add(true);
      }
    });
  }

  List<Map<String, dynamic>> _weightComparisonData = [];

  // เพิ่มฟังก์ชันคำนวณข้อมูลเปรียบเทียบน้ำหนัก
  Future<List<Map<String, dynamic>>> _calculateWeightComparison(List<Cattle> cattleList, List<WeightRecord> allRecords) async {
    List<Map<String, dynamic>> result = [];
    
    for (var cattle in cattleList) {
      // ดึงข้อมูลบันทึกน้ำหนักของโคตัวนี้
      List<WeightRecord> cattleRecords = allRecords.where((r) => r.cattleId == cattle.id).toList();
      
      // ถ้ามีบันทึกน้ำหนัก เรียงตามวันที่จากเก่าไปใหม่
      if (cattleRecords.isNotEmpty) {
        cattleRecords.sort((a, b) => a.date.compareTo(b.date));
        
        // น้ำหนักเริ่มต้น (จากการเพิ่มโค)
        double initialWeight = 0.0;
        
        // ตรวจสอบว่ามีบันทึกน้ำหนักแรก
        WeightRecord? firstRecord;
        
        // ตรวจสอบว่าบันทึกแรกเกิดขึ้นในวันเดียวกันกับวันที่สร้างโค
        // (ใช้ช่วงเวลา 24 ชั่วโมงเป็นเกณฑ์)
        for (var record in cattleRecords) {
          if (record.date.difference(cattle.lastUpdated).inHours.abs() <= 24) {
            firstRecord = record;
            break;
          }
        }
        
        // ถ้าไม่มีบันทึกในวันที่สร้าง ใช้น้ำหนักจากข้อมูลโคเป็นค่าเริ่มต้น
        initialWeight = firstRecord?.weight ?? cattle.estimatedWeight;
        
        // น้ำหนักล่าสุด (จากการวัด)
        double latestWeight = 0.0;
        
        // ใช้บันทึกล่าสุด
        if (cattleRecords.isNotEmpty) {
          cattleRecords.sort((a, b) => b.date.compareTo(a.date)); // เรียงจากใหม่ไปเก่า
          latestWeight = cattleRecords.first.weight;
        } else {
          // ถ้าไม่มีบันทึก ใช้น้ำหนักจากข้อมูลโค
          latestWeight = cattle.estimatedWeight;
        }
        
        // คำนวณความแตกต่าง
        double difference = latestWeight - initialWeight;
        double percentChange = initialWeight > 0 ? (difference / initialWeight) * 100 : 0.0;
        
        // ระยะเวลาการเลี้ยง (วัน)
        int daysKept = DateTime.now().difference(cattle.birthDate).inDays;
        
        // คำนวณการเติบโตเฉลี่ยต่อวัน
        double dailyGrowth = 0.0;
        if (daysKept > 0) {
          dailyGrowth = difference / daysKept.toDouble(); // แปลง int เป็น double ชัดเจน
        }
        
        // สร้างข้อมูลการเปรียบเทียบ
        result.add({
          'cattle': cattle,
          'initialWeight': initialWeight,
          'latestWeight': latestWeight,
          'difference': difference,
          'percentChange': percentChange,
          'daysKept': daysKept,
          'dailyGrowth': dailyGrowth,
        });
      } else {
        // ถ้าไม่มีบันทึกน้ำหนัก ใช้ข้อมูลโคอย่างเดียว
        final int daysKept = DateTime.now().difference(cattle.birthDate).inDays;
        
        result.add({
          'cattle': cattle,
          'initialWeight': cattle.estimatedWeight,
          'latestWeight': cattle.estimatedWeight,
          'difference': 0.0,
          'percentChange': 0.0,
          'daysKept': daysKept,
          'dailyGrowth': 0.0,
        });
      }
    }
    
    // เรียงตามเปอร์เซ็นต์การเปลี่ยนแปลงจากมากไปน้อย
    result.sort((a, b) => (b['percentChange'] as double).compareTo(a['percentChange'] as double));
    
    return result;
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    
    try {
      setState(() {
        _isLoading = true;
      });
      
      // โหลดข้อมูลโคทั้งหมด
      final cattleList = await _dbHelper.getAllCattle();
      
      // รวบรวมข้อมูลน้ำหนักทั้งหมด
      List<WeightRecord> allRecords = [];

      for (var cattle in cattleList) {
        final records = await _dbHelper.getWeightRecordsByCattleId(cattle.id);
        allRecords.addAll(records);
      }

      // ป้องกันข้อมูลซ้ำโดยใช้ Set เพื่อตรวจสอบ
      final uniqueRecords = _removeDuplicateRecords(allRecords);
      
      // คำนวณข้อมูลเปรียบเทียบน้ำหนัก
      List<Map<String, dynamic>> weightComparisonData = await _calculateWeightComparison(cattleList, uniqueRecords);
      
      // คำนวณสถิติเบื้องต้น
      _totalCattle = cattleList.length;
      
      // หาโคที่มีน้ำหนักมากที่สุด
      double maxWeight = 0.0;
      Cattle? heaviestCattle;
      
      for (var cattle in cattleList) {
        if (cattle.estimatedWeight > maxWeight) {
          maxWeight = cattle.estimatedWeight;
          heaviestCattle = cattle;
        }
      }
      
      // คำนวณน้ำหนักเฉลี่ย
      double totalWeight = 0.0;
      for (var cattle in cattleList) {
        totalWeight += cattle.estimatedWeight;
      }
      double averageWeight = _totalCattle > 0 ? totalWeight / _totalCattle : 0.0;
      
      // คำนวณอัตราการเติบโตเฉลี่ยตามสายพันธุ์
      Map<String, List<double>> growthRatesByBreed = {};
      
      for (var cattle in cattleList) {
        final records = await _dbHelper.getWeightRecordsByCattleId(cattle.id);
        
        if (records.length >= 2) {
          // เรียงตามวันที่
          records.sort((a, b) => a.date.compareTo(b.date));
          
          // คำนวณอัตราการเติบโตต่อวัน (กก./วัน)
          final firstRecord = records.first;
          final lastRecord = records.last;
          final daysDifference = lastRecord.date.difference(firstRecord.date).inDays;
          
          if (daysDifference > 0) {
            final growthRate = (lastRecord.weight - firstRecord.weight) / daysDifference.toDouble();
            
            if (!growthRatesByBreed.containsKey(cattle.breed)) {
              growthRatesByBreed[cattle.breed] = [];
            }
            growthRatesByBreed[cattle.breed]!.add(growthRate);
          }
        }
      }
      
      // คำนวณค่าเฉลี่ยของอัตราการเติบโตแต่ละสายพันธุ์
      Map<String, double> averageGrowthRates = {};
      growthRatesByBreed.forEach((breed, rates) {
        if (rates.isNotEmpty) {
          double sum = rates.reduce((a, b) => a + b);
          averageGrowthRates[breed] = sum / rates.length;
        }
      });
      
      // สร้างข้อมูลน้ำหนักตามสายพันธุ์
      Map<String, List<double>> weightByBreed = {};
      for (var cattle in cattleList) {
        if (!weightByBreed.containsKey(cattle.breed)) {
          weightByBreed[cattle.breed] = [];
        }
        weightByBreed[cattle.breed]!.add(cattle.estimatedWeight);
      }
      
      // คำนวณการกระจายน้ำหนัก
      List<WeightDistribution> weightDistribution = _calculateWeightDistribution(cattleList);
      
      // อัพเดทสถานะ
      if (mounted) {
        setState(() {
          _cattleList = cattleList;
          _allWeightRecords = uniqueRecords;
          _maxWeight = maxWeight;
          _heaviestCattle = heaviestCattle;
          _averageWeight = averageWeight;
          _averageGrowthRates = averageGrowthRates;
          _weightByBreed = weightByBreed;
          _weightDistribution = weightDistribution;
          _weightComparisonData = weightComparisonData;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        // แสดงข้อความผิดพลาด
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการโหลดข้อมูล: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // เพิ่มฟังก์ชันใหม่เพื่อกำจัดข้อมูลซ้ำ
  List<WeightRecord> _removeDuplicateRecords(List<WeightRecord> records) {
    // จัดเรียงข้อมูลตามวันที่จากใหม่ไปเก่า
    records.sort((a, b) => b.date.compareTo(a.date));
    
    // ใช้ Map เพื่อเก็บข้อมูลที่ไม่ซ้ำกัน โดยพิจารณาจาก cattleId และเวลาที่บันทึก
    final Map<String, WeightRecord> uniqueRecordsMap = {};
    
    for (var record in records) {
      // สร้างคีย์ที่ไม่ซ้ำกันจาก cattleId และเวลา (ตัดวินาทีออก)
      String dateWithoutSeconds = DateFormat('yyyy-MM-dd HH:mm').format(record.date);
      String uniqueKey = '${record.cattleId}_${dateWithoutSeconds}_${record.weight}';
      
      // เก็บเฉพาะรายการแรกที่พบตามคีย์นี้
      if (!uniqueRecordsMap.containsKey(uniqueKey)) {
        uniqueRecordsMap[uniqueKey] = record;
      }
    }
    
    // แปลงกลับเป็น List
    return uniqueRecordsMap.values.toList();
  }
  
  // คำนวณการกระจายน้ำหนักแบ่งเป็นช่วง
  List<WeightDistribution> _calculateWeightDistribution(List<Cattle> cattleList) {
    if (cattleList.isEmpty) return [];
    
    List<double> weights = cattleList.map((c) => c.estimatedWeight).toList();
    weights.sort();
    
    double minWeight = weights.first;
    double maxWeight = weights.last;
    
    // สร้างช่วงน้ำหนัก 5 ช่วง
    double range = (maxWeight - minWeight) / 5;
    if (range <= 0) range = 100; // กรณีมีค่าเดียว
    
    List<WeightDistribution> distribution = [];
    
    for (int i = 0; i < 5; i++) {
      double start = minWeight + (i * range);
      double end = minWeight + ((i + 1) * range);
      
      if (i == 4) {
        // ช่วงสุดท้ายให้ครอบคลุมค่าสูงสุด
        end = maxWeight;
      }
      
      // นับจำนวนโคในช่วงนี้
      int count = weights.where((w) => w >= start && (i < 4 ? w < end : w <= end)).length;
      
      distribution.add(WeightDistribution(
        startWeight: start,
        endWeight: end,
        count: count,
      ));
    }
    
    return distribution;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('รายงานและสถิติ'),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: 'ภาพรวม'),
            Tab(text: 'น้ำหนักตามสายพันธุ์'),
            Tab(text: 'การเจริญเติบโต'),
          ],
        ),
      ),
      body: _isLoading 
          ? LoadingWidget(message: 'กำลังโหลดข้อมูลสถิติ...')
          : _cattleList.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.bar_chart,
                  title: 'ไม่มีข้อมูลสำหรับสร้างรายงาน',
                  message: 'เพิ่มข้อมูลโคและบันทึกน้ำหนักเพื่อดูรายงานและสถิติ',
                  actionText: 'กลับสู่หน้าหลัก',
                  onActionPressed: () => Navigator.pop(context),
                )
              : Stack(
                  children: [
                    TabBarView(
                      controller: _tabController,
                      children: [
                        _buildOverviewTab(),
                        _buildWeightByBreedTab(),
                        _buildGrowthRateTab(),
                      ],
                    ),
                    // เพิ่ม Positioned เพื่อวาง FAB ให้สูงขึ้น
                    Positioned(
                      bottom: 80, // เพิ่มระยะห่างจากด้านล่าง ให้พ้นจากปุ่มนำทาง
                      right: 16,
                      child: FloatingActionButton(
                        onPressed: () => _showExportOptions(),
                        child: Icon(Icons.ios_share),
                        backgroundColor: AppTheme.primaryColor,
                        tooltip: 'ส่งออกข้อมูล CSV',
                      ),
                    ),
                  ],
                ),
    );
  }

  // สร้างคอลัมน์ข้อมูลการเปรียบเทียบ
  Widget _buildComparisonDataColumn(String title, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // แสดงข้อมูลการเปรียบเทียบทั้งหมด
  void _showAllWeightComparisons() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: double.maxFinite,
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'การเปรียบเทียบน้ำหนักทั้งหมด',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryDarkColor,
                ),
              ),
              SizedBox(height: 16),
              Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _weightComparisonData.length,
                  itemBuilder: (context, index) {
                    final data = _weightComparisonData[index];
                    final cattle = data['cattle'] as Cattle;
                    final double initialWeight = data['initialWeight'] as double;
                    final double latestWeight = data['latestWeight'] as double;
                    final double difference = data['difference'] as double;
                    final double percentChange = data['percentChange'] as double;
                    final double dailyGrowth = data['dailyGrowth'] as double;
                    
                    // สร้างสีตามการเปลี่ยนแปลง
                    Color changeColor = Colors.grey;
                    String changeSymbol = '';
                    
                    if (difference > 0) {
                      changeColor = Colors.green;
                      changeSymbol = '+';
                    } else if (difference < 0) {
                      changeColor = Colors.red;
                      changeSymbol = '';
                    }
                    
                    return Card(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(
                          cattle.name,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text('${initialWeight.toStringAsFixed(1)} → ${latestWeight.toStringAsFixed(1)} กก.'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$changeSymbol${difference.toStringAsFixed(1)} กก.',
                              style: TextStyle(
                                color: changeColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              '(${percentChange > 0 ? '+' : ''}${percentChange.toStringAsFixed(1)}%)',
                              style: TextStyle(
                                color: changeColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('ปิด'),
                style: ElevatedButton.styleFrom(
                  minimumSize: Size(double.infinity, 48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้างการ์ดเปรียบเทียบน้ำหนัก
  Widget _buildWeightComparisonCard() {
    if (_weightComparisonData.isEmpty) {
      return SizedBox.shrink(); // ไม่แสดงถ้าไม่มีข้อมูล
    }
    
    return DetailCard(
      title: 'การเทียบเติบโตนับตั้งแต่เพิ่มโค',
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ข้อมูลนี้แสดงการเปรียบเทียบระหว่างน้ำหนักแรกเข้าและน้ำหนักล่าสุดที่วัดได้',
                  style: TextStyle(color: Colors.blue[800]),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        ..._weightComparisonData.take(5).map((data) { // แสดงเฉพาะ 5 ตัวที่มีการเปลี่ยนแปลงมากที่สุด
          final cattle = data['cattle'] as Cattle;
          final double initialWeight = data['initialWeight'] as double;
          final double latestWeight = data['latestWeight'] as double;
          final double difference = data['difference'] as double;
          final double percentChange = data['percentChange'] as double;
          final int daysKept = data['daysKept'] as int;
          final double dailyGrowth = data['dailyGrowth'] as double;
          
          // สร้างสีตามการเปลี่ยนแปลง (เพิ่มขึ้น = เขียว, ลดลง = แดง, คงที่ = เทา)
          Color changeColor = Colors.grey;
          IconData changeIcon = Icons.remove;
          
          if (difference > 0) {
            changeColor = Colors.green;
            changeIcon = Icons.arrow_upward;
          } else if (difference < 0) {
            changeColor = Colors.red;
            changeIcon = Icons.arrow_downward;
          }
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey.withOpacity(0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  spreadRadius: 1,
                  blurRadius: 2,
                  offset: Offset(0, 1),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        cattle.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: changeColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            changeIcon,
                            color: changeColor,
                            size: 14,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${percentChange.toStringAsFixed(1)}%',
                            style: TextStyle(
                              color: changeColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  'สายพันธุ์: ${cattle.breed}${cattle.color != null && cattle.color!.isNotEmpty ? ' • ${cattle.color}' : ''}',
                  style: TextStyle(
                    color: AppTheme.textSecondaryColor,
                    fontSize: 13,
                  ),
                ),
                SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildComparisonDataColumn(
                      'น้ำหนักเริ่มต้น',
                      '${initialWeight.toStringAsFixed(1)} กก.',
                      Colors.blue,
                    ),
                    _buildComparisonDataColumn(
                      'น้ำหนักปัจจุบัน',
                      '${latestWeight.toStringAsFixed(1)} กก.',
                      Colors.green,
                    ),
                    _buildComparisonDataColumn(
                      'เพิ่ม/ลด',
                      '${difference > 0 ? '+' : ''}${difference.toStringAsFixed(1)} กก.',
                      changeColor,
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'อัตราการเติบโต:',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                      Text(
                        '${dailyGrowth.toStringAsFixed(3)} กก./วัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: changeColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        if (_weightComparisonData.length > 5)
          TextButton(
            onPressed: () {
              // แสดงข้อมูลทั้งหมดในหน้าใหม่หรือ dialog
              _showAllWeightComparisons();
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('ดูข้อมูลทั้งหมด'),
                SizedBox(width: 4),
                Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          ),
      ],
    );
  }
  
  // แท็บภาพรวม
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: EdgeInsets.only(
      left: 16, 
      right: 16, 
      top: 16, 
      bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(),
          SizedBox(height: 20),
          _buildWeightDistributionCard(),
          SizedBox(height: 20),
          _buildWeightComparisonCard(),
          SizedBox(height: 20),
          _buildTopCattleCard(),
          SizedBox(height: 20),
          _buildRecentWeightRecordsCard(),
          SizedBox(height: 80), // เพิ่มพื้นที่ด้านล่างเพื่อให้เลื่อนได้เต็มที่
        ],
      ),
    );
  }
  
  // แท็บน้ำหนักตามสายพันธุ์
  Widget _buildWeightByBreedTab() {
    if (_weightByBreed.isEmpty) {
      return Center(
        child: Text('ไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์', 
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor)),
      );
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.only(
      left: 16, 
      right: 16, 
      top: 16, 
      bottom: 120, // เพิ่มจาก 80 เป็น 120
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailCard(
            title: 'น้ำหนักเฉลี่ยตามสายพันธุ์',
            children: [
              SizedBox(
                height: 300,
                child: _buildBreedWeightChart(),
              ),
              SizedBox(height: 20),
              ..._weightByBreed.entries.map((entry) {
                // คำนวณค่าเฉลี่ย
                double avgWeight = entry.value.reduce((a, b) => a + b) / entry.value.length;
                
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getColorForBreed(entry.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${avgWeight.toStringAsFixed(1)} กก.',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        ' (${entry.value.length} ตัว)',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          SizedBox(height: 20),
          DetailCard(
            title: 'การเปรียบเทียบน้ำหนักตามสายพันธุ์',
            children: [
              ..._weightByBreed.entries.map((entry) {
                // หาค่าต่ำสุด สูงสุด และเฉลี่ย
                double minWeight = entry.value.reduce((a, b) => a < b ? a : b);
                double maxWeight = entry.value.reduce((a, b) => a > b ? a : b);
                double avgWeight = entry.value.reduce((a, b) => a + b) / entry.value.length;
                
                return Container(
                  margin: EdgeInsets.only(bottom: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 20,
                            color: _getColorForBreed(entry.key),
                            margin: EdgeInsets.only(right: 8),
                          ),
                          Text(
                            entry.key,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDarkColor,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildWeightMetricBox(
                            'ต่ำสุด',
                            minWeight,
                            Icons.arrow_downward,
                            Colors.blue,
                          ),
                          _buildWeightMetricBox(
                            'เฉลี่ย',
                            avgWeight,
                            Icons.horizontal_rule,
                            Colors.amber,
                          ),
                          _buildWeightMetricBox(
                            'สูงสุด',
                            maxWeight,
                            Icons.arrow_upward,
                            Colors.green,
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text(
                        'การกระจายน้ำหนัก:',
                        style: TextStyle(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: 8),
                      Container(
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: Colors.grey[200],
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: _countInRange(entry.value, 0, avgWeight - (avgWeight * 0.2)),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(20),
                                    bottomLeft: Radius.circular(20),
                                  ),
                                  color: Colors.blue[300],
                                ),
                              ),
                            ),
                            Expanded(
                              flex: _countInRange(entry.value, avgWeight - (avgWeight * 0.2), avgWeight),
                              child: Container(
                                color: Colors.blue[500],
                              ),
                            ),
                            Expanded(
                              flex: _countInRange(entry.value, avgWeight, avgWeight + (avgWeight * 0.2)),
                              child: Container(
                                color: Colors.amber[500],
                              ),
                            ),
                            Expanded(
                              flex: _countInRange(entry.value, avgWeight + (avgWeight * 0.2), double.infinity),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.only(
                                    topRight: Radius.circular(20),
                                    bottomRight: Radius.circular(20),
                                  ),
                                  color: Colors.green[500],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${minWeight.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            '${avgWeight.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                          Text(
                            '${maxWeight.toStringAsFixed(0)}',
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }
  
  // แท็บการเจริญเติบโต
  Widget _buildGrowthRateTab() {
    if (_averageGrowthRates.isEmpty) {
      return Center(
        child: Text('ไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์การเจริญเติบโต\nต้องมีการบันทึกน้ำหนักอย่างน้อย 2 ครั้งสำหรับโคแต่ละตัว', 
          style: TextStyle(fontSize: 16, color: AppTheme.textSecondaryColor),
          textAlign: TextAlign.center,
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: EdgeInsets.only(
      left: 16, 
      right: 16, 
      top: 16, 
      bottom: 120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DetailCard(
            title: 'อัตราการเจริญเติบโตเฉลี่ย',
            children: [
              SizedBox(
                height: 300,
                child: _buildGrowthRateChart(),
              ),
              SizedBox(height: 20),
              ..._averageGrowthRates.entries.map((entry) {
                return Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: _getColorForBreed(entry.key),
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          entry.key,
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        '${entry.value.toStringAsFixed(3)} กก./วัน',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              Container(
                margin: EdgeInsets.only(top: 16),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'อัตราการเจริญเติบโตคำนวณจากน้ำหนักที่เพิ่มขึ้นต่อวัน (กก./วัน) โดยใช้ข้อมูลจากการบันทึกน้ำหนักครั้งแรกและครั้งล่าสุด',
                        style: TextStyle(color: Colors.blue[800]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 20),
          DetailCard(
            title: 'โคที่มีการเจริญเติบโตดีที่สุด',
            children: [
              _buildTopGrowthCattleList(),
            ],
          ),
          SizedBox(height: 80),
        ],
      ),
    );
  }
  
  // แท็บประสิทธิภาพการเลี้ยง
  // Widget _buildEfficiencyTab() {
  //   return SingleChildScrollView(
  //     padding: EdgeInsets.all(16),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         DetailCard(
  //           title: 'ประสิทธิภาพตามสายพันธุ์',
  //           children: [
  //             Container(
  //               margin: EdgeInsets.only(bottom: 20),
  //               padding: EdgeInsets.all(12),
  //               decoration: BoxDecoration(
  //                 color: Colors.amber.withOpacity(0.1),
  //                 borderRadius: BorderRadius.circular(8),
  //                 border: Border.all(color: Colors.amber.withOpacity(0.3)),
  //               ),
  //               child: Row(
  //                 children: [
  //                   Icon(Icons.lightbulb_outline, color: Colors.amber[800]),
  //                   SizedBox(width: 10),
  //                   Expanded(
  //                     child: Text(
  //                       'การวิเคราะห์นี้แสดงประสิทธิภาพการเลี้ยงโคแต่ละสายพันธุ์ โดยพิจารณาจากอัตราการเจริญเติบโตและน้ำหนักเฉลี่ย',
  //                       style: TextStyle(color: Colors.amber[800]),
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             SizedBox(
  //               height: 300,
  //               child: _buildEfficiencyChart(),
  //             ),
  //             SizedBox(height: 20),
  //             ..._getBreedEfficiencyData().map((data) {
  //               return Padding(
  //                 padding: EdgeInsets.only(bottom: 16),
  //                 child: Row(
  //                   children: [
  //                     Container(
  //                       width: 12,
  //                       height: 12,
  //                       decoration: BoxDecoration(
  //                         color: _getColorForBreed(data['breed'] as String),
  //                         shape: BoxShape.circle,
  //                       ),
  //                     ),
  //                     SizedBox(width: 8),
  //                     Expanded(
  //                       child: Text(
  //                         data['breed'] as String,
  //                         style: TextStyle(
  //                           fontWeight: FontWeight.w500,
  //                         ),
  //                       ),
  //                     ),
  //                     _buildEfficiencyStars(data['efficiency'] as double),
  //                   ],
  //                 ),
  //               );
  //             }).toList(),
  //           ],
  //         ),
  //         SizedBox(height: 20),
  //         DetailCard(
  //           title: 'คำแนะนำสำหรับการปรับปรุง',
  //           children: [
  //             _buildBreedingAdvice(),
  //           ],
  //         ),
  //         SizedBox(height: 80),
  //       ],
  //     ),
  //   );
  // }
  
  // สร้างกราฟน้ำหนักตามสายพันธุ์
  Widget _buildBreedWeightChart() {
    // แปลงข้อมูลให้อยู่ในรูปแบบที่ต้องการ
    List<Map<String, dynamic>> chartData = _getBreedWeightData();
    
    // เพิ่มข้อมูลสีตามสายพันธุ์
    for (var data in chartData) {
      data['color'] = _getColorForBreed(data['label'] as String);
    }
    
    // ใส่ Container พร้อมตั้งค่า LayoutBuilder เพื่อให้ปรับขนาดตามพื้นที่ที่มี
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: 300,
          child: CustomPaint(
            painter: BarChartPainter(
              data: chartData,
              maxValue: _getMaxAverageWeight() * 1.2,
              barColor: Colors.grey,
              showValues: true,
              useCustomColors: true,
              isSmallScreen: constraints.maxWidth < 400,
            ),
            size: Size(constraints.maxWidth, 300),
          ),
        );
      }
    );
  }
  
  // สร้างกราฟอัตราการเติบโตตามสายพันธุ์
  Widget _buildGrowthRateChart() {
    // แปลงข้อมูลให้อยู่ในรูปแบบที่ต้องการ
    List<Map<String, dynamic>> chartData = _getGrowthRateData();
    
    // เพิ่มข้อมูลสีตามสายพันธุ์
    for (var data in chartData) {
      data['color'] = _getColorForBreed(data['label'] as String);
    }
    
    // ใช้ LayoutBuilder เพื่อให้ปรับขนาดตามพื้นที่ที่มี
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          width: constraints.maxWidth,
          height: 300,
          child: CustomPaint(
            painter: BarChartPainter(
              data: chartData,
              maxValue: _getMaxGrowthRate() * 1.2,
              barColor: Colors.green,
              showValues: true,
              valueFormat: (value) => '${value.toStringAsFixed(3)} กก./วัน',
              useCustomColors: true,
              isSmallScreen: constraints.maxWidth < 400,
            ),
            size: Size(constraints.maxWidth, 300),
          ),
        );
      }
    );
  }
  
  // สร้างกราฟประสิทธิภาพ
  // Widget _buildEfficiencyChart() {
  //   return CustomPaint(
  //     painter: RadarChartPainter(
  //       data: _getBreedEfficiencyData(),
  //       maxValue: 5.0,
  //       lineColor: AppTheme.primaryColor,
  //     ),
  //     size: Size.fromHeight(300),
  //   );
  // }
  
  // ข้อมูลน้ำหนักตามสายพันธุ์
  List<Map<String, dynamic>> _getBreedWeightData() {
    List<Map<String, dynamic>> result = [];
    
    _weightByBreed.forEach((breed, weights) {
      if (weights.isNotEmpty) {
        double average = weights.reduce((a, b) => a + b) / weights.length;
        result.add({
          'label': breed,
          'value': average,
          'count': weights.length, // เพิ่มจำนวนโคในแต่ละสายพันธุ์
        });
      }
    });
    
    // เรียงลำดับจากมากไปน้อย
    result.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    return result;
  }
  
  // ข้อมูลอัตราการเติบโตตามสายพันธุ์
  List<Map<String, dynamic>> _getGrowthRateData() {
    List<Map<String, dynamic>> result = [];
    
    _averageGrowthRates.forEach((breed, rate) {
      result.add({
        'label': breed,
        'value': rate,
      });
    });
    
    // เรียงลำดับจากมากไปน้อย
    result.sort((a, b) => (b['value'] as double).compareTo(a['value'] as double));
    
    return result;
  }
  
  // ข้อมูลประสิทธิภาพตามสายพันธุ์
  // List<Map<String, dynamic>> _getBreedEfficiencyData() {
  //   List<Map<String, dynamic>> result = [];
    
  //   // ดึงข้อมูลน้ำหนักและอัตราการเติบโต
  //   Map<String, double> avgWeightByBreed = {};
  //   _weightByBreed.forEach((breed, weights) {
  //     if (weights.isNotEmpty) {
  //       avgWeightByBreed[breed] = weights.reduce((a, b) => a + b) / weights.length;
  //     }
  //   });
    
  //   // รวมข้อมูลและคำนวณประสิทธิภาพ (สเกล 1-5)
  //   Set<String> allBreeds = {...avgWeightByBreed.keys, ..._averageGrowthRates.keys};
    
  //   for (var breed in allBreeds) {
  //     double weightScore = 0;
  //     double growthScore = 0;
      
  //     // คำนวณคะแนนน้ำหนัก
  //     if (avgWeightByBreed.containsKey(breed)) {
  //       // คำนวณโดยเทียบกับค่าสูงสุด
  //       double maxAvgWeight = avgWeightByBreed.values.reduce((a, b) => a > b ? a : b);
  //       weightScore = (avgWeightByBreed[breed]! / maxAvgWeight) * 5;
  //     }
      
  //     // คำนวณคะแนนการเติบโต
  //     if (_averageGrowthRates.containsKey(breed)) {
  //       // คำนวณโดยเทียบกับค่าสูงสุด
  //       double maxGrowthRate = _averageGrowthRates.values.reduce((a, b) => a > b ? a : b);
  //       if (maxGrowthRate > 0) {
  //         growthScore = math.max(0, (_averageGrowthRates[breed]! / maxGrowthRate) * 5);
  //       }
  //     }
      
  //     // คำนวณคะแนนเฉลี่ย - ป้องกันค่าติดลบ
  //     double efficiency = (weightScore + growthScore) / 2;
  //     // ป้องกันค่าติดลบ
  //     efficiency = math.max(0.0, efficiency);
      
  //     result.add({
  //       'breed': breed,
  //       'efficiency': efficiency,
  //       'weightScore': weightScore,
  //       'growthScore': growthScore,
  //     });
  //   }
    
  //   return result;
  // }
  
  // หาค่าน้ำหนักเฉลี่ยสูงสุด
  double _getMaxAverageWeight() {
    double maxWeight = 0;
    
    _weightByBreed.forEach((breed, weights) {
      if (weights.isNotEmpty) {
        double average = weights.reduce((a, b) => a + b) / weights.length;
        if (average > maxWeight) {
          maxWeight = average;
        }
      }
    });
    
    return maxWeight > 0 ? maxWeight : 1.0;
  }
  
  // หาค่าอัตราการเติบโตสูงสุด
  double _getMaxGrowthRate() {
    if (_averageGrowthRates.isEmpty) return 1.0;
    return _averageGrowthRates.values.reduce((a, b) => a > b ? a : b);
  }
  
  // นับจำนวนโคในช่วงน้ำหนัก
  int _countInRange(List<double> weights, double min, double max) {
    return weights.where((w) => w >= min && w < max).length;
  }
  
  // สร้างกล่องแสดงข้อมูลสถิติน้ำหนัก
  Widget _buildWeightMetricBox(String label, double value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 16),
              SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 4),
          Text(
            '${value.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkColor,
            ),
          ),
          Text(
            'กก.',
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondaryColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // สร้างดาวแสดงประสิทธิภาพ
  // Widget _buildEfficiencyStars(double efficiency) {
  //   // ป้องกันค่าติดลบ
  //   efficiency = math.max(0.0, efficiency);
  //   int fullStars = efficiency.floor();
  //   double remainder = efficiency - fullStars;
    
  //   return Row(
  //     children: [
  //       for (int i = 0; i < 5; i++)
  //         Icon(
  //           i < fullStars
  //               ? Icons.star
  //               : (i == fullStars && remainder >= 0.5)
  //                   ? Icons.star_half
  //                   : Icons.star_border,
  //           color: Colors.amber,
  //           size: 20,
  //         ),
  //       SizedBox(width: 4),
  //       Text(
  //         efficiency.toStringAsFixed(1),
  //         style: TextStyle(
  //           fontWeight: FontWeight.bold,
  //         ),
  //       ),
  //     ],
  //   );
  // }
  
  // สร้างรายการโคที่เติบโตดีที่สุด
  Widget _buildTopGrowthCattleList() {
    // สร้างข้อมูลอัตราการเติบโตของโคแต่ละตัว
    List<Map<String, dynamic>> cattleGrowthData = [];
    
    for (var cattle in _cattleList) {
      try {
        // ดึงบันทึกน้ำหนักของโคตัวนี้
        final records = _allWeightRecords.where((record) => record.cattleId == cattle.id).toList();
        
        if (records.length >= 2) {
          // เรียงตามวันที่
          records.sort((a, b) => a.date.compareTo(b.date));
          
          // คำนวณอัตราการเติบโต
          final firstRecord = records.first;
          final lastRecord = records.last;
          final daysDifference = lastRecord.date.difference(firstRecord.date).inDays;
          
          if (daysDifference > 0) {
            final growthRate = (lastRecord.weight - firstRecord.weight) / daysDifference;
            
            cattleGrowthData.add({
              'cattle': cattle,
              'growthRate': growthRate,
              'startWeight': firstRecord.weight,
              'endWeight': lastRecord.weight,
              'days': daysDifference,
            });
          }
        }
      } catch (e) {
        print('เกิดข้อผิดพลาดในการคำนวณอัตราการเติบโตของโค ${cattle.name}: $e');
      }
    }
    
    // เรียงตามอัตราการเติบโตจากมากไปน้อย
    cattleGrowthData.sort((a, b) => (b['growthRate'] as double).compareTo(a['growthRate'] as double));
    
    // แสดงเฉพาะ 5 อันดับแรก
    final topGrowth = cattleGrowthData.take(5).toList();
    
    if (topGrowth.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16),
        alignment: Alignment.center,
        child: Text(
          'ไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์',
          style: TextStyle(
            color: AppTheme.textSecondaryColor,
          ),
        ),
      );
    }
    
    return Column(
      children: [
        ...topGrowth.asMap().entries.map((entry) {
          final index = entry.key;
          final data = entry.value;
          final cattle = data['cattle'] as Cattle;
          final growthRate = data['growthRate'] as double;
          final startWeight = data['startWeight'] as double;
          final endWeight = data['endWeight'] as double;
          final days = data['days'] as int;
          
          return Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: index == 0 ? Colors.amber.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: index == 0 ? Colors.amber : Colors.grey.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: index == 0
                        ? Colors.amber
                        : index == 1
                            ? Colors.grey[400]
                            : index == 2
                                ? Colors.brown[300]
                                : AppTheme.primaryColor.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: index == 0 ? Colors.white : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        cattle.name,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        'สายพันธุ์: ${cattle.breed}',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.trending_up,
                          color: Colors.green,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${growthRate.toStringAsFixed(3)} กก./วัน',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text(
                      '${startWeight.toStringAsFixed(1)} → ${endWeight.toStringAsFixed(1)} กก. (${days} วัน)',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  // สร้างข้อแนะนำสำหรับการปรับปรุง
  // Widget _buildBreedingAdvice() {
  //   // ข้อมูลประสิทธิภาพของสายพันธุ์
  //   final efficiencyData = _getBreedEfficiencyData();
    
  //   if (efficiencyData.isEmpty) {
  //     return Container(
  //       padding: EdgeInsets.all(16),
  //       alignment: Alignment.center,
  //       child: Text(
  //         'ไม่มีข้อมูลเพียงพอสำหรับการวิเคราะห์',
  //         style: TextStyle(
  //           color: AppTheme.textSecondaryColor,
  //         ),
  //       ),
  //     );
  //   }
    
  //   // เรียงลำดับตามประสิทธิภาพ
  //   efficiencyData.sort((a, b) => (b['efficiency'] as double).compareTo(a['efficiency'] as double));
    
  //   // สายพันธุ์ที่มีประสิทธิภาพดีที่สุดและแย่ที่สุด
  //   final bestBreed = efficiencyData.first;
  //   final worstBreed = efficiencyData.last;
    
  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Container(
  //         margin: EdgeInsets.only(bottom: 16),
  //         padding: EdgeInsets.all(12),
  //         decoration: BoxDecoration(
  //           color: Colors.green.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(8),
  //           border: Border.all(color: Colors.green.withOpacity(0.3)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(Icons.thumb_up, color: Colors.green),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'จุดแข็ง',
  //                   style: TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                     fontSize: 16,
  //                     color: Colors.green[800],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 8),
  //             Text(
  //               'สายพันธุ์ ${bestBreed['breed']} ให้ผลลัพธ์ดีที่สุดในฟาร์มของคุณ ด้วยอัตราการเจริญเติบโตและน้ำหนักเฉลี่ยที่ดี สามารถพิจารณาเพิ่มจำนวนโคสายพันธุ์นี้ในฝูงเพื่อเพิ่มประสิทธิภาพโดยรวม',
  //               style: TextStyle(
  //                 color: Colors.green[800],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       Container(
  //         margin: EdgeInsets.only(bottom: 16),
  //         padding: EdgeInsets.all(12),
  //         decoration: BoxDecoration(
  //           color: Colors.red.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(8),
  //           border: Border.all(color: Colors.red.withOpacity(0.3)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(Icons.thumb_down, color: Colors.red),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'จุดที่ควรปรับปรุง',
  //                   style: TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                     fontSize: 16,
  //                     color: Colors.red[800],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 8),
  //             Text(
  //               'สายพันธุ์ ${worstBreed['breed']} มีประสิทธิภาพต่ำกว่าสายพันธุ์อื่นในฝูงของคุณ พิจารณาปรับปรุงการให้อาหารหรือการจัดการสำหรับโคสายพันธุ์นี้ หรือพิจารณาลดสัดส่วนในฝูงในอนาคต',
  //               style: TextStyle(
  //                 color: Colors.red[800],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       Container(
  //         padding: EdgeInsets.all(12),
  //         decoration: BoxDecoration(
  //           color: Colors.blue.withOpacity(0.1),
  //           borderRadius: BorderRadius.circular(8),
  //           border: Border.all(color: Colors.blue.withOpacity(0.3)),
  //         ),
  //         child: Column(
  //           crossAxisAlignment: CrossAxisAlignment.start,
  //           children: [
  //             Row(
  //               children: [
  //                 Icon(Icons.lightbulb, color: Colors.blue),
  //                 SizedBox(width: 8),
  //                 Text(
  //                   'คำแนะนำทั่วไป',
  //                   style: TextStyle(
  //                     fontWeight: FontWeight.bold,
  //                     fontSize: 16,
  //                     color: Colors.blue[800],
  //                   ),
  //                 ),
  //               ],
  //             ),
  //             SizedBox(height: 8),
  //             Text(
  //               'ตรวจสอบโคสม่ำเสมอและบันทึกน้ำหนักอย่างน้อยเดือนละครั้งเพื่อติดตามการเจริญเติบโต โคที่มีอัตราการเติบโตต่ำกว่า 0.5 กก./วัน อาจต้องการโภชนาการเพิ่มเติมหรือการตรวจสุขภาพ',
  //               style: TextStyle(
  //                 color: Colors.blue[800],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //     ],
  //   );
  // }
  
  // การ์ดสรุปภาพรวม
  Widget _buildSummaryCard() {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.dashboard,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'ภาพรวมฟาร์ม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDarkColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'จำนวนโคทั้งหมด',
                    '$_totalCattle ตัว',
                    Icons.pets,
                    Colors.blue,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'น้ำหนักเฉลี่ย',
                    '${_averageWeight.toStringAsFixed(1)} กก.',
                    Icons.monitor_weight,
                    Colors.green,
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'น้ำหนักสูงสุด',
                    '${_maxWeight.toStringAsFixed(1)} กก.',
                    Icons.trending_up,
                    Colors.orange,
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: _buildSummaryItem(
                    'จำนวนบันทึกน้ำหนัก',
                    '${_allWeightRecords.length} รายการ',
                    Icons.history,
                    Colors.purple,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // สร้างรายการสรุปข้อมูล
  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkColor,
            ),
          ),
        ],
      ),
    );
  }
  
  // การ์ดแสดงการกระจายน้ำหนัก
  Widget _buildWeightDistributionCard() {
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return DetailCard(
      title: 'การกระจายน้ำหนัก',
      children: [
        SizedBox(
          height: 200,
          child: _buildWeightDistributionChart(),
        ),
        SizedBox(height: isSmallScreen ? 12 : 16),
        ..._weightDistribution.map((distribution) {
          return Padding(
            padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 8),
            // ใช้ Row พร้อม Expanded เพื่อป้องกัน overflow
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _getColorForRange(_weightDistribution.indexOf(distribution)),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 8),
                // ใช้ Expanded เพื่อรองรับข้อความที่ยาว
                Expanded(
                  child: Text(
                    '${distribution.startWeight.toStringAsFixed(0)} - ${distribution.endWeight.toStringAsFixed(0)} กก.',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
                    ),
                    overflow: TextOverflow.ellipsis, // ตัดข้อความที่ยาวเกิน
                  ),
                ),
                SizedBox(width: 4), // ระยะห่างเล็กลง
                // ไม่ใช้ Expanded ที่นี่เพราะเป็นข้อความสั้นๆ
                Text(
                  '${distribution.count} ตัว',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isSmallScreen ? 12 : 14,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    );
  }
  
  // สร้างกราฟการกระจายน้ำหนัก
  Widget _buildWeightDistributionChart() {
    return CustomPaint(
      painter: PieChartPainter(
        data: _weightDistribution.map((item) => item.count.toDouble()).toList(),
        colors: _weightDistribution
            .asMap()
            .entries
            .map((entry) => _getColorForRange(entry.key))
            .toList(),
      ),
      size: Size.fromHeight(200),
    );
  }
  
  // การ์ดแสดงโคที่มีน้ำหนักมากที่สุด
  Widget _buildTopCattleCard() {
    // เตรียมข้อมูลโคพร้อมน้ำหนักล่าสุด
    List<Map<String, dynamic>> cattleWithLatestWeight = [];
    
    for (var cattle in _cattleList) {
      // ค้นหาบันทึกน้ำหนักล่าสุดของโคแต่ละตัว
      List<WeightRecord> cattleRecords = _allWeightRecords
          .where((record) => record.cattleId == cattle.id)
          .toList();
      
      if (cattleRecords.isNotEmpty) {
        // เรียงลำดับตามวันที่จากใหม่ไปเก่า
        cattleRecords.sort((a, b) => b.date.compareTo(a.date));
        
        // เก็บข้อมูลโคพร้อมกับน้ำหนักล่าสุด
        cattleWithLatestWeight.add({
          'cattle': cattle,
          'latestWeightRecord': cattleRecords.first,
          'latestWeight': cattleRecords.first.weight,
          'date': cattleRecords.first.date,
        });
      } else {
        // กรณีไม่มีบันทึกน้ำหนัก ใช้น้ำหนักจากข้อมูลโค
        cattleWithLatestWeight.add({
          'cattle': cattle,
          'latestWeightRecord': null,
          'latestWeight': cattle.estimatedWeight,
          'date': cattle.lastUpdated,
        });
      }
    }
    
    // เรียงลำดับตามน้ำหนักล่าสุดจากมากไปน้อย
    cattleWithLatestWeight.sort((a, b) {
      return (b['latestWeight'] as double).compareTo(a['latestWeight'] as double);
    });
    
    // เอาเฉพาะ 5 อันดับแรก
    final topCattle = cattleWithLatestWeight.take(5).toList();
    
    // ตรวจสอบว่าเป็นหน้าจอขนาดเล็กหรือไม่
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return DetailCard(
      title: 'โคที่มีน้ำหนักมากที่สุด',
      children: [
        if (topCattle.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'ไม่มีข้อมูลโค',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          )
        else
          ...topCattle.asMap().entries.map((entry) {
            final index = entry.key;
            final data = entry.value;
            final cattle = data['cattle'] as Cattle;
            final double latestWeight = data['latestWeight'] as double;
            final WeightRecord? record = data['latestWeightRecord'] as WeightRecord?;
            final DateTime date = data['date'] as DateTime;
            
            // คำนวณความแตกต่างระหว่างน้ำหนักที่วัดได้กับน้ำหนักที่บันทึกในข้อมูลโค
            double? weightDifference;
            String? differenceText;
            if (record != null && record.weight != cattle.estimatedWeight) {
              weightDifference = record.weight - cattle.estimatedWeight;
              differenceText = weightDifference > 0 
                  ? '+${weightDifference.toStringAsFixed(1)}' 
                  : '${weightDifference.toStringAsFixed(1)}';
            }
            
            return Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(isSmallScreen ? 8 : 12), // ปรับ padding ตามขนาดหน้าจอ
              decoration: BoxDecoration(
                color: index == 0 ? Colors.amber.withOpacity(0.1) : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: index == 0 ? Colors.amber : Colors.grey.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  // ส่วนหมายเลขลำดับ
                  Container(
                    width: isSmallScreen ? 32 : 40, // ปรับขนาดตามหน้าจอ
                    height: isSmallScreen ? 32 : 40,
                    decoration: BoxDecoration(
                      color: index == 0
                          ? Colors.amber
                          : index == 1
                              ? Colors.grey[400]
                              : index == 2
                                  ? Colors.brown[300]
                                  : AppTheme.primaryColor.withOpacity(0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: isSmallScreen ? 14 : 16,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  // ส่วนข้อมูลโค - ใช้ Flexible เพื่อให้สามารถย่อขนาดได้
                  Flexible(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cattle.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis, // ตัดข้อความที่ยาวเกิน
                          maxLines: 1, // จำกัดจำนวนบรรทัด
                        ),
                        Text(
                          'สายพันธุ์: ${cattle.breed}',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                            fontSize: isSmallScreen ? 12 : 14,
                          ),
                          overflow: TextOverflow.ellipsis, // ตัดข้อความที่ยาวเกิน
                          maxLines: 1, // จำกัดจำนวนบรรทัด
                        ),
                      ],
                    ),
                  ),
                  // ส่วนแสดงน้ำหนัก - ใช้ Flexible เพื่อให้สามารถย่อขนาดได้
                  Flexible(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${latestWeight.toStringAsFixed(1)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: isSmallScreen ? 14 : 16,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                              Text(
                                ' กก.',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 14,
                                  color: AppTheme.primaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          'อัปเดต: ${DateFormat('dd/MM/yy').format(date)}', // ลดรูปแบบวันที่
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }
  
  // การ์ดแสดงบันทึกน้ำหนักล่าสุด
  Widget _buildRecentWeightRecordsCard() {
    // เรียงบันทึกตามวันที่
    List<WeightRecord> sortedRecords = List.from(_allWeightRecords);
    sortedRecords.sort((a, b) => b.date.compareTo(a.date));

    // กำจัดรายการซ้ำอีกครั้งก่อนแสดงผล (ป้องกันเพิ่มเติม)
    final uniqueRecords = _getUniqueRecentRecords(sortedRecords);
    
    // เอาแค่ 5 รายการล่าสุด
    final recentRecords = uniqueRecords.take(5).toList();
    
    // ตรวจสอบว่าเป็นหน้าจอขนาดเล็กหรือไม่
    final isSmallScreen = MediaQuery.of(context).size.width < 400;
    
    return DetailCard(
      title: 'การบันทึกน้ำหนักล่าสุด',
      children: [
        if (recentRecords.isEmpty)
          Container(
            padding: EdgeInsets.all(16),
            alignment: Alignment.center,
            child: Text(
              'ยังไม่มีการบันทึกน้ำหนัก',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          )
        else
          ...recentRecords.map((record) {
            // หาข้อมูลโค
            Cattle? cattle;
            for (var c in _cattleList) {
              if (c.id == record.cattleId) {
                cattle = c;
                break;
              }
            }
            
            if (cattle == null) return Container(); // กรณีไม่พบข้อมูลโค
            
            return Container(
              margin: EdgeInsets.only(bottom: isSmallScreen ? 8 : 10),
              padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 36 : 40,
                    height: isSmallScreen ? 36 : 40,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.scale,
                        color: AppTheme.primaryColor,
                        size: isSmallScreen ? 18 : 20,
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 8 : 12),
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          cattle.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isSmallScreen ? 14 : 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        Text(
                          DateFormat(isSmallScreen ? 'dd/MM/yy HH:mm' : 'dd/MM/yyyy HH:mm').format(record.date),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 12,
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // น้ำหนัก
                  Expanded(
                    flex: 1,
                    child: Text(
                      '${record.weight.toStringAsFixed(1)} กก.',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        fontSize: isSmallScreen ? 14 : 16,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
      ],
    );
  }

  // เพิ่มฟังก์ชันเพื่อกรองรายการซ้ำในการแสดงผล
  List<WeightRecord> _getUniqueRecentRecords(List<WeightRecord> records) {
    final Map<String, WeightRecord> uniqueMap = {};
    
    for (var record in records) {
      // สร้างคีย์จากข้อมูลสำคัญ
      String key = '${record.cattleId}_${record.weight}_${DateFormat('dd/MM/yyyy HH:mm').format(record.date)}';
      
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = record;
      }
    }
    
    // เรียงลำดับตามวันที่อีกครั้ง
    List<WeightRecord> result = uniqueMap.values.toList();
    result.sort((a, b) => b.date.compareTo(a.date));
    
    return result;
  }

  // เพิ่มเมธอดใหม่สำหรับแสดงโปรไฟล์โค
  void _showCattleProfile(Cattle cattle, WeightRecord? latestWeightRecord) {
    // ค้นหาประวัติน้ำหนักทั้งหมดของโคตัวนี้
    List<WeightRecord> cattleRecords = _allWeightRecords
        .where((record) => record.cattleId == cattle.id)
        .toList();
    
    // เรียงตามวันที่ (จากใหม่ไปเก่า)
    cattleRecords.sort((a, b) => b.date.compareTo(a.date));
    
    // คำนวณอายุปัจจุบัน
    String age = _calculateAge(cattle.birthDate);
    
    // แสดงกราฟการเติบโต (ถ้ามีข้อมูลอย่างน้อย 2 รายการ)
    Widget? growthChart;
    if (cattleRecords.length >= 2) {
      growthChart = SizedBox(
        height: 200,
        child: _buildGrowthHistoryChart(cattleRecords),
      );
    }
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: 500),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ส่วนหัวแสดงชื่อและน้ำหนักล่าสุด
                Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.pets,
                          color: AppTheme.primaryColor,
                          size: 30,
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            cattle.name,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'รหัสโค: ${cattle.cattleNumber}',
                            style: TextStyle(
                              color: AppTheme.textSecondaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'น้ำหนักล่าสุด',
                          style: TextStyle(
                            color: AppTheme.textSecondaryColor,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              latestWeightRecord != null
                                  ? '${latestWeightRecord.weight.toStringAsFixed(1)}'
                                  : '${cattle.estimatedWeight.toStringAsFixed(1)}',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                            Text(
                              ' กก.',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                
                SizedBox(height: 20),
                
                // ข้อมูลพื้นฐาน
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      _buildProfileInfoRow('สายพันธุ์', cattle.breed),
                      _buildProfileInfoRow('เพศ', cattle.gender),
                      _buildProfileInfoRow('วันเกิด', DateFormat('dd/MM/yyyy').format(cattle.birthDate)),
                      _buildProfileInfoRow('อายุ', age),
                      if (cattle.color != null && cattle.color!.isNotEmpty)
                        _buildProfileInfoRow('สี', cattle.color!),
                      _buildProfileInfoRow('ผู้เลี้ยง', cattle.breeder),
                      _buildProfileInfoRow('เจ้าของปัจจุบัน', cattle.currentOwner),
                      if (cattle.fatherNumber.isNotEmpty)
                        _buildProfileInfoRow('หมายเลขพ่อพันธุ์', cattle.fatherNumber),
                      if (cattle.motherNumber.isNotEmpty)
                        _buildProfileInfoRow('หมายเลขแม่พันธุ์', cattle.motherNumber),
                    ],
                  ),
                ),
                
                SizedBox(height: 20),
                
                // กราฟประวัติการเติบโต (ถ้ามี)
                if (growthChart != null) ...[
                  Text(
                    'ประวัติการเติบโต',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  growthChart,
                ],
                
                SizedBox(height: 20),
                
                // ประวัติการชั่งน้ำหนัก
                Text(
                  'ประวัติการชั่งน้ำหนัก',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                
                if (cattleRecords.isEmpty)
                  Container(
                    padding: EdgeInsets.all(16),
                    alignment: Alignment.center,
                    child: Text(
                      'ยังไม่มีประวัติการชั่งน้ำหนัก',
                      style: TextStyle(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        // หัวตาราง
                        Container(
                          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'วันที่',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'น้ำหนัก',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              Expanded(
                                flex: 3,
                                child: Text(
                                  'บันทึก',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                        
                        // รายการน้ำหนัก
                        Container(
                          constraints: BoxConstraints(
                            maxHeight: 200, // จำกัดความสูงและให้เลื่อนได้
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              children: cattleRecords.map((record) {
                                return Container(
                                  padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          DateFormat('dd/MM/yyyy HH:mm').format(record.date),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${record.weight.toStringAsFixed(1)} กก.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          record.notes ?? '-',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                SizedBox(height: 20),
                
                // ปุ่มปิด
                Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text('ปิด'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // แสดงกราฟประวัติการเติบโต
  Widget _buildGrowthHistoryChart(List<WeightRecord> records) {
    // เรียงข้อมูลตามวันที่จากเก่าไปใหม่ (สำหรับการแสดงกราฟ)
    records = List.from(records);
    records.sort((a, b) => a.date.compareTo(b.date));
    
    // สร้างข้อมูลสำหรับแสดงกราฟ
    List<Map<String, dynamic>> chartData = [];
    for (var record in records) {
      chartData.add({
        'date': DateFormat('dd/MM').format(record.date),
        'weight': record.weight,
      });
    }
    
    // หาค่าสูงสุดเพื่อกำหนดขนาดกราฟ
    double maxWeight = 0;
    for (var record in records) {
      if (record.weight > maxWeight) {
        maxWeight = record.weight;
      }
    }
    
    return CustomPaint(
      painter: LineChartPainter(
        data: chartData,
        maxValue: maxWeight * 1.2,
        lineColor: AppTheme.primaryColor,
      ),
      size: Size.fromHeight(200),
    );
  }

  // คำนวณอายุเป็นปีและเดือน
  String _calculateAge(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    final years = difference.inDays ~/ 365;
    final months = (difference.inDays % 365) ~/ 30;
    
    if (years > 0) {
      return '$years ปี $months เดือน';
    } else {
      return '$months เดือน';
    }
  }
  
  // แสดงตัวเลือกการส่งออก
  void _showExportOptions() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('ส่งออกรายงาน'),
      content: Container(
        width: double.maxFinite,
        child: ListTile(
          leading: Icon(Icons.table_chart, color: AppTheme.primaryColor),
          title: Text('ส่งออกเป็น CSV'),
          subtitle: Text('ส่งออกข้อมูลดิบในรูปแบบไฟล์ CSV'),
          onTap: () {
            Navigator.pop(context);
            _exportDataToCSV();
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('ยกเลิก'),
        ),
      ],
    ),
  );
}
  
  // ส่งออกข้อมูลเป็น CSV
  Future<void> _exportDataToCSV() async {
    try {
      // แสดง loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('กำลังส่งออกข้อมูล...'),
            ],
          ),
        ),
      );

      // สร้างข้อมูล CSV
      String csvHeader = 'ชื่อโค,หมายเลขโค,สายพันธุ์,เพศ,น้ำหนัก (กก.),วันที่บันทึกล่าสุด\n';
      String csvContent = csvHeader;
      
      for (var cattle in _cattleList) {
        csvContent += '${cattle.name},${cattle.cattleNumber},${cattle.breed},${cattle.gender},${cattle.estimatedWeight},${DateFormat('dd/MM/yyyy').format(cattle.lastUpdated)}\n';
      }
      
      // บันทึกไฟล์
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/cattle_report_${DateTime.now().millisecondsSinceEpoch}.csv';
      
      final file = File(filePath);
      await file.writeAsString(csvContent);
      
      // ปิด loading dialog
      Navigator.pop(context);
      
      // แสดงข้อความสำเร็จในรูปแบบ dialog
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('ส่งออกข้อมูลสำเร็จ'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('บันทึกไฟล์ไว้ที่:'),
              SizedBox(height: 8),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  filePath,
                  style: TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('ตกลง'),
            ),
          ],
        ),
      );
    } catch (e) {
      // ปิด loading dialog ถ้ามี
      Navigator.of(context).pop();
      
      print('เกิดข้อผิดพลาดในการส่งออกข้อมูล: $e');
      
      // แสดงข้อความผิดพลาด
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกข้อมูล: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // สร้างแถวข้อมูลในโปรไฟล์
  Widget _buildProfileInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label + ':',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // แสดงข้อความฟีเจอร์ยังไม่พร้อมใช้งาน
  void _showNotImplementedMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue,
      ),
    );
  }
  
  // ฟังก์ชันกำหนดสีตามสายพันธุ์
  Color _getColorForBreed(String breed) {
    // กำหนดสีแบบคงที่สำหรับแต่ละสายพันธุ์
    final Map<String, Color> breedColors = {
      'Beefmaster': Colors.red,
      'Brahman': Colors.blue,
      'Charolais': Colors.green,
      'บราห์มัน': Colors.blue,
      'ชาร์โรเลส์': Colors.green,
    };
    
    // ถ้ามีสีสำหรับสายพันธุ์นี้แล้ว ให้ใช้สีที่กำหนดไว้
    if (breedColors.containsKey(breed)) {
      return breedColors[breed]!;
    }
    
    // ถ้าไม่มี ให้ใช้ hash code ของชื่อเพื่อสร้างสีแบบสุ่มแต่คงที่
    final int hash = breed.hashCode;
    final List<Color> defaultColors = [
      Colors.purple,
      Colors.orange,
      Colors.teal,
      Colors.pink,
      Colors.indigo,
      Colors.lime,
      Colors.brown,
      Colors.cyan,
    ];
    
    return defaultColors[hash % defaultColors.length];
  }
  
  // ฟังก์ชันกำหนดสีตามช่วง
  Color _getColorForRange(int index) {
    final List<Color> rangeColors = [
      Colors.blue[300]!,
      Colors.green[300]!,
      Colors.amber[300]!,
      Colors.orange[300]!,
      Colors.red[300]!,
    ];
    
    return index < rangeColors.length ? rangeColors[index] : Colors.grey;
  }
}