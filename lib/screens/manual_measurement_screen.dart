import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:ui' as ui;
import '../models/cattle.dart';
import '../utils/cattle_detector.dart' as detector;
import '../utils/weight_calculator.dart';
import '../utils/manual_measurement_painter.dart';

class ManualMeasurementScreen extends StatefulWidget {
  final File imageFile;
  final Cattle cattle;

  const ManualMeasurementScreen({
    Key? key,
    required this.imageFile,
    required this.cattle,
  }) : super(key: key);

  @override
  _ManualMeasurementScreenState createState() => _ManualMeasurementScreenState();
}

class _ManualMeasurementScreenState extends State<ManualMeasurementScreen> {
  // การรู้จำภาพ
  ui.Image? _image;
  bool _imageLoaded = false;
  Size _imageSize = Size(0, 0);
  
  // ข้อมูลการวัด
  List<detector.DetectedObject> _detectedObjects = [];
  int _selectedObjectIndex = -1;
  bool _isEditing = false;
  
  // จุดสำหรับการวัด
  Offset? _startPoint;
  Offset? _endPoint;
  int _currentEditingObject = -1; // 0=body length, 1=heart girth, 2=yellow mark
  
  // ผลลัพธ์การคำนวณ
  double _bodyLengthCm = 0.0;
  double _heartGirthCm = 0.0;
  double _estimatedWeight = 0.0;
  
  @override
  void initState() {
    super.initState();
    _loadImage();
    
    // สร้างออบเจ็กต์เริ่มต้นให้ผู้ใช้แก้ไข
    _createDefaultObjects();
  }
  
  // โหลดรูปภาพ
  Future<void> _loadImage() async {
    final data = await widget.imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(data);
    final frame = await codec.getNextFrame();
    
    setState(() {
      _image = frame.image;
      _imageSize = Size(_image!.width.toDouble(), _image!.height.toDouble());
      _imageLoaded = true;
    });
    
    print('โหลดรูปภาพสำเร็จ: ${_imageSize.width} x ${_imageSize.height}');
  }
  
  // สร้างออบเจ็กต์เริ่มต้น (ถ้าไม่มี)
  void _createDefaultObjects() {
    // สร้างออบเจ็กต์เริ่มต้นให้ผู้ใช้แก้ไข
    if (_detectedObjects.isEmpty) {
      // สร้างกรอบความยาวลำตัว (Body_Length) - กรอบแนวนอน
      _detectedObjects.add(detector.DetectedObject(
        classId: 0,
        className: 'Body_Length',
        confidence: 0.8,
        x1: _imageSize.width * 0.2,
        y1: _imageSize.height * 0.5,
        x2: _imageSize.width * 0.8,
        y2: _imageSize.height * 0.6,
      ));
      
      // สร้างกรอบรอบอก (Heart_Girth) - กรอบแนวตั้ง
      _detectedObjects.add(detector.DetectedObject(
        classId: 1,
        className: 'Heart_Girth',
        confidence: 0.8,
        x1: _imageSize.width * 0.4,
        y1: _imageSize.height * 0.3,
        x2: _imageSize.width * 0.5,
        y2: _imageSize.height * 0.7,
      ));
      
      // สร้างกรอบจุดอ้างอิง (Yellow_Mark)
      _detectedObjects.add(detector.DetectedObject(
        classId: 2,
        className: 'Yellow_Mark',
        confidence: 0.8,
        x1: _imageSize.width * 0.6,
        y1: _imageSize.height * 0.7,
        x2: _imageSize.width * 0.7,
        y2: _imageSize.height * 0.8,
      ));
    }
    
    // คำนวณผลเริ่มต้น
    _calculateMeasurements();
  }
  
