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
  double? _estimatedWeight = 0.0;
  double _bodyLengthCm = 0.0;
  double _heartGirthCm = 0.0;
  double _confidenceValue = 0.0;
  bool _hasResult = false;

  bool _resultWasAlreadySaved = false;

  final TextEditingController _notesController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final CattleMeasurementService _measurementService =
      CattleMeasurementService();
  List<WeightRecord> _weightRecords = [];
  bool _isLoadingHistory = true;
  bool _isManualMeasurement = false;  // เพื่อระบุว่าเป็นการวัดด้วยตนเองหรือไม่
  
  // ตัวแปรเพิ่มเติม
  File? _analyzedImageFile;
  detector.DetectionResult? _detectionResult; // แก้ไขชื่อตัวแปรที่ซ้ำกัน
  
  // ตัวแปรบริการ
  late CattleMeasurementService _cattleMeasurementService;

  bool _isSaving = false;  // สำหรับควบคุมสถานะการบันทึก


  // เพิ่มเมธอดหรือตัวแปรสำหรับแสดงวิธีการวัด
  String get measurementMethod => _isManualMeasurement ? "วัดด้วยตนเอง" : "วัดโดยอัตโนมัติ";

  // ฟังก์ชันสำหรับแสดงสีของวิธีการวัด
  Color getMeasurementMethodColor() {
    return _isManualMeasurement ? Colors.orange : Colors.green;
  }

  // ฟังก์ชันสำหรับแสดงไอคอนของวิธีการวัด
  IconData getMeasurementMethodIcon() {
    return _isManualMeasurement ? Icons.straighten : Icons.auto_awesome;
  }

  // ข้อมูลการวัดสัดส่วน
  double? _heartGirth;
  double? _bodyLength;
  double? _height;
  double? _confidence;
  bool _showDetails = false; // แสดงรายละเอียดการคำนวณ

  // แฟล็กเพื่อตรวจสอบว่ามีการตรวจพบวัตถุหรือไม่
  bool _objectsDetected = false;

  late BuildContext _buildContext;

  @override
  void initState() {
    super.initState();
    _initializeModel();
    // เตรียมบริการสำหรับการประมาณน้ำหนัก
    _cattleMeasurementService = CattleMeasurementService();
    _initializeMeasurementService();
    _loadWeightHistory();
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

  // ฟังก์ชัน _openManualMeasurement ที่ต้องแก้ไข
  Future<void> _openManualMeasurement() async {
    try {
      if (_imageFile == null) return;
      
      // เปิดหน้าวัดด้วยตนเอง
      final result = await Navigator.push(
        _buildContext,
        MaterialPageRoute(
          builder: (context) => ManualMeasurementScreen(
            imageFile: _imageFile!,
            cattle: widget.cattle,
            initialDetections: _detectionResult?.objects ?? [],
          ),
        ),
      );
      
      // จัดการกับผลลัพธ์ที่ได้จากการวัดด้วยตนเอง
      if (result != null && result is Map<String, dynamic>) {
        setState(() {
          if (result.containsKey('body_length_cm')) {
            _bodyLengthCm = result['body_length_cm'];
          }
          if (result.containsKey('heart_girth_cm')) {
            _heartGirthCm = result['heart_girth_cm'];
          }
          if (result.containsKey('estimated_weight')) {
            _estimatedWeight = result['estimated_weight'];
            _hasResult = true;
          }
          if (result.containsKey('confidence')) {
            _confidenceValue = result['confidence'];
          }
          if (result.containsKey('notes')) {
            _notesController.text = result['notes'];
          }
          
          // อัปเดตสถานะการวัดให้เป็นการวัดล่าสุด
          _isManualMeasurement = result['is_manual'] ?? true;
          
          // ตรวจสอบว่ามีการบันทึกข้อมูลจากหน้า manual_measurement_screen แล้วหรือยัง
          _resultWasAlreadySaved = result.containsKey('save_result') && result['save_result'] == true;
        });
        
        // ปรับภาพและแสดงผลลัพธ์
        if (result.containsKey('detection_result')) {
          _detectionResult = result['detection_result'];
          _analyzedImageFile = await _cattleMeasurementService.saveAnalyzedImage(
            _imageFile!,
            _detectionResult!,
          );
        }
        
        // แสดงผลลัพธ์ (ใช้ await เพื่อรอให้ dialog ปิดก่อนทำงานต่อ)
        if (_hasResult) {
          await _showResultDialog();
        }
        
        // ถ้ามีการระบุว่าต้องการบันทึกผลทันที และยังไม่ได้บันทึก
        if (result.containsKey('save_result') && result['save_result'] == true && !_resultWasAlreadySaved) {
          await _saveWeightRecord();
        }
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเปิดหน้าวัดด้วยตนเอง: $e');
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการวัด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // แสดงข้อความแจ้งเตือน
  void _showErrorMessage(String message) {
    if (!mounted) return;
    
    ScaffoldMessenger.of(_buildContext).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // เตรียมบริการวิเคราะห์ภาพ
  Future<void> _initializeMeasurementService() async {
    bool initialized = await _cattleMeasurementService.initialize();
    if (!initialized) {
      _showErrorMessage('ไม่สามารถโหลดโมเดลวิเคราะห์ภาพได้ ระบบจะใช้การวัดด้วยตนเอง');
    }
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

  // ปรับปรุงฟังก์ชัน _processImage ที่มีอยู่
  Future<void> _processImage() async {
    if (_imageFile == null) {
      _showErrorMessage('กรุณาเลือกรูปภาพก่อน');
      return;
    }

    setState(() {
      _isProcessing = true;
      _hasResult = false;
    });

    try {
      // สร้างข้อมูลโคจากข้อมูลที่มีอยู่
      final cow = widget.cattle;
      final ageMonths = WeightCalculator.calculateAgeInMonths(cow.birthDate);
      
      // ใช้บริการวิเคราะห์ภาพ
      final result = await _cattleMeasurementService.analyzeImage(
        _imageFile!,
        cow.breed,
        cow.gender,
        ageMonths,
      );
      
      // ส่งไปยังฟังก์ชันที่จัดการผลลัพธ์
      await _handleDetectionResult(result);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      _showErrorMessage('เกิดข้อผิดพลาดในการวิเคราะห์: $e');
    }
  }

  // ฟังก์ชัน _handleDetectionResult
  Future<void> _handleDetectionResult(MeasurementResult result) async {
    setState(() {
      _isProcessing = false;
    });
    
    if (result.success) {
      // การตรวจจับสำเร็จและได้น้ำหนักที่ประมาณ
      setState(() {
        _estimatedWeight = result.adjustedWeight ?? 0.0;
        _bodyLengthCm = result.bodyLength ?? 0.0;
        _heartGirthCm = result.heartGirth ?? 0.0;
        _confidence = result.confidence ?? 0.8;
        _hasResult = true;
      });
      
      // บันทึกภาพที่มีการวิเคราะห์แล้ว
      if (result.detectionResult != null) {
        _analyzedImageFile = await _cattleMeasurementService.saveAnalyzedImage(
          _imageFile!,
          result.detectionResult!,
        );
      }
      
      // แสดงผลลัพธ์
      await _showResultDialog(); // เพิ่ม await เพื่อรอให้ dialog ปิดก่อนทำงานต่อ
    } else {
      // กรณีที่ตรวจจับไม่สำเร็จ แต่อาจมีการตรวจพบบางส่วน
      bool hasYellowMark = false;
      bool hasHeartGirth = false;
      bool hasBodyLength = false;
      
      // ตรวจสอบว่าตรวจพบวัตถุส่วนไหนบ้าง
      if (result.detectionResult != null && result.detectionResult!.objects != null) {
        for (var obj in result.detectionResult!.objects!) {
          if (obj.classId == 0) { // Yellow Mark
            hasYellowMark = true;
          } else if (obj.classId == 1) { // Heart Girth
            hasHeartGirth = true;
          } else if (obj.classId == 2) { // Body Length
            hasBodyLength = true;
          }
        }
      }
      
      // แสดงข้อความแจ้งเตือนพร้อมระบุว่าตรวจพบส่วนไหนบ้าง
      bool? dialogResult = await showDialog<bool?>(
        context: _buildContext,
        barrierDismissible: false,  // ป้องกันการปิด dialog ด้วยการแตะพื้นหลัง
        builder: (context) => AlertDialog(
          title: Text('ต้องวัดด้วยตนเอง'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ไม่สามารถตรวจจับวัตถุได้ครบถ้วน กรุณาวัดด้วยตนเอง'),
              SizedBox(height: 12),
              Text('ผลการตรวจจับ:'),
              _buildDetectionStatusRow('จุดอ้างอิง (Yellow Mark)', hasYellowMark),
              _buildDetectionStatusRow('รอบอก (Heart Girth)', hasHeartGirth),
              _buildDetectionStatusRow('ความยาวลำตัว (Body Length)', hasBodyLength),
              SizedBox(height: 8),
              Text(
                'คุณจะต้องทำการวัดส่วนที่ขาดหายไปเพิ่มเติมในหน้าถัดไป',
                style: TextStyle(fontStyle: FontStyle.italic, fontSize: 13),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);  // ส่งค่า true กลับ
              },
              child: Text('ดำเนินการต่อ'),
            ),
          ],
        ),
      );
      
      // ตรวจสอบผลลัพธ์จาก dialog
      if (dialogResult == true) {
        // เก็บข้อมูลที่ตรวจพบบางส่วนเพื่อส่งไปยังหน้าวัดด้วยตนเอง
        _detectionResult = result.detectionResult;
        
        await _openManualMeasurement();
      }
    }
  }

  //Widget สำหรับแสดงสถานะการตรวจจับแต่ละส่วน
  Widget _buildDetectionStatusRow(String label, bool detected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.cancel,
            color: detected ? Colors.green : Colors.red,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            '$label: ${detected ? 'ตรวจพบ' : 'ไม่พบ'}',
            style: TextStyle(
              fontWeight: detected ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // แสดงผลลัพธ์การวัด
  Future<void> _showResultDialog() async {
    return showDialog<void>(
      context: _buildContext, 
      barrierDismissible: false, // ป้องกันการปิด dialog ด้วยการแตะพื้นหลัง
      builder: (context) => AlertDialog(
        title: Text(_isManualMeasurement ? 'ผลการวัดด้วยตนเอง' : 'ผลการประมาณน้ำหนักโค'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${_estimatedWeight!.toStringAsFixed(1)} กก.',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              Text('(${(_estimatedWeight! / 0.453592).toStringAsFixed(1)} ปอนด์)'),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายละเอียดการวัด:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    _buildMeasurementRow('รอบอก', '${_heartGirthCm.toStringAsFixed(1)} ซม.'),
                    _buildMeasurementRow('ความยาวลำตัว', '${_bodyLengthCm.toStringAsFixed(1)} ซม.'),
                    SizedBox(height: 8),
                    _buildMeasurementRow(
                      'การวัด',
                      _isManualMeasurement ? 'วัดด้วยตนเอง' : 'วัดโดยอัตโนมัติ',
                    ),
                    _buildMeasurementRow(
                      'ความเชื่อมั่น',
                      '${((_confidenceValue != 0 ? _confidenceValue : 0.9) * 100).toStringAsFixed(0)}%',
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              if (_notesController.text.isNotEmpty) 
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.yellow[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.yellow[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'บันทึกเพิ่มเติม:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text(_notesController.text),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
            },
            child: Text('ปิด'),
          ),
          // ถ้ายังไม่เคยบันทึก ให้แสดงปุ่ม "บันทึกผล" มิฉะนั้นแสดงปุ่ม "ตกลง"
          _resultWasAlreadySaved ? 
          TextButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
            },
            child: Text('ตกลง'),
          ) :
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // ปิด dialog
              _saveWeightRecord(); // บันทึกข้อมูล
            },
            child: Text('บันทึกผล'),
          ),
        ],
      ),
    );
  }

  // สร้างแถวแสดงค่าการวัด
  Widget _buildMeasurementRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  // บันทึกผลการประมาณน้ำหนัก
  void _saveResult() {
    // ตรงนี้จะเป็นโค้ดสำหรับบันทึกผลการประมาณน้ำหนักลงในฐานข้อมูลหรือแสดงหน้าถัดไป
    Navigator.pop(_buildContext, {
      'estimated_weight': _estimatedWeight,
      'body_length_cm': _bodyLengthCm,
      'heart_girth_cm': _heartGirthCm,
      'measured_date': DateTime.now(),
      'image_path': _analyzedImageFile?.path ?? _imageFile?.path,
    });
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

      ScaffoldMessenger.of(_buildContext).showSnackBar(
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
        ScaffoldMessenger.of(_buildContext).showSnackBar(
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
        ScaffoldMessenger.of(_buildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเลือกภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // บันทึกภาพที่มีการวิเคราะห์
  Future<void> _saveAnalyzedImage() async {
    if (_detectionResult != null && _imageFile != null) {
      _analyzedImageFile = await _measurementService.saveAnalyzedImage(
        _imageFile!,
        _detectionResult!
      );
    }
  }

  // ปรับปรุงฟังก์ชัน _analyzeImage เพื่อประมวลผลอัตโนมัติ
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
            // การตรวจจับสำเร็จและพบวัตถุทั้งหมด
            if (mounted) {
              setState(() {
                _isProcessing = false;
                _heartGirth = result.heartGirth;
                _bodyLength = result.bodyLength;
                _height = result.height;
                _estimatedWeight = result.adjustedWeight;
                _confidence = result.confidence;
                _detectionResult = result.detectionResult;
                _objectsDetected = true;
                _hasResult = true;
                
                // บันทึกภาพที่มีการวิเคราะห์
                _saveAnalyzedImage();
              });
            }
            
            // แสดงผลลัพธ์ทันที
            _showResultDialog();
            
            print('วิเคราะห์ภาพสำเร็จ: น้ำหนัก = ${result.adjustedWeight} กก.');
            return;
          } else {
            // ถ้าการวิเคราะห์ไม่สำเร็จ ให้ไปใช้การวัดด้วยตนเอง
            print('การวิเคราะห์ด้วย ML ไม่สำเร็จ: ${result.error}');
            
            if (mounted) {
              ScaffoldMessenger.of(_buildContext).showSnackBar(
                SnackBar(
                  content: Text('${result.error ?? "ไม่สามารถวิเคราะห์ภาพโดยอัตโนมัติได้"} กรุณาวัดด้วยตนเอง'),
                  duration: Duration(seconds: 3),
                  action: SnackBarAction(
                    label: 'วัดเอง',
                    onPressed: () {
                      _navigateToManualMeasurement();
                    },
                  ),
                ),
              );
              
              setState(() {
                _isProcessing = false;
                _objectsDetected = false;
              });
            }
            
            // ไปที่หน้าวัดด้วยตนเองอัตโนมัติถ้ามีการตรวจพบวัตถุบางส่วน
            if (result.detectionResult != null && result.detectionResult!.objects != null && 
                result.detectionResult!.objects!.isNotEmpty) {
              _detectionResult = result.detectionResult;
              _navigateToManualMeasurement();
            }
            return;
          }
        } else {
          print('ไม่สามารถใช้โมเดล ML ได้ จะใช้การวัดด้วยตนเอง');
          // แสดงปุ่มให้ผู้ใช้กดเพื่อวัดด้วยตนเอง
          setState(() {
            _isProcessing = false;
          });
        }
      } catch (e) {
        print('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e');
        
        if (mounted) {
          ScaffoldMessenger.of(_buildContext).showSnackBar(
            SnackBar(
              content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ กรุณาวัดด้วยตนเอง'),
              duration: Duration(seconds: 3),
              action: SnackBarAction(
                label: 'วัดเอง',
                onPressed: () {
                  _navigateToManualMeasurement();
                },
              ),
            ),
          );
          
          setState(() {
            _isProcessing = false;
            _objectsDetected = false;
          });
        }
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดทั่วไปในการวิเคราะห์ภาพ: $e');
      
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _objectsDetected = false;
        });
        
        ScaffoldMessenger.of(_buildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
        // แสดงปุ่มให้ผู้ใช้กดเพื่อวัดด้วยตนเอง
        _showManualMeasurementPrompt();
      }
    }
  }

  // แสดงปุ่มให้ผู้ใช้กดเพื่อวัดด้วยตนเอง
  void _showManualMeasurementPrompt() {
    if (mounted) {
      setState(() {
        _isProcessing = false;
      });
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

          ScaffoldMessenger.of(_buildContext).showSnackBar(
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

        ScaffoldMessenger.of(_buildContext).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // เพิ่มฟังก์ชันสำหรับลดขนาดรูปภาพ
  Future<File> _resizeImageIfNeeded(File imageFile) async {
    try {
      // อ่านข้อมูลภาพ
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // ตรวจสอบขนาดรูปภาพ
      if (image.width > 1200 || image.height > 1200) {
        // ลดขนาดรูปภาพให้มีด้านยาวไม่เกิน 1200 พิกเซล
        final resizedImage = img.copyResize(
          image,
          width: image.width > image.height ? 1200 : null,
          height: image.height >= image.width ? 1200 : null,
        );
        
        // บันทึกรูปภาพที่ลดขนาดแล้ว
        final tempDir = await getTemporaryDirectory();
        final tempFile = File('${tempDir.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg');
        
        await tempFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));
        
        print('ลดขนาดรูปภาพจาก ${image.width}x${image.height} เป็น ${resizedImage.width}x${resizedImage.height}');
        return tempFile;
      }
      
      return imageFile;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลดขนาดรูปภาพ: $e');
      return imageFile;
    }
  }

  // ฟังก์ชันสำหรับนำทางไปยังหน้าวัดด้วยตนเอง
  Future<void> _navigateToManualMeasurement() async {
    _openManualMeasurement();
  }

  Future<void> _saveWeightRecord() async {
    // ป้องกันการบันทึกซ้ำซ้อน
    if (_isSaving) return;
    
    try {
      // ตั้งค่าว่ากำลังบันทึก
      setState(() {
        _isSaving = true;
      });
      
      // สร้าง detector.DetectionResult จากข้อมูลที่วัดได้
      final detectionResult = detector.DetectionResult(
        success: true,
        objects: _detectionResult?.objects ?? [],
      );
      
      // เก็บภาพที่มีการไฮไลท์การวัด
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final analyzedImagePath = '${appDir.path}/$fileName';
      
      // คัดลอกภาพต้นฉบับไปที่พื้นที่แอป
      final copiedImage = await _imageFile!.copy(analyzedImagePath);
      
      // สร้างบันทึกน้ำหนักใหม่ด้วย WeightRecord object
      final weightRecord = WeightRecord(
        recordId: '', // จะถูกกำหนดโดย DatabaseHelper
        cattleId: widget.cattle.id,
        weight: _estimatedWeight!,
        imagePath: copiedImage.path,
        date: DateTime.now(),
        notes: _notesController.text.isEmpty 
            ? 'รอบอก: ${_heartGirthCm.toStringAsFixed(1)} ซม., ความยาว: ${_bodyLengthCm.toStringAsFixed(1)} ซม. (${_isManualMeasurement ? 'วัดด้วยตนเอง' : 'วัดโดยอัตโนมัติ'})'
            : _notesController.text,
      );
      
      // บันทึกลงฐานข้อมูล
      final recordId = await _dbHelper.insertWeightRecord(weightRecord);
      
      // อัปเดตสถานะว่าได้บันทึกแล้ว
      setState(() {
        _resultWasAlreadySaved = true;
      });
      
      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('บันทึกข้อมูลน้ำหนักเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
      
      // โหลดข้อมูลประวัติใหม่
      await _loadWeightHistory();

      // รีเซ็ตสถานะ
      setState(() {
        _imageFile = null;
        _estimatedWeight = null;
        _heartGirthCm = 0.0;
        _bodyLengthCm = 0.0;
        _confidenceValue = 0.0;
        _notesController.clear();
        _isProcessing = false;
        _showDetails = false;
        _detectionResult = null;
        _objectsDetected = false;
        _hasResult = false;
        _isManualMeasurement = false;
      });

      // แสดง dialog ก่อนกลับไปหน้าก่อนหน้า
      await showDialog(
        context: _buildContext,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text('บันทึกสำเร็จ'),
          content: Text('บันทึกข้อมูลน้ำหนักเรียบร้อยแล้ว'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // ปิด dialog
                // ส่งค่ากลับว่าบันทึกสำเร็จเพื่อให้หน้า detail รีเฟรชข้อมูล
                Navigator.pop(_buildContext, true);
              },
              child: Text('ตกลง'),
            ),
          ],
        ),
      );
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
      
      // รีเซ็ตสถานะว่ายังไม่ได้บันทึก
      setState(() {
        _resultWasAlreadySaved = false;
      });
    } finally {
      // รีเซ็ตสถานะการบันทึก
      setState(() {
        _isSaving = false;
      });
    }
  }

  

  // แสดง dialog ยืนยันการลบประวัติน้ำหนัก
  Future<void> _confirmDeleteWeightRecord(WeightRecord record) async {
    return showDialog(
      context: _buildContext,
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
        ScaffoldMessenger.of(_buildContext).showSnackBar(
          SnackBar(
            content: Text('ลบประวัติน้ำหนักเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการลบประวัติน้ำหนัก: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(_buildContext).showSnackBar(
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
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
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
      context: context as BuildContext,
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
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
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
      context: _buildContext,
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
            Icons.history,
            size: 80,
            color: Colors.grey[400],
          ),
          SizedBox(height: 16),
          Text(
            'ยังไม่มีประวัติการชั่งน้ำหนัก',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(height: 8),
          Text(
            'วัดน้ำหนักโคเพื่อบันทึกประวัติ',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  // ฟอร์แมตวันที่
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // เพิ่มเมธอด _buildWeightHistoryView สำหรับแสดงประวัติน้ำหนัก
  Widget _buildWeightHistoryView() {
    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: _weightRecords.length,
      itemBuilder: (context, index) {
        final record = _weightRecords[index];
        return Card(
          margin: EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green[100],
              child: Icon(Icons.scale, color: Colors.green[700]),
            ),
            title: Text(
              '${record.weight.toStringAsFixed(1)} กก.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('วันที่: ${_formatDate(record.date)}'),
                if (record.notes != null && record.notes!.isNotEmpty)
                  Text(
                    record.notes!.length > 30 
                      ? record.notes!.substring(0, 30) + '...' 
                      : record.notes!,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red),
              onPressed: () => _confirmDeleteRecordbyId(record.recordId),
            ),
            onTap: () => _showWeightRecordDetails(record),
          ),
        );
      },
    );
  }
  
  // แสดง dialog ยืนยันการลบประวัติน้ำหนักโดยใช้ ID
  Future<void> _confirmDeleteRecordbyId(String recordId) async {
    try {
      // ค้นหาบันทึกที่ต้องการลบตาม ID
      WeightRecord? recordToDelete;
      for (var record in _weightRecords) {
        if (record.recordId == recordId) {
          recordToDelete = record;
          break;
        }
      }
      
      if (recordToDelete != null) {
        return _confirmDeleteWeightRecord(recordToDelete);
      } else {
        // กรณีไม่พบบันทึกตาม ID
        ScaffoldMessenger.of(_buildContext).showSnackBar(
          SnackBar(
            content: Text('ไม่พบบันทึกที่ต้องการลบ'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเรียกใช้ _confirmDeleteRecordbyId: $e');
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // เพิ่มเมธอด _showWeightRecordDetails เพื่อแสดงรายละเอียดประวัติน้ำหนัก
  void _showWeightRecordDetails(WeightRecord record) {
    showDialog(
      context: _buildContext,
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
  
  // ฟังก์ชันเพิ่มเติมสำหรับแชร์ประวัติน้ำหนัก
  void _shareWeightRecord(WeightRecord record) {
    // สร้างข้อความสำหรับแชร์
    String shareText = 'บันทึกน้ำหนักโค ${widget.cattle.name}\n';
    shareText += 'วันที่: ${DateFormat('dd/MM/yyyy').format(record.date)}\n';
    shareText += 'น้ำหนัก: ${record.weight.toStringAsFixed(1)} กก. (${(record.weight / 0.453592).toStringAsFixed(1)} ปอนด์)\n';
    
    if (record.notes != null && record.notes!.isNotEmpty) {
      shareText += 'หมายเหตุ: ${record.notes}\n';
    }
    
    // แสดงข้อความแจ้งเตือนว่าฟังก์ชันนี้ยังไม่พร้อมใช้งาน
    ScaffoldMessenger.of(_buildContext).showSnackBar(
      SnackBar(
        content: Text('ฟังก์ชันการแชร์ยังไม่พร้อมใช้งาน กรุณาใช้ฟังก์ชันนี้ในเวอร์ชันถัดไป'),
        backgroundColor: Colors.orange,
      ),
    );
    
    // หมายเหตุ: คุณต้องเพิ่ม Package share_plus หรือคล้ายกันเพื่อใช้งานฟังก์ชันนี้
    // share.share(shareText, subject: 'บันทึกน้ำหนักโค');
  }

  // เพิ่มฟังก์ชัน export ข้อมูลประวัติน้ำหนัก
  Future<void> _exportWeightHistoryData() async {
    if (_weightRecords.isEmpty) {
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('ไม่มีข้อมูลสำหรับส่งออก'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    try {
      // สร้างข้อมูล CSV
      String csvData = 'วันที่,น้ำหนัก (กก.),น้ำหนัก (ปอนด์),หมายเหตุ\n';
      
      for (var record in _weightRecords) {
        String date = DateFormat('dd/MM/yyyy').format(record.date);
        double weightLbs = record.weight / 0.453592;
        String notes = record.notes ?? '';
        
        // ทำความสะอาดหมายเหตุเพื่อไม่ให้มีปัญหากับ CSV
        notes = notes.replaceAll(',', ' ').replaceAll('\n', ' ');
        
        csvData += '$date,${record.weight.toStringAsFixed(1)},${weightLbs.toStringAsFixed(1)},$notes\n';
      }
      
      // ดึงตำแหน่งสำหรับบันทึกไฟล์
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'weight_history_${widget.cattle.name}_${DateTime.now().millisecondsSinceEpoch}.csv';
      final filePath = '${directory.path}/$fileName';
      
      // บันทึกไฟล์
      final file = File(filePath);
      await file.writeAsString(csvData);
      
      // แจ้งเตือนผู้ใช้
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('ส่งออกข้อมูลสำเร็จ: $filePath'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'ตกลง',
            onPressed: () {},
          ),
        ),
      );
      
      // หมายเหตุ: คุณอาจต้องเพิ่มโค้ดเพื่อแชร์ไฟล์กับแอปอื่นๆ ตามความเหมาะสม
    } catch (e) {
      print('เกิดข้อผิดพลาดในการส่งออกข้อมูล: $e');
      
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการส่งออกข้อมูล: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // แสดงตัวเลือกการจัดการประวัติน้ำหนัก
  void _showWeightHistoryOptions() {
    showModalBottomSheet(
      context: _buildContext,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.bar_chart),
              title: Text('แสดงกราฟน้ำหนัก'),
              onTap: () {
                Navigator.pop(context);
                _showWeightChart();
              },
            ),
            ListTile(
              leading: Icon(Icons.analytics),
              title: Text('แสดงรายงานสรุป'),
              onTap: () {
                Navigator.pop(context);
                _showWeightSummaryReport();
              },
            ),
            ListTile(
              leading: Icon(Icons.compare_arrows),
              title: Text('เปรียบเทียบกับค่าเฉลี่ย'),
              onTap: () {
                Navigator.pop(context);
                _showWeightComparison();
              },
            ),
            ListTile(
              leading: Icon(Icons.file_download),
              title: Text('ส่งออกข้อมูล (CSV)'),
              onTap: () {
                Navigator.pop(context);
                _exportWeightHistoryData();
              },
            ),
          ],
        ),
      ),
    );
  }
  
  // แสดงรายงานสรุปน้ำหนักของโค
  void _showWeightSummaryReport() {
    if (_weightRecords.isEmpty) {
      ScaffoldMessenger.of(_buildContext).showSnackBar(
        SnackBar(
          content: Text('ไม่มีข้อมูลสำหรับสร้างรายงาน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    // เรียงลำดับข้อมูลตามวันที่
    _weightRecords.sort((a, b) => a.date.compareTo(b.date));
    
    // คำนวณค่าสถิติต่างๆ
    double initialWeight = _weightRecords.first.weight;
    double latestWeight = _weightRecords.last.weight;
    double weightChange = latestWeight - initialWeight;
    double weightChangePercent = (weightChange / initialWeight) * 100;
    
    // คำนวณอัตราการเจริญเติบโตเฉลี่ยต่อวัน (ADG)
    int daysBetween = _weightRecords.last.date.difference(_weightRecords.first.date).inDays;
    double adg = daysBetween > 0 ? weightChange / daysBetween : 0;
    
    // หาค่าเฉลี่ยของน้ำหนัก
    double totalWeight = 0;
    for (var record in _weightRecords) {
      totalWeight += record.weight;
    }
    double averageWeight = totalWeight / _weightRecords.length;
    
    // ช่วงวันที่มีการบันทึกข้อมูล
    String dateRange = '${DateFormat('dd/MM/yyyy').format(_weightRecords.first.date)} - ${DateFormat('dd/MM/yyyy').format(_weightRecords.last.date)}';
    
    // แสดงรายงานสรุป
    showDialog(
      context: _buildContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'รายงานสรุปน้ำหนักของ ${widget.cattle.name}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16),
              Text('ช่วงวันที่: $dateRange'),
              SizedBox(height: 8),
              _buildReportRow('น้ำหนักเริ่มต้น', '${initialWeight.toStringAsFixed(1)} กก.'),
              _buildReportRow('น้ำหนักล่าสุด', '${latestWeight.toStringAsFixed(1)} กก.'),
              _buildReportRow('น้ำหนักเปลี่ยนแปลง', '${weightChange.toStringAsFixed(1)} กก. (${weightChangePercent.toStringAsFixed(1)}%)'),
              _buildReportRow('น้ำหนักเฉลี่ย', '${averageWeight.toStringAsFixed(1)} กก.'),
              _buildReportRow('อัตราการเจริญเติบโตเฉลี่ย', '${adg.toStringAsFixed(3)} กก./วัน'),
              _buildReportRow('จำนวนบันทึก', '${_weightRecords.length} รายการ'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _showWeightChart();
                    },
                    child: Text('ดูกราฟ'),
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
      ),
    );
  }
  
  // สร้างแถวสำหรับรายงาน
  Widget _buildReportRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _buildContext = context;
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
           SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16.0,
                right: 16.0,
                top: 16.0,
                bottom: 80.0,// Extra padding to avoid navigation bar
              ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ข้อมูลโค
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
                    
                    // คำแนะนำการถ่ายภาพ
                    _buildGuideCard(),
                    SizedBox(height: 20),
                    
                    // พื้นที่แสดงรูปภาพ
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _hasResult && _analyzedImageFile != null
                          ? Image.file(
                              _analyzedImageFile!,
                              fit: BoxFit.contain,
                            )
                          : _imageFile != null
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
                    
                    // ปุ่มเลือกรูปภาพ
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
                    
                    SizedBox(height: 20),
                    
                    // ปุ่มวัดด้วยตนเอง - แสดงเมื่อมีรูปภาพแต่ยังไม่มีผลลัพธ์
                    if (_imageFile != null && !_hasResult) 
                      ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _navigateToManualMeasurement,
                        icon: Icon(Icons.straighten),
                        label: Text('วัดด้วยตนเอง'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          minimumSize: Size(double.infinity, 48),
                        ),
                      ),
                      
                    // ปุ่มบันทึกน้ำหนัก - แสดงเมื่อมีผลลัพธ์แล้ว
                    if (_hasResult && !_resultWasAlreadySaved)
                    Padding(
                      padding: EdgeInsets.only(bottom: 16.0),
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : _saveWeightRecord,
                        icon: Icon(Icons.save),
                        label: Text('บันทึกน้ำหนัก: ${_estimatedWeight!.toStringAsFixed(1)} กก.'),
                        style: ElevatedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          minimumSize: Size(double.infinity, 48),
                          backgroundColor: Colors.green,
                        ),
                      ),
                    ),
                        
                    SizedBox(height: 20),
                    
                    // แสดงสถานะการประมวลผลหรือผลลัพธ์
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
                    else if (_hasResult && _estimatedWeight! > 0)
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
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(
          _imageFile!,
          fit: BoxFit.contain,
        ),
        if (_hasResult && (_heartGirthCm > 0 || _bodyLengthCm > 0))
          Positioned(
            top: 10,
            right: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (_heartGirthCm > 0)
                    Text(
                      'รอบอก: ${_heartGirthCm.toStringAsFixed(1)} ซม.',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (_bodyLengthCm > 0)
                    Text(
                      'ความยาว: ${_bodyLengthCm.toStringAsFixed(1)} ซม.',
                      style: TextStyle(
                        color: Colors.blue,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // วิดเจ็ตสำหรับแสดงคำแนะนำการถ่ายภาพ
  Widget _buildGuideCard() {
    return Card(
      color: Colors.blue[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'คำแนะนำการถ่ายภาพ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            _buildGuideItem('ถ่ายภาพจากด้านข้างของโคโดยให้เห็นทั้งตัว'),
            _buildGuideItem('ถ่ายที่ระยะห่างประมาณ 2-3 เมตร'),
            _buildGuideItem('วางวัตถุอ้างอิงขนาด 100 ซม. ไว้ใกล้ตัวโค'),
            _buildGuideItem('ถ่ายในที่มีแสงสว่างเพียงพอ'),
          ],
        ),
      ),
    );
  }

  // รายการคำแนะนำ
  Widget _buildGuideItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check, size: 18, color: Colors.blue[400]),
          SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  // วิดเจ็ตสำหรับแสดงผลลัพธ์การประมาณน้ำหนักและเพื่อแสดงว่าเป็นการวัดแบบใด
  Widget _buildResultCard() {
    return Card(
      color: Colors.green[50],
      elevation: 3,
      margin: EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text(
                  'ผลการประมาณน้ำหนัก',
                  style: TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.green[700],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Center(
              child: Column(
                children: [
                  Text(
                    '${_estimatedWeight!.toStringAsFixed(1)} กก.',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  Text(
                    '(${(_estimatedWeight! / 0.453592).toStringAsFixed(1)} ปอนด์)',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildMeasurementRow('รอบอก', '${_heartGirthCm.toStringAsFixed(1)} ซม.'),
            _buildMeasurementRow('ความยาวลำตัว', '${_bodyLengthCm.toStringAsFixed(1)} ซม.'),
            
            // เพิ่มส่วนแสดงวิธีการวัด
            Container(
              margin: EdgeInsets.symmetric(vertical: 8),
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: getMeasurementMethodColor().withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: getMeasurementMethodColor().withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  Icon(
                    getMeasurementMethodIcon(),
                    size: 20,
                    color: getMeasurementMethodColor(),
                  ),
                  SizedBox(width: 8),
                  Text(
                    measurementMethod,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: getMeasurementMethodColor(),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.grey[600],
                ),
                SizedBox(width: 4),
                Text(
                  'ความเชื่อมั่น: ${((_confidenceValue != 0 ? _confidenceValue : 0.9) * 100).toStringAsFixed(0)}%',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _saveWeightRecord,
              child: Text('บันทึกน้ำหนัก'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.green,
              ),
            ),
          ],
        ),
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