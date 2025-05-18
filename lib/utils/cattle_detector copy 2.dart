import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// คลาสเก็บข้อมูลกรอบสี่เหลี่ยมที่ตรวจพบ (Bounding Box)
class Rect {
  final double left;
  final double top;
  final double right;
  final double bottom;

  Rect({
    required this.left,
    required this.top,
    required this.right,
    required this.bottom,
  });

  // คำนวณความกว้างของกรอบสี่เหลี่ยม
  double get width => (right - left).abs();
  
  // คำนวณความสูงของกรอบสี่เหลี่ยม
  double get height => (bottom - top).abs();
  
  // คำนวณพื้นที่ของกรอบสี่เหลี่ยม
  double get area => width * height;
  
  // คำนวณจุดศูนย์กลาง
  Map<String, double> get center => {
    'x': (left + right) / 2,
    'y': (top + bottom) / 2,
  };
}

/// คลาสเก็บข้อมูลวัตถุที่ตรวจพบ
class DetectedObject {
  final int classId;
  final String className;
  final double confidence;
  final double x1, y1, x2, y2;
  final Rect? boundingBox;  // เพิ่ม boundingBox สำหรับการแสดงผล
  
  DetectedObject({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
    this.boundingBox,
  });
  
  // คำนวณความกว้างของกรอบสี่เหลี่ยม
  double get width => (x2 - x1).abs();
  
  // คำนวณความสูงของกรอบสี่เหลี่ยม
  double get height => (y2 - y1).abs();
  
  // คำนวณพื้นที่ของกรอบสี่เหลี่ยม
  double get area => width * height;
  
  // คำนวณจุดศูนย์กลาง
  Map<String, double> get center => {
    'x': (x1 + x2) / 2,
    'y': (y1 + y2) / 2,
  };
  
  // คำนวณความยาวของเส้น
  double get length => 
      math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
  
  // แปลงเป็น Map สำหรับการบันทึกหรือส่งต่อข้อมูล
  Map<String, dynamic> toMap() {
    return {
      'class_id': classId,
      'class_name': className,
      'confidence': confidence,
      'x1': x1,
      'y1': y1,
      'x2': x2,
      'y2': y2,
      'width': width,
      'height': height,
      'length': length,
      'bounding_box': boundingBox != null ? {
        'left': boundingBox!.left,
        'top': boundingBox!.top,
        'right': boundingBox!.right,
        'bottom': boundingBox!.bottom,
      } : null,
    };
  }
  // สร้างจาก Map สำหรับการอ่านข้อมูลที่บันทึกไว้
  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    Rect? rect;
    if (map.containsKey('bounding_box') && map['bounding_box'] != null) {
      var boxMap = map['bounding_box'];
      rect = Rect(
        left: boxMap['left'],
        top: boxMap['top'],
        right: boxMap['right'],
        bottom: boxMap['bottom'],
      );
    }
    
    return DetectedObject(
      classId: map['class_id'],
      className: map['class_name'],
      confidence: map['confidence'],
      x1: map['x1'],
      y1: map['y1'],
      x2: map['x2'],
      y2: map['y2'],
      boundingBox: rect,
    );
  }
  
  // สร้างสำเนาของวัตถุพร้อมแก้ไขค่าบางส่วน
  DetectedObject copyWith({
    int? classId,
    String? className,
    double? confidence,
    double? x1,
    double? y1,
    double? x2,
    double? y2,
    Rect? boundingBox,
  }) {
    return DetectedObject(
      classId: classId ?? this.classId,
      className: className ?? this.className,
      confidence: confidence ?? this.confidence,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
      boundingBox: boundingBox ?? this.boundingBox,
    );
  }
  
  // ดึงข้อมูลแบบสตริง
  @override
  String toString() {
    return 'DetectedObject(classId: $classId, className: $className, confidence: ${(confidence * 100).toStringAsFixed(1)}%, '
           'coords: ($x1, $y1) - ($x2, $y2), length: ${length.toStringAsFixed(1)})';
  }
}

/// คลาสเก็บผลลัพธ์การตรวจจับ
class DetectionResult {
  final bool success;
  final List<DetectedObject>? objects;
  final String? error;
  final String? resizedImagePath;
  final Size? originalImageSize;
  
  DetectionResult({
    required this.success,
    this.objects,
    this.error,
    this.resizedImagePath,
    this.originalImageSize,
  });
  
  // ดึงจำนวนวัตถุที่ตรวจจับได้
  int get objectCount => objects?.length ?? 0;
  
  // ดึงวัตถุตามชื่อ class
  DetectedObject? findObjectByClass(String className) {
    if (objects == null || objects!.isEmpty) return null;
    try {
      return objects!.firstWhere((obj) => obj.className == className);
    } catch (e) {
      return null;
    }
  }
  
  // ดึงวัตถุตามประเภท
  DetectedObject? getObjectByClass(int classId) {
    if (objects == null || objects!.isEmpty) return null;
    try {
      return objects!.firstWhere((obj) => obj.classId == classId);
    } catch (e) {
      return null;
    }
  }
  // ตรวจสอบว่ามีวัตถุที่ต้องการครบถ้วนหรือไม่
  bool hasRequiredObjects(List<int> requiredClassIds) {
    if (objects == null || objects!.isEmpty) return false;
    for (var classId in requiredClassIds) {
      if (getObjectByClass(classId) == null) return false;
    }
    return true;
  }
  
  // ตรวจสอบว่ามีวัตถุใดบ้างที่ตรวจพบ
  Map<int, bool> detectObjectStatus() {
    Map<int, bool> status = {
      0: false, // Body Length
      1: false, // Heart Girth
      2: false, // Yellow Mark
    };
    
    if (objects != null && objects!.isNotEmpty) {
      for (var obj in objects!) {
        if (obj.classId >= 0 && obj.classId <= 2) {
          status[obj.classId] = true;
        }
      }
    }
    
    return status;
  }
  