  // คำนวณการวัดและน้ำหนัก
  void _calculateMeasurements() {
    // ค้นหาออบเจ็กต์ตามประเภท
    detector.DetectedObject? bodyLengthObj;
    detector.DetectedObject? heartGirthObj;
    detector.DetectedObject? yellowMarkObj;
    
    for (var obj in _detectedObjects) {
      if (obj.classId == 0) bodyLengthObj = obj;
      if (obj.classId == 1) heartGirthObj = obj;
      if (obj.classId == 2) yellowMarkObj = obj;
    }
    
    // ตรวจสอบว่ามีวัตถุครบหรือไม่
    if (bodyLengthObj == null || heartGirthObj == null) {
      print('ไม่พบข้อมูลการวัดที่จำเป็น');
      return;
    }
    
    // คำนวณอัตราส่วนพิกเซลต่อเซนติเมตร
    double ratio = 1.0;
    if (yellowMarkObj != null) {
      // สมมติว่าขนาดของ Yellow Mark คือ 100 ซม. (1 เมตร)
      ratio = 100.0 / yellowMarkObj.width;
    } else {
      // ถ้าไม่มีจุดอ้างอิง ใช้การประมาณค่า
      // สมมติว่าความยาวลำตัวประมาณ 150 ซม.
      ratio = 150.0 / bodyLengthObj.width;
    }
    
    // คำนวณขนาดจริงในหน่วยเซนติเมตร
    _bodyLengthCm = bodyLengthObj.width * ratio;
    _heartGirthCm = heartGirthObj.height * ratio;
    
    // ตรวจสอบและปรับค่าให้อยู่ในช่วงที่สมเหตุสมผล
    if (_bodyLengthCm < 80 || _bodyLengthCm > 250) _bodyLengthCm = 150.0;
    if (_heartGirthCm < 100 || _heartGirthCm > 280) _heartGirthCm = 180.0;
    
    // คำนวณน้ำหนักจากสูตร
    _estimatedWeight = WeightCalculator.calculateWeightByBreed(
      _heartGirthCm,
      _bodyLengthCm,
      widget.cattle.breed,
    );
    
    // ปรับค่าตามอายุและเพศ
    final ageMonths = WeightCalculator.calculateAgeInMonths(widget.cattle.birthDate);
    _estimatedWeight = WeightCalculator.adjustWeightByAgeAndGender(
      _estimatedWeight,
      widget.cattle.gender,
      ageMonths,
    );
    
    print('คำนวณการวัด: ความยาวลำตัว = $_bodyLengthCm ซม., รอบอก = $_heartGirthCm ซม.');
    print('น้ำหนักโดยประมาณ: $_estimatedWeight กก.');
    
    // บังคับให้อัพเดท UI
    setState(() {});
  }
  
  // ฟังก์ชันสำหรับเลือกวัตถุเพื่อแก้ไข
  void _selectObject(int index) {
    setState(() {
      _selectedObjectIndex = index;
      _isEditing = false;
      _startPoint = null;
      _endPoint = null;
    });
  }
  
  // เริ่มต้นการแก้ไขวัตถุที่เลือก
  void _startEdit(int objectType) {
    setState(() {
      _isEditing = true;
      _currentEditingObject = objectType;
      _startPoint = null;
      _endPoint = null;
    });
  }
  
