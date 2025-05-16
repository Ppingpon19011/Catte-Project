import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/enhanced_measurement_painter.dart';

/// คลาสสำหรับตรวจจับโคด้วยโมเดล YOLOv8 แปลงเป็น TFLite
class CattleDetector {
  // ชื่อไฟล์โมเดลที่ใช้ (ให้ตรงกับที่กำหนดใน pubspec.yaml)
  static const String MODEL_FILE_NAME = 'best_model_float32.tflite';
  static const int INPUT_SIZE = 640; // ขนาด input ของโมเดล YOLOv8

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
      
      // แปลงรูปภาพให้เป็นรูปแบบที่เหมาะสมกับโมเดล
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('ไม่สามารถอ่านรูปภาพได้');
        return DetectionResult(
          success: false,
          error: 'ไม่สามารถอ่านรูปภาพได้',
        );
      }
      
      try {
        // แปลงรูปภาพเป็น tensor และบันทึกรูปที่ resize แล้ว
        var result = await _imageToTensor(image);
        var inputTensor = result['tensor'];
        var resizedImagePath = result['resizedImagePath'];
        
        try {
          // ดึงข้อมูลเกี่ยวกับ output shape ของโมเดล
          var outputShape = _interpreter!.getOutputTensor(0).shape;
          print('รูปแบบ output tensor: $outputShape');
          
          // สร้าง buffer สำหรับเก็บผลลัพธ์
          var outputBuffer;
          
          // สร้าง buffer ที่เหมาะสมกับโมเดล YOLOv8
          if (outputShape.length == 3) {
            // รูปแบบ [1, 84, 8400] สำหรับ YOLOv8
            final int rows = outputShape[1]; // คาดว่าเป็น 84 (4+1+คลาส)
            final int cols = outputShape[2]; // คาดว่าเป็น 8400 (จำนวนการทำนาย)
            
            print('กำลังสร้าง tensor 3 มิติขนาด ${outputShape[0]}x${rows}x${cols}');
            outputBuffer = List.filled(
              outputShape[0], 
              List.filled(
                rows,
                List.filled(cols, 0.0, growable: false),
                growable: false
              ),
              growable: false
            );
          } else if (outputShape.length == 2) {
            // รูปแบบ [84, 8400] สำหรับบางเวอร์ชัน
            print('กำลังสร้าง tensor 2 มิติขนาด ${outputShape[0]}x${outputShape[1]}');
            outputBuffer = List.filled(
              outputShape[0],
              List.filled(outputShape[1], 0.0, growable: false),
              growable: false
            );
          } else {
            print('รูปแบบ output (${outputShape.length} มิติ) ไม่ตรงกับที่คาดหวัง');
            return DetectionResult(
              success: false,
              error: 'รูปแบบ output ไม่ตรงกับที่คาดหวัง',
              resizedImagePath: resizedImagePath,
            );
          }
          
          // รัน inference
          print('กำลังรัน inference...');
          
          try {
            print('รูปแบบ tensor ก่อนส่งเข้า inference: ${inputTensor.runtimeType}');
            print('ตัวอย่างค่าใน inputTensor[0][0][0]: ${inputTensor[0][0][0]}');

            _interpreter!.run(inputTensor, outputBuffer);
            print('รัน inference สำเร็จ');
            
            // แสดงตัวอย่างค่าใน outputBuffer เพื่อดีบัก
            print('ตัวอย่างค่าใน outputBuffer:');
            if (outputShape.length == 3) {
              print('ตัวอย่างค่า [0][0][0]: ${outputBuffer[0][0][0]}');
              print('ตัวอย่างค่า [0][4][0]: ${outputBuffer[0][4][0]}');
              
              // เพิ่มการแสดงค่าในช่วงคลาส
              if (outputBuffer[0].length > 5) {
                for (int i = 5; i < math.min(8, outputBuffer[0].length); i++) {
                  print('ตัวอย่างค่าคลาส [0][$i][0]: ${outputBuffer[0][i][0]}');
                }
              }
            } else if (outputShape.length == 2) {
              print('ตัวอย่างค่า [0][0]: ${outputBuffer[0][0]}');
              print('ตัวอย่างค่า [4][0]: ${outputBuffer[4][0]}');
              
              // เพิ่มการแสดงค่าในช่วงคลาส
              if (outputBuffer.length > 5) {
                for (int i = 5; i < math.min(8, outputBuffer.length); i++) {
                  print('ตัวอย่างค่าคลาส [$i][0]: ${outputBuffer[i][0]}');
                }
              }
            }
            
          } catch (runError) {
            print('ไม่สามารถรัน inference ได้: $runError');
            return DetectionResult(
              success: false,
              error: 'ไม่สามารถรัน inference ได้: $runError',
              resizedImagePath: resizedImagePath,
            );
          }
          
          // แปลงผลลัพธ์เป็น DetectedObject - ลดค่า confidence threshold ลงเพื่อให้ตรวจจับได้ง่ายขึ้น
          List<DetectedObject> detectionResults = _processOutput(
            outputBuffer, 
            image.width, 
            image.height, 
            confidenceThreshold: 0.15 // ลดค่าความเชื่อมั่นลงเพื่อให้ตรวจจับได้ง่ายขึ้น
          );
          
          // ตรวจสอบผลการตรวจจับ
          if (detectionResults.isEmpty) {
            print('ไม่พบวัตถุในภาพ กรุณาวัดด้วยตนเอง');
            return DetectionResult(
              success: false,
              error: 'ไม่พบวัตถุในภาพ กรุณาวัดด้วยตนเอง',
              resizedImagePath: resizedImagePath,
            );
          }
          
          // ตรวจสอบว่าพบวัตถุแต่ละประเภทหรือไม่
          bool hasYellowMark = false;
          bool hasHeartGirth = false; 
          bool hasBodyLength = false;
          
          for (var obj in detectionResults) {
            if (obj.classId == 0) hasYellowMark = true;       // จุดอ้างอิง
            else if (obj.classId == 1) hasHeartGirth = true;  // รอบอก
            else if (obj.classId == 2) hasBodyLength = true;  // ความยาวลำตัว
          }
          
          print('ผลการตรวจจับ:');
          print('- จุดอ้างอิง: ${hasYellowMark ? "พบ" : "ไม่พบ"}');
          print('- รอบอก: ${hasHeartGirth ? "พบ" : "ไม่พบ"}');
          print('- ความยาวลำตัว: ${hasBodyLength ? "พบ" : "ไม่พบ"}');
          
          // ถ้าตรวจพบวัตถุไม่ครบทั้ง 3 ประเภท ให้พยายามใช้ตรวจจับด้วยความเชื่อมั่นที่ต่ำลงอีก
          if (!hasYellowMark || !hasHeartGirth || !hasBodyLength) {
            print('ตรวจพบวัตถุไม่ครบ พยายามปรับลดค่าความเชื่อมั่นลงอีก');
            // ลองใช้ค่า confidence ที่ต่ำมากเพื่อให้ตรวจพบได้มากขึ้น
            List<DetectedObject> moreDetections = _processOutput(
              outputBuffer, 
              image.width, 
              image.height, 
              confidenceThreshold: 0.05 // ลดลงเหลือ 5%
            );
            
            // เพิ่มวัตถุที่ยังไม่พบเข้าไป
            for (var obj in moreDetections) {
              bool isDuplicate = false;
              for (var existingObj in detectionResults) {
                if (obj.classId == existingObj.classId) {
                  isDuplicate = true;
                  break;
                }
              }
              
              if (!isDuplicate) {
                detectionResults.add(obj);
                print('เพิ่มวัตถุพิเศษ: ${obj.className} (ความเชื่อมั่น: ${(obj.confidence * 100).toStringAsFixed(1)}%)');
                
                // อัปเดตสถานะการตรวจพบ
                if (obj.classId == 0) hasYellowMark = true;
                else if (obj.classId == 1) hasHeartGirth = true;
                else if (obj.classId == 2) hasBodyLength = true;
              }
            }
          }
          
          return DetectionResult(
            success: true,
            objects: detectionResults,
            resizedImagePath: resizedImagePath,
          );

        } catch (e) {
          print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
          return DetectionResult(
            success: false,
            error: 'เกิดข้อผิดพลาดในการประมวลผล output: $e',
            resizedImagePath: resizedImagePath,
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

  /// บันทึกรูปที่ resize แล้วเพื่อตรวจสอบความถูกต้อง - แบบไม่บล็อกการทำงาน
  void _saveResizedImageNonBlocking(img.Image resizedImage) {
    // เรียกใช้งานแบบไม่รอ (Fire and forget)
    Future(() async {
      try {
        // สร้างโฟลเดอร์สำหรับบันทึกรูป
        final appDir = await getApplicationDocumentsDirectory();
        final debugDir = Directory('${appDir.path}/debug_images');
        if (!await debugDir.exists()) {
          await debugDir.create(recursive: true);
        }
        
        // กำหนดชื่อไฟล์
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final imagePath = '${debugDir.path}/resized_${timestamp}.jpg';
        
        // บันทึกรูปในรูปแบบ JPG
        final jpgData = img.encodeJpg(resizedImage, quality: 95);
        final file = File(imagePath);
        await file.writeAsBytes(jpgData);
        
        print('บันทึกรูปที่ resize แล้วที่: $imagePath');
      } catch (e) {
        print('ไม่สามารถบันทึกรูปที่ resize: $e');
      }
    });
  }
  

  /// แปลงรูปภาพเป็น tensor สำหรับโมเดล YOLOv8
  /// คืนค่าเป็น [tensor, resizedImagePath]
  Future<Map<String, dynamic>> _imageToTensor(img.Image originalImage) async {
    try {
      print('กำลังแปลงรูปภาพเป็น tensor สำหรับ YOLOv8...');
      
      // 1. Resize ภาพให้มีขนาด INPUT_SIZE x INPUT_SIZE โดยรักษาอัตราส่วน
      final int originalWidth = originalImage.width;
      final int originalHeight = originalImage.height;
      
      // คำนวณสัดส่วนการ resize โดยรักษาอัตราส่วนภาพ
      final double scale = math.min(
        INPUT_SIZE / originalWidth,
        INPUT_SIZE / originalHeight
      );
      
      final int newWidth = (originalWidth * scale).round();
      final int newHeight = (originalHeight * scale).round();
      
      // ปรับขนาดภาพตามสัดส่วนที่คำนวณไว้
      final img.Image scaledImage = img.copyResize(
        originalImage,
        width: newWidth,
        height: newHeight,
        interpolation: img.Interpolation.cubic // ใช้ cubic interpolation เพื่อคุณภาพที่ดีกว่า
      );
      
      // 2. สร้างรูปภาพขนาด INPUT_SIZE x INPUT_SIZE พร้อมพื้นที่ว่างสีดำ
      final img.Image paddedImage = img.Image(
        width: INPUT_SIZE,
        height: INPUT_SIZE,
        format: originalImage.format,
      );
      
      // คำนวณตำแหน่งวางภาพตรงกลาง canvas
      final int offsetX = (INPUT_SIZE - newWidth) ~/ 2;
      final int offsetY = (INPUT_SIZE - newHeight) ~/ 2;
      
      // วางภาพที่ resize แล้วลงบน canvas ขนาด INPUT_SIZE x INPUT_SIZE
      img.compositeImage(paddedImage, scaledImage, dstX: offsetX, dstY: offsetY);
      
      // 3. บันทึกรูปที่ทำการ preprocess แล้วเพื่อตรวจสอบ
      String? resizedImagePath = await _saveDebugImage(paddedImage, 'preprocessed');
      
      // 4. สร้าง tensor เริ่มต้นขนาด [1, INPUT_SIZE, INPUT_SIZE, 3]
      var tensor = List.filled(
        1, // batch size
        List.filled(
          INPUT_SIZE, // height
          List.filled(
            INPUT_SIZE, // width
            List.filled(
              3, // channels (RGB)
              0.0,
              growable: false
            ),
            growable: false
          ),
          growable: false
        ),
        growable: false
      );
      
      // 5. แปลงรูปภาพเป็น tensor (ใช้รูปภาพที่ preprocess แล้ว)
      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          final img.Pixel pixel = paddedImage.getPixel(x, y);
          
          // YOLOv8 ต้องการภาพในรูปแบบ RGB normalized (0-1)
          tensor[0][y][x][0] = pixel.r / 255.0; // Red
          tensor[0][y][x][1] = pixel.g / 255.0; // Green
          tensor[0][y][x][2] = pixel.b / 255.0; // Blue
        }
      }
      
      print('แปลงรูปภาพเป็น tensor สำเร็จ: [1, $INPUT_SIZE, $INPUT_SIZE, 3]');
      return {
        'tensor': tensor,
        'resizedImagePath': resizedImagePath,
      };
      
    } catch (e) {
      print('เกิดข้อผิดพลาดในการสร้าง input tensor: $e');
      
      // สร้าง tensor เริ่มต้นในกรณีที่มีข้อผิดพลาด
      print('สร้าง tensor เริ่มต้นแทน');
      return {
        'tensor': List.filled(
          1, // batch size
          List.filled(
            INPUT_SIZE, // height
            List.filled(
              INPUT_SIZE, // width
              List.filled(
                3, // channels (RGB)
                0.0,
                growable: false
              ),
              growable: false
            ),
            growable: false
          ),
          growable: false
        ),
        'resizedImagePath': null,
      };
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

  /// บันทึกรูปที่ resize แล้วเพื่อตรวจสอบความถูกต้อง (เป็น async แต่ไม่ await)
  Future<void> _saveResizedImage(img.Image resizedImage) async {
    try {
      // สร้างโฟลเดอร์ในพื้นที่จัดเก็บภายนอก (external storage)
      final appDir = await getExternalStorageDirectory(); // จาก path_provider
      final debugDir = Directory('${appDir?.path}/cattle_debug_images');
      
      if (!await debugDir.exists()) {
        await debugDir.create(recursive: true);
      }
      
      // บันทึกรูปภาพ
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final imagePath = '${debugDir.path}/resized_${timestamp}.jpg';
      
      final jpgData = img.encodeJpg(resizedImage, quality: 95);
      final file = File(imagePath);
      await file.writeAsBytes(jpgData);
      
      print('บันทึกรูปที่ resize แล้วที่: $imagePath');
      
      // เพิ่มไฟล์ลงในแกลเลอรีของอุปกรณ์ (ต้องใช้ media_scanner_scan_file หรือ plugin เช่น image_gallery_saver)
    } catch (e) {
      print('ไม่สามารถบันทึกรูปที่ resize: $e');
    }
  }
  
  
  /// แปลง output จากโมเดล YOLOv8 เป็นรายการวัตถุที่ตรวจพบ
  List<DetectedObject> _processOutput(dynamic outputData, int imageWidth, int imageHeight, {double confidenceThreshold = 0.01}) {  
    List<DetectedObject> detectedObjects = [];
    
    try {
      print('กำลังประมวลผล output จากโมเดล...');
      print('รูปแบบ outputData: ${outputData.runtimeType}');
      
      // ตรวจสอบโครงสร้างของ outputData
      if (outputData is List) {
        print('จำนวนมิติของ outputData: ${outputData.length}');
        
        // แก้ไขการประมวลผลสำหรับ YOLOv8 ในรูปแบบ TFLite
        // YOLOv8 ในรูปแบบ TFLite มักจะมี output ในรูปแบบ [1, 84, 8400] หรือ [84, 8400]
        
        try {
          // กรณี 1: รูปแบบ [1, 84, 8400]
          if (outputData.length == 1 && outputData[0] is List) {
            print('กำลังประมวลผลในรูปแบบ [${outputData.length}, ${outputData[0].length}, ${outputData[0][0].length}]');
            return _processYoloV8Output(outputData[0], imageWidth, imageHeight, confidenceThreshold);
          }
          // กรณี 2: รูปแบบ [84, 8400]
          else if (outputData.length > 5 && outputData[0] is List) { // คาดว่ามี 84 แถว
            print('กำลังประมวลผลในรูปแบบ [84, 8400]');
            return _processYoloV8Output(outputData, imageWidth, imageHeight, confidenceThreshold);
          }
          // กรณี 3: รูปแบบอื่นๆ ที่ไม่รู้จัก
          else {
            print('รูปแบบข้อมูลไม่ตรงกับที่คาดหวัง ลองวิเคราะห์เพิ่มเติม');
            // ดีบักเพื่อเข้าใจรูปแบบข้อมูล
            _debugOutputFormat(outputData);
            
            // ลองใช้วิธี fallback ถ้ามี
            if (outputData[0] is List) {
              print('ลองใช้การประมวลผลแบบ fallback');
              return _processFallbackOutput(outputData, imageWidth, imageHeight, confidenceThreshold);
            } else if (outputData is List<dynamic>) {
              // ถ้า outputData เป็น List<dynamic> แต่ต้องการ List<List<dynamic>>
              // ลองแปลงข้อมูลให้เป็นรูปแบบที่ถูกต้อง
              print('พยายามแปลงรูปแบบข้อมูลให้ตรงกับที่ต้องการ');
              
              // สร้าง List<List<dynamic>> จาก List<dynamic>
              List<List<dynamic>> convertedData = [];
              
              // ตรวจสอบโครงสร้างข้อมูลและแปลงตามความเหมาะสม
              if (outputData.length > 0) {
                // สำหรับ YOLOv8 แบบ 1 มิติ
                // [box1, box2, box3, ...] โดยแต่ละ box มีข้อมูล 7 ตัว (x, y, w, h, conf, class1, class2)
                int boxSize = 7; // จำนวนค่าต่อ box
                
                if (outputData.length % boxSize == 0) {
                  int numBoxes = outputData.length ~/ boxSize;
                  
                  // จัดเรียงข้อมูลใหม่
                  for (int i = 0; i < boxSize; i++) {
                    List<dynamic> row = [];
                    for (int j = 0; j < numBoxes; j++) {
                      row.add(outputData[j * boxSize + i]);
                    }
                    convertedData.add(row);
                  }
                  
                  return _processYoloV8Output(convertedData, imageWidth, imageHeight, confidenceThreshold);
                }
              }
            }
          }
        } catch (formatError) {
          print('เกิดข้อผิดพลาดในการวิเคราะห์รูปแบบ output: $formatError');
        }
      }
      
      print('ไม่พบรูปแบบ output ที่รองรับ');
      return [];
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
      return [];
    }
  }

  /// ประมวลผล output จากโมเดล YOLOv8 และแปลงเป็นรายการวัตถุที่ตรวจพบ
  List<DetectedObject> _processYoloV8Output(dynamic output, int imageWidth, int imageHeight, double confidenceThreshold) {
    List<DetectedObject> allDetectedObjects = [];
    
    try {
      // ตรวจสอบประเภทข้อมูล output และแปลงให้ถูกต้อง
      List<List<dynamic>> formattedOutput;
      
      if (output is List<List<dynamic>>) {
        // ข้อมูลมีรูปแบบที่ถูกต้องแล้ว
        formattedOutput = output;
      } 
      else if (output is List<dynamic>) {
        // ต้องแปลงเป็น List<List<dynamic>>
        print('แปลงข้อมูลจาก List<dynamic> เป็น List<List<dynamic>>');
        
        formattedOutput = [];
        for (var item in output) {
          if (item is List<dynamic>) {
            formattedOutput.add(item);
          } else {
            // กรณีที่ข้อมูลไม่ใช่ List
            print('ข้อมูลไม่อยู่ในรูปแบบที่คาดหวัง: $item');
            List<dynamic> newRow = [item]; // แปลงเป็น List
            formattedOutput.add(newRow);
          }
        }
      } 
      else {
        print('ไม่สามารถแปลงรูปแบบข้อมูลได้');
        return [];
      }
      
      // ดำเนินการประมวลผลต่อ
      final int rows = formattedOutput.length;
      int cols = 0;
      
      if (rows > 0 && formattedOutput[0] is List) {
        cols = formattedOutput[0].length;
      } else {
        print('ข้อมูลไม่มีคอลัมน์ที่ถูกต้อง');
        return [];
      }
      
      print('ขนาด output หลังจากการแปลง: [$rows, $cols]');
      
      // ลดค่า confidence threshold ลงเพื่อให้ตรวจจับได้ง่ายขึ้น
      double effectiveThreshold = 0.0001;  // ลดเหลือ 70% ของค่าเดิม
      print('ปรับลดค่า confidence threshold เหลือ: $effectiveThreshold');

      // จำนวนคลาสทั้งหมดในโมเดล
      final int numClasses = rows - 5;
      print('จำนวนคลาสทั้งหมด: $numClasses');
      
      // สแกนทุกวัตถุที่เป็นไปได้
      for (int i = 0; i < cols; i++) {
        // ตรวจสอบว่ามีข้อมูลเพียงพอ
        // if (rows <= 4 || i >= formattedOutput[0].length) {
        //   continue;
        // }

        final double conf1 = formattedOutput[4][i].toDouble();
        final double conf2 = formattedOutput[5][i].toDouble();
        final double conf3 = formattedOutput[6][i].toDouble();

        final confidences = [conf1, conf2, conf3];
        final maxConfidence = confidences.reduce(math.max);

        if (maxConfidence >= effectiveThreshold) {

          final tempIndex = confidences.indexOf(maxConfidence);

          print('Found class $tempIndex at conf: $maxConfidence' );

        }
        
        // ตรวจสอบ objectness score
        // final double objectness = formattedOutput[4][i].toDouble();
        
        // if (objectness >= effectiveThreshold) {
        //   // หาคลาสที่มีความน่าจะเป็นสูงสุด
        //   int bestClassIdx = -1;
        //   double bestClassScore = 0;
          
        //   for (int c = 0; c < numClasses && (5 + c) < rows; c++) {
        //     double classScore = formattedOutput[5 + c][i].toDouble();
        //     if (classScore > bestClassScore) {
        //       bestClassScore = classScore;
        //       bestClassIdx = c;
        //     }
        //   }
          
        //   // ถ้ามีคลาสที่มีคะแนนสูงพอ
        //   if (bestClassIdx != -1 && bestClassScore * objectness >= effectiveThreshold) {
        //     // ดึงค่าพิกัดกล่อง
        //     double x = formattedOutput[0][i].toDouble();
        //     double y = formattedOutput[1][i].toDouble();
        //     double w = formattedOutput[2][i].toDouble();
        //     double h = formattedOutput[3][i].toDouble();
            
        //     // แปลงเป็นพิกัด x1, y1, x2, y2 (เทียบกับภาพต้นฉบับ)
        //     double boxX1 = (x - w / 2) * imageWidth;
        //     double boxY1 = (y - h / 2) * imageHeight;
        //     double boxX2 = (x + w / 2) * imageWidth;
        //     double boxY2 = (y + h / 2) * imageHeight;
            
        //     // จำกัดพิกัดไม่ให้เกินขอบภาพ
        //     boxX1 = math.max(0, math.min(boxX1, imageWidth.toDouble()));
        //     boxY1 = math.max(0, math.min(boxY1, imageHeight.toDouble()));
        //     boxX2 = math.max(0, math.min(boxX2, imageWidth.toDouble()));
        //     boxY2 = math.max(0, math.min(boxY2, imageHeight.toDouble()));
            
        //     // แมป classId จากโมเดลเป็น classId ในแอป
        //     int mappedClassId = _mapClassIdToAppId(bestClassIdx);
            
        //     // คำนวณพิกัดเส้นตามประเภทของคลาส
        //     double x1, y1, x2, y2;
            
        //     // กำหนดพิกัดของเส้นตามประเภทของวัตถุหลังจากแมป
        //     if (mappedClassId == 0) {  // จุดอ้างอิง (Yellow Mark)
        //       // ใช้ขอบซ้ายและขอบขวาของบ็อกซ์ - เส้นแนวนอน
        //       x1 = boxX1;
        //       y1 = (boxY1 + boxY2) / 2;
        //       x2 = boxX2;
        //       y2 = y1;
        //     } 
        //     else if (mappedClassId == 1) {  // รอบอก (Heart Girth)
        //       // เส้นแนวตั้ง
        //       x1 = boxX1 + (boxX2 - boxX1) * HEART_GIRTH_X_OFFSET;
        //       y1 = boxY1;
        //       x2 = x1;
        //       y2 = boxY2;
        //     } 
        //     else if (mappedClassId == 2) {  // ความยาวลำตัว (Body Length)
        //       // เส้นแนวเฉียงตามโครงสร้างของโค
        //       x1 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_START_X;
        //       y1 = (boxY1 + boxY2) / 2 + (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET;
        //       x2 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_END_X;
        //       y2 = (boxY1 + boxY2) / 2 - (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET;
        //     } 
        //     else {
        //       // กรณีคลาสที่ไม่รู้จัก ใช้บ็อกซ์ตามปกติ
        //       x1 = boxX1;
        //       y1 = boxY1;
        //       x2 = boxX2;
        //       y2 = boxY2;
        //     }
            
        //     // กำหนดชื่อคลาสตาม mappedClassId
        //     String className = _getClassNameFromId(mappedClassId);
            
        //     // เพิ่มวัตถุที่ตรวจพบ
        //     allDetectedObjects.add(DetectedObject(
        //       classId: mappedClassId,
        //       className: className,
        //       confidence: objectness * bestClassScore,
        //       x1: x1,
        //       y1: y1,
        //       x2: x2,
        //       y2: y2,
        //     ));
            
        //     print('ตรวจพบ $className (Model ClassID: $bestClassIdx → App ClassID: $mappedClassId): ความเชื่อมั่น ${(objectness * bestClassScore * 100).toStringAsFixed(1)}%');
        //     print('  ตำแหน่งเส้น: (${x1.toInt()},${y1.toInt()}) - (${x2.toInt()},${y2.toInt()})');
        //     print('  ขอบเขตกรอบ: (${boxX1.toInt()},${boxY1.toInt()}) - (${boxX2.toInt()},${boxY2.toInt()})');
        //   }
        // }
      }
      
      // เรียงลำดับตามความเชื่อมั่น
      allDetectedObjects.sort((a, b) => b.confidence.compareTo(a.confidence));
      
      // กรองให้เหลือเพียงวัตถุที่ดีที่สุดสำหรับแต่ละคลาส
      Map<int, DetectedObject> bestObjectsByClass = {};
      for (var obj in allDetectedObjects) {
        if (!bestObjectsByClass.containsKey(obj.classId) || 
            bestObjectsByClass[obj.classId]!.confidence < obj.confidence) {
          bestObjectsByClass[obj.classId] = obj;
        }
      }
      
      return bestObjectsByClass.values.toList();
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมวลผล YOLOv8 output: $e');
      return [];
    }
  }
  
  /// ประมวลผลแบบสำรองในกรณีที่รูปแบบ output ไม่ตรงกับที่คาดหวัง
  List<DetectedObject> _processFallbackOutput(dynamic outputData, int imageWidth, int imageHeight, double confidenceThreshold) {
    List<DetectedObject> detectedObjects = [];
    
    try {
      // ตรวจสอบรูปแบบข้อมูลและพยายามประมวลผล
      // ในกรณีที่รูปแบบไม่ตรงกับที่คาดหวัง
      print('กำลังใช้การประมวลผลแบบสำรอง');
      
      // วิเคราะห์รูปแบบของข้อมูลเพิ่มเติม
      _debugOutputFormat(outputData);
      
      // ถ้าไม่สามารถแปลงเป็นรูปแบบที่รองรับได้ ให้คืนค่าเป็นลิสต์ว่าง
      return detectedObjects;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมวลผลแบบสำรอง: $e');
      return [];
    }
  }
  
  /// ดีบักรูปแบบข้อมูล output จากโมเดล
  void _debugOutputFormat(dynamic outputData) {
    try {
      print('=== เริ่มวิเคราะห์รูปแบบ output ===');
      
      if (outputData is List) {
        print('รูปแบบระดับที่ 1: List ที่มี ${outputData.length} สมาชิก');
        
        // แสดงตัวอย่างค่าในระดับแรก
        if (outputData.isNotEmpty) {
          print('ค่าแรก: ${outputData[0]}');
          print('ค่าที่ 4 (ถ้ามี): ${outputData.length > 4 ? outputData[4] : "ไม่มีข้อมูล"}');
          
          // ตรวจสอบช่วงที่น่าจะเป็นคลาส (5-83)
          if (outputData.length > 5) {
            for (int i = 5; i < math.min(8, outputData.length); i++) {
              print('ค่าที่ $i: ${outputData[i]}');
            }
          }
          
          var firstElement = outputData[0];
          print('รูปแบบระดับที่ 2: ${firstElement.runtimeType}');
          
          if (firstElement is List) {
            print('จำนวนสมาชิกในระดับที่ 2: ${firstElement.length}');
            print('ตัวอย่างค่า: ${firstElement.length > 0 ? firstElement[0] : "ไม่มีข้อมูล"}');
            
            if (firstElement.isNotEmpty) {
              var subElement = firstElement[0];
              print('รูปแบบระดับที่ 3: ${subElement.runtimeType}');
              
              if (subElement is List) {
                print('จำนวนสมาชิกในระดับที่ 3: ${subElement.length}');
              }
            }
          }
        }
      }
      
      print('=== จบการวิเคราะห์รูปแบบ output ===');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวิเคราะห์รูปแบบ output: $e');
    }
  }

  /// แก้ไขการแมป classId ระหว่างโมเดลกับแอป
  int _mapClassIdToAppId(int modelClassId) {
    // แมปตามลำดับคลาสใน data.yaml:
    // 0: Body_Length - ในแอปใช้เป็น 2: ความยาวลำตัว
    // 1: Heart_Girth - ในแอปใช้เป็น 1: รอบอก 
    // 2: Yellow_Mark - ในแอปใช้เป็น 0: จุดอ้างอิง
    switch (modelClassId) {
      case 0: return 2; // Model's Body_Length -> App's ความยาวลำตัว (2)
      case 1: return 1; // Model's Heart_Girth -> App's รอบอก (1)
      case 2: return 0; // Model's Yellow_Mark -> App's จุดอ้างอิง (0)
      default: return modelClassId;
    }
  }
  
  /// ดึงชื่อคลาสจาก classId ของแอป (หลังจากแมปแล้ว)
  String _getClassNameFromId(int classId) {
    switch (classId) {
      case 0: return 'จุดอ้างอิง';   // Yellow Mark
      case 1: return 'รอบอก';       // Heart Girth
      case 2: return 'ความยาวลำตัว'; // Body Length
      default: return 'Unknown_$classId';
    }
  }
  
  /// ปล่อยทรัพยากรเมื่อไม่ใช้งานแล้ว
  void dispose() {
    try {
      _interpreter?.close();
      _interpreter = null;
      _modelLoaded = false;
      print('ปล่อยทรัพยากรของโมเดล');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการปล่อยทรัพยากร: $e');
    }
  }
}

/// คลาสเก็บข้อมูลวัตถุที่ตรวจพบ
class DetectedObject {
  final int classId;
  final String className;
  final double confidence;
  final double x1, y1, x2, y2;
  
  DetectedObject({
    required this.classId,
    required this.className,
    required this.confidence,
    required this.x1,
    required this.y1,
    required this.x2,
    required this.y2,
  });
  
  // คำนวณความกว้างของกรอบสี่เหลี่ยม
  double get width => x2 - x1;
  
  // คำนวณความสูงของกรอบสี่เหลี่ยม
  double get height => y2 - y1;
  
  // คำนวณพื้นที่ของกรอบสี่เหลี่ยม
  double get area => width * height;
  
  // คำนวณจุดศูนย์กลาง
  Map<String, double> get center => {
    'x': (x1 + x2) / 2,
    'y': (y1 + y2) / 2,
  };
  
  // แปลงเป็น Map
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
    };
  }
}

/// คลาสเก็บผลลัพธ์การตรวจจับ
class DetectionResult {
  final bool success;
  final List<DetectedObject>? objects;
  final String? error;
  final String? resizedImagePath;
  
  DetectionResult({
    required this.success,
    this.objects,
    this.error,
    this.resizedImagePath,
  });
  
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
}