  // สร้างการตรวจจับแบบเต็มรูปแบบ (ใช้ในกรณีที่ต้องสร้างการจำลองการตรวจจับ)
  factory DetectionResult.createFullDetection(int imageWidth, int imageHeight) {
    // คำนวณตำแหน่งกลางของภาพ
    double centerX = imageWidth / 2;
    double centerY = imageHeight / 2;
    
    // สร้างรายการวัตถุที่ตรวจจับได้
    List<DetectedObject> objects = [
      // จุดอ้างอิง (Yellow Mark) - แนวนอน
      DetectedObject(
        classId: 2,
        className: 'จุดอ้างอิง',
        confidence: 0.95,
        x1: centerX - imageWidth * 0.25,
        y1: centerY - imageHeight * 0.2,
        x2: centerX + imageWidth * 0.25,
        y2: centerY - imageHeight * 0.2,
      ),
      
      // รอบอก (Heart Girth) - แนวตั้ง
      DetectedObject(
        classId: 1,
        className: 'รอบอก',
        confidence: 0.95,
        x1: centerX + imageWidth * 0.1,
        y1: centerY - imageHeight * 0.2,
        x2: centerX + imageWidth * 0.1,
        y2: centerY + imageHeight * 0.2,
      ),
      
      // ความยาวลำตัว (Body Length) - แนวนอน
      DetectedObject(
        classId: 0,
        className: 'ความยาวลำตัว',
        confidence: 0.95,
        x1: centerX - imageWidth * 0.3,
        y1: centerY,
        x2: centerX + imageWidth * 0.3,
        y2: centerY,
      ),
    ];
    
    return DetectionResult(
      success: true,
      objects: objects,
      originalImageSize: Size(imageWidth.toDouble(), imageHeight.toDouble()),
    );
  }
  // สร้าง DetectionResult จาก Map (สำหรับการอ่านข้อมูลที่บันทึกไว้)
  factory DetectionResult.fromMap(Map<String, dynamic> map) {
    List<DetectedObject>? objectsList;
    
    if (map.containsKey('objects') && map['objects'] is List) {
      objectsList = (map['objects'] as List)
          .map((objMap) => DetectedObject.fromMap(objMap))
          .toList();
    }

    Size? size;
    if (map.containsKey('original_image_width') && map.containsKey('original_image_height')) {
      size = Size(
        map['original_image_width'] ?? 0.0,
        map['original_image_height'] ?? 0.0,
      );
    }
    
    return DetectionResult(
      success: map['success'] ?? false,
      objects: objectsList,
      error: map['error'],
      resizedImagePath: map['resized_image_path'],
      originalImageSize: size,
    );
  }
  
  // แปลงเป็น Map (สำหรับการบันทึกข้อมูล)
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'error': error,
      'resized_image_path': resizedImagePath,
      'objects': objects?.map((obj) => obj.toMap()).toList(),
      'original_image_width': originalImageSize?.width,
      'original_image_height': originalImageSize?.height,
    };
  }
}

/// คลาสสำหรับตรวจจับโคด้วยโมเดล YOLOv8 แปลงเป็น TFLite
class CattleDetector {
  // ชื่อไฟล์โมเดลที่ใช้ (ให้ตรงกับที่กำหนดใน pubspec.yaml)
  static const String MODEL_FILE_NAME = 'best_model_float32.tflite';
  // ขนาด input ของโมเดล YOLOv8
  static const int INPUT_SIZE = 1280;

  // จำนวนคลาสทั้งหมดในโมเดล (ความยาวลำตัว, รอบอก, จุดอ้างอิง)
  static const int NUM_CLASSES = 3;

  // ค่า confidence threshold ที่เหมาะสมสำหรับการตรวจจับ
  static const double DEFAULT_CONFIDENCE_THRESHOLD = 0.25;

  // ขนาดสูงสุดสำหรับรูปภาพก่อนทำการ resize
  static const int MAX_IMAGE_DIMENSION = 1200;

  // ค่าคงที่สำหรับการวางตำแหน่งเส้น
  static const double HEART_GIRTH_X_OFFSET = 0.3;
  static const double BODY_LENGTH_START_X = 0.1;
  static const double BODY_LENGTH_END_X = 0.9;   
  static const double BODY_LENGTH_Y_OFFSET = 0.1;
  
  // คลาสสำหรับรันโมเดล TFLite
  Interpreter? _interpreter;
  bool _modelLoaded = false;
  // สร้าง singleton pattern สำหรับ CattleDetector
  static final CattleDetector _instance = CattleDetector._internal();
  factory CattleDetector() => _instance;
  CattleDetector._internal();
  