  // บันทึกการเปลี่ยนแปลงและส่งข้อมูลกลับ
  void _saveAndReturn() {
    // คำนวณผลลัพธ์อีกครั้ง
    _calculateMeasurements();
    
    // สร้าง DetectionResult
    final detectionResult = detector.DetectionResult(
      success: true,
      objects: _detectedObjects,
    );
    
    // ส่งข้อมูลกลับไปยังหน้าประมาณน้ำหนัก
    Navigator.pop(context, {
      'detection_result': detectionResult,
      'body_length_cm': _bodyLengthCm,
      'heart_girth_cm': _heartGirthCm,
      'estimated_weight': _estimatedWeight,
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('วัดขนาดด้วยตนเอง'),
      ),
      body: _imageLoaded 
          ? Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // แสดงรูปภาพ
                      Center(
                        child: GestureDetector(
                          onPanDown: (details) {
                            if (_isEditing) {
                              setState(() {
                                _startPoint = details.localPosition;
                                _endPoint = details.localPosition;
                              });
                            }
                          },
                          onPanUpdate: (details) {
                            if (_isEditing && _startPoint != null) {
                              setState(() {
                                _endPoint = details.localPosition;
                              });
                            }
                          },
                          onPanEnd: (details) {
                            if (_isEditing && _startPoint != null && _endPoint != null) {
                              // แปลงพิกัดจาก UI เป็นพิกัดของรูปภาพจริง
                              final RenderBox renderBox = context.findRenderObject() as RenderBox;
                              final imageWidth = renderBox.size.width;
                              final imageHeight = renderBox.size.height;
                              
                              final xScale = _imageSize.width / imageWidth;
                              final yScale = _imageSize.height / imageHeight;
                              
                              final x1 = _startPoint!.dx * xScale;
                              final y1 = _startPoint!.dy * yScale;
                              final x2 = _endPoint!.dx * xScale;
                              final y2 = _endPoint!.dy * yScale;
                              
                              setState(() {
                                // อัปเดตหรือสร้างวัตถุใหม่
                                bool objectExists = false;
                                
                                for (int i = 0; i < _detectedObjects.length; i++) {
                                  if (_detectedObjects[i].classId == _currentEditingObject) {
                                    // อัปเดตวัตถุที่มีอยู่
                                    _detectedObjects[i] = detector.DetectedObject(
                                      classId: _currentEditingObject,
                                      className: _getClassNameById(_currentEditingObject),
                                      confidence: 1.0, // ผู้ใช้กำหนดเอง ความเชื่อมั่น 100%
                                      x1: math.min(x1, x2),
                                      y1: math.min(y1, y2),
                                      x2: math.max(x1, x2),
                                      y2: math.max(y1, y2),
                                    );
                                    objectExists = true;
                                    break;
                                  }
                                }
                                
                                if (!objectExists) {
                                  // สร้างวัตถุใหม่ถ้ายังไม่มี
                                  _detectedObjects.add(detector.DetectedObject(
                                    classId: _currentEditingObject,
                                    className: _getClassNameById(_currentEditingObject),
                                    confidence: 1.0,
                                    x1: math.min(x1, x2),
                                    y1: math.min(y1, y2),
                                    x2: math.max(x1, x2),
                                    y2: math.max(y1, y2),
                                  ));
                                }
                                
                                // รีเซ็ตสถานะการแก้ไข
                                _isEditing = false;
                                _startPoint = null;
                                _endPoint = null;
                                
                                // คำนวณการวัดใหม่
                                _calculateMeasurements();
                              });
                            }
                          },
                          child: CustomPaint(
                            painter: ManualMeasurementPainter(
                              image: _image!,
                              detectedObjects: _detectedObjects,
                              selectedIndex: _selectedObjectIndex,
                              startPoint: _startPoint,
                              endPoint: _endPoint,
                              isEditing: _isEditing,
                              currentEditingObject: _currentEditingObject,
                            ),
                            size: Size(double.infinity, double.infinity),
                          ),
                        ),
                      ),
                      
                      // คำแนะนำสำหรับผู้ใช้
                      if (_isEditing) 
                        Positioned(
                          top: 20,
                          left: 0,
                          right: 0,
                          child: Container(
                            padding: EdgeInsets.all(8),
                            color: Colors.black.withOpacity(0.7),
                            child: Text(
                              'แตะค้างและลากเพื่อวาดกรอบ ${_getInstructionText(_currentEditingObject)}',
                              style: TextStyle(color: Colors.white),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                
                // แสดงผลลัพธ์การวัด
                Container(
                  padding: EdgeInsets.all(16),
                  color: Colors.grey[200],
                  child: Column(
                    children: [
                      Text(
                        'ผลการวัด',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildMeasurementItem(
                            'ความยาวลำตัว',
                            '${_bodyLengthCm.toStringAsFixed(1)} ซม.',
                            Colors.blue,
                            () => _startEdit(0),
                          ),
                          _buildMeasurementItem(
                            'รอบอก',
                            '${_heartGirthCm.toStringAsFixed(1)} ซม.',
                            Colors.red,
                            () => _startEdit(1),
                          ),
                          _buildMeasurementItem(
                            'จุดอ้างอิง',
                            '100 ซม.',
                            Colors.amber,
                            () => _startEdit(2),
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Text('น้ำหนักโดยประมาณ', style: TextStyle(fontSize: 16)),
                            Text(
                              '${_estimatedWeight.toStringAsFixed(1)} กก.',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.green[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(context),
                              child: Text('ยกเลิก'),
                              style: OutlinedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                          SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _saveAndReturn,
                              child: Text('บันทึกการวัด'),
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
  
  Widget _buildMeasurementItem(String title, String value, Color color, VoidCallback onEdit) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withOpacity(0.1),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
          ),
          SizedBox(height: 4),
          InkWell(
            onTap: onEdit,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.edit, size: 14, color: color),
                  SizedBox(width: 4),
                  Text('แก้ไข', style: TextStyle(fontSize: 12, color: color)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  String _getClassNameById(int classId) {
    switch (classId) {
      case 0:
        return 'Body_Length';
      case 1:
        return 'Heart_Girth';
      case 2:
        return 'Yellow_Mark';
      default:
        return 'Unknown';
    }
  }
  
  String _getInstructionText(int classId) {
    switch (classId) {
      case 0:
        return 'ความยาวลำตัว (กรอบสีฟ้า)';
      case 1:
        return 'รอบอก (กรอบสีแดง)';
      case 2:
        return 'จุดอ้างอิง (กรอบสีเหลือง)';
      default:
        return '';
    }
  }
}