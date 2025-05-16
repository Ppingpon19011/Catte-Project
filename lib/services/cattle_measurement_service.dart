import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'dart:ui' as ui;
import '../utils/cattle_detector.dart' as detector;
import '../utils/weight_calculator.dart';

// สร้างคลาส CattleMeasurementService 
class CattleMeasurementService {
  static final CattleMeasurementService _instance = CattleMeasurementService._internal();
  factory CattleMeasurementService() => _instance;
  CattleMeasurementService._internal();
  
  final detector.CattleDetector _detector = detector.CattleDetector();

  Future<File> resizeImageForDisplay(File imageFile, {int maxWidth = 800, int maxHeight = 800}) async {
    try {
      // อ่านข้อมูลภาพ
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      
      if (image == null) return imageFile;
      
      // ตรวจสอบว่าจำเป็นต้องปรับขนาดหรือไม่
      if (image.width <= maxWidth && image.height <= maxHeight) {
        return imageFile; // ไม่จำเป็นต้องปรับขนาด
      }
      
      // คำนวณขนาดใหม่โดยรักษาสัดส่วนภาพ
      int newWidth = image.width;
      int newHeight = image.height;
      
      if (image.width > maxWidth) {
        newWidth = maxWidth;
        newHeight = (image.height * maxWidth ~/ image.width);
      }
      
      if (newHeight > maxHeight) {
        newHeight = maxHeight;
        newWidth = (image.width * maxHeight ~/ image.height);
      }
      
      // ปรับขนาดภาพ
      final resizedImage = img.copyResize(
        image,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.linear,
      );
      
      // บันทึกภาพขนาดใหม่
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'resized_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${appDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(resizedImage, quality: 85));
      
      print('ปรับขนาดภาพจาก ${image.width}x${image.height} เป็น ${newWidth}x${newHeight}');
      return file;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการปรับขนาดภาพ: $e');
      return imageFile; // กรณีเกิดข้อผิดพลาด ให้ใช้ภาพเดิม
    }
  }
  