  /// โหลดโมเดล TFLite จาก assets หรือพื้นที่เก็บข้อมูลถาวร
  Future<bool> loadModel() async {
    try {
      // ตรวจสอบว่าโหลดโมเดลไว้แล้วหรือไม่
      if (_modelLoaded && _interpreter != null) {
        print('โมเดลถูกโหลดแล้ว กำลังใช้งานโมเดลที่โหลดไว้');
        return true;
      }
      
      print('เริ่มต้นโหลดโมเดล...');
      
      try {
        // ตรวจสอบก่อนว่ามีโมเดลในพื้นที่เก็บข้อมูลถาวรหรือไม่
        final appDir = await getApplicationDocumentsDirectory();
        String modelPath = '${appDir.path}/$MODEL_FILE_NAME';
        File modelFile = File(modelPath);
        
        if (await modelFile.exists()) {
          print('พบโมเดลในพื้นที่เก็บข้อมูลถาวร: $modelPath');
        } else {
          // ถ้าไม่มี ให้คัดลอกจาก assets
          print('ไม่พบโมเดลในพื้นที่เก็บข้อมูลถาวร กำลังคัดลอกจาก assets...');
          ByteData modelData = await rootBundle.load('assets/models/$MODEL_FILE_NAME');
          await modelFile.writeAsBytes(modelData.buffer.asUint8List());
          print('คัดลอกโมเดลไปยังพื้นที่เก็บข้อมูลถาวร: $modelPath');
        }
        
        // ตรวจสอบว่าไฟล์มีอยู่จริง
        if (!await modelFile.exists()) {
          print('ไม่พบไฟล์หลังจากการคัดลอก');
          return false;
        }
        
        print('ขนาดไฟล์: ${await modelFile.length()} bytes');
        
        // สร้าง interpreter options
        final options = InterpreterOptions();
        options.threads = 4; // ใช้ 4 threads สำหรับการประมวลผล
        
        try {
          // สร้าง Interpreter จากไฟล์
          _interpreter = await Interpreter.fromFile(modelFile, options: options);
          _modelLoaded = true;
          print('โหลดโมเดลสำเร็จจาก: $modelPath');
          
          // แสดงข้อมูลของโมเดลเพื่อการตรวจสอบ
          var inputTensors = _interpreter!.getInputTensors();
          var outputTensors = _interpreter!.getOutputTensors();
          
          print('จำนวน input tensor: ${inputTensors.length}');
          print('จำนวน output tensor: ${outputTensors.length}');
          
          // แสดงรายละเอียดของ input tensor
          for (var i = 0; i < inputTensors.length; i++) {
            print('Input tensor $i shape: ${inputTensors[i].shape}');
            print('Input tensor $i type: ${inputTensors[i].type}');
          }
          
          // แสดงรายละเอียดของ output tensor
          for (var i = 0; i < outputTensors.length; i++) {
            print('Output tensor $i shape: ${outputTensors[i].shape}');
            print('Output tensor $i type: ${outputTensors[i].type}');
          }
          return true;
        } catch (interpreterError) {
          print('เกิดข้อผิดพลาดในการสร้าง Interpreter: $interpreterError');
          return false;
        }
      } catch (assetError) {
        print('ไม่สามารถโหลดโมเดลจาก assets: $assetError');
        return false;
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดทั่วไปในการโหลดโมเดล: $e');
      return false;
    }
  }

  /// Resize รูปภาพถ้าขนาดใหญ่เกินไป เพื่อลดการใช้หน่วยความจำและเพิ่มความเร็วในการประมวลผล
  Future<File> _resizeImageIfNeeded(File imageFile) async {
    try {
      // อ่านข้อมูลภาพ
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('ไม่สามารถอ่านรูปภาพสำหรับ resize');
        return imageFile; // ถ้าเกิดข้อผิดพลาดให้ใช้ไฟล์เดิม
      }
      
      // ตรวจสอบว่าขนาดภาพต่ำกว่าขีดจำกัดหรือไม่
      if (image.width <= MAX_IMAGE_DIMENSION && image.height <= MAX_IMAGE_DIMENSION) {
        print('ขนาดรูปภาพอยู่ในเกณฑ์ที่เหมาะสม: ${image.width}x${image.height}');
        return imageFile; // ไม่จำเป็นต้อง resize
      }
      
      // คำนวณสัดส่วนการลดขนาดโดยรักษาอัตราส่วนภาพ
      double ratio = math.min(
        MAX_IMAGE_DIMENSION / image.width,
        MAX_IMAGE_DIMENSION / image.height
      );
      
      // คำนวณขนาดใหม่
      int newWidth = (image.width * ratio).round();
      int newHeight = (image.height * ratio).round();
      
      print('กำลัง resize รูปภาพจาก ${image.width}x${image.height} เป็น ${newWidth}x${newHeight}');
      
      // Resize รูปภาพ
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear
      );
      
      // บันทึกรูปภาพใหม่
      final directory = await getTemporaryDirectory();
      final resizedFilePath = '${directory.path}/resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // บันทึกในรูปแบบ JPEG ด้วยคุณภาพสูง
      final resizedFile = File(resizedFilePath);
      await resizedFile.writeAsBytes(img.encodeJpg(resizedImage, quality: 95));
      
      print('บันทึกรูปภาพที่ resize แล้วที่: $resizedFilePath');
      return resizedFile;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการ resize รูปภาพ: $e');
      return imageFile; // กรณีเกิดข้อผิดพลาดให้ใช้ไฟล์เดิม
    }
  }
  /// ปรับปรุงคุณภาพรูปภาพสำหรับการตรวจจับ 
  Future<img.Image> _enhanceImageForDetection(img.Image originalImage) async {
    try {
      print('กำลังปรับปรุงรูปภาพสำหรับการตรวจจับ...');
      
      // ปรับความสว่างและคอนทราสต์
      img.Image enhancedImage = img.copyResize(originalImage);
      enhancedImage = img.adjustColor(
        enhancedImage,
        contrast: 1.2,    // เพิ่มคอนทราสต์เล็กน้อย
        brightness: 0.05, // เพิ่มความสว่างเล็กน้อย
        saturation: 1.1,  // เพิ่มความอิ่มตัวของสีเล็กน้อย
        exposure: 0.05,   // เพิ่มการเปิดรับแสงเล็กน้อย
      );
      
      // ทำ Noise reduction เพื่อลดสัญญาณรบกวน
      enhancedImage = img.gaussianBlur(enhancedImage, radius: 1);
      
      // ปรับปรุงขอบภาพ
      enhancedImage = img.adjustColor(
        enhancedImage,
        contrast: 1.1,     // เพิ่มคอนทราสต์อีกเล็กน้อย
        saturation: 1.05,  // เพิ่มความอิ่มตัวของสีอีกเล็กน้อย
      );
      
      // บันทึกรูปที่ปรับปรุงแล้วเพื่อตรวจสอบ (ถ้าต้องการ)
      await _saveDebugImage(enhancedImage, 'enhanced');
      
      print('ปรับปรุงรูปภาพสำเร็จ');
      return enhancedImage;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการปรับปรุงรูปภาพ: $e');
      return originalImage; // ในกรณีเกิดข้อผิดพลาด ให้ใช้รูปภาพเดิม
    }
  }

  /// ตรวจจับโคจากไฟล์ภาพ และรายละเอียดวัตถุที่ตรวจพบ
  Future<DetectionResult> detectCattle(File imageFile) async {
    try {
      // โหลดโมเดลถ้ายังไม่ได้โหลด
      if (!await loadModel() || _interpreter == null) {
        print('ไม่สามารถโหลดหรือเรียกใช้โมเดลได้');
        return DetectionResult(
          success: false,
          error: 'ไม่สามารถโหลดหรือเรียกใช้โมเดลได้',
        );
      }

      // resize รูปภาพเพื่อลดขนาดและเพิ่มประสิทธิภาพในการประมวลผล
      File resizedImageFile = await _resizeImageIfNeeded(imageFile);
      
      // แปลงรูปภาพให้เป็นรูปแบบที่เหมาะสมกับโมเดล
      final imageBytes = await resizedImageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        print('ไม่สามารถอ่านรูปภาพได้');
        return DetectionResult(
          success: false,
          error: 'ไม่สามารถอ่านรูปภาพได้',
        );
      }

      // เพิ่มการปรับแต่งภาพเพื่อเพิ่มประสิทธิภาพการตรวจจับ
      final enhancedImage = await _enhanceImageForDetection(originalImage);
      
      print('ขนาดรูปภาพที่ใช้ในการตรวจจับ: ${enhancedImage.width}x${enhancedImage.height}');

      try {
        // แปลงรูปภาพเป็น tensor และบันทึกรูปที่ resize แล้ว
        var result = await _prepareImageForInference(enhancedImage);
        var inputTensor = result['tensor'];
        var resizedImagePath = result['resizedImagePath'];
        
        try {
          // ดึงข้อมูลเกี่ยวกับ output shape ของโมเดล
          var outputShape = _interpreter!.getOutputTensor(0).shape;
          print('รูปแบบ output tensor: $outputShape');
          
          // สร้าง buffer สำหรับเก็บผลลัพธ์
          Map<int, dynamic> outputs = {};
          
          // สร้าง buffer ที่เหมาะสมกับโมเดล YOLOv8
          if (outputShape.length >= 2) {
            // รูปแบบ output ของ YOLOv8
            print('กำลังสร้าง buffer สำหรับ output ของ YOLOv8');
            
            List<List<double>> outputBuffer = [];
            
            // ตรวจสอบและสร้าง buffer ตามรูปแบบ output
            // กรณี [1, 84, 8400]
            if (outputShape.length == 3) {
              final rows = outputShape[1];
              final cols = outputShape[2];
              
              for (int i = 0; i < rows; i++) {
                outputBuffer.add(List<double>.filled(cols, 0.0));
              }
              
              outputs[0] = [outputBuffer];
            }
            // กรณี [84, 8400]
            else if (outputShape.length == 2) {
              final rows = outputShape[0];
              final cols = outputShape[1];
              
              for (int i = 0; i < rows; i++) {
                outputBuffer.add(List<double>.filled(cols, 0.0));
              }
              
              outputs[0] = outputBuffer;
            }
            else {
              print('รูปแบบ output ไม่ตรงกับที่คาดหวัง: $outputShape');
              return DetectionResult(
                success: false,
                error: 'รูปแบบ output ไม่ตรงกับที่คาดหวัง: $outputShape',
                resizedImagePath: resizedImagePath,
                originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
              );
            }
          }
          else {
            print('รูปแบบ output ไม่รองรับ: $outputShape');
            return DetectionResult(
              success: false,
              error: 'รูปแบบ output ไม่รองรับ: $outputShape',
              resizedImagePath: resizedImagePath,
              originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
            );
          }
          
          // รัน inference
          print('กำลังรัน inference...');
          
          try {
            // ใช้ dynamic dispatch เพื่อรันโมเดลด้วย buffer
            Map<String, dynamic> inputs = {'input': inputTensor};
            
            // แก้ไขเป็น Map<int, Object> ตามที่ต้องการ
            Map<int, Object> outputsObject = {};
            for (var key in outputs.keys) {
              outputsObject[key] = outputs[key] as Object;
            }
            
            _interpreter!.runForMultipleInputs([inputTensor], outputsObject);
            print('รัน inference สำเร็จ');
            
            // ตรวจสอบ output และแปลงให้อยู่ในรูปแบบที่สามารถประมวลผลได้
            var standardizedOutput = _standardizeOutput(outputsObject);
            
            // ประมวลผล output และดึงการตรวจจับ
            List<DetectedObject> detections = _processOutput(
              standardizedOutput, 
              enhancedImage.width, 
              enhancedImage.height, 
              confidenceThreshold: DEFAULT_CONFIDENCE_THRESHOLD
            );
            
            print('พบวัตถุทั้งหมด ${detections.length} รายการ');
            
            // ตรวจสอบว่าพบวัตถุหรือไม่
            if (detections.isEmpty) {
              print('ไม่พบวัตถุในภาพ ลองลดค่า threshold');
              
              // ลองใช้ threshold ที่ต่ำลง
              detections = _processOutput(
                standardizedOutput, 
                enhancedImage.width, 
                enhancedImage.height, 
                confidenceThreshold: 0.01 // ใช้ค่าต่ำมาก
              );
              
              if (detections.isEmpty) {
                print('ไม่พบวัตถุในภาพแม้จะใช้ค่า threshold ต่ำมาก');
                
                // ถ้ายังไม่พบ ให้สร้างการตรวจจับแบบสำรอง
                return DetectionResult.createFullDetection(
                  enhancedImage.width, 
                  enhancedImage.height
                );
              }
            }
            
            // แบ่งตามประเภทและเลือกเฉพาะวัตถุที่มีความเชื่อมั่นสูงสุดในแต่ละคลาส
            Map<int, List<DetectedObject>> objectsByClass = {};
            for (var obj in detections) {
              if (!objectsByClass.containsKey(obj.classId)) {
                objectsByClass[obj.classId] = [];
              }
              objectsByClass[obj.classId]!.add(obj);
            }
            
            List<DetectedObject> bestObjects = [];
            objectsByClass.forEach((classId, objects) {
              if (objects.isNotEmpty) {
                // เรียงลำดับตามความเชื่อมั่นและเลือกวัตถุที่มีความเชื่อมั่นสูงสุด
                objects.sort((a, b) => b.confidence.compareTo(a.confidence));
                bestObjects.add(objects.first);
              }
            });
            
            print('เลือกวัตถุที่ดีที่สุดสำหรับแต่ละประเภท: ${bestObjects.length} รายการ');
            for (var obj in bestObjects) {
              print('- ${obj.className} (ClassID: ${obj.classId}): ${(obj.confidence * 100).toStringAsFixed(2)}%');
            }
            
            if (bestObjects.isEmpty) {
              return DetectionResult(
                success: false,
                error: 'ไม่พบวัตถุที่ต้องการในภาพ',
                resizedImagePath: resizedImagePath,
                originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
              );
            }
            
            return DetectionResult(
              success: true,
              objects: bestObjects,
              resizedImagePath: resizedImagePath,
              originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
            );
          } catch (runError) {
            print('ไม่สามารถรัน inference ได้: $runError');
            return DetectionResult(
              success: false,
              error: 'ไม่สามารถรัน inference ได้: $runError',
              resizedImagePath: resizedImagePath,
              originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
            );
          }
        } catch (e) {
          print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
          return DetectionResult(
            success: false,
            error: 'เกิดข้อผิดพลาดในการประมวลผล output: $e',
            resizedImagePath: resizedImagePath,
            originalImageSize: Size(enhancedImage.width.toDouble(), enhancedImage.height.toDouble()),
          );
        }
      } catch (e) {
        print('เกิดข้อผิดพลาดในการแปลงรูปภาพเป็น tensor: $e');
        return DetectionResult(
          success: false,
          error: 'เกิดข้อผิดพลาดในการแปลงรูปภาพเป็น tensor: $e',
        );
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการตรวจจับโค: $e');
      return DetectionResult(
        success: false,
        error: 'เกิดข้อผิดพลาดในการตรวจจับโค: $e',
      );
    }
  }

  /// ประเมินน้ำหนักโคจากวัตถุที่ตรวจพบ
  /// คืนค่าเป็นน้ำหนักโดยประมาณในหน่วยกิโลกรัม
  double estimateWeight(List<DetectedObject> detectedObjects, double pixelToMetricRatio) {
    try {
      print('กำลังประเมินน้ำหนักโค...');
      
      // ค้นหาวัตถุที่จำเป็นต้องใช้ในการคำนวณ
      DetectedObject? bodyLengthObj = null;
      DetectedObject? heartGirthObj = null;
      
      for (var obj in detectedObjects) {
        if (obj.classId == 0) {  // ความยาวลำตัว (Body Length)
          bodyLengthObj = obj;
        } else if (obj.classId == 1) {  // รอบอก (Heart Girth)
          heartGirthObj = obj;
        }
      }
      
      // ตรวจสอบว่ามีข้อมูลครบถ้วนหรือไม่
      if (bodyLengthObj == null || heartGirthObj == null) {
        print('ไม่มีข้อมูลความยาวลำตัวหรือรอบอกเพียงพอสำหรับการประเมินน้ำหนัก');
        return 0.0;
      }
      
      // คำนวณความยาวจริงของเส้นในหน่วยเซนติเมตร
      double bodyLengthPixels = bodyLengthObj.length;
      double heartGirthPixels = heartGirthObj.length;
      
      double bodyLengthCm = bodyLengthPixels * pixelToMetricRatio;
      double heartGirthCm = heartGirthPixels * pixelToMetricRatio;
      
      print('ความยาวลำตัว: ${bodyLengthCm.toStringAsFixed(1)} ซม. (${bodyLengthPixels.toStringAsFixed(1)} พิกเซล)');
      print('รอบอก: ${heartGirthCm.toStringAsFixed(1)} ซม. (${heartGirthPixels.toStringAsFixed(1)} พิกเซล)');
      
      // ใช้สูตรคำนวณน้ำหนักโค (ตัวอย่างสูตร: W = (HG^2 x BL) / 300)
      // โดย W = น้ำหนัก (กก.), HG = รอบอก (ซม.), BL = ความยาวลำตัว (ซม.)
      double estimatedWeight = (heartGirthCm * heartGirthCm * bodyLengthCm) / 300;
      
      print('น้ำหนักโดยประมาณ: ${estimatedWeight.toStringAsFixed(1)} กิโลกรัม');
      
      return estimatedWeight;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประเมินน้ำหนักโค: $e');
      return 0.0;
    }
  }

  /// คำนวณอัตราส่วนพิกเซลต่อหน่วยความยาวจริง (ซม.) จากวัตถุอ้างอิง
  double calculatePixelToMetricRatio(List<DetectedObject> detectedObjects, double referenceObjectLengthCm) {
    try {
      // ค้นหาวัตถุอ้างอิง (Yellow Mark)
      DetectedObject? referenceObject = null;
      
      for (var obj in detectedObjects) {
        if (obj.classId == 2) {  // จุดอ้างอิง (Yellow Mark)
          referenceObject = obj;
          break;
        }
      }
      
      // ตรวจสอบว่ามีวัตถุอ้างอิงหรือไม่
      if (referenceObject == null) {
        print('ไม่พบวัตถุอ้างอิงสำหรับการคำนวณอัตราส่วน');
        return 1.0;  // ค่าเริ่มต้น (1 พิกเซล = 1 ซม.)
      }
      
      // คำนวณความยาวของวัตถุอ้างอิงในหน่วยพิกเซล
      double referencePixelLength = referenceObject.length;
      
      // คำนวณอัตราส่วน (ซม. ต่อพิกเซล)
      double ratio = referenceObjectLengthCm / referencePixelLength;
      
      print('อัตราส่วน: ${ratio.toStringAsFixed(4)} ซม./พิกเซล (จากวัตถุอ้างอิงยาว ${referenceObjectLengthCm.toStringAsFixed(1)} ซม. = ${referencePixelLength.toStringAsFixed(1)} พิกเซล)');
      
      return ratio;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการคำนวณอัตราส่วนพิกเซลต่อหน่วยความยาวจริง: $e');
      return 1.0;  // ค่าเริ่มต้น (1 พิกเซล = 1 ซม.)
    }
  }

  /// ปรับปรุงและเตรียมรูปภาพสำหรับการตรวจจับ
  Future<Map<String, dynamic>> _prepareImageForInference(img.Image image) async {
    try {
      print('กำลังเตรียมรูปภาพสำหรับการอนุมาน...');
      
      // 1. Resize ภาพให้มีขนาด INPUT_SIZE x INPUT_SIZE โดยรักษาอัตราส่วน
      final int originalWidth = image.width;
      final int originalHeight = image.height;
      
      // คำนวณสัดส่วนการ resize โดยรักษาอัตราส่วนภาพ
      final double scale = math.min(
        INPUT_SIZE / originalWidth,
        INPUT_SIZE / originalHeight
      );
      
      final int newWidth = (originalWidth * scale).round();
      final int newHeight = (originalHeight * scale).round();
      
      // ปรับขนาดภาพตามสัดส่วนที่คำนวณไว้
      final img.Image scaledImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear
      );
      
      // 2. สร้างรูปภาพขนาด INPUT_SIZE x INPUT_SIZE พร้อมพื้นที่ว่างสีดำ
      final img.Image paddedImage = img.Image(
        width: INPUT_SIZE,
        height: INPUT_SIZE,
        format: image.format,
      );
      
      // เติมสีดำลงใน paddedImage
      img.fill(paddedImage, color: img.ColorRgb8(0, 0, 0));
      
      // คำนวณตำแหน่งวางภาพตรงกลาง canvas
      final int offsetX = (INPUT_SIZE - newWidth) ~/ 2;
      final int offsetY = (INPUT_SIZE - newHeight) ~/ 2;
      
      // วางภาพที่ resize แล้วลงบน canvas ขนาด INPUT_SIZE x INPUT_SIZE
      img.compositeImage(paddedImage, scaledImage, dstX: offsetX, dstY: offsetY);
      
      // 3. บันทึกรูปที่ทำการ preprocess แล้วเพื่อตรวจสอบ
      String? resizedImagePath = await _saveDebugImage(paddedImage, 'preprocessed');
      
      // 4. แปลงรูปภาพเป็น tensor ในรูปแบบ [1, INPUT_SIZE, INPUT_SIZE, 3]
      var inputBuffer = List.filled(
        1 * INPUT_SIZE * INPUT_SIZE * 3, 
        0.0,
        growable: false
      );
      
      // 5. ใส่ข้อมูลรูปภาพลงใน tensor
      int bufferIndex = 0;
      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          final pixel = paddedImage.getPixel(x, y);
          
          // แปลงเป็นค่าระหว่าง 0-1 และจัดเรียงเป็น RGB
          inputBuffer[bufferIndex++] = pixel.r / 255.0; // Red
          inputBuffer[bufferIndex++] = pixel.g / 255.0; // Green
          inputBuffer[bufferIndex++] = pixel.b / 255.0; // Blue
        }
      }
      
      // 6. ปรับรูปร่าง tensor ให้ตรงกับ input ของโมเดล [1, INPUT_SIZE, INPUT_SIZE, 3]
      List<int> inputShape = [1, INPUT_SIZE, INPUT_SIZE, 3];
      var tensor = inputBuffer.reshape(inputShape);
      
      print('แปลงรูปภาพเป็น tensor สำเร็จ: $inputShape');
      return {
        'tensor': tensor,
        'resizedImagePath': resizedImagePath,
      };
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเตรียมรูปภาพ: $e');
      rethrow;
    }
  }

  /// ปรับรูปแบบ output ให้เป็นมาตรฐานสำหรับการประมวลผล
