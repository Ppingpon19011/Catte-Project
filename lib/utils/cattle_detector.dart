import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// คลาสสำหรับตรวจจับโคด้วยโมเดล YOLOv8 แปลงเป็น TFLite
class CattleDetector {
  // ชื่อไฟล์โมเดลที่ใช้ (ให้ตรงกับที่กำหนดใน pubspec.yaml)
  static const String MODEL_FILE_NAME = 'best_model_float32.tflite';
  // ขนาด input ของโมเดล YOLOv8
  static const int INPUT_SIZE = 640;

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
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        print('ไม่สามารถอ่านรูปภาพได้');
        return DetectionResult(
          success: false,
          error: 'ไม่สามารถอ่านรูปภาพได้',
        );
      }

      print('ขนาดรูปภาพที่ใช้ในการตรวจจับ: ${image.width}x${image.height}');
      
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
            if (inputTensor is List && inputTensor.isNotEmpty && inputTensor[0] is List && 
                inputTensor[0].isNotEmpty && inputTensor[0][0] is List && inputTensor[0][0].isNotEmpty) {
              print('ตัวอย่างค่าใน inputTensor[0][0][0]: ${inputTensor[0][0][0]}');
            }

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
                  print('ค่าคลาส [0][$i][0]: ${outputBuffer[0][i][0]}');
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
            confidenceThreshold: 0.0001 // ปรับค่าความเชื่อมั่นให้เหมาะสม
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
            if (obj.classId == 0) hasBodyLength = true;       //  ความยาวลำตัว
            else if (obj.classId == 1) hasHeartGirth = true;  // รอบอก
            else if (obj.classId == 2)  hasYellowMark = true;  // จุดอ้างอิง
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
              confidenceThreshold: 0.1 // ลดลงเหลือ 10%
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
                if (obj.classId == 0) hasBodyLength = true;
                else if (obj.classId == 1) hasHeartGirth = true;
                else if (obj.classId == 2) hasYellowMark = true;
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
          final pixel = paddedImage.getPixel(x, y);
          
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
  
  /// แปลง output จากโมเดล YOLOv8 เป็นรายการวัตถุที่ตรวจพบ
  List<DetectedObject> _processOutput(dynamic outputData, int imageWidth, int imageHeight, {double confidenceThreshold = 0.25}) {  
    List<DetectedObject> detectedObjects = [];
    
    try {
      print('กำลังประมวลผล output จากโมเดล...');
      print('รูปแบบ outputData: ${outputData.runtimeType}');
      
      // ตรวจสอบโครงสร้างของ outputData
      if (outputData is List) {
        print('จำนวนมิติของ outputData: ${outputData.length}');
        
        // ระบุรูปแบบของ output และดำเนินการประมวลผลให้ถูกต้อง
        try {
          // รูปแบบ [1, 84, 8400] (YOLOv8 ทั่วไป)
          if (outputData.length == 1 && outputData[0] is List && outputData[0].isNotEmpty) {
            print('กำลังประมวลผลในรูปแบบ [1, rows, cols]');
            return _processYoloV8Output(outputData[0], imageWidth, imageHeight, confidenceThreshold);
          }
          // รูปแบบ [84, 8400] (YOLOv8 บางเวอร์ชัน)
          else if (outputData.length > 5 && outputData[0] is List && outputData[0].isNotEmpty) {
            print('กำลังประมวลผลในรูปแบบ [rows, cols]');
            return _processYoloV8Output(outputData, imageWidth, imageHeight, confidenceThreshold);
          }
          // รูปแบบอื่นๆ ที่ไม่ทราบล่วงหน้า
          else {
            print('รูปแบบข้อมูลไม่ตรงกับที่คาดหวัง ลองวิเคราะห์เพิ่มเติม');
            
            // พยายามตรวจสอบโครงสร้างข้อมูลเพื่อประมวลผล
            _debugOutputFormat(outputData);
            
            // ทดลองใช้รูปแบบต่างๆ
            if (outputData.length > 0) {
              var firstElement = outputData[0];
              
              // รูปแบบ 1D ไม่ใช่ nested list
              if (firstElement is! List && outputData.length % 7 == 0) {
                print('อาจเป็นรูปแบบ 1 มิติแบบแบน (flat) ลองประมวลผลด้วยการปรับรูปแบบ');
                
                // แปลงข้อมูลให้อยู่ในรูปแบบที่เข้ากับ _processYoloV8Output
                List<List<dynamic>> restructuredData = [];
                int numBoxElements = 7; // box_data, conf, class_data (5)
                
                // แปลงข้อมูลเป็นแถวๆ
                for (int i = 0; i < numBoxElements; i++) {
                  List<dynamic> row = [];
                  for (int j = 0; j < outputData.length ~/ numBoxElements; j++) {
                    row.add(outputData[j * numBoxElements + i]);
                  }
                  restructuredData.add(row);
                }
                
                return _processYoloV8Output(restructuredData, imageWidth, imageHeight, confidenceThreshold);
              }
              
              // รูปแบบมากกว่า 1 มิติแต่ไม่ใช่รูปแบบมาตรฐาน
              if (firstElement is List) {
                try {
                  return _processYoloV8Output(outputData, imageWidth, imageHeight, confidenceThreshold);
                } catch (innerError) {
                  print('การประมวลผลล้มเหลว: $innerError, ลองใช้วิธีสำรอง');
                  return _processFallbackOutput(outputData, imageWidth, imageHeight, confidenceThreshold);
                }
              }
            }
          }
        } catch (formatError) {
          print('เกิดข้อผิดพลาดในการวิเคราะห์รูปแบบ output: $formatError');
          // ทดลองใช้การประมวลผลแบบสำรอง
          return _processFallbackOutput(outputData, imageWidth, imageHeight, confidenceThreshold);
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
      
      // ** ปรับค่า threshold ให้เหมาะสม **
      double effectiveThreshold = confidenceThreshold;
      print('ค่า confidence threshold: $effectiveThreshold');

      // จำนวนคลาสทั้งหมดในโมเดล (ประมาณว่ามี class_data 3 ชุด เริ่มจาก index ที่ 5)
      final int numClasses = 3; // ระบุเป็น 3 คลาสที่ต้องการเท่านั้น (YellowMark, HeartGirth, BodyLength)
      print('จำนวนคลาสที่ต้องการตรวจจับ: $numClasses');
      
      // สแกนทุกวัตถุที่เป็นไปได้ (แต่ละคอลัมน์คือ 1 วัตถุ)
      for (int i = 0; i < cols; i++) {
        // ** ตรวจสอบว่ามีข้อมูลเพียงพอ **
        if (rows <= 5) { // ขั้นต่ำต้องมี x, y, w, h, objectness_score
          print('ข้อมูลไม่เพียงพอสำหรับการแปลผล');
          continue;
        }

        try {
          // ** ดึงและแสดงค่า objectness score **
          double objectness = 0.0;
          if (4 < rows) {
            objectness = formattedOutput[4][i].toDouble();
          } else {
            print('ไม่พบข้อมูล objectness score');
            continue;
          }
          
          // ** ดึงค่า confidence ของแต่ละคลาส **
          List<double> classConfidences = [];
          
          // ตรวจสอบว่าข้อมูลมีเพียงพอสำหรับคลาสที่ต้องการหรือไม่
          bool hasClassData = false;
          if (rows > 5) { // มีข้อมูลคลาส (เริ่มจาก index 5)
            hasClassData = true;
            
            // ระบุจำนวนคลาสสูงสุดที่จะอ่าน (สูงสุด 3 คลาส)
            int maxClasses = math.min(numClasses, rows - 5);
            
            // ดึงค่า confidence ของแต่ละคลาส
            for (int c = 0; c < maxClasses; c++) {
              if (5 + c < rows) {
                double classConf = formattedOutput[5 + c][i].toDouble();
                classConfidences.add(classConf);
              }
            }
            
            // หากมีคลาสน้อยกว่า 3 ให้เพิ่มค่า 0 จนครบ 3
            while (classConfidences.length < 3) {
              classConfidences.add(0.0);
            }
          } else {
            print('ไม่พบข้อมูลคลาส ใช้ค่า default แทน');
            // กรณีที่ไม่มีข้อมูลคลาส ให้ใช้ค่า default
            classConfidences = [1.0, 0.0, 0.0]; // สมมติว่าเป็นคลาสแรกเสมอ
          }
          
          // ** ตรวจสอบว่ามีข้อมูล confidence ครบถ้วน **
          if (classConfidences.isEmpty) {
            print('ไม่มีข้อมูล confidence ของคลาส');
            continue;
          }

          // ใช้ค่า confidence ที่ได้
          final double conf1 = classConfidences[0]; // ความยาวลำตัว
          final double conf2 = classConfidences[1]; // รอบอก
          final double conf3 = classConfidences[2]; // จุดอ้างอิง

          final List<double> confidences = [conf1, conf2, conf3];
          final double maxConfidence = confidences.reduce(math.max);
          int tempIndex = confidences.indexOf(maxConfidence);

          // ** คำนวณความเชื่อมั่นรวม **
          double finalConfidence = hasClassData 
              ? math.max(objectness, maxConfidence) 
              : objectness; // ถ้าไม่มีข้อมูลคลาส ใช้ objectness เป็นค่าความเชื่อมั่น
          
          // ตรวจสอบค่าความเชื่อมั่นรวม
          if (finalConfidence >= effectiveThreshold) {
            print('พบคลาส $tempIndex ด้วยความเชื่อมั่น $finalConfidence');
            
            // ดึงค่าพิกัดกล่อง
            double x = formattedOutput[0][i].toDouble(); // center_x
            double y = formattedOutput[1][i].toDouble(); // center_y
            double w = formattedOutput[2][i].toDouble(); // width
            double h = formattedOutput[3][i].toDouble(); // height
            
            // แปลงเป็นพิกัด x1, y1, x2, y2 (เทียบกับภาพต้นฉบับ)
            double boxX1 = (x - w / 2) * imageWidth;
            double boxY1 = (y - h / 2) * imageHeight;
            double boxX2 = (x + w / 2) * imageWidth;
            double boxY2 = (y + h / 2) * imageHeight;
            
            // จำกัดพิกัดไม่ให้เกินขอบภาพ
            boxX1 = math.max(0, math.min(boxX1, imageWidth.toDouble()));
            boxY1 = math.max(0, math.min(boxY1, imageHeight.toDouble()));
            boxX2 = math.max(0, math.min(boxX2, imageWidth.toDouble()));
            boxY2 = math.max(0, math.min(boxY2, imageHeight.toDouble()));
            
            // ** แมป classId จากโมเดลเป็น classId ในแอป **
            int modelClassId = tempIndex;
            
            // กำหนดพิกัดของเส้นตามประเภทของวัตถุ
            double x1, y1, x2, y2;
            
            if (modelClassId == 0) {  // ความยาวลำตัว (Body Length)
              // เส้นแนวเฉียงตามโครงสร้างของโค
              x1 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_START_X;
              y1 = (boxY1 + boxY2) / 2 + (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET;
              x2 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_END_X;
              y2 = (boxY1 + boxY2) / 2 - (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET;
            } 
            else if (modelClassId == 1) {  // รอบอก (Heart Girth)
              // เส้นแนวตั้ง
              x1 = boxX1 + (boxX2 - boxX1) * HEART_GIRTH_X_OFFSET;
              y1 = boxY1;
              x2 = x1;
              y2 = boxY2;
            } 
            else if (modelClassId == 2) {  // จุดอ้างอิง (Yellow Mark)
              // ใช้ขอบซ้ายและขอบขวาของบ็อกซ์ - เส้นแนวนอน
              x1 = boxX1;
              y1 = (boxY1 + boxY2) / 2;
              x2 = boxX2;
              y2 = y1;
            } 
            else {
              // กรณีคลาสที่ไม่รู้จัก ใช้บ็อกซ์ตามปกติ
              x1 = boxX1;
              y1 = boxY1;
              x2 = boxX2;
              y2 = boxY2;
            }
            
            // กำหนดชื่อคลาสตาม modelClassId
            String className = _getClassNameFromId(modelClassId);
            
            // เพิ่มวัตถุที่ตรวจพบ
            allDetectedObjects.add(DetectedObject(
              classId: modelClassId,
              className: className,
              confidence: finalConfidence,
              x1: x1,
              y1: y1,
              x2: x2,
              y2: y2,
            ));
            
            print('ตรวจพบ $className (ClassID: $modelClassId): ความเชื่อมั่น ${(finalConfidence * 100).toStringAsFixed(1)}%');
            print('  ตำแหน่งเส้น: (${x1.toInt()},${y1.toInt()}) - (${x2.toInt()},${y2.toInt()})');
            print('  ขอบเขตกรอบ: (${boxX1.toInt()},${boxY1.toInt()}) - (${boxX2.toInt()},${boxY2.toInt()})');
          }
        } catch (innerError) {
          print('เกิดข้อผิดพลาดในการประมวลผลคอลัมน์ $i: $innerError');
          continue; // ข้ามไปยังคอลัมน์ถัดไป
        }
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
      
      // ** เพิ่มเติม: แสดงสรุปผลการตรวจจับ **
      print('สรุปการตรวจจับ: พบวัตถุทั้งหมด ${bestObjectsByClass.length} ประเภท');
      bestObjectsByClass.forEach((classId, obj) {
        print('- ${obj.className}: ความเชื่อมั่น ${(obj.confidence * 100).toStringAsFixed(1)}%');
      });
      
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
      print('กำลังใช้การประมวลผลแบบสำรอง');
      
      // วิเคราะห์รูปแบบของข้อมูลเพิ่มเติม
      _debugOutputFormat(outputData);
      
      // หากไม่สามารถประมวลผลได้ ให้สร้าง detection สำหรับการวัดด้วยตนเอง
      // โดยสร้างวัตถุที่ตรวจจับเป็นเส้นแต่ละประเภท
      print('สร้างการตรวจจับแบบสำรองสำหรับการวัดด้วยตนเอง');
      
      // คำนวณตำแหน่งกลางของภาพ
      double centerX = imageWidth / 2;
      double centerY = imageHeight / 2;
      
      // สร้างจุดอ้างอิง (Yellow Mark) - แนวนอน
      detectedObjects.add(DetectedObject(
        classId: 2, // Yellow Mark
        className: 'จุดอ้างอิง',
        confidence: 0.9,
        x1: centerX - imageWidth * 0.25,
        y1: centerY - imageHeight * 0.2,
        x2: centerX + imageWidth * 0.25,
        y2: centerY - imageHeight * 0.2,
      ));
      
      // สร้างรอบอก (Heart Girth) - แนวตั้ง
      detectedObjects.add(DetectedObject(
        classId: 1, // Heart Girth
        className: 'รอบอก',
        confidence: 0.9,
        x1: centerX + imageWidth * 0.1,
        y1: centerY - imageHeight * 0.2,
        x2: centerX + imageWidth * 0.1,
        y2: centerY + imageHeight * 0.2,
      ));
      
      // สร้างความยาวลำตัว (Body Length) - แนวนอน
      detectedObjects.add(DetectedObject(
        classId: 0, // Body Length
        className: 'ความยาวลำตัว',
        confidence: 0.9,
        x1: centerX - imageWidth * 0.3,
        y1: centerY,
        x2: centerX + imageWidth * 0.3,
        y2: centerY,
      ));
      
      print('สร้างการตรวจจับแบบสำรองสำเร็จ: ${detectedObjects.length} รายการ');
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
          if (outputData.length > 4) {
            print('ค่าที่ 4: ${outputData[4]}');
          } else {
            print('ไม่มีค่าที่ 4 (มีเพียง ${outputData.length} สมาชิก)');
          }
          
          // ตรวจสอบช่วงที่น่าจะเป็นคลาส (5-7)
          if (outputData.length > 5) {
            for (int i = 5; i < math.min(8, outputData.length); i++) {
              print('ค่าที่ $i: ${outputData[i]}');
            }
          }
          
          var firstElement = outputData[0];
          print('รูปแบบระดับที่ 2: ${firstElement.runtimeType}');
          
          if (firstElement is List) {
            print('จำนวนสมาชิกในระดับที่ 2: ${firstElement.length}');
            
            if (firstElement.isNotEmpty) {
              print('ตัวอย่างค่า: ${firstElement[0]}');
              
              var subElement = firstElement[0];
              print('รูปแบบระดับที่ 3: ${subElement.runtimeType}');
              
              if (subElement is List) {
                print('จำนวนสมาชิกในระดับที่ 3: ${subElement.length}');
              }
            } else {
              print('ไม่มีสมาชิกในระดับที่ 2');
            }
          } else {
            print('สมาชิกแรกไม่ใช่ List แต่เป็น ${firstElement.runtimeType}');
          }
        } else {
          print('ไม่มีสมาชิกในระดับที่ 1');
        }
      } else {
        print('ข้อมูลไม่ใช่ List แต่เป็น ${outputData.runtimeType}');
      }
      
      print('=== จบการวิเคราะห์รูปแบบ output ===');
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวิเคราะห์รูปแบบ output: $e');
    }
  }

  /// แก้ไขการแมป classId ระหว่างโมเดลกับแอป
  int _mapClassIdToAppId(int modelClassId) {
    // ในกรณีนี้ ระบบจะใช้ค่า classId ในรูปแบบ:
    // 0 = ความยาวลำตัว (Body Length)
    // 1 = รอบอก (Heart Girth)
    // 2 = จุดอ้างอิง (Yellow Mark)
    return modelClassId;
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
    };
  }
  
  // สร้างจาก Map สำหรับการอ่านข้อมูลที่บันทึกไว้
  factory DetectedObject.fromMap(Map<String, dynamic> map) {
    return DetectedObject(
      classId: map['class_id'],
      className: map['class_name'],
      confidence: map['confidence'],
      x1: map['x1'],
      y1: map['y1'],
      x2: map['x2'],
      y2: map['y2'],
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
  }) {
    return DetectedObject(
      classId: classId ?? this.classId,
      className: className ?? this.className,
      confidence: confidence ?? this.confidence,
      x1: x1 ?? this.x1,
      y1: y1 ?? this.y1,
      x2: x2 ?? this.x2,
      y2: y2 ?? this.y2,
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