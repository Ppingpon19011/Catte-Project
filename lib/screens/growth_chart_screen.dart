import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/cattle.dart';
import '../models/weight_record.dart';
import '../database/database_helper.dart';
import '../utils/theme_config.dart';
import '../widgets/unit_display_widget.dart';

class GrowthChartScreen extends StatefulWidget {
  final Cattle cattle;

  const GrowthChartScreen({Key? key, required this.cattle}) : super(key: key);

  @override
  _GrowthChartScreenState createState() => _GrowthChartScreenState();
}

class _GrowthChartScreenState extends State<GrowthChartScreen> with SingleTickerProviderStateMixin {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<WeightRecord> _weightRecords = [];
  bool _isLoading = true;
  
  // สร้างตัวแปรสำหรับข้อมูลที่จะใช้แสดงในกราฟ
  List<Map<String, dynamic>> _chartData = [];
  
  // สร้างตัวแปรสำหรับ Animation Controller
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    
    // สร้าง Animation Controller
    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 1500),
    );
    
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    
    _loadWeightData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWeightData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // ดึงข้อมูลน้ำหนักทั้งหมดของโคตัวนี้
      final records = await _dbHelper.getWeightRecordsByCattleId(widget.cattle.id);
      
      // เรียงลำดับตามวันที่จากเก่าไปใหม่
      records.sort((a, b) => a.date.compareTo(b.date));
      
      // สร้างข้อมูลสำหรับกราฟ
      List<Map<String, dynamic>> chartData = [];
      for (int i = 0; i < records.length; i++) {
        chartData.add({
          'date': records[i].date,
          'weight': records[i].weight,
          'formattedDate': DateFormat('dd/MM/yy').format(records[i].date),
          'imagePath': records[i].imagePath,
          'notes': records[i].notes,
        });
      }

      setState(() {
        _weightRecords = records;
        _chartData = chartData;
        _isLoading = false;
      });
      
      // เริ่ม animation
      _animationController.forward();
    } catch (e) {
      print('Error loading weight records: $e');
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
        title: Text('กราฟการเจริญเติบโต'),
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
          : _weightRecords.isEmpty
              ? _buildEmptyState()
              : _buildContent(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.show_chart,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.4),
          ),
          SizedBox(height: 16),
          Text(
            'ไม่มีข้อมูลน้ำหนัก',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkColor,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'บันทึกน้ำหนักหลายครั้งเพื่อดูกราฟการเจริญเติบโต',
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
            },
            icon: Icon(Icons.arrow_back),
            label: Text('กลับไปบันทึกน้ำหนัก'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    // คำนวณค่าสูงสุดและต่ำสุดของน้ำหนักเพื่อใช้กำหนดขอบเขตของกราฟ
    double minWeight = _weightRecords.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    double maxWeight = _weightRecords.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
    
    // เพิ่มช่องว่าง 10% ด้านบนและล่างของกราฟ
    double padding = (maxWeight - minWeight) * 0.1;
    minWeight = minWeight - padding > 0 ? minWeight - padding : 0;
    maxWeight = maxWeight + padding;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ส่วนหัวแสดงข้อมูลพื้นฐานของโค
          Container(
            padding: EdgeInsets.all(16),
            color: AppTheme.primaryColor.withOpacity(0.05),
            child: Row(
              children: [
                // รูปภาพโค
                Container(
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
                    child: widget.cattle.imageUrl.startsWith('assets/')
                        ? Image.asset(
                            widget.cattle.imageUrl,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(widget.cattle.imageUrl),
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
                ),
                
                SizedBox(width: 16),
                
                // ข้อมูลโค
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.cattle.name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDarkColor,
                        ),
                      ),
                      Text(
                        'หมายเลข: ${widget.cattle.cattleNumber}',
                        style: TextStyle(
                          color: AppTheme.textSecondaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // น้ำหนักล่าสุด
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    WeightDisplay(
                      weight: widget.cattle.estimatedWeight,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                    Text(
                      'น้ำหนักล่าสุด',
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
          
          // แสดงสรุปข้อมูล
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
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
                  'กราฟการเจริญเติบโต',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDarkColor,
                  ),
                ),
              ],
            ),
          ),
          
          // ส่วนแสดงกราฟ
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16.0),
            height: 250,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.all(16),
            child: _chartData.length < 2 
                ? Center(
                    child: Text(
                      'ต้องมีข้อมูลน้ำหนักอย่างน้อย 2 รายการเพื่อแสดงกราฟ',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppTheme.textSecondaryColor),
                    ),
                  )
                : AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      return _buildChart(
                        minWeight, 
                        maxWeight,
                        animationValue: _animation.value,
                      );
                    },
                  ),
          ),
          
          // แสดงประวัติการบันทึกน้ำหนัก
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'ประวัติการบันทึกน้ำหนัก',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDarkColor,
              ),
            ),
          ),
          
          ListView.builder(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            itemCount: _weightRecords.length,
            itemBuilder: (context, index) {
              final record = _weightRecords[_weightRecords.length - index - 1]; // แสดงรายการล่าสุดก่อน
              return Card(
                margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Icon(
                            Icons.scale,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              DateFormat('dd/MM/yyyy').format(record.date),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primaryDarkColor,
                              ),
                            ),
                            Text(
                              DateFormat('HH:mm').format(record.date),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      WeightDisplay(
                        weight: record.weight,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          
          SizedBox(height: 24),
        ],
      ),
    );
  }

  // ส่วนสำคัญที่สุด - สร้างกราฟ
  Widget _buildChart(double minWeight, double maxWeight, {double animationValue = 1.0}) {
    if (_chartData.length < 2) {
      return Container();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final double height = constraints.maxHeight;
        final double bottomPadding = 30; // พื้นที่ด้านล่างสำหรับแสดงวันที่
        final double leftPadding = 50;   // พื้นที่ด้านซ้ายสำหรับแสดงน้ำหนัก
        
        final double graphHeight = height - bottomPadding;
        final double graphWidth = width - leftPadding;
        
        // คำนวณตำแหน่งของจุดบนกราฟ
        List<Offset> points = [];
        for (int i = 0; i < _chartData.length; i++) {
          final x = leftPadding + (i / (_chartData.length - 1)) * graphWidth;
          final normalizedY = (_chartData[i]['weight'] - minWeight) / (maxWeight - minWeight);
          final y = graphHeight - (normalizedY * graphHeight);
          points.add(Offset(x, y));
        }
        
        return CustomPaint(
          size: Size(width, height),
          painter: ChartPainter(
            points: points,
            labels: _chartData.map((data) => data['formattedDate'] as String).toList(),
            minValue: minWeight,
            maxValue: maxWeight,
            bottomPadding: bottomPadding,
            leftPadding: leftPadding,
            primaryColor: AppTheme.primaryColor,
            secondaryColor: AppTheme.primaryColor.withOpacity(0.3),
            animationValue: animationValue,
          ),
        );
      },
    );
  }

  void _showWeightRecordDetail(WeightRecord record, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(record.imagePath),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    width: double.infinity,
                    height: 200,
                    color: AppTheme.primaryColor.withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported,
                        size: 64,
                        color: AppTheme.primaryColor.withOpacity(0.5),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: WeightDisplay(
                      weight: record.weight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(record.date)}',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    Text(
                      'บันทึกเพิ่มเติม:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      record.notes!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('ปิด'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ChartPainter extends CustomPainter {
  final List<Offset> points;
  final List<String> labels;
  final double minValue;
  final double maxValue;
  final double bottomPadding;
  final double leftPadding;
  final Color primaryColor;
  final Color secondaryColor;
  final double animationValue;

  ChartPainter({
    required this.points,
    required this.labels,
    required this.minValue,
    required this.maxValue,
    required this.bottomPadding,
    required this.leftPadding,
    required this.primaryColor,
    required this.secondaryColor,
    this.animationValue = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;
    
    final dotPaint = Paint()
      ..color = primaryColor
      ..style = PaintingStyle.fill;
      
    final linePaint = Paint()
      ..color = secondaryColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    // วาดเส้นแกน Y
    canvas.drawLine(
      Offset(leftPadding, 0),
      Offset(leftPadding, size.height - bottomPadding),
      linePaint,
    );
    
    // วาดเส้นแกน X
    canvas.drawLine(
      Offset(leftPadding, size.height - bottomPadding),
      Offset(size.width, size.height - bottomPadding),
      linePaint,
    );
    
    // วาดเส้นตาราง Y axis - แบ่งเป็น 4 ช่อง
    for (int i = 0; i <= 4; i++) {
      final y = (size.height - bottomPadding) * i / 4;
      
      // วาดเส้นแนวนอน
      canvas.drawLine(
        Offset(leftPadding, y),
        Offset(size.width, y),
        linePaint,
      );
      
      // แสดงค่าน้ำหนัก
      final value = maxValue - ((maxValue - minValue) * i / 4);
      final textStyle = TextStyle(color: secondaryColor, fontSize: 10);
      final textSpan = TextSpan(text: value.toStringAsFixed(1), style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: ui.TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }
    
    // วาดเส้นกราฟ
    if (points.isNotEmpty) {
      // คำนวณจำนวนจุดตามค่า animation
      int pointsToDraw = (points.length * animationValue).round();
      pointsToDraw = pointsToDraw < 1 ? 1 : pointsToDraw;
      
      final pointsToUse = points.sublist(0, pointsToDraw);
      
      final path = Path();
      if (pointsToUse.isNotEmpty) {
        path.moveTo(pointsToUse[0].dx, pointsToUse[0].dy);
        
        for (int i = 1; i < pointsToUse.length; i++) {
          path.lineTo(pointsToUse[i].dx, pointsToUse[i].dy);
        }
      }
      
      canvas.drawPath(path, paint);
      
      // วาดจุดและวันที่
      for (int i = 0; i < pointsToUse.length; i++) {
        // วาดจุด
        canvas.drawCircle(pointsToUse[i], 5, dotPaint);
        
        // แสดงวันที่
        if (i % 2 == 0 || points.length <= 4) { // แสดงเฉพาะบางวันถ้ามีข้อมูลมาก
          final textStyle = TextStyle(color: secondaryColor, fontSize: 10);
          final textSpan = TextSpan(text: labels[i], style: textStyle);
          final textPainter = TextPainter(
            text: textSpan,
            textDirection: ui.TextDirection.ltr,
          );
          
          textPainter.layout();
          textPainter.paint(
            canvas,
            Offset(
              pointsToUse[i].dx - textPainter.width / 2,
              size.height - bottomPadding + 10,
            ),
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}