import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import 'dart:async';
import '../models/cattle.dart';
import '../models/weight_record.dart';
import '../database/database_helper.dart';
import '../widgets/unit_display_widget.dart';
import '../utils/weight_calculator.dart';
import '../utils/cattle_detector.dart' as detector; // ใช้ prefix เพื่อแก้ไขความขัดแย้ง
import '../services/cattle_measurement_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:ui' as ui;
import 'package:image/image.dart' as img;
import '../utils/enhanced_measurement_painter.dart';
import '../screens/manual_measurement_screen.dart';

class WeightEstimateScreen extends StatefulWidget {
  final Cattle cattle;

  const WeightEstimateScreen({Key? key, required this.cattle})
    : super(key: key);

  @override
  _WeightEstimateScreenState createState() => _WeightEstimateScreenState();
}

class _WeightEstimateScreenState extends State<WeightEstimateScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  bool _modelInitialized = false;
  double? _estimatedWeight;
  final TextEditingController _notesController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CattleMeasurementService _measurementService =
      CattleMeasurementService();
  List<WeightRecord> _weightRecords = [];
  bool _isLoadingHistory = true;

  // ข้อมูลการวัดสัดส่วน
  double? _heartGirth;
  double? _bodyLength;
  double? _height;
  double? _confidence;
  bool _showDetails = false; // แสดงรายละเอียดการคำนวณ

  // ข้อมูลการตรวจจับ
  detector.DetectionResult? _detectionResult;
  
  // แฟล็กเพื่อตรวจสอบว่ามีการตรวจพบวัตถุหรือไม่
  bool _objectsDetected = false;

  @override
  void initState() {
    super.initState();
    _loadWeightHistory();
    _initializeModel();
  }
  
  @override
  void dispose() {
    // ปล่อยทรัพยากรต่างๆ
    _notesController.dispose();
    
    // ปล่อยทรัพยากรของโมเดล
    if (_modelInitialized) {
      try {
        final detector.CattleDetector cattleDetector = detector.CattleDetector();
        cattleDetector.dispose();
      } catch (e) {
        print("Error disposing CattleDetector: $e");
      }
    }
    
    super.dispose();
  }

  // เริ่มต้นโมเดล ML
  Future<void> _initializeModel() async {
    try {
      final result = await _measurementService.initialize();
      if (mounted) {
        setState(() {
          _modelInitialized = result;
        });
      }

      if (!result) {
        Fluttertoast.showToast(
          msg: "ไม่สามารถโหลดโมเดลได้ จะใช้การคำนวณแบบทั่วไปแทน",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      } else {
        Fluttertoast.showToast(
          msg: "โหลดโมเดลเรียบร้อยแล้ว",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดโมเดล: $e');
      if (mounted) {
        setState(() {
          _modelInitialized = false;
        });
      }
      
      Fluttertoast.showToast(
        msg: "เกิดข้อผิดพลาดในการโหลดโมเดล: $e",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  Future<void> _loadWeightHistory() async {
    if (mounted) {
      setState(() {
        _isLoadingHistory = true;
      });
    }

    try {
      // ดึงข้อมูลน้ำหนักทั้งหมดของโคตัวนี้
      final records = await _dbHelper.getWeightRecordsByCattleId(
        widget.cattle.id,
      );
      
      if (mounted) {
        setState(() {
          _weightRecords = records;
          _isLoadingHistory = false;
        });
      }
    } catch (e) {
      print('Error loading weight history: $e');
      if (mounted) {
        setState(() {
          _isLoadingHistory = false;
        });
      }

      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดประวัติน้ำหนัก: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        if (mounted) {
          setState(() {
            _imageFile = File(image.path);
            _isProcessing = true;
            _estimatedWeight = null;
            _heartGirth = null;
            _bodyLength = null;
            _height = null;
            _confidence = null;
            _showDetails = false;
            _detectionResult = null;
            _objectsDetected = false; // รีเซ็ตค่าการตรวจจับ
          });
        }

        // ประมวลผลภาพและประมาณน้ำหนัก
        await _analyzeImage();
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการถ่ายภาพ: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการถ่ายภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectPicture() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (image != null) {
        if (mounted) {
          setState(() {
            _imageFile = File(image.path);
            _isProcessing = true;
            _estimatedWeight = null;
            _heartGirth = null;
            _bodyLength = null;
            _height = null;
            _confidence = null;
            _showDetails = false;
            _detectionResult = null;
            _objectsDetected = false; // รีเซ็ตค่าการตรวจจับ
          });
        }

        // ประมวลผลภาพและประมาณน้ำหนัก
        await _analyzeImage();
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเลือกภาพ: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    }

  Future<void> _analyzeImage() async {
    if (!mounted || _imageFile == null) return;
  
    try {
      // แสดงข้อความกำลังประมวลผล
      setState(() {
        _isProcessing = true;
      });
      
      // คำนวณอายุของโคเป็นเดือน
      int ageMonths = WeightCalculator.calculateAgeInMonths(
        widget.cattle.birthDate,
      );

      try {
        if (_modelInitialized && _imageFile != null) {
          print('กำลังวิเคราะห์ภาพด้วยโมเดล ML...');
          
          // ใช้โมเดล ML และคลาส CattleMeasurementService
          final result = await _measurementService.analyzeImage(
            _imageFile!,
            widget.cattle.breed,
            widget.cattle.gender,
            ageMonths,
          );

          if (result.success) {
            // ตรวจสอบว่าพบวัตถุหรือไม่ (Body_Length, Heart_Girth, Yellow_Mark)
            bool foundObjects = false;
            
            if (result.detectionResult != null && 
                result.detectionResult!.objects != null && 
                result.detectionResult!.objects!.isNotEmpty) {
              
              // ตรวจสอบว่าพบวัตถุที่ไม่ได้ประมาณค่า (ไม่มีคำว่า Estimated ในชื่อ)
              int realObjectCount = 0;
              for (var obj in result.detectionResult!.objects!) {
                if (!obj.className.contains('Estimated')) {
                  realObjectCount++;
                }
              }
              
              foundObjects = realObjectCount > 0;
            }

            if (mounted) {
              setState(() {
                _isProcessing = false;
                _heartGirth = result.heartGirth;
                _bodyLength = result.bodyLength;
                _height = result.height;
                _estimatedWeight = result.adjustedWeight;
                _confidence = result.confidence;
                _detectionResult = result.detectionResult;
                _objectsDetected = foundObjects; // บันทึกสถานะการตรวจพบวัตถุ
              });
            }
            print('วิเคราะห์ภาพสำเร็จ: น้ำหนัก = ${result.adjustedWeight} กก.');
            return; // จบการทำงานหากสำเร็จ
          } else {
            // ถ้า ML ล้มเหลว แสดงข้อความและใช้การคำนวณแบบเดิม
            print('การวิเคราะห์ด้วย ML ล้มเหลว: ${result.error}');
            
            if (mounted) {
              ScaffoldMessenger.of(context as BuildContext).showSnackBar(
                SnackBar(
                  content: Text('ใช้การคำนวณน้ำหนักแบบดั้งเดิมแทน: ${result.error}'),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        } else {
          print('ไม่สามารถใช้โมเดล ML ได้ จะใช้การคำนวณแบบดั้งเดิมแทน');
        }
        
        // ใช้การคำนวณแบบเดิมถ้าไม่ได้โหลดโมเดลหรือ ML ล้มเหลว
        await _fallbackAnalysis();
      } catch (e) {
        print('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(
              content: Text('ใช้การคำนวณน้ำหนักแบบดั้งเดิมแทน: $e'),
              duration: Duration(seconds: 3),
            ),
          );
        }
        
        await _fallbackAnalysis();
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดทั่วไปในการวิเคราะห์ภาพ: $e');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _objectsDetected = false; // ไม่มีการตรวจพบวัตถุ
        });
        
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // การวิเคราะห์แบบ fallback ถ้าโมเดล ML ไม่ทำงาน
  Future<void> _fallbackAnalysis() async {
    if (!mounted || _imageFile == null) return;
    
    try {
      print('ใช้การคำนวณแบบทั่วไปแทนการตรวจจับด้วย ML model');
      
      // คำนวณอายุของโคเป็นเดือน
      int ageMonths = WeightCalculator.calculateAgeInMonths(
        widget.cattle.birthDate,
      );

      // เพิ่มการหน่วงเวลาเล็กน้อยเพื่อจำลองการประมวลผล
      await Future.delayed(Duration(seconds: 1));

      // ใช้ WeightCalculator เพื่อประมาณน้ำหนักจากภาพ
      final result = await WeightCalculator.estimateFromImage(
        _imageFile!,
        widget.cattle.breed,
        widget.cattle.gender,
        ageMonths,
      );

      if (result['success'] == true) {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _heartGirth = result['heartGirth'];
            _bodyLength = result['bodyLength'];
            _height = result['height'];
            _estimatedWeight = result['adjustedWeight'];
            _confidence = result['confidence'];
            _objectsDetected = false; // ไม่มีการตรวจพบวัตถุจริงจาก AI
          });
        }
        
        print('วิเคราะห์แบบดั้งเดิมสำเร็จ: น้ำหนัก = ${result['adjustedWeight']} กก.');
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _objectsDetected = false;
          });

          ScaffoldMessenger.of(context as BuildContext).showSnackBar(
            SnackBar(
              content: Text(
                'เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: ${result['error']}',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวิเคราะห์แบบดั้งเดิม: $e');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _objectsDetected = false;
        });

        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ฟังก์ชันสำหรับนำทางไปยังหน้าวัดด้วยตนเอง
  Future<void> _navigateToManualMeasurement() async {
    if (_imageFile == null) return;
    
    // เปิดหน้าวัดด้วยตนเองและรอรับผลลัพธ์กลับมา
    final result = await Navigator.push(
      context as BuildContext,
      MaterialPageRoute(
        builder: (context) => ManualMeasurementScreen(
          imageFile: _imageFile!,
          cattle: widget.cattle,
        ),
      ),
    );
    
    // ตรวจสอบผลลัพธ์ที่ได้รับกลับมา
    if (result != null && result is Map<String, dynamic>) {
      setState(() {
        _isProcessing = false;
        _detectionResult = result['detection_result'] as detector.DetectionResult;
        _estimatedWeight = result['estimated_weight'] as double;
        _heartGirth = result['heart_girth_cm'] as double;
        _bodyLength = result['body_length_cm'] as double;
        _confidence = 1.0; // ค่าความเชื่อมั่นสูงสุด เนื่องจากผู้ใช้กำหนดเอง
        _objectsDetected = true; // ถือว่ามีการกำหนดวัตถุแล้ว
        
        // แสดงรายละเอียดเพิ่มเติม
        _showDetails = true;
      });
      
      print('ได้รับข้อมูลจากการวัดด้วยตนเอง: น้ำหนัก $_estimatedWeight กก., รอบอก $_heartGirth ซม., ความยาว $_bodyLength ซม.');
    }
  }

  Future<void> _saveWeightRecord() async {
    if (_estimatedWeight == null || _imageFile == null) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('กรุณาถ่ายภาพหรือเลือกภาพก่อนบันทึก'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isProcessing = true;
      });
    }

    try {
      File imageToSave = _imageFile!;

      // ถ้ามีผลการตรวจจับ ให้บันทึกภาพที่มีไฮไลท์การวัด
      if (_detectionResult != null && _modelInitialized) {
        final analyzedImage = await _measurementService.saveAnalyzedImage(
          _imageFile!,
          _detectionResult!,
        );
        if (analyzedImage != null) {
          imageToSave = analyzedImage;
        }
      } else {
        // คัดลอกภาพต้นฉบับไปยังพื้นที่แอป
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
        imageToSave = await _imageFile!.copy('${appDir.path}/$fileName');
      }

      // สร้างและบันทึกข้อมูลน้ำหนัก
      String notes = _notesController.text;
      if (_heartGirth != null && _bodyLength != null) {
        if (notes.isNotEmpty) {
          notes += '\n';
        }
        notes += '(รอบอก: ${_heartGirth?.toStringAsFixed(1)} ซม., ความยาว: ${_bodyLength?.toStringAsFixed(1)} ซม.)';
      }
      
      final WeightRecord record = WeightRecord(
        recordId: '', // จะถูกสร้างโดย DatabaseHelper
        cattleId: widget.cattle.id,
        weight: _estimatedWeight!,
        imagePath: imageToSave.path,
        date: DateTime.now(),
        notes: notes,
      );

      await _dbHelper.insertWeightRecord(record);

      // โหลดข้อมูลประวัติใหม่
      await _loadWeightHistory();

      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('บันทึกน้ำหนักเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );

        // รีเซ็ตสถานะ
        setState(() {
          _imageFile = null;
          _estimatedWeight = null;
          _heartGirth = null;
          _bodyLength = null;
          _height = null;
          _confidence = null;
          _notesController.clear();
          _isProcessing = false;
          _showDetails = false;
          _detectionResult = null;
          _objectsDetected = false;
        });

        // ส่งค่ากลับว่าบันทึกสำเร็จเพื่อให้หน้า detail รีเฟรชข้อมูล
        Navigator.pop(context as BuildContext, true);
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกน้ำหนัก: $e');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  // แสดง dialog ยืนยันการลบประวัติน้ำหนัก
  Future<void> _confirmDeleteWeightRecord(WeightRecord record) async {
    return showDialog(
      context: context  as BuildContext,
      builder: (context) => AlertDialog(
        title: Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบประวัติน้ำหนักนี้ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              await _deleteWeightRecord(record);
            },
            child: Text('ลบ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ลบประวัติน้ำหนัก
  Future<void> _deleteWeightRecord(WeightRecord record) async {
    try {
      await _dbHelper.deleteWeightRecord(record.recordId);
      
      // ลบรูปภาพถ้ามี
      if (record.imagePath.isNotEmpty) {
        File imageFile = File(record.imagePath);
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      }
      
      // โหลดข้อมูลประวัติใหม่
      await _loadWeightHistory();
      
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('ลบประวัติน้ำหนักเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบประวัติน้ำหนัก: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context as BuildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  // แสดงกราฟประวัติน้ำหนัก
  void _showWeightChart() {
    if (_weightRecords.isEmpty) {
      ScaffoldMessenger.of(context  as BuildContext).showSnackBar(
        SnackBar(
          content: Text('ไม่มีข้อมูลสำหรับสร้างกราฟ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // เรียงลำดับข้อมูลตามวันที่
    final sortedRecords = List<WeightRecord>.from(_weightRecords);
    sortedRecords.sort((a, b) => a.date.compareTo(b.date));

    // เตรียมข้อมูลสำหรับกราฟ
    List<Map<String, dynamic>> chartData = [];
    for (var record in sortedRecords) {
      // ใช้เฉพาะข้อมูล 6 เดือนล่าสุด
      if (DateTime.now().difference(record.date).inDays <= 180) {
        chartData.add({
          'date': DateFormat('dd/MM').format(record.date),
          'weight': record.weight,
        });
      }
    }

    // แสดง Dialog กราฟน้ำหนัก
    showDialog(
      context: context  as BuildContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          padding: EdgeInsets.all(16),
          width: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'กราฟน้ำหนักของ ${widget.cattle.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Container(
                height: 300,
                child: _buildWeightChart(chartData),
              ),
              SizedBox(height: 16),
              Text(
                'แสดงข้อมูล ${chartData.length} รายการล่าสุด',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: Text('ปิด'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้างกราฟน้ำหนัก
  Widget _buildWeightChart(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return Center(
        child: Text('ไม่มีข้อมูล'),
      );
    }

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: Colors.grey[100],
      ),
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // หาค่า min และ max ของน้ำหนัก
                double minWeight = double.infinity;
                double maxWeight = 0;
                for (var item in data) {
                  if (item['weight'] < minWeight) minWeight = item['weight'];
                  if (item['weight'] > maxWeight) maxWeight = item['weight'];
                }
                
                // ปรับค่า min และ max ให้สวยงาม
                minWeight = (minWeight * 0.9).floorToDouble();
                maxWeight = (maxWeight * 1.1).ceilToDouble();
                
                // ความสูงทั้งหมดที่ใช้วาดกราฟ
                final chartHeight = constraints.maxHeight - 40;
                
                return Stack(
                  children: [
                    // เส้นแกน Y
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('${maxWeight.toStringAsFixed(0)} กก.', style: TextStyle(fontSize: 10)),
                          Text('${((maxWeight + minWeight) / 2).toStringAsFixed(0)} กก.', style: TextStyle(fontSize: 10)),
                          Text('${minWeight.toStringAsFixed(0)} กก.', style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                    
                    // กราฟ
                    Positioned(
                      left: 40,
                      right: 0,
                      top: 0,
                      bottom: 20,
                      child: CustomPaint(
                        size: Size(constraints.maxWidth - 40, chartHeight),
                        painter: WeightChartPainter(
                          data: data,
                          minValue: minWeight,
                          maxValue: maxWeight,
                        ),
                      ),
                    ),
                    
                    // แกน X (วันที่)
                    Positioned(
                      left: 40,
                      right: 0,
                      bottom: 0,
                      height: 20,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int i = 0; i < data.length; i++)
                            if (i % (data.length ~/ 5 + 1) == 0 || i == data.length - 1)
                              Text(data[i]['date'], style: TextStyle(fontSize: 10)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // แสดงรายละเอียดการเปรียบเทียบน้ำหนัก
  void _showWeightComparison() {
    if (_weightRecords.isEmpty) {
      ScaffoldMessenger.of(context  as BuildContext).showSnackBar(
        SnackBar(
          content: Text('ไม่มีข้อมูลสำหรับเปรียบเทียบ'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // หาน้ำหนักล่าสุด
    _weightRecords.sort((a, b) => b.date.compareTo(a.date));
    final latestWeight = _weightRecords.first.weight;

    // คำนวณค่าเฉลี่ยน้ำหนักตามสายพันธุ์และอายุ
    final ageMonths = WeightCalculator.calculateAgeInMonths(widget.cattle.birthDate);
    final breed = widget.cattle.breed;
    final gender = widget.cattle.gender;

    // อัตราการเจริญเติบโตเฉลี่ยต่อวัน (กรณีมีข้อมูลมากกว่า 1 รายการ)
    double adg = 0;
    if (_weightRecords.length > 1) {
      final firstRecord = _weightRecords.last; // รายการแรกสุด (เก่าสุด)
      final latestRecord = _weightRecords.first; // รายการล่าสุด
      final daysBetween = latestRecord.date.difference(firstRecord.date).inDays;
      if (daysBetween > 0) {
        adg = (latestRecord.weight - firstRecord.weight) / daysBetween;
      }
    }

    // ค่าเฉลี่ยน้ำหนักตามสายพันธุ์และอายุ (สมมติค่า)
    double averageWeight = 0;
    if (breed == 'Brahman' || breed == 'บราห์มัน') {
      averageWeight = 180 + (ageMonths * 15); // สมมติค่า
    } else if (breed == 'Charolais' || breed == 'ชาร์โรเลส์') {
      averageWeight = 200 + (ageMonths * 18); // สมมติค่า
    } else if (breed == 'Angus' || breed == 'แองกัส') {
      averageWeight = 190 + (ageMonths * 17); // สมมติค่า
    } else {
      averageWeight = 170 + (ageMonths * 14); // ค่าเฉลี่ยทั่วไป
    }

    // ปรับตามเพศ
    if (gender == 'เพศผู้') {
      averageWeight *= 1.1; // ผู้หนักกว่าเมียประมาณ 10%
    }

    // เปอร์เซ็นต์เทียบกับค่าเฉลี่ย
    final weightPercentage = (latestWeight / averageWeight) * 100;

    showDialog(
      context: context as BuildContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'ข้อมูลการเติบโตของ ${widget.cattle.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              _buildComparisonItem(
                'น้ำหนักปัจจุบัน',
                '${latestWeight.toStringAsFixed(1)} กก.',
                Colors.blue,
              ),
              _buildComparisonItem(
                'ค่าเฉลี่ยตามสายพันธุ์และอายุ',
                '${averageWeight.toStringAsFixed(1)} กก.',
                Colors.green,
              ),
              _buildComparisonItem(
                'เปรียบเทียบกับค่าเฉลี่ย',
                '${weightPercentage.toStringAsFixed(1)}%',
                weightPercentage >= 95 ? Colors.green : Colors.orange,
              ),
              if (_weightRecords.length > 1)
                _buildComparisonItem(
                  'อัตราการเจริญเติบโตต่อวัน (ADG)',
                  '${adg.toStringAsFixed(3)} กก./วัน',
                  adg > 0.5 ? Colors.green : Colors.orange,
                ),
              _buildComparisonItem(
                'จำนวนข้อมูลน้ำหนักที่บันทึก',
                '${_weightRecords.length} รายการ',
                Colors.blue,
              ),
              SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: Text('ปิด'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // สร้าง Widget สำหรับแสดงรายการเปรียบเทียบ
  Widget _buildComparisonItem(String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 16)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  // เพิ่มเมธอด _calculateAge เพื่อแสดงอายุของโค
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

  // เพิ่มเมธอด _buildDetailRow สำหรับแสดงข้อมูลรายละเอียด
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // เพิ่มเมธอด _buildEmptyHistoryView สำหรับแสดงเมื่อไม่มีประวัติน้ำหนัก
  Widget _buildEmptyHistoryView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'ไม่มีประวัติการชั่งน้ำหนัก',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[700],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'ถ่ายภาพโคเพื่อประมาณน้ำหนักและบันทึกประวัติ',
            style: TextStyle(color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // เพิ่มเมธอด _buildWeightHistoryView สำหรับแสดงประวัติน้ำหนัก
  Widget _buildWeightHistoryView() {
    return Column(
      children: [
        // ปุ่มสำหรับแสดงกราฟและเปรียบเทียบ
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                onPressed: _showWeightChart,
                icon: Icon(Icons.timeline),
                label: Text('กราฟน้ำหนัก'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _showWeightComparison,
                icon: Icon(Icons.compare_arrows),
                label: Text('เปรียบเทียบ'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                ),
              ),
            ],
          ),
        ),
        // รายการประวัติน้ำหนัก
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _weightRecords.length,
            itemBuilder: (context, index) {
              final record = _weightRecords[index];
              final formattedDate = DateFormat('dd/MM/yyyy HH:mm').format(record.date);
              
              return Card(
                margin: EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: InkWell(
                  onTap: () {
                    _showWeightRecordDetails(record);
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ภาพตัวอย่าง
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.file(
                            File(record.imagePath),
                            width: 80,
                            height: 80,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 80,
                                height: 80,
                                color: Colors.grey[200],
                                child: Icon(
                                  Icons.broken_image,
                                  color: Colors.grey[400],
                                ),
                              );
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        // ข้อมูล
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    formattedDate,
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 14,
                                    ),
                                  ),
                                  WeightDisplay(
                                    weight: record.weight,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green[700],
                                  ),
                                ],
                              ),
                              SizedBox(height: 8),
                              if (record.notes != null && record.notes!.isNotEmpty)
                                Text(
                                  record.notes!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[700],
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                        // ปุ่มลบ
                        IconButton(
                          icon: Icon(Icons.delete, color: Colors.red),
                          onPressed: () => _confirmDeleteWeightRecord(record),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // เพิ่มเมธอด _showWeightRecordDetails เพื่อแสดงรายละเอียดประวัติน้ำหนัก
  void _showWeightRecordDetails(WeightRecord record) {
    showDialog(
      context: context as BuildContext,
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
                    color: Colors.grey[200],
                    child: Icon(
                      Icons.image_not_supported,
                      size: 64,
                      color: Colors.grey[400],
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        DateFormat('dd/MM/yyyy HH:mm').format(record.date),
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                      WeightDisplay(
                        weight: record.weight,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.green[700],
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    Text(
                      'บันทึกเพิ่มเติม:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      record.notes!,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => _confirmDeleteWeightRecord(record),
                        child: Text('ลบ', style: TextStyle(color: Colors.red)),
                      ),
                      SizedBox(width: 8),
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
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ประมาณน้ำหนักด้วยภาพถ่าย'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'ประมาณน้ำหนัก'),
              Tab(text: 'ประวัติการชั่งน้ำหนัก'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // แท็บประมาณน้ำหนัก
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Card(
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            // รูปภาพโค
                            CircleAvatar(
                              radius: 30,
                              backgroundImage:
                                  widget.cattle.imageUrl.startsWith('assets/')
                                      ? AssetImage(widget.cattle.imageUrl)
                                      : FileImage(File(widget.cattle.imageUrl))
                                          as ImageProvider,
                              onBackgroundImageError: (exception, stackTrace) {
                                print("เกิดข้อผิดพลาดในการโหลดรูปภาพโค: $exception");
                              },
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
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text('สายพันธุ์: ${widget.cattle.breed}'),
                                  Text('เพศ: ${widget.cattle.gender}'),
                                  Text(
                                    'อายุ: ${_calculateAge(widget.cattle.birthDate)}',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    _buildGuideCard(),
                    SizedBox(height: 20),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child:
                          _imageFile != null
                              ? _buildImagePreview()
                              : Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.camera_alt,
                                      size: 64,
                                      color: Colors.grey[400],
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'ไม่มีภาพ',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _takePicture,
                            icon: Icon(Icons.camera_alt),
                            label: Text('ถ่ายภาพ'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _selectPicture,
                            icon: Icon(Icons.photo_library),
                            label: Text('เลือกจากแกลเลอรี'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    if (_isProcessing)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('กำลังประมวลผลภาพ...'),
                          ],
                        ),
                      )
                    else if (_estimatedWeight != null)
                      _buildResultCard(),
                  ],
                ),
              ),
            ),

            // แท็บประวัติการชั่งน้ำหนัก
            _isLoadingHistory
                ? Center(child: CircularProgressIndicator())
                : _weightRecords.isEmpty
                ? _buildEmptyHistoryView()
                : _buildWeightHistoryView(),
          ],
        ),
      ),
    );
  }

  // วิดเจ็ตสำหรับแสดงภาพพร้อมการไฮไลท์การวัด
  Widget _buildImagePreview() {
    if (_imageFile == null) {
      // กรณีไม่มีภาพ
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.camera_alt,
              size: 64,
              color: Colors.grey[400],
            ),
            SizedBox(height: 16),
            Text(
              'ไม่มีภาพ',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      );
    }

    // กรณีมีภาพแต่กำลังประมวลผล
    if (_isProcessing) {
      return Stack(
        children: [
          // แสดงภาพพื้นหลัง
          Image.file(
            _imageFile!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
          // แสดงตัวโหลด
          Center(
            child: CircularProgressIndicator(),
          ),
        ],
      );
    }

    // กรณีมีผลการตรวจจับ
    if (_detectionResult != null && _detectionResult!.objects != null && _detectionResult!.objects!.isNotEmpty) {
      print("มีการตรวจพบวัตถุ ${_detectionResult!.objects!.length} ชิ้น");
      
      // คำนวณขนาดของ image container
      return LayoutBuilder(
        builder: (context, constraints) {
          // วัดขนาดรูปภาพจริง (จะใช้ในการคำนวณสัดส่วน)
          final Image image = Image.file(_imageFile!);
          final Completer<Size> completer = Completer<Size>();
          
          image.image.resolve(const ImageConfiguration()).addListener(
            ImageStreamListener((info, _) {
              completer.complete(Size(
                info.image.width.toDouble(),
                info.image.height.toDouble(),
              ));
            })
          );
          
          // สร้าง Stack ที่มีภาพและ CustomPaint ซ้อนกัน
          return Stack(
            fit: StackFit.expand,
            children: [
              // แสดงภาพต้นฉบับ
              Image.file(
                _imageFile!,
                fit: BoxFit.contain,
                width: double.infinity,
                height: double.infinity,
              ),
              
              // วาดกรอบและป้ายกำกับ
              FutureBuilder<Size>(
                future: completer.future,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return Container();
                  
                  final double imageRatio = snapshot.data!.width / snapshot.data!.height;
                  final double containerRatio = constraints.maxWidth / constraints.maxHeight;
                  
                  Size renderSize;
                  Offset renderOffset = Offset.zero;
                  
                  // คำนวณขนาดที่ใช้แสดงภาพจริง (เพื่อให้ CustomPaint ตรงกับภาพที่แสดง)
                  if (imageRatio > containerRatio) {
                    // กรณีภาพกว้างกว่า container
                    renderSize = Size(constraints.maxWidth, constraints.maxWidth / imageRatio);
                    renderOffset = Offset(0, (constraints.maxHeight - renderSize.height) / 2);
                  } else {
                    // กรณีภาพสูงกว่า container
                    renderSize = Size(constraints.maxHeight * imageRatio, constraints.maxHeight);
                    renderOffset = Offset((constraints.maxWidth - renderSize.width) / 2, 0);
                  }
                  
                  return Positioned(
                    left: renderOffset.dx,
                    top: renderOffset.dy,
                    width: renderSize.width,
                    height: renderSize.height,
                    child: CustomPaint(
                      size: renderSize,
                      painter: EnhancedMeasurementPainter(
                        _detectionResult!.objects!,
                        originalImageSize: snapshot.data!,
                        renderSize: renderSize,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      );
    } else {
      // กรณีมีภาพแต่ไม่พบวัตถุ - เพิ่มปุ่มเข้าสู่โหมดวัดด้วยตนเอง
      return Stack(
        children: [
          // แสดงภาพพื้นหลัง
          Image.file(
            _imageFile!,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
          // แสดงข้อความและปุ่ม
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        "ไม่พบวัตถุในภาพ",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: Icon(Icons.edit),
                        label: Text('กำหนดการวัดด้วยตนเอง'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          backgroundColor: Colors.amber,
                        ),
                        onPressed: () => _navigateToManualMeasurement(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }

  // วิดเจ็ตสำหรับแสดงคำแนะนำการถ่ายภาพ
  Widget _buildGuideCard() {
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue, size: 20),
                SizedBox(width: 8),
                Text(
                  'คำแนะนำการถ่ายภาพ:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 28.0, top: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGuideItem(
                    'ถ่ายภาพโคจากด้านข้าง โดยให้เห็นตัวโคเต็มตัว',
                  ),
                  _buildGuideItem('โคควรยืนตรงบนพื้นที่ราบ'),
                  _buildGuideItem('กล้องควรอยู่ในระดับกลางลำตัวโค'),
                  _buildGuideItem('หลีกเลี่ยงเงาและแสงจ้า'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // รายการคำแนะนำ
  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(text, style: TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  // วิดเจ็ตสำหรับแสดงผลลัพธ์การประมาณน้ำหนัก
  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green!),
      ),
      child: Column(
        children: [
          Text('น้ำหนักโดยประมาณ', style: TextStyle(fontSize: 18)),
          SizedBox(height: 8),
          WeightDisplay(
            weight: _estimatedWeight!,
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.green[700],
          ),
          SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.info_outline, color: Colors.grey[600], size: 16),
              SizedBox(width: 4),
              Text(
                'ความแม่นยำ: ${(_confidence! * 100).toStringAsFixed(0)}%',
                style: TextStyle(color: Colors.grey[600], fontSize: 14),
              ),
              SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  setState(() {
                    _showDetails = !_showDetails;
                  });
                },
                child: Text(
                  _showDetails ? 'ซ่อนรายละเอียด' : 'แสดงรายละเอียด',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          if (_showDetails)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  _buildDetailRow(
                    'รอบอก:',
                    '${_heartGirth?.toStringAsFixed(1)} ซม.',
                  ),
                  _buildDetailRow(
                    'ความยาวลำตัว:',
                    '${_bodyLength?.toStringAsFixed(1)} ซม.',
                  ),
                  _buildDetailRow(
                    'ความสูง:',
                    _height != null ? '${_height?.toStringAsFixed(1)} ซม.' : 'ไม่พบข้อมูล',
                  ),
                  _buildDetailRow('สายพันธุ์:', widget.cattle.breed),
                  _buildDetailRow(
                    'อายุ:',
                    _calculateAge(widget.cattle.birthDate),
                  ),
                  _buildDetailRow('สูตรคำนวณ:', 'Schaeffer (ปรับตามสายพันธุ์)'),
                  _buildDetailRow(
                    'วิธีการ:',
                    _objectsDetected
                        ? 'Machine Learning + สูตรคำนวณ'
                        : 'สูตรคำนวณ',
                  ),
                ],
              ),
            ),
          Divider(),
          Text(
            'ความแม่นยำอาจแตกต่างกันไปขึ้นอยู่กับคุณภาพของภาพและตำแหน่งของโค',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          SizedBox(height: 16),
          TextField(
            controller: _notesController,
            decoration: InputDecoration(
              labelText: 'บันทึกเพิ่มเติม (ถ้ามี)',
              border: OutlineInputBorder(),
              hintText: 'เช่น สภาพของโค, การให้อาหาร, ฯลฯ',
            ),
            maxLines: 3,
          ),
          SizedBox(height: 16),
          Container(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saveWeightRecord,
              icon: Icon(Icons.save),
              label: Text('บันทึกข้อมูลน้ำหนัก'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom Painter สำหรับวาดกราฟน้ำหนัก
class WeightChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double minValue;
  final double maxValue;

  WeightChartPainter({
    required this.data,
    required this.minValue,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final Paint linePaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    final Paint dotPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.fill;
      
    final Paint gridPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // วาดเส้นกริด
    for (int i = 0; i < 3; i++) {
      final y = size.height * i / 2;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        gridPaint,
      );
    }
    
    // คำนวณตำแหน่งของจุดข้อมูลแต่ละจุด
    List<Offset> points = [];
    
    for (int i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      final normalizedValue = (data[i]['weight'] - minValue) / (maxValue - minValue);
      final y = size.height - (normalizedValue * size.height);
      points.add(Offset(x, y));
    }
    
    // วาดเส้นเชื่อมจุด
    final Path path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    
    canvas.drawPath(path, linePaint);
    
    // วาดจุดข้อมูล
    for (var point in points) {
      canvas.drawCircle(point, 5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}