List<List<double>> _standardizeOutput(Map<int, dynamic> outputs) {
    try {
      List<List<double>> standardOutput = [];
      
      // ตรวจสอบว่ามีข้อมูลหรือไม่
      if (!outputs.containsKey(0)) {
        print('ไม่พบข้อมูล output ใน key 0');
        return standardOutput;
      }
      
      // ตรวจสอบรูปแบบของ output และแปลงให้อยู่ในรูปแบบเดียวกัน
      var output = outputs[0];
      
      // กรณี output เป็น [1, rows, cols]
      if (output is List && output.length == 1 && output[0] is List) {
        print('กำลังแปลง output รูปแบบ [1, rows, cols]');
        
        List<List<dynamic>> rawOutput = output[0] as List<List<dynamic>>;
        for (var row in rawOutput) {
          List<double> doubleRow = [];
          for (var val in row) {
            doubleRow.add(val is num ? val.toDouble() : 0.0);
          }
          standardOutput.add(doubleRow);
        }
      }
      // กรณี output เป็น [rows, cols]
      else if (output is List && output.length > 0 && output[0] is List) {
        print('กำลังแปลง output รูปแบบ [rows, cols]');
        
        List<List<dynamic>> rawOutput = output as List<List<dynamic>>;
        for (var row in rawOutput) {
          List<double> doubleRow = [];
          for (var val in row) {
            doubleRow.add(val is num ? val.toDouble() : 0.0);
          }
          standardOutput.add(doubleRow);
        }
      }
      // กรณีอื่นๆ (มีโอกาสน้อย)
      else {
        print('รูปแบบ output ไม่ตรงกับที่คาดหวัง: ${output.runtimeType}');
        // สร้าง output มาตรฐานที่ว่างเปล่า
      }
      
      return standardOutput;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการแปลง output เป็นรูปแบบมาตรฐาน: $e');
      return [];
    }
  }

    void _fillCircle(img.Image image, int x, int y, int radius, img.Color color) {
      // วาดวงกลมที่มีจุดศูนย์กลางที่ (x, y) และรัศมี radius
      for (int cx = -radius; cx <= radius; cx++) {
        for (int cy = -radius; cy <= radius; cy++) {
          if (cx * cx + cy * cy <= radius * radius) {
            int px = x + cx;
            int py = y + cy;
            if (px >= 0 && px < image.width && py >= 0 && py < image.height) {
              image.setPixel(px, py, color);
            }
          }
        }
      }
    }

  /// แปลง output จาก YOLOv8 เป็นรายการวัตถุที่ตรวจพบ
  List<DetectedObject> _processOutput(List<List<double>> output, int imageWidth, int imageHeight, {double confidenceThreshold = 0.25}) {
    List<DetectedObject> detections = [];
    
    try {
      // ตรวจสอบว่ามีข้อมูล output หรือไม่
      if (output.isEmpty || output[0].isEmpty) {
        print('ไม่มีข้อมูล output จากโมเดล');
        return [];
      }
      
      print('กำลังประมวลผล output จากโมเดล YOLOv8');
      
      // ดูว่า output มีกี่แถวและคอลัมน์
      final int rows = output.length;
      final int cols = output[0].length;
      
      print('ขนาด output: $rows แถว, $cols คอลัมน์');
      
      // ตรวจสอบว่าเป็นรูปแบบ output ของ YOLOv8 หรือไม่
      bool isYoloV8Format = rows >= 4 + NUM_CLASSES; // x, y, w, h, [class_scores] 
      
      if (!isYoloV8Format) {
        print('รูปแบบ output ไม่ตรงกับโมเดล YOLOv8');
        return [];
      }
      
      // ประมวลผลการตรวจจับจาก YOLOv8
      // แต่ละคอลัมน์แทนการตรวจจับหนึ่งรายการ
      for (int i = 0; i < cols; i++) {
        try {
          // ดึงความเชื่อมั่นของแต่ละคลาส
          List<double> classConfidences = [];
          for (int c = 0; c < NUM_CLASSES; c++) {
            double confidence = output[4 + c][i];
            classConfidences.add(confidence);
          }
          
          // หาคลาสที่มีความเชื่อมั่นสูงสุด
          int classId = -1;
          double maxConfidence = 0.0;
          
          for (int c = 0; c < classConfidences.length; c++) {
            if (classConfidences[c] > maxConfidence) {
              maxConfidence = classConfidences[c];
              classId = c;
            }
          }

          // ตรวจสอบว่าเกินค่า threshold หรือไม่
          if (maxConfidence < confidenceThreshold) {
            continue;
          }
          
          // ดึงค่าพิกัดกล่อง (normalized coordinates)
          double centerX = output[0][i]; // center_x
          double centerY = output[1][i]; // center_y
          double width = output[2][i];   // width
          double height = output[3][i];  // height
          
          // แปลงเป็นพิกัดจริงในรูปภาพ
          double boxX1 = (centerX - width / 2) * imageWidth;
          double boxY1 = (centerY - height / 2) * imageHeight;
          double boxX2 = (centerX + width / 2) * imageWidth;
          double boxY2 = (centerY + height / 2) * imageHeight;
          
          // จำกัดพิกัดไม่ให้เกินขอบภาพ
          boxX1 = math.max(0, math.min(boxX1, imageWidth.toDouble()));
          boxY1 = math.max(0, math.min(boxY1, imageHeight.toDouble()));
          boxX2 = math.max(0, math.min(boxX2, imageWidth.toDouble()));
          boxY2 = math.max(0, math.min(boxY2, imageHeight.toDouble()));
          
          // สร้าง Rect สำหรับ bounding box
          Rect boundingBox = Rect(
            left: boxX1,
            top: boxY1,
            right: boxX2,
            bottom: boxY2,
          );
          
          // คำนวณพิกัดเส้นตามประเภทของวัตถุ
          double x1, y1, x2, y2;
          
          if (classId == 0) {  // ความยาวลำตัว (Body Length)
            // เส้นแนวนอนตามความยาวลำตัว
            x1 = boxX1;
            y1 = (boxY1 + boxY2) / 2;
            x2 = boxX2;
            y2 = y1;
          } 
          else if (classId == 1) {  // รอบอก (Heart Girth)
            // เส้นแนวตั้งตามรอบอก
            x1 = (boxX1 + boxX2) / 2;
            y1 = boxY1;
            x2 = x1;
            y2 = boxY2;
          } 
          else {  // จุดอ้างอิง (Yellow Mark)
            // เส้นแนวนอนตามจุดอ้างอิง
            x1 = boxX1;
            y1 = (boxY1 + boxY2) / 2;
            x2 = boxX2;
            y2 = y1;
          }
          
          // ดึงชื่อคลาส
          String className = _getClassNameFromId(classId);
          
          // เพิ่มวัตถุที่ตรวจพบ
          detections.add(DetectedObject(
            classId: classId,
            className: className,
            confidence: maxConfidence,
            x1: x1,
            y1: y1,
            x2: x2,
            y2: y2,
            boundingBox: boundingBox,
          ));
          
          print('ตรวจพบ $className (id: $classId): ความเชื่อมั่น ${(maxConfidence * 100).toStringAsFixed(1)}%');
        } catch (innerError) {
          print('เกิดข้อผิดพลาดในการประมวลผลการตรวจจับที่ $i: $innerError');
          continue;
        }
      }
      
      print('ตรวจพบวัตถุทั้งหมด ${detections.length} รายการ');
      return detections;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
      return [];
    }
  }
  
  /// ดึงชื่อคลาสจาก classId ของแอป
  String _getClassNameFromId(int classId) {
    switch (classId) {
      case 0: return 'ความยาวลำตัว';   // Body Length
      case 1: return 'รอบอก';          // Heart Girth
      case 2: return 'จุดอ้างอิง';      // Yellow Mark
      default: return 'Unknown_$classId';
    }
  }

  /// บันทึกรูปภาพสำหรับการตรวจสอบความถูกต้องและคืนค่าพาธของไฟล์
  Future<String?> _saveDebugImage(img.Image image, String prefix) async {
    try {
      // สร้าง timestamp เพื่อป้องกันการบันทึกทับไฟล์เดิม
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      // ใช้ getApplicationDocumentsDirectory ซึ่งเป็นที่นิยมใช้ทั้งใน iOS และ Android
      final appDir = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${appDir.path}/cattle_debug_images');
      
      // สร้างโฟลเดอร์ถ้ายังไม่มี
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }
      
      // กำหนดพาธของไฟล์
      final filePath = '${debugDir.path}/${prefix}_${timestamp}.jpg';
      
      // บันทึกเป็นไฟล์ JPG ด้วยคุณภาพสูง
      final File outputFile = File(filePath);
      final List<int> jpgBytes = img.encodeJpg(image, quality: 95);
      await outputFile.writeAsBytes(jpgBytes);
      
      print('บันทึกรูปภาพตรวจสอบที่: $filePath');
      return filePath;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกรูปภาพตรวจสอบ: $e');
      return null;
    }
  }

  /// ปล่อยทรัพยากรเมื่อไม่ใช้งานแล้ว
  void dispose() {
    try {
      if (_interpreter != null) {
        _interpreter!.close();
        _interpreter = null;
        _modelLoaded = false;
        print('ปล่อยทรัพยากรของโมเดลเรียบร้อยแล้ว');
      }
    } catch (e) {
      print('เกิดข้อผิดพลาดในการปล่อยทรัพยากร: $e');
    }
  }

  /// สร้างการตรวจจับจำลองสำหรับการทดสอบ
  Future<DetectionResult> createMockDetection(File imageFile) async {
    try {
      print('กำลังสร้างการตรวจจับจำลอง...');
      
      // อ่านขนาดรูปภาพ
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        print('ไม่สามารถอ่านรูปภาพได้สำหรับการสร้างการตรวจจับจำลอง');
        return DetectionResult(
          success: false,
          error: 'ไม่สามารถอ่านรูปภาพได้',
        );
      }
      
      // Resize รูปภาพเพื่อลดขนาด
      final resizedImage = await _resizeImageIfNeeded(imageFile);
      final resizedImageBytes = await resizedImage.readAsBytes();
      final resizedImagePath = resizedImage.path;
      
      // สร้างการตรวจจับแบบจำลอง
      return DetectionResult.createFullDetection(
        originalImage.width,
        originalImage.height,
      );
    } catch (e) {
      print('เกิดข้อผิดพลาดในการสร้างการตรวจจับจำลอง: $e');
      return DetectionResult(
        success: false,
        error: 'เกิดข้อผิดพลาดในการสร้างการตรวจจับจำลอง: $e',
      );
    }
  }

  /// วาดเส้นและกรอบการตรวจจับลงบนรูปภาพ
  Future<File?> drawDetectionLines(File imageFile, List<DetectedObject> detectedObjects) async {
    try {
      print('กำลังวาดเส้นการตรวจจับลงบนรูปภาพ...');
      
      // อ่านรูปภาพต้นฉบับ
      final imageBytes = await imageFile.readAsBytes();
      final originalImage = img.decodeImage(imageBytes);
      
      if (originalImage == null) {
        print('ไม่สามารถอ่านรูปภาพสำหรับการวาดเส้น');
        return null;
      }
      
      // สร้างสำเนาของรูปภาพเพื่อวาดเส้น
      final resultImage = img.copyResize(originalImage);
      
      // วาดกรอบและเส้นสำหรับแต่ละวัตถุที่ตรวจพบ
      for (var object in detectedObjects) {
        final classId = object.classId;
        final x1 = object.x1.round();
        final y1 = object.y1.round();
        final x2 = object.x2.round();
        final y2 = object.y2.round();
        
        // กำหนดสีตามประเภทของวัตถุ
        img.Color lineColor;
        
        switch (classId) {
          case 0: // ความยาวลำตัว (Body Length)
            lineColor = img.ColorRgb8(0, 255, 0); // สีเขียว
            break;
          case 1: // รอบอก (Heart Girth)
            lineColor = img.ColorRgb8(255, 0, 0); // สีแดง
            break;
          case 2: // จุดอ้างอิง (Yellow Mark)
            lineColor = img.ColorRgb8(255, 255, 0); // สีเหลือง
            break;
          default:
            lineColor = img.ColorRgb8(0, 0, 255); // สีน้ำเงิน
        }
        
        // วาดเส้น - ใช้วิธีวาดตามพิกัด
        _drawLine(resultImage, x1, y1, x2, y2, lineColor);
        
        // วาดกรอบ bounding box ถ้ามี
        if (object.boundingBox != null) {
          final left = object.boundingBox!.left.round();
          final top = object.boundingBox!.top.round();
          final right = object.boundingBox!.right.round();
          final bottom = object.boundingBox!.bottom.round();
          
          _drawRectangle(resultImage, left, top, right, bottom, lineColor);
        }
        
        // วาดป้ายข้อความแสดงชื่อคลาสและความเชื่อมั่น
        String label = '${object.className} (${(object.confidence * 100).toStringAsFixed(1)}%)';
        
        // ตำแหน่งของข้อความ
        int textX = x1;
        int textY = y1 - 10; // วางข้อความเหนือเส้น
        
        // ให้ข้อความอยู่ในภาพเสมอ
        if (textY < 10) textY = 10;
        
        // วาดข้อความลงบนรูปภาพ (ใช้ฟังก์ชันช่วยสำหรับการวาดข้อความ)
        _drawText(resultImage, label, textX, textY, lineColor);
      }
      
      // บันทึกรูปภาพผลลัพธ์
      final tempDir = await getTemporaryDirectory();
      final resultPath = '${tempDir.path}/detection_result_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final resultFile = File(resultPath);
      
      // บันทึกเป็นไฟล์ JPEG
      await resultFile.writeAsBytes(img.encodeJpg(resultImage, quality: 95));
      
      print('บันทึกรูปภาพผลลัพธ์ที่: $resultPath');
      return resultFile;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวาดเส้นการตรวจจับ: $e');
      return null;
    }
  }

  /// ฟังก์ชันช่วยสำหรับการวาดเส้นตรงระหว่างจุดสองจุด
  void _drawLine(img.Image image, int x1, int y1, int x2, int y2, img.Color color) {
    // ใช้ Bresenham's line algorithm สำหรับการวาดเส้น
    int dx = (x2 - x1).abs();
    int dy = (y2 - y1).abs();
    int sx = x1 < x2 ? 1 : -1;
    int sy = y1 < y2 ? 1 : -1;
    int err = dx - dy;
    
    int thickness = 2; // ความหนาของเส้น
    
    while (true) {
      // วาดจุดหนา ๆ เพื่อเป็นเส้น
      for (int i = -thickness ~/ 2; i <= thickness ~/ 2; i++) {
        for (int j = -thickness ~/ 2; j <= thickness ~/ 2; j++) {
          if (x1 + i >= 0 && x1 + i < image.width && y1 + j >= 0 && y1 + j < image.height) {
            image.setPixel(x1 + i, y1 + j, color);
          }
        }
      }
      
      if (x1 == x2 && y1 == y2) break;
      int e2 = 2 * err;
      if (e2 > -dy) {
        err -= dy;
        x1 += sx;
      }
      if (e2 < dx) {
        err += dx;
        y1 += sy;
      }
    }
  }
  
  /// ฟังก์ชันช่วยสำหรับการวาดสี่เหลี่ยม
  void _drawRectangle(img.Image image, int left, int top, int right, int bottom, img.Color color) {
    // วาดเส้นทั้ง 4 ด้านของสี่เหลี่ยม
    _drawLine(image, left, top, right, top, color); // ด้านบน
    _drawLine(image, left, bottom, right, bottom, color); // ด้านล่าง
    _drawLine(image, left, top, left, bottom, color); // ด้านซ้าย
    _drawLine(image, right, top, right, bottom, color); // ด้านขวา
  }
  
  /// ฟังก์ชันช่วยสำหรับการวาดข้อความบนรูปภาพ
  void _drawText(img.Image image, String text, int x, int y, img.Color color) {
    // ขนาดตัวอักษร (ขนาดพิกเซล)
    final int letterWidth = 5;
    final int letterHeight = 7;
    final int spacing = 2;
    
    int currentX = x;
    
    // วาดพื้นหลังสำหรับข้อความ (แบบพื้นที่สี่เหลี่ยมทึบ)
    int backgroundWidth = text.length * (letterWidth + spacing);
    int backgroundHeight = letterHeight + 4;
    
    for (int bx = currentX - 2; bx < currentX + backgroundWidth; bx++) {
      for (int by = y - 2; by < y + backgroundHeight; by++) {
        if (bx >= 0 && bx < image.width && by >= 0 && by < image.height) {
          // พื้นหลังสีดำโปร่งใส
          image.setPixel(bx, by, img.ColorRgb8(0, 0, 0));
        }
      }
    }
    
    // วาดข้อความแบบง่ายๆ (เป็นจุดเล็กๆ)
    for (int i = 0; i < text.length; i++) {
      // แทนที่จะวาดตัวอักษรจริง เราวาดเป็นจุดเล็กๆ แทน
      int dotX = currentX + (letterWidth ~/ 2);
      int dotY = y + (letterHeight ~/ 2);
      
      if (dotX >= 0 && dotX < image.width && dotY >= 0 && dotY < image.height) {
        // วาดจุดสีตามข้อความ
        for (int dx = -1; dx <= 1; dx++) {
          for (int dy = -1; dy <= 1; dy++) {
            if (dotX + dx >= 0 && dotX + dx < image.width && dotY + dy >= 0 && dotY + dy < image.height) {
              image.setPixel(dotX + dx, dotY + dy, color);
            }
          }
        }
      }
      
      currentX += letterWidth + spacing;
    }
  }
  
}

