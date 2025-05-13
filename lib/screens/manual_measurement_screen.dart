import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:math' as math;
import 'dart:async';
import 'dart:ui' as ui;
import '../models/cattle.dart';
import '../models/weight_record.dart';
import '../utils/cattle_detector.dart' as detector;
import '../utils/weight_calculator.dart';
import '../utils/manual_measurement_painter.dart';
import '../database/database_helper.dart';
import 'package:path_provider/path_provider.dart';

class ManualMeasurementScreen extends StatefulWidget {
  final File imageFile;
  final Cattle cattle;
  final List<detector.DetectedObject> initialDetections;

  const ManualMeasurementScreen({
    Key? key,
    required this.imageFile,
    required this.cattle,
    this.initialDetections = const [],
  }) : super(key: key);

  @override
  _ManualMeasurementScreenState createState() => _ManualMeasurementScreenState();
}

class _ManualMeasurementScreenState extends State<ManualMeasurementScreen> {

  // เพิ่มตัวแปรเก็บสถานะการแสดงกรอบ
  bool _showOriginalBoxes = true;

  // ตัวแปรสำหรับภาพ
  ui.Image? _image;
  bool _imageLoaded = false;
  Size _imageSize = Size(0, 0);

  // เพิ่มตัวแปรเพื่อจัดการการซูม
  double _zoomScale = 1.0;  // ค่าเริ่มต้นไม่มีการซูม
  double _minZoom = 0.5;    // ซูมออกได้สูงสุด 50%
  double _maxZoom = 2.0;    // ซูมเข้าได้สูงสุด 200%
  
  // ข้อมูลพื้นที่แสดงผล
  Size _viewportSize = Size.zero;
  double _imageScale = 1.0;
  Offset _imagePosition = Offset.zero;
  
  // ข้อมูลการวัด
  List<detector.DetectedObject> _detectedObjects = [];
  int _selectedIndex = -1;
  bool _isDragging = false;
  bool _isDraggingStartPoint = false;
  
  // จุดสำหรับการวัด
  Offset? _dragStartPosition;
  int _currentEditingObject = -1; // 0=yellow mark, 1=heart girth, 2=body length
  
  // การตรวจจับหมุด (ปรับปรุงใหม่)
  double _hitTestTolerance = 45.0; // พื้นที่ที่ผู้ใช้สามารถกดเพื่อเลือกหมุด
  double _anchorPointRadius = 10.0; // ขนาดของหมุดที่แสดง
  
  // ผลลัพธ์การคำนวณ
  double _bodyLengthCm = 0.0;
  double _heartGirthCm = 0.0;
  double _estimatedWeight = 0.0;
  double _scaleRatio = 0.0; // อัตราส่วนจากพิกเซลเป็นเซนติเมตร
  
  // สถานะการวัด
  bool _hasYellowMark = false;
  bool _hasHeartGirth = false;
  bool _hasBodyLength = false;

  // เพิ่มตัวแปรสำหรับแอนิเมชัน
  double _pinScale = 1.0;
  int? _animatingPinIndex;
  DateTime? _lastPinAnimTime;
  
  // ข้อความแสดงช่วยเหลือ
  String _helpText = 'แตะที่หมุดและลากเพื่อปรับตำแหน่ง';
  bool _showHelp = true;
  
  // เพิ่มการรองรับการกดค้างที่หมุด
  bool _longPressActivated = false;
  
  // ตัวแปรสำหรับติดต่อกับฐานข้อมูล
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // ตัวแปรสำหรับควบคุมการบันทึก
  bool _isSaving = false;

  // เพิ่มตัวแปรเพื่อเก็บค่าที่จะส่งกลับ
  DateTime _measuredDate = DateTime.now(); // วันที่วัด
  bool _isManualMeasurement = true; // การวัดด้วยตนเอง
  bool _shouldSaveResult = true; // ควรบันทึกผลหรือไม่