  // ติดตั้งโมเดลตรวจจับ
  Future<bool> initialize() async {
    try {
      print('เริ่มต้นการทำงานของ CattleMeasurementService');
      bool result = await _detector.loadModel();
      print('ผลการโหลดโมเดล: $result');
      return result;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการเริ่มต้น CattleMeasurementService: $e');
      // แสดงข้อความแจ้งเตือนให้ผู้ใช้ทราบ
      Fluttertoast.showToast(
        msg: "ไม่สามารถเริ่มต้นระบบวิเคราะห์ภาพได้ จะใช้การวัดด้วยตนเอง",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      return false;
    }
  }
  
  //เมธอด analyzeImage สำหรับวิเคราะห์ภาพและประมาณน้ำหนัก
  /// วิเคราะห์ภาพและประมาณน้ำหนักโค
  Future<MeasurementResult> analyzeImage(
    File imageFile,
    String breed,
    String gender,
    int ageMonths,
    [Map<String, dynamic>? options] // พารามิเตอร์เสริม
  ) async {
    try {
      print('เริ่มต้นวิเคราะห์ภาพ...');
      
      // ตรวจสอบว่าไฟล์ภาพมีอยู่จริงและอ่านได้
      if (!await imageFile.exists()) {
        return MeasurementResult(
          success: false,
          error: 'ไม่พบไฟล์ภาพ',
        );
      }
      
      // ปรับขนาดภาพถ้าจำเป็น (ลดขนาดไฟล์ใหญ่)
      if (options != null && options['resize'] == true) {
        imageFile = await resizeImageForDisplay(imageFile);
      }
      
      // ใช้ CattleDetector สำหรับตรวจจับวัตถุในภาพ
      final detectionResult = await _detector.detectCattle(imageFile);
      
      // ถ้าไม่พบวัตถุหรือไม่สำเร็จ
      if (!detectionResult.success || detectionResult.objects == null || detectionResult.objects!.isEmpty) {
        print('การตรวจจับวัตถุไม่สำเร็จ กรุณาวัดด้วยตนเอง');
        return MeasurementResult(
          success: false,
          error: 'การตรวจจับวัตถุไม่สำเร็จ กรุณาวัดด้วยตนเอง',
          detectionResult: detectionResult, // ส่งผลลัพธ์การตรวจจับบางส่วนกลับไปด้วย
        );
      }
      
      // ตรวจสอบว่ามีวัตถุที่ต้องการครบถ้วนหรือไม่
      bool hasYellowMark = false;
      bool hasHeartGirth = false;
      bool hasBodyLength = false;
      
      detector.DetectedObject? yellowMarkObj;
      detector.DetectedObject? heartGirthObj;
      detector.DetectedObject? bodyLengthObj;
      
      // เลือกวัตถุที่มีความเชื่อมั่นสูงสุดสำหรับแต่ละประเภท
      Map<int, detector.DetectedObject> bestObjects = {};
      
      for (var obj in detectionResult.objects!) {
        int classId = obj.classId;
        
        // ถ้ายังไม่มีวัตถุประเภทนี้ หรือวัตถุนี้มีความเชื่อมั่นสูงกว่าที่มีอยู่
        if (!bestObjects.containsKey(classId) || 
            obj.confidence > bestObjects[classId]!.confidence) {
          bestObjects[classId] = obj;
        }
        
        // บันทึกว่าพบวัตถุประเภทนี้แล้ว
        if (classId == 0) hasYellowMark = true;      // จุดอ้างอิง
        else if (classId == 1) hasHeartGirth = true; // รอบอก
        else if (classId == 2) hasBodyLength = true; // ความยาวลำตัว
      }
      
      // ดึงวัตถุที่ดีที่สุดสำหรับแต่ละประเภท
      if (hasYellowMark) yellowMarkObj = bestObjects[0];
      if (hasHeartGirth) heartGirthObj = bestObjects[1];
      if (hasBodyLength) bodyLengthObj = bestObjects[2];
      
      // ถ้าไม่พบวัตถุครบทั้ง 3 ประเภท ให้ผู้ใช้วัดเอง
      if (!hasYellowMark || !hasHeartGirth || !hasBodyLength) {
        print('ไม่พบวัตถุครบทั้ง 3 ประเภท กรุณาวัดด้วยตนเอง');
        
        // สร้างข้อความแจ้งเตือนที่ระบุว่าขาดวัตถุประเภทใด
        List<String> missingObjects = [];
        if (!hasYellowMark) missingObjects.add("จุดอ้างอิง");
        if (!hasHeartGirth) missingObjects.add("รอบอก");
        if (!hasBodyLength) missingObjects.add("ความยาวลำตัว");
        
        String errorMsg = 'ไม่พบ ${missingObjects.join(", ")} ในภาพ กรุณาวัดด้วยตนเอง';
        
        return MeasurementResult(
          success: false,
          error: errorMsg,
          detectionResult: detectionResult, // ส่งผลลัพธ์การตรวจจับบางส่วนกลับไปด้วย
        );
      }
      
      // คำนวณขนาดจริงในหน่วยเซนติเมตร
      double yellowMarkWidthCm = WeightCalculator.REFERENCE_MARK_LENGTH_CM; // ความยาวจุดอ้างอิงเป็น 100 ซม.
      
      // คำนวณระยะห่างระหว่างจุดของจุดอ้างอิง
      double yellowMarkPixelLength = math.sqrt(
        math.pow(yellowMarkObj!.x2 - yellowMarkObj.x1, 2) + 
        math.pow(yellowMarkObj.y2 - yellowMarkObj.y1, 2)
      );
      
      // อัตราส่วนพิกเซลต่อเซนติเมตร (ใช้สำหรับแปลงหน่วย)
      double pixelToCmRatio = yellowMarkPixelLength / yellowMarkWidthCm;
      print('อัตราส่วนการแปลงหน่วย: $pixelToCmRatio พิกเซล/ซม.');
      
      // ตรวจสอบอัตราส่วนว่าสมเหตุสมผลหรือไม่
      if (pixelToCmRatio <= 0 || pixelToCmRatio > 50) {
        print('อัตราส่วนการแปลงหน่วยไม่สมเหตุสมผล: $pixelToCmRatio พิกเซล/ซม.');
        return MeasurementResult(
          success: false,
          error: 'การวัดจุดอ้างอิงไม่ถูกต้อง กรุณาวัดด้วยตนเอง',
          detectionResult: detectionResult,
        );
      }
      
      // คำนวณความยาวของเส้นรอบอกและความยาวลำตัวในหน่วยพิกเซล
      double heartGirthPixels = math.sqrt(
        math.pow(heartGirthObj!.x2 - heartGirthObj.x1, 2) + 
        math.pow(heartGirthObj.y2 - heartGirthObj.y1, 2)
      );
      
      double bodyLengthPixels = math.sqrt(
        math.pow(bodyLengthObj!.x2 - bodyLengthObj.x1, 2) + 
        math.pow(bodyLengthObj.y2 - bodyLengthObj.y1, 2)
      );
      
      // แปลงจากพิกเซลเป็นเซนติเมตร
      double heartGirthCm = heartGirthPixels / pixelToCmRatio;
      double bodyLengthCm = bodyLengthPixels / pixelToCmRatio;
      
      // คำนวณเส้นรอบวงของรอบอกโดยใช้สูตรเส้นรอบวงวงกลม
      double heartGirthCircumference = WeightCalculator.calculateHeartGirthFromHeight(heartGirthCm);
      
      // บันทึกข้อมูลการคำนวณเพื่อตรวจสอบ
      print('การวัดในหน่วยพิกเซล:');
      print('- จุดอ้างอิง: ${yellowMarkPixelLength.toStringAsFixed(1)} พิกเซล');
      print('- รอบอก: ${heartGirthPixels.toStringAsFixed(1)} พิกเซล');
      print('- ความยาวลำตัว: ${bodyLengthPixels.toStringAsFixed(1)} พิกเซล');
      
      print('การวัดในหน่วยเซนติเมตร:');
      print('- จุดอ้างอิง: ${yellowMarkWidthCm} ซม.');
      print('- รอบอก (ความสูง): ${heartGirthCm.toStringAsFixed(1)} ซม.');
      print('- รอบอก (เส้นรอบวง): ${heartGirthCircumference.toStringAsFixed(1)} ซม.');
      print('- ความยาวลำตัว: ${bodyLengthCm.toStringAsFixed(1)} ซม.');
      
      // แปลงหน่วยจากเซนติเมตรเป็นนิ้ว (สำหรับคำนวณน้ำหนัก)
      double bodyLengthInches = WeightCalculator.cmToInches(bodyLengthCm);
      double heartGirthInches = WeightCalculator.cmToInches(heartGirthCircumference);
      
      print('การวัดในหน่วยนิ้ว:');
      print('- รอบอก: ${heartGirthInches.toStringAsFixed(1)} นิ้ว');
      print('- ความยาวลำตัว: ${bodyLengthInches.toStringAsFixed(1)} นิ้ว');
      
      // คำนวณน้ำหนักโดยใช้สูตรของ WeightCalculator
      double weightInKg = WeightCalculator.calculateWeight(heartGirthInches, bodyLengthInches);
      
      // ปรับค่าน้ำหนักตามอายุและเพศของโค
      double adjustedWeight = WeightCalculator.adjustWeightByAgeAndGender(
        weightInKg,
        gender,
        ageMonths,
      );
      
      // คำนวณความเชื่อมั่น
      double confidence = _calculateConfidence(detectionResult);
      
      // บันทึกข้อมูลการคำนวณน้ำหนัก
      print('น้ำหนักที่คำนวณได้:');
      print('- น้ำหนักดิบ: ${weightInKg.toStringAsFixed(1)} กก.');
      print('- น้ำหนักปรับแล้ว: ${adjustedWeight.toStringAsFixed(1)} กก.');
      print('- ความเชื่อมั่น: ${(confidence * 100).toStringAsFixed(1)}%');
      
      // ตรวจสอบว่าน้ำหนักเป็นไปได้หรือไม่
      if (adjustedWeight <= 0 || adjustedWeight > 2000) {
        print('น้ำหนักที่คำนวณได้ไม่อยู่ในช่วงที่เป็นไปได้: $adjustedWeight กก.');
        return MeasurementResult(
          success: false,
          error: 'น้ำหนักที่คำนวณได้ไม่สมเหตุสมผล กรุณาวัดด้วยตนเอง',
          detectionResult: detectionResult,
          heartGirth: heartGirthCircumference,
          bodyLength: bodyLengthCm,
        );
      }
      
      return MeasurementResult(
        success: true,
        heartGirth: heartGirthCircumference,
        bodyLength: bodyLengthCm,
        height: null, // ไม่ได้วัดความสูง
        rawWeight: weightInKg,
        adjustedWeight: adjustedWeight,
        confidence: confidence,
        detectionResult: detectionResult,
      );
      
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e');
      return MeasurementResult(
        success: false,
        error: 'เกิดข้อผิดพลาดในการวิเคราะห์ภาพ: $e',
      );
    }
  }
  
  // คำนวณความเชื่อมั่นจากผลการตรวจจับ
  double _calculateConfidence(detector.DetectionResult detectionResult) {
    double confidence = 0.8; // ค่าเริ่มต้น
    
    try {
      // ใช้ค่าความเชื่อมั่นเฉลี่ยของวัตถุที่ตรวจพบ
      if (detectionResult.objects != null && detectionResult.objects!.isNotEmpty) {
        double sum = 0;
        for (var obj in detectionResult.objects!) {
          sum += obj.confidence;
        }
        confidence = sum / detectionResult.objects!.length;
      }
      
      // ปรับให้อยู่ในช่วง 0.7-0.95
      confidence = 0.7 + (confidence * 0.25);
      if (confidence > 0.95) confidence = 0.95;
      if (confidence < 0.7) confidence = 0.7;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการคำนวณความเชื่อมั่น: $e');
    }
    
    return confidence;
  }
  
  // เพิ่มเมธอด saveAnalyzedImage เพื่อบันทึกภาพที่มีการวิเคราะห์แล้ว
  Future<File?> saveAnalyzedImage(
    File originalImage,
    detector.DetectionResult detectionResult,
    [Map<String, dynamic>? options] // เพิ่มพารามิเตอร์ที่ 3 เป็น optional parameter
  ) async {
    try {
      if (detectionResult.objects == null || detectionResult.objects!.isEmpty) {
        return originalImage;
      }
      
      // อ่านข้อมูลภาพ
      final imageBytes = await originalImage.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('ไม่สามารถอ่านรูปภาพได้');
        return originalImage;
      }
      
      // สร้างภาพใหม่โดยวาดกรอบและป้ายกำกับ
      final analyzedImage = img.copyResize(image, width: image.width, height: image.height);
      
      // วาดกรอบและป้ายกำกับลงบนภาพ
      for (var object in detectionResult.objects!) {
        // กำหนดสีตามประเภทของวัตถุ
        img.Color color;
        if (object.classId == 0) { // Yellow_Mark (จุดอ้างอิง)
          color = img.ColorRgb8(255, 255, 0); // เหลือง
        } else if (object.classId == 1) { // Heart_Girth (รอบอก)
          color = img.ColorRgb8(255, 0, 0); // แดง
        } else if (object.classId == 2) { // Body_Length (ความยาวลำตัว)
          color = img.ColorRgb8(0, 0, 255); // น้ำเงิน
        } else {
          color = img.ColorRgb8(128, 128, 128); // เทา
        }
        
        // วาดเส้นระหว่างจุดเริ่มต้นและจุดสิ้นสุด
        img.drawLine(
          analyzedImage,
          x1: object.x1.toInt(),
          y1: object.y1.toInt(),
          x2: object.x2.toInt(),
          y2: object.y2.toInt(),
          color: color,
          thickness: 3,
        );
        
        // วาดจุดที่ปลายทั้งสองของเส้น
        img.fillCircle(
          analyzedImage,
          x: object.x1.toInt(),
          y: object.y1.toInt(),
          radius: 5,
          color: color,
        );
        
        img.fillCircle(
          analyzedImage,
          x: object.x2.toInt(),
          y: object.y2.toInt(),
          radius: 5,
          color: color,
        );
      }
      
      // บันทึกภาพลงไฟล์ใหม่
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'analyzed_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '${appDir.path}/$fileName';
      
      final file = File(filePath);
      await file.writeAsBytes(img.encodeJpg(analyzedImage, quality: 90));
      
      print('บันทึกภาพที่วิเคราะห์แล้วที่: $filePath');
      return file;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกภาพที่วิเคราะห์แล้ว: $e');
      return originalImage;
    }
  }
}

// คลาสสำหรับเก็บผลลัพธ์การวัด
class MeasurementResult {
  final bool success;
  final double? heartGirth;
  final double? bodyLength;
  final double? height;
  final double? rawWeight;
  final double? adjustedWeight;
  final double? confidence;
  final String? error;
  final detector.DetectionResult? detectionResult;
  
  MeasurementResult({
    required this.success,
    this.heartGirth,
    this.bodyLength,
    this.height,
    this.rawWeight,
    this.adjustedWeight,
    this.confidence,
    this.error,
    this.detectionResult,
  });
  
  // แปลงเป็น Map
  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'heart_girth': heartGirth,
      'body_length': bodyLength,
      'height': height,
      'raw_weight': rawWeight,
      'adjusted_weight': adjustedWeight,
      'confidence': confidence,
      'error': error,
    };
  }
}