/// คลาสสร้างพารามิเตอร์สำหรับการตรวจจับ
class DetectionConfig {
  // ขนาด input ของโมเดล
  final int inputSize;
  
  // ขนาด batch (ปกติเป็น 1)
  final int batchSize;
  
  // ค่า mean สำหรับการปรับค่าพิกเซล
  final List<double> mean;
  
  // ค่า std สำหรับการปรับค่าพิกเซล
  final List<double> std;
  
  // ชื่อของ input tensor
  final String inputTensorName;
  
  // ชื่อของ output tensor
  final List<String> outputTensorNames;
  
  // จำนวนคลาสทั้งหมด
  final int numClasses;
  
  // ค่า threshold สำหรับการกรองผลลัพธ์
  final double confidenceThreshold;
  
  // ขนาดสูงสุดที่ยอมรับได้ของรูปภาพ (เพื่อประสิทธิภาพ)
  final int maxImageDimension;
  
  DetectionConfig({
    this.inputSize = 1280,
    this.batchSize = 1,
    this.mean = const [0.0, 0.0, 0.0],
    this.std = const [1.0, 1.0, 1.0],
    this.inputTensorName = 'images',
    this.outputTensorNames = const ['output0'],
    this.numClasses = 3,
    this.confidenceThreshold = 0.25,
    this.maxImageDimension = 1200,
  });
  