  @override
  void initState() {
    super.initState();
    
    // บังคับให้หน้าจออยู่ในแนวนอนเฉพาะหน้านี้
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    
    // ซ่อน status bar เพื่อให้มีพื้นที่การแสดงผลเต็มที่
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // โหลดรูปภาพ
    _loadImage().then((_) {
      if (mounted) {
        _initializeDetections();
      }
    });
    
    // ซ่อนข้อความช่วยเหลือหลังจาก 5 วินาที
    Future.delayed(Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _showHelp = false;
        });
      }
    });

    // เพิ่มการตรวจสอบข้อมูล
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _logDetectedObjects();
    });
  }

  void _logDetectedObjects() {
    print("จำนวนวัตถุที่ตรวจพบ: ${_detectedObjects.length}");
    for (int i = 0; i < _detectedObjects.length; i++) {
      final obj = _detectedObjects[i];
      print("วัตถุที่ ${i+1}: ${_getLabelByClassId(obj.classId)}");
      print("  พิกัด: (${obj.x1.toInt()}, ${obj.y1.toInt()}) - (${obj.x2.toInt()}, ${obj.y2.toInt()})");
      print("  ความเชื่อมั่น: ${obj.confidence}");
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // อัปเดตขนาดหน้าจอเมื่อมีการเปลี่ยนแปลง
    _updateViewportSize();
  }
  
  void _updateViewportSize() {
    final mediaQuery = MediaQuery.of(context);
    final appBarHeight = AppBar().preferredSize.height;
    
    setState(() {
      _viewportSize = Size(
        mediaQuery.size.width,
        mediaQuery.size.height - mediaQuery.padding.top - appBarHeight,
      );
    });
  }
  
  @override
  void dispose() {

    // คืนค่าการวางแนวหน้าจอกลับเป็นค่าเริ่มต้น
    Future.delayed(Duration.zero, () {
      SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    });

    super.dispose();
  }

  // อัปเดตข้อมูลวิวพอร์ตตามการซูม
  void _updateViewport() {
    final mediaQuery = MediaQuery.of(context);
    final baseWidth = mediaQuery.size.width;
    final baseHeight = mediaQuery.size.height;
    
    setState(() {
      _viewportSize = Size(
        baseWidth * _zoomScale,
        baseHeight * _zoomScale,
      );
    });
  }

  // ฟังก์ชันสำหรับซูมเข้า
  void _zoomIn() {
    setState(() {
      _zoomScale = math.min(_zoomScale + 0.1, _maxZoom);
      _updateViewport();
    });
  }

  // ฟังก์ชันสำหรับซูมออก
  void _zoomOut() {
    setState(() {
      _zoomScale = math.max(_zoomScale - 0.1, _minZoom);
      _updateViewport();
    });
  }

  // ฟังก์ชันสำหรับคืนค่าการซูมเป็นค่าเริ่มต้น
  void _resetZoom() {
    setState(() {
      _zoomScale = 1.0;
      _updateViewport();
    });
  }

  // เมธอดสำหรับแสดงเอฟเฟกต์หมุด
  void _animatePin(int pinIndex) {
    _animatingPinIndex = pinIndex;
    _lastPinAnimTime = DateTime.now();
    
    setState(() {
      _pinScale = 1.2; // เริ่มแอนิเมชันด้วยการขยายหมุด
    });
    
    Future.delayed(Duration(milliseconds: 100), () {
      if (mounted) {
        setState(() {
          _pinScale = 1.1;
        });
      }
    });
    
    Future.delayed(Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _pinScale = 1.0; // คืนกลับเป็นขนาดปกติ
        });
      }
    });
    
    Future.delayed(Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _animatingPinIndex = null;
        });
      }
    });
    
    // สั่นเบาๆ เพื่อให้รู้สึกได้ว่าเลือกหมุดสำเร็จ
    HapticFeedback.lightImpact();
  }

  // โหลดรูปภาพ
  Future<void> _loadImage() async {
    try {
      final data = await widget.imageFile.readAsBytes();
      final codec = await ui.instantiateImageCodec(data);
      final frame = await codec.getNextFrame();
      
      if (mounted) {
        setState(() {
          _image = frame.image;
          _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
          _imageLoaded = true;
        });
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดรูปภาพ: $e');
    }
  }

  // จัดวางเส้นให้อยู่กลางภาพ
  void _centerOnlyMissingLines() {
    // คำนวณตำแหน่งกลางของภาพ
    final double centerX = _imageSize.width / 2;
    final double centerY = _imageSize.height / 2;
    
    // ความยาวของเส้นแต่ละประเภท
    final double referenceLength = _imageSize.width * 0.5; // ความยาวเส้นอ้างอิง
    final double heartGirthHeight = _imageSize.height * 0.35; // ความสูงของเส้นรอบอก
    final double bodyLength = _imageSize.width * 0.6; // ความยาวของเส้นความยาวลำตัว
    
    // อัปเดตเฉพาะเส้นที่เพิ่งสร้างใหม่ (เส้นที่มีค่า x1,y1,x2,y2 เป็น 0)
    for (int i = 0; i < _detectedObjects.length; i++) {
      final obj = _detectedObjects[i];
      
      // ตรวจสอบว่าเป็นเส้นที่เพิ่งสร้างใหม่หรือไม่
      bool isNewLine = (obj.x1 == 0 && obj.y1 == 0 && obj.x2 == 0 && obj.y2 == 0);
      
      if (isNewLine) {
        if (obj.classId == 0) { // จุดอ้างอิง - แนวนอน
          _detectedObjects[i] = detector.DetectedObject(
            classId: 0,
            className: 'จุดอ้างอิง',
            confidence: 1.0,
            x1: centerX - referenceLength / 2,
            y1: centerY - heartGirthHeight / 2, // อยู่เหนือจุดกึ่งกลาง
            x2: centerX + referenceLength / 2,
            y2: centerY - heartGirthHeight / 2,
          );
        }
        else if (obj.classId == 1) { // รอบอก - แนวตั้ง
          _detectedObjects[i] = detector.DetectedObject(
            classId: 1,
            className: 'รอบอก',
            confidence: 1.0,
            x1: centerX + bodyLength / 4, // ออฟเซ็ตไปทางขวาเล็กน้อย
            y1: centerY - heartGirthHeight / 2,
            x2: centerX + bodyLength / 4,
            y2: centerY + heartGirthHeight / 2,
          );
        }
        else if (obj.classId == 2) { // ความยาวลำตัว - แนวนอน
          _detectedObjects[i] = detector.DetectedObject(
            classId: 2,
            className: 'ความยาวลำตัว',
            confidence: 1.0,
            x1: centerX - bodyLength / 2,
            y1: centerY,
            x2: centerX + bodyLength / 2,
            y2: centerY,
          );
        }
      }
    }
    // คำนวณการวัดใหม่
    _calculateMeasurements();
  }

  // ฟังก์ชันเตรียมเส้นมาตรฐาน
  void _setupMissingLines() {
  if (!_imageLoaded || _image == null) return;
  
  // ตรวจสอบข้อมูลการวัดที่ขาดหายไป
  bool needCenterLines = false;
  
  // เส้นวัดจุดอ้างอิง (Yellow Mark)
  if (!_hasYellowMark) {
    _detectedObjects.add(detector.DetectedObject(
      classId: 0,
      className: 'จุดอ้างอิง',
      confidence: 1.0,
      x1: 0, y1: 0, x2: 0, y2: 0, // ค่าเริ่มต้น
    ));
    
    _hasYellowMark = true;
    needCenterLines = true;
  }

  // เส้นวัดรอบอก (Heart Girth)
  if (!_hasHeartGirth) {
    _detectedObjects.add(detector.DetectedObject(
      classId: 1,
      className: 'รอบอก',
      confidence: 1.0,
      x1: 0, y1: 0, x2: 0, y2: 0, // ค่าเริ่มต้น
    ));
    
    _hasHeartGirth = true;
    needCenterLines = true;
  }

  // เส้นวัดความยาวลำตัว (Body Length)
  if (!_hasBodyLength) {
    _detectedObjects.add(detector.DetectedObject(
      classId: 2,
      className: 'ความยาวลำตัว',
      confidence: 1.0,
      x1: 0, y1: 0, x2: 0, y2: 0, // ค่าเริ่มต้น
    ));
    
    _hasBodyLength = true;
    needCenterLines = true;
  }

  // จัดวางเส้นให้อยู่ตรงกลางเฉพาะเส้นที่สร้างใหม่
  if (needCenterLines) {
    _centerOnlyMissingLines();
  }
}

  void _initializeDetections() {
    // รับข้อมูลจาก initialDetections (จากการตรวจจับใน cattle_estimate_screen.dart)
    if (widget.initialDetections.isNotEmpty) {
      setState(() {
        _detectedObjects = List.from(widget.initialDetections);

        // ตรวจสอบแต่ละประเภทว่ามีการตรวจพบหรือไม่
      for (var obj in _detectedObjects) {
        if (obj.classId == 0) { // Yellow Mark
          _hasYellowMark = true;
        } else if (obj.classId == 1) { // Heart Girth
          _hasHeartGirth = true;
        } else if (obj.classId == 2) { // Body Length
          _hasBodyLength = true;
        }
      }

      // คำนวณการวัดจากข้อมูลที่มี
      _calculateMeasurements();

      });
    }
    
    // สร้างเส้นที่ยังไม่มี
    _setupMissingLines();
  }

  // คำนวณการวัดและน้ำหนัก - แก้ไขเพื่อใช้ WeightCalculator อย่างเหมาะสม
  void _calculateMeasurements() {
    // รีเซ็ตค่า
    _hasYellowMark = false;
    _hasHeartGirth = false;
    _hasBodyLength = false;
    
    // ค้นหาออบเจ็กต์ตามประเภท
    detector.DetectedObject? yellowMarkObj;
    detector.DetectedObject? heartGirthObj;
    detector.DetectedObject? bodyLengthObj;

    // เพิ่มการตรวจสอบเพื่อหา Yellow Mark ก่อน
    List<detector.DetectedObject> potentialYellowMarks = [];

    for (var obj in _detectedObjects) {
        if (obj.classId == 0) { // Yellow Mark
            potentialYellowMarks.add(obj);
            _hasYellowMark = true;
        }
    }

    // เลือก Yellow Mark ที่มีความเชื่อมั่นสูงสุด
    if (potentialYellowMarks.isNotEmpty) {
        potentialYellowMarks.sort((a, b) => b.confidence.compareTo(a.confidence));
        yellowMarkObj = potentialYellowMarks.first;
        print('เลือก Yellow Mark ที่มีความเชื่อมั่นสูงสุด: ${yellowMarkObj.confidence}');
    }
    
    for (var obj in _detectedObjects) {
      if (obj.classId == 1) { // Heart Girth
        heartGirthObj = obj;
        _hasHeartGirth = true;
      }
      if (obj.classId == 2) { // Body Length
        bodyLengthObj = obj;
        _hasBodyLength = true;
      }
    }
    
    // ถ้าไม่มีจุดอ้างอิง ไม่สามารถคำนวณต่อได้
    if (!_hasYellowMark) {
      setState(() {
        _scaleRatio = 0.0;
        _bodyLengthCm = 0.0;
        _heartGirthCm = 0.0;
        _estimatedWeight = 0.0;
        
      });

      // แสดงข้อความแจ้งเตือน
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('ไม่พบจุดอ้างอิง (Yellow Mark) กรุณาตรวจสอบการวางตำแหน่งจุดอ้างอิงในภาพ'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
          ),
      );

      return;
    }
    
    // คำนวณความกว้างของจุดอ้างอิง
    final yellowMarkLength = math.sqrt(
        math.pow(yellowMarkObj!.x2 - yellowMarkObj.x1, 2) + 
        math.pow(yellowMarkObj.y2 - yellowMarkObj.y1, 2)
      ).abs();
    
    // คำนวณอัตราส่วนพิกเซลต่อเซนติเมตร
    _scaleRatio = yellowMarkLength / 100; // จุดอ้างอิง 100 ซม.

    print('การวัด: จุดอ้างอิง = $yellowMarkLength พิกเซล, อัตราส่วน = $_scaleRatio พิกเซล/ซม.');
    
    // คำนวณขนาดจริง
    if (_hasHeartGirth && _hasBodyLength) {
      // คำนวณความยาวของเส้นในพิกเซล
      final bodyLengthWidth = math.sqrt(
        math.pow(bodyLengthObj!.x2 - bodyLengthObj.x1, 2) + 
        math.pow(bodyLengthObj.y2 - bodyLengthObj.y1, 2)
      );
      
      final heartGirthHeight = (heartGirthObj!.y2 - heartGirthObj.y1).abs();
      
      // คำนวณขนาดจริงในหน่วยเซนติเมตร
      _bodyLengthCm = bodyLengthWidth / _scaleRatio;
      _heartGirthCm = heartGirthHeight / _scaleRatio;

      double heartGirthCircumference = math.pi * _heartGirthCm;
      
      // แปลงหน่วยจากเซนติเมตรเป็นนิ้ว
      double bodyLengthInches = WeightCalculator.cmToInches(_bodyLengthCm);
      double heartGirthInches = WeightCalculator.cmToInches(heartGirthCircumference);
      
      // คำนวณน้ำหนักจาก WeightCalculator
      double weightInKg = WeightCalculator.calculateWeight(heartGirthInches, bodyLengthInches);
      
      // ปรับค่าตามอายุและเพศโดยใช้ WeightCalculator
      final ageMonths = WeightCalculator.calculateAgeInMonths(widget.cattle.birthDate);
      _estimatedWeight = WeightCalculator.adjustWeightByAgeAndGender(
        weightInKg,
        widget.cattle.gender,
        ageMonths,
      );
    } else {
      // ยังวัดไม่ครบ
      if (_hasBodyLength) {
        final bodyLengthWidth = math.sqrt(
          math.pow(bodyLengthObj!.x2 - bodyLengthObj.x1, 2) + 
          math.pow(bodyLengthObj.y2 - bodyLengthObj.y1, 2)
        );
        _bodyLengthCm = bodyLengthWidth / _scaleRatio;
      } else {
        _bodyLengthCm = 0.0;
      }
      
      if (_hasHeartGirth) {
        final heartGirthHeight = math.sqrt(
          math.pow(heartGirthObj!.x2 - heartGirthObj.x1, 2) + 
          math.pow(heartGirthObj.y2 - heartGirthObj.y1, 2)
        );
        _heartGirthCm = heartGirthHeight / _scaleRatio;
      } else {
        _heartGirthCm = 0.0;
      }
      
      _estimatedWeight = 0.0;
    }
    
    // อัพเดท UI
    setState(() {});
  }

  // คำนวณตำแหน่งจริงของภาพ
  Rect _getImageRect() {
    if (!_imageLoaded || _image == null) {
      return Rect.zero;
    }
    
    final double screenWidth = _viewportSize.width;
    final double screenHeight = _viewportSize.height;
    
    // คำนวณอัตราส่วนสำหรับการ fit
    final double screenRatio = screenWidth / screenHeight;
    final double imageRatio = _imageSize.width / _imageSize.height;
    
    double width, height;
    double x, y;
    
    if (imageRatio > screenRatio) {
      // ถ้าภาพกว้างกว่า ให้ fit ตามความกว้าง
      width = screenWidth;
      height = screenWidth / imageRatio;
      x = 0;
      y = (screenHeight - height) / 2;
    } else {
      // ถ้าภาพสูงกว่า ให้ fit ตามความสูง
      height = screenHeight;
      width = screenHeight * imageRatio;
      y = 0;
      x = (screenWidth - width) / 2;
    }
    
    return Rect.fromLTWH(x, y, width, height);
  }

  // แปลงพิกัดจากหน้าจอเป็นพิกัดของรูปภาพ
  Offset _screenToImageCoordinates(Offset screenPoint) {
    if (!_imageLoaded || _image == null) {
      return screenPoint;
    }
    
    final Rect imageRect = _getImageRect();
    
    // ตรวจสอบว่าจุดอยู่นอกขอบเขตของภาพหรือไม่
    if (!imageRect.contains(screenPoint)) {
      // ปรับให้อยู่ในขอบเขตของภาพ
      final double x = screenPoint.dx.clamp(imageRect.left, imageRect.right);
      final double y = screenPoint.dy.clamp(imageRect.top, imageRect.bottom);
      screenPoint = Offset(x, y);
    }
    
    // แปลงพิกัดจากหน้าจอเป็นพิกัดในภาพ
    final double imageX = (screenPoint.dx - imageRect.left) * _imageSize.width / imageRect.width;
    final double imageY = (screenPoint.dy - imageRect.top) * _imageSize.height / imageRect.height;
    
    return Offset(imageX, imageY);
  }

  // แปลงพิกัดจากรูปภาพเป็นพิกัดบนหน้าจอ
  Offset _imageToScreenCoordinates(Offset imagePoint) {
    if (!_imageLoaded || _image == null) {
      return imagePoint;
    }
    
    final Rect imageRect = _getImageRect();
    
    // แปลงพิกัดจากภาพเป็นพิกัดบนหน้าจอ
    final double screenX = imageRect.left + (imagePoint.dx / _imageSize.width) * imageRect.width;
    final double screenY = imageRect.top + (imagePoint.dy / _imageSize.height) * imageRect.height;
    
    return Offset(screenX, screenY);
  }

  // ตรวจสอบว่าแตะที่จุดหรือไม่
  bool _isPointNearby(Offset screenPoint, Offset imagePoint, double radius) {
    final Offset pointOnScreen = _imageToScreenCoordinates(imagePoint);
    return (pointOnScreen - screenPoint).distance <= radius;
  }

  // จัดการเมื่อแตะที่หน้าจอ (เอาไว้จับการเลือกหมุด)
  void _onPanStart(DragStartDetails details) {
    // ตรวจจับการแตะที่หมุด
    final Offset touchPosition = details.localPosition;
    
    // ตรวจสอบทุกวัตถุ
    for (int i = 0; i < _detectedObjects.length; i++) {
      final obj = _detectedObjects[i];
      
      // ตรวจสอบว่าแตะที่จุดเริ่มต้นหรือไม่
      if (_isPointNearby(touchPosition, Offset(obj.x1, obj.y1), _hitTestTolerance)) {
        setState(() {
          _selectedIndex = i;
          _isDragging = true;
          _isDraggingStartPoint = true;
          _dragStartPosition = touchPosition;
          _currentEditingObject = obj.classId;
          _helpText = 'กำลังปรับจุด${_getLabelByClassId(obj.classId)}';
          _showHelp = true;
          // เพิ่มเอฟเฟกต์การคลิก
          _animatePin(i);
        });
        return;
      }
      
      // ตรวจสอบว่าแตะที่จุดสิ้นสุดหรือไม่
      if (_isPointNearby(touchPosition, Offset(obj.x2, obj.y2), _hitTestTolerance)) {
        setState(() {
          _selectedIndex = i;
          _isDragging = true;
          _isDraggingStartPoint = false;
          _dragStartPosition = touchPosition;
          _currentEditingObject = obj.classId;
          _helpText = 'กำลังปรับจุด${_getLabelByClassId(obj.classId)}';
          _showHelp = true;
          
          // เพิ่มเอฟเฟกต์การคลิก
          _animatePin(i);

        });
        return;
      }
    }
    
    // ถ้าไม่ได้แตะที่หมุดใดๆ และกำลังอยู่ในโหมดการแก้ไข ให้เริ่มวาดเส้นใหม่
    if (_isDragging && _selectedIndex != -1) {
      setState(() {
        _isDragging = false;
        _selectedIndex = -1;
        _currentEditingObject = -1;
        _helpText = 'แตะที่หมุดและลากเพื่อปรับตำแหน่ง';
        _showHelp = true;
      });
      return;
    }
    
    // ถ้ากดที่พื้นที่ว่าง อาจเป็นการเริ่มวาดเส้นใหม่ (optional - เฉพาะกรณีที่ต้องการให้ผู้ใช้วาดเส้นเอง)
    // setState(() {
    //   _isDragging = true;
    //   _dragStartPosition = touchPosition;
    //   _currentEditingObject = _getCurrentDrawingMode(); // เมธอดหากำหนดโหมดการวาด
    //   _helpText = 'กำลังวาด${_getLabelByClassId(_currentEditingObject)}';
    //   _showHelp = true;
    // });
  }

  // จัดการเมื่อลากนิ้ว
  void _onPanUpdate(DragUpdateDetails details) {
    if (!_isDragging || _selectedIndex == -1 || _dragStartPosition == null || _longPressActivated) return;

    // คำนวณระยะทางที่เลื่อน
    if (_dragStartPosition != null) {
      final Offset delta = details.localPosition - _dragStartPosition!;
      _dragStartPosition = details.localPosition;
      
      setState(() {
        // ดึงข้อมูลวัตถุที่กำลังแก้ไข
        final obj = _detectedObjects[_selectedIndex];
        
        // แปลงพิกัดของตำแหน่งใหม่
        final Offset touchPosition = details.localPosition;
        final Offset newPointInImage = _screenToImageCoordinates(touchPosition);
        
        // อัปเดตพิกัดตามจุดที่กำลังลาก
        if (_isDraggingStartPoint) {
          // ลากจุดเริ่มต้น
          _detectedObjects[_selectedIndex] = detector.DetectedObject(
            classId: obj.classId,
            className: obj.className,
            confidence: obj.confidence,
            x1: newPointInImage.dx,
            y1: newPointInImage.dy,
            x2: obj.x2,
            y2: obj.y2,
          );
        } else {
          // ลากจุดสิ้นสุด
          _detectedObjects[_selectedIndex] = detector.DetectedObject(
            classId: obj.classId,
            className: obj.className,
            confidence: obj.confidence,
            x1: obj.x1,
            y1: obj.y1,
            x2: newPointInImage.dx,
            y2: newPointInImage.dy,
          );
        }
        
        // คำนวณการวัดใหม่
        _calculateMeasurements();
      });
    }else {
        // กรณีที่ _dragStartPosition เป็น null ให้กำหนดค่าใหม่
        _dragStartPosition = details.localPosition;
    }
  }

  // จัดการการปล่อยนิ้วหลังจากการกดค้าง
  void _onLongPressEnd(LongPressEndDetails details) {
    if (!_isDragging || _selectedIndex == -1 || !_longPressActivated) return;
    
    setState(() {
      _isDragging = false;
      _longPressActivated = false;
      _dragStartPosition = null;
      
      // ซ่อนข้อความช่วยเหลือหลังจาก 2 วินาที
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showHelp = false;
          });
        }
      });
    });
  }

  // จัดการการกดค้างที่หมุด
  void _onLongPress(LongPressStartDetails details) {
    // ตรวจจับการแตะที่หมุด
    final Offset touchPosition = details.localPosition;
    
    // ตรวจสอบทุกวัตถุ
    for (int i = 0; i < _detectedObjects.length; i++) {
      final obj = _detectedObjects[i];
      
      // ตรวจสอบว่าแตะที่จุดเริ่มต้นหรือไม่
      if (_isPointNearby(touchPosition, Offset(obj.x1, obj.y1), _hitTestTolerance)) {
        setState(() {
          _selectedIndex = i;
          _isDragging = true;
          _isDraggingStartPoint = true;
          _dragStartPosition = touchPosition;
          _currentEditingObject = obj.classId;
          _helpText = 'กำลังลากจุด${_getLabelByClassId(obj.classId)}';
          _showHelp = true;
          _longPressActivated = true;
          
          // สั่นหนักๆ เพื่อสื่อว่าเป็นการลากแบบกดค้าง
          HapticFeedback.mediumImpact();
        });
        return;
      }
      
      // ตรวจสอบว่าแตะที่จุดสิ้นสุดหรือไม่
      if (_isPointNearby(touchPosition, Offset(obj.x2, obj.y2), _hitTestTolerance)) {
        setState(() {
          _selectedIndex = i;
          _isDragging = true;
          _isDraggingStartPoint = false;
          _dragStartPosition = touchPosition;
          _currentEditingObject = obj.classId;
          _helpText = 'กำลังลากจุด${_getLabelByClassId(obj.classId)}';
          _showHelp = true;
          _longPressActivated = true;
          
          // สั่นหนักๆ เพื่อสื่อว่าเป็นการลากแบบกดค้าง
          HapticFeedback.mediumImpact();
        });
        return;
      }
    }
  }

  // จัดการการลากนิ้วหลังจากการกดค้าง
  void _onLongPressMoveUpdate(LongPressMoveUpdateDetails details) {
    if (!_isDragging || _selectedIndex == -1 || !_longPressActivated) return;
    
    // ใช้ตำแหน่งล่าสุดโดยตรง
    final Offset touchPosition = details.localPosition;
    
    setState(() {
      // ดึงข้อมูลวัตถุที่กำลังแก้ไข
      final obj = _detectedObjects[_selectedIndex];
      
      // แปลงพิกัดของตำแหน่งใหม่
      final Offset newPointInImage = _screenToImageCoordinates(touchPosition);
      
      // อัปเดตพิกัดตามจุดที่กำลังลาก
      if (_isDraggingStartPoint) {
        // ลากจุดเริ่มต้น
        _detectedObjects[_selectedIndex] = detector.DetectedObject(
          classId: obj.classId,
          className: obj.className,
          confidence: obj.confidence,
          x1: newPointInImage.dx,
          y1: newPointInImage.dy,
          x2: obj.x2,
          y2: obj.y2,
        );
      } else {
        // ลากจุดสิ้นสุด
        _detectedObjects[_selectedIndex] = detector.DetectedObject(
          classId: obj.classId,
          className: obj.className,
          confidence: obj.confidence,
          x1: obj.x1,
          y1: obj.y1,
          x2: newPointInImage.dx,
          y2: newPointInImage.dy,
        );
      }
      
      // คำนวณการวัดใหม่
      _calculateMeasurements();
    });
  }

  // จัดการเมื่อปล่อยนิ้ว
  void _onPanEnd(DragEndDetails details) {
    if (!_isDragging || _selectedIndex == -1 || _longPressActivated) return;
    
    setState(() {
      _isDragging = false;
      _dragStartPosition = null;
      
      // ซ่อนข้อความช่วยเหลือหลังจาก 2 วินาที
      Future.delayed(Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showHelp = false;
          });
        }
      });
    });
  }

  // ฟังก์ชันสำหรับดึงป้ายกำกับตามประเภทของวัตถุ
  String _getLabelByClassId(int classId) {
    switch (classId) {
      case 0:
        return 'จุดอ้างอิง'; 
      case 1:
        return 'รอบอก'; 
      case 2:
        return 'ความยาวลำตัว'; 
      default:
        return 'ไม่ทราบประเภท';
    }
  }
  
  // ฟังก์ชันสำหรับดึงสีตามประเภทของวัตถุ
  Color _getColorByObjectType(int objectType) {
    switch (objectType) {
      case 0:
        return Colors.amber; // Yellow Mark
      case 1:
        return Colors.red; // Heart Girth
      case 2:
        return Colors.blue; // Body Length
      default:
        return Colors.grey;
    }
  }
  
  // เพิ่มฟังก์ชัน Reset สำหรับปุ่ม Reset
  void _resetLines() {
    setState(() {
      // ล้างข้อมูลเดิม
      _detectedObjects.clear();
      _hasYellowMark = false;
      _hasHeartGirth = false;
      _hasBodyLength = false;
      
      // นำเข้าข้อมูลจาก initialDetections อีกครั้ง
      if (widget.initialDetections.isNotEmpty) {
        _detectedObjects = List.from(widget.initialDetections);
        
        // ตรวจสอบประเภทที่มี
        for (var obj in _detectedObjects) {
          if (obj.classId == 0) _hasYellowMark = true;
          else if (obj.classId == 1) _hasHeartGirth = true;
          else if (obj.classId == 2) _hasBodyLength = true;
        }
      }
      
      // สร้างเส้นที่ยังไม่มี
      _setupMissingLines();
      
      // คำนวณใหม่
      _calculateMeasurements();
    });
  }

  // ฟังก์ชันบันทึกข้อมูลการวัดขั้นสูง
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
        objects: _detectedObjects,
      );
      
      // ตรวจสอบว่ามีข้อมูลที่เพิ่งบันทึกไปหรือไม่ (ภายใน 1 นาที)
      final now = DateTime.now();
      final oneMinuteAgo = now.subtract(Duration(minutes: 1));
      
      final recentRecords = await _dbHelper.getRecentWeightRecords(
        widget.cattle.id, 
        oneMinuteAgo, 
        _estimatedWeight,
        weightTolerance: 0.5 // เพิ่มค่าความคลาดเคลื่อนที่ยอมรับได้เป็น 0.5 กก.
      );
      
      if (recentRecords.isNotEmpty) {
        setState(() {
          _isSaving = false;
        });
        
        // แสดงข้อความแจ้งเตือนและถามว่าต้องการบันทึกซ้ำหรือไม่
        bool? shouldSaveAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('พบข้อมูลที่คล้ายกัน'),
            content: Text('มีการบันทึกน้ำหนักที่ใกล้เคียงกันในช่วงเวลาใกล้เคียง คุณต้องการบันทึกข้อมูลนี้ซ้ำหรือไม่?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text('ยกเลิก'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('บันทึกซ้ำ'),
              ),
            ],
          ),
        );
        
        if (shouldSaveAnyway != true) return;
        
        setState(() {
          _isSaving = true;
        });
      }
      
      // เก็บภาพที่มีการไฮไลท์การวัด
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final analyzedImagePath = '${appDir.path}/$fileName';
      
      // คัดลอกภาพต้นฉบับไปที่พื้นที่แอป
      final copiedImage = await widget.imageFile.copy(analyzedImagePath);
      
      // สร้างบันทึกน้ำหนักใหม่ด้วย WeightRecord object
      final weightRecord = WeightRecord(
        recordId: '', // จะถูกกำหนดโดย DatabaseHelper
        cattleId: widget.cattle.id,
        weight: _estimatedWeight,
        imagePath: copiedImage.path,
        date: DateTime.now(),
        notes: 'รอบอก: ${_heartGirthCm.toStringAsFixed(1)} ซม., ความยาว: ${_bodyLengthCm.toStringAsFixed(1)} ซม. (วัดด้วยตนเอง)',
      );
      
      // บันทึกลงฐานข้อมูล
      final recordId = await _dbHelper.insertWeightRecord(weightRecord);
      
      // แสดงข้อความสำเร็จ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('บันทึกข้อมูลน้ำหนักเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );
      
      // ส่งข้อมูลกลับไปยังหน้าก่อน
      Navigator.pop(context, {
        'success': true,
        'detection_result': detectionResult,
        'estimated_weight': _estimatedWeight,
        'heart_girth_cm': _heartGirthCm,
        'body_length_cm': _bodyLengthCm,
        'record_id': recordId,
      });
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการบันทึกข้อมูล: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      // รีเซ็ตสถานะการบันทึก
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  // บันทึกและส่งข้อมูลกลับ (เพื่อให้เข้ากับระบบเดิม)
  void _saveAndReturn() {
    // คำนวณผลลัพธ์อีกครั้ง
    _calculateMeasurements();

    // อัปเดตค่าวันที่ล่าสุด
    _measuredDate = DateTime.now();
    
    // เตรียมสร้าง DetectionResult
    final detectionResult = detector.DetectionResult(
      success: true,
      objects: _detectedObjects,
    );
    
    // แสดง log เพื่อตรวจสอบค่า
    print('ส่งค่ากลับ: น้ำหนัก = $_estimatedWeight กก., รอบอก = $_heartGirthCm ซม., ความยาว = $_bodyLengthCm ซม.');
    
    // ส่งข้อมูลกลับอย่างครบถ้วน
    Navigator.pop(context, {
      'success': true,
      'detection_result': detectionResult,
      'body_length_cm': _bodyLengthCm,
      'heart_girth_cm': _heartGirthCm,
      'estimated_weight': _estimatedWeight > 0 ? _estimatedWeight : 0.0,
      'confidence': 0.95, // ค่าความเชื่อมั่น
      'measured_date': _measuredDate,
      'is_manual': _isManualMeasurement,
      'save_result': _shouldSaveResult,
    });
  }
  
  // แสดงคำแนะนำการวัด
  void _showMeasurementGuide() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => AlertDialog(
        title: Text('คำแนะนำการวัด'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('1. จุดอ้างอิง (สีเหลือง): จุดอ้างอิงสำหรับวัตถุที่รู้ขนาดแน่นอน (100 ซม.)'),
            Text('2. รอบอก (สีแดง): จุดวัดความสูงของรอบอกโค'),
            Text('3. ความยาวลำตัว (สีน้ำเงิน): จุดวัดความยาวลำตัวโค'),
            SizedBox(height: 8),
            Text('- แตะค้างที่หมุดสีและลากเพื่อปรับตำแหน่งเส้นวัด'),
            Text('- แตะค้างที่หมุดเพื่อลากได้ง่ายขึ้น'),
            
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('เข้าใจแล้ว'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true, // ขยายพื้นที่เนื้อหาไปอยู่ใต้ AppBar
      
      body: Stack(
        children: [
          // พื้นที่แสดงรูปภาพเต็มหน้าจอ
          Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.grey[200],
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              onLongPressStart: _onLongPress,
              onLongPressMoveUpdate: _onLongPressMoveUpdate,
              onLongPressEnd: _onLongPressEnd,


              child: Center(
                child: _imageLoaded && _image != null
                  ? CustomPaint(
                      painter: ManualMeasurementPainter(
                        image: _image!,
                        detectedObjects: _detectedObjects,
                        selectedIndex: _selectedIndex,
                        startPoint: _dragStartPosition,
                        endPoint: null,
                        isEditing: _isDragging,
                        currentEditingObject: _currentEditingObject,
                        zoomScale: 1.0,
                        anchorPointRadius: _anchorPointRadius, // ใช้ค่าที่ปรับแล้ว
                        pinScale: _pinScale, // ส่ง scale แทน animate flag
                        showOriginalBoxes: _showOriginalBoxes, // ส่งค่าไปยัง painter
                      ),
                      size: _viewportSize,
                    )
                  : CircularProgressIndicator(),
              ),
            ),
          ),

          // เพิ่มปุ่มสำหรับสลับการแสดงกรอบ
          Positioned(
            top: 4,
            right: 108, // ปรับตำแหน่งให้เหมาะสม
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(),
                  icon: Icon(
                    _showOriginalBoxes ? Icons.grid_on : Icons.grid_off,
                    color: Colors.white,
                    size: 22
                  ),
                  onPressed: () {
                    setState(() {
                      _showOriginalBoxes = !_showOriginalBoxes;
                    });
                  },
                  tooltip: 'แสดง/ซ่อนกรอบตรวจจับ',
                ),
              ),
            ),
          ),

          // ปุ่มย้อนกลับและปุ่มอื่นๆ แบบลอย (แทน AppBar)
          Positioned(
            top: 4, // ปรับให้ติดขอบจอมากขึ้น
            left: 0.1,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.all(8), // ลดขนาด padding
                  constraints: BoxConstraints(), // ยกเลิกข้อจำกัดขนาดเริ่มต้น
                  icon: Icon(Icons.arrow_back, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'กลับ',
                ),
              ),
            ),
          ),
          
          // ปุ่ม Reset ลอย
          Positioned(
            top: 4,
            right: 56, // ปรับตำแหน่งให้ห่างจากปุ่ม Help พอประมาณ
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.all(8), // ลดขนาด padding
                  constraints: BoxConstraints(), // ยกเลิกข้อจำกัดขนาดเริ่มต้น
                  icon: Icon(Icons.refresh, color: Colors.white, size: 22), // ปรับขนาดไอคอนให้เล็กลง
                  onPressed: _resetLines,
                  tooltip: 'รีเซ็ตเส้น',
                ),
              ),
            ),
          ),
          
          // ปุ่ม Help ลอย
          Positioned(
            top: 4,
            right: 4,
            child: SafeArea(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.brown.withOpacity(0.7),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.all(8), // ลดขนาด padding
                  constraints: BoxConstraints(), // ยกเลิกข้อจำกัดขนาดเริ่มต้น
                  icon: Icon(Icons.help_outline, color: Colors.white, size: 22), // ปรับขนาดไอคอนให้เล็กลง
                  onPressed: _showMeasurementGuide,
                  tooltip: 'คำแนะนำ',
                ),
              ),
            ),
          ),
          
          // ชื่อหน้า (แบบลอย)
          Positioned(
            top: 4,
            left: 55,
            child: SafeArea(
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.brown.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    'วัดขนาดโค',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
          
          // ข้อความช่วยเหลือแบบโปร่งใส
          if (_showHelp)
            Positioned(
              top: 60, // ใต้ AppBar ที่บางลง
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _helpText,
                    style: TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ),
            
          // กล่องข้อมูลการวัดแบบลอยซ้อนทับ - จัดเรียงทางด้านซ้าย
          Positioned(
            left: 50,
            top: 60, // ใต้ AppBar ที่บางลง
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // จุดอ้างอิง
                _buildInfoBox(
                  'จุดอ้างอิง',
                  '100 ซม.',
                  Colors.amber,
                  _hasYellowMark,
                ),
                SizedBox(height: 8),
                // ความยาวลำตัว
                _buildInfoBox(
                  'ความยาวลำตัว',
                  _bodyLengthCm > 0 ? '${_bodyLengthCm.toStringAsFixed(1)} ซม.' : '- ซม.',
                  Colors.blue,
                  _hasBodyLength,
                ),
                SizedBox(height: 8),
                // รอบอก
                _buildInfoBox(
                  'รอบอก',
                  _heartGirthCm > 0 ? '${_heartGirthCm.toStringAsFixed(1)} ซม.' : '- ซม.',
                  Colors.red,
                  _hasHeartGirth,
                ),
              ],
            ),
          ),
          
          // แสดงน้ำหนักและปุ่มบันทึกด้านล่าง
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                // น้ำหนักโดยประมาณ
                Expanded(
                  flex: 2,
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.monitor_weight, color: Colors.white, size: 18),
                        SizedBox(width: 6),
                        Text(
                          _estimatedWeight > 0 ? 'น้ำหนัก: ${_estimatedWeight.toStringAsFixed(1)} กก.' : 'รอการวัด',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(width: 8),
                
                // ปุ่มบันทึก
                Container(
                  decoration: BoxDecoration(
                    color: _hasYellowMark && _hasHeartGirth && _hasBodyLength 
                        ? Colors.green 
                        : Colors.grey,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: _hasYellowMark && _hasHeartGirth && _hasBodyLength && !_isSaving ? _saveAndReturn : null,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Row(
                          children: [
                            _isSaving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : Icon(
                                  Icons.save, 
                                  color: Colors.white, 
                                  size: 18
                                ),
                            SizedBox(width: 4),
                            Text(
                              _isSaving ? 'กำลังบันทึก' : 'บันทึก',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // สร้างกล่องข้อมูลแบบลอย
  Widget _buildInfoBox(
    String title,
    String value,
    Color color,
    bool measured,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.85),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: color.withOpacity(measured ? 1.0 : 0.5),
              shape: BoxShape.circle,
            ),
            child: measured
                ? Icon(Icons.check, color: Colors.white, size: 12)
                : null,
          ),
          SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}