  // สร้าง config จาก map
  factory DetectionConfig.fromMap(Map<String, dynamic> map) {
    return DetectionConfig(
      inputSize: map['input_size'] ?? 1280,
      batchSize: map['batch_size'] ?? 1,
      mean: List<double>.from(map['mean'] ?? [0.0, 0.0, 0.0]),
      std: List<double>.from(map['std'] ?? [1.0, 1.0, 1.0]),
      inputTensorName: map['input_tensor_name'] ?? 'images',
      outputTensorNames: List<String>.from(map['output_tensor_names'] ?? ['output0']),
      numClasses: map['num_classes'] ?? 3,
      confidenceThreshold: map['confidence_threshold'] ?? 0.25,
      maxImageDimension: map['max_image_dimension'] ?? 1200,
    );
  }
  
  // แปลงเป็น map
  Map<String, dynamic> toMap() {
    return {
      'input_size': inputSize,
      'batch_size': batchSize,
      'mean': mean,
      'std': std,
      'input_tensor_name': inputTensorName,
      'output_tensor_names': outputTensorNames,
      'num_classes': numClasses,
      'confidence_threshold': confidenceThreshold,
      'max_image_dimension': maxImageDimension,
    };
  }
}

/// คลาส Size สำหรับเก็บข้อมูลขนาด
class Size {
  final double width;
  final double height;
  
  Size(this.width, this.height);
  
  @override
  String toString() {
    return 'Size(${width.toStringAsFixed(1)} x ${height.toStringAsFixed(1)})';
  }
  
  // คำนวณอัตราส่วน
  double get aspectRatio => width / height;
  
  // คำนวณพื้นที่
  double get area => width * height;
  
  // สร้าง Size ใหม่โดยคูณด้วยสเกลแฟคเตอร์
  Size scale(double factor) {
    return Size(width * factor, height * factor);
  }
  
  // สร้าง Size ใหม่โดยจำกัดขนาดสูงสุด แต่รักษาอัตราส่วน
  Size constrainDimension(double maxDimension) {
    if (width <= maxDimension && height <= maxDimension) {
      return this;
    }
    
    double scaleFactor = maxDimension / math.max(width, height);
    return Size(width * scaleFactor, height * scaleFactor);
  }
}