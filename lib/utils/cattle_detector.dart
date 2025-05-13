import 'dart:io';
import 'dart:math' as Math;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import '../utils/enhanced_measurement_painter.dart';

// เป็นคลาสที่ใช้ในการตรวจจับโคด้วย ML Model
class CattleDetector {
  // แก้ไขชื่อไฟล์ให้ตรงกับที่กำหนดใน pubspec.yaml
  static const String MODEL_FILE_NAME = 'best_model_float32.tflite';
  static const int INPUT_SIZE = 640; // ขนาด input ของโมเดล YOLOv8

  static const double HEART_GIRTH_X_OFFSET = 0.3;  // ค่า offset สำหรับตำแหน่ง x ของเส้นรอบอก
  static const double BODY_LENGTH_START_X = 0.1;   // ตำแหน่งเริ่มต้น x ของเส้นความยาวลำตัว (0-1)
  static const double BODY_LENGTH_END_X = 0.9;     // ตำแหน่งสิ้นสุด x ของเส้นความยาวลำตัว (0-1)
  static const double BODY_LENGTH_Y_OFFSET = 0.1;  // ค่า offset สำหรับความเอียงของเส้นความยาวลำตัว
  
  Interpreter? _interpreter;
  bool _modelLoaded = false;
  
  // สร้าง singleton pattern สำหรับ CattleDetector
  static final CattleDetector _instance = CattleDetector._internal();
  factory CattleDetector() => _instance;
  CattleDetector._internal();
  
  // ตรวจสอบและโหลดโมเดล
  Future<bool> loadModel() async {
    try {
      if (_modelLoaded && _interpreter != null) {
        print('โมเดลถูกโหลดแล้ว กำลังใช้งานโมเดลที่โหลดไว้');
        return true;
      }
      
      print('เริ่มต้นโหลดโมเดล...');
      
      // ค้นหาไฟล์โมเดลจาก assets
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
            options.threads = 4;
            
            try {
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
  
  // ฟังก์ชันสำหรับการตรวจจับโคจากภาพ
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
      
      // ปรับขนาดภาพให้เหมาะสมกับ input ของโมเดล
      var resizedImage = img.copyResize(
        image,
        width: INPUT_SIZE,
        height: INPUT_SIZE,
        interpolation: img.Interpolation.linear,
      );
      
      try {
        // แปลงรูปภาพเป็น tensor
        var inputTensor = _imageToTensor(resizedImage);
        
        try {
          // ตรวจสอบรูปแบบ output ของโมเดล
          var outputShape = _interpreter!.getOutputTensor(0).shape;
          print('รูปแบบ output tensor: $outputShape');
          
          // สร้าง output buffer ตามขนาดที่ถูกต้อง
          var outputBuffer;
          
          // สร้าง buffer ที่เหมาะสมกับโมเดล YOLOv8
          if (outputShape.length == 3) {
            print('กำลังสร้าง tensor 3 มิติขนาด ${outputShape[0]}x${outputShape[1]}x${outputShape[2]}');
            
            // สร้าง nested lists ตามขนาด tensor 3 มิติ
            outputBuffer = List<List<List<dynamic>>>.filled(
              outputShape[0],
              List<List<dynamic>>.filled(
                outputShape[1],
                List<dynamic>.filled(outputShape[2], 0.0),
                growable: false
              ),
              growable: false
            );
          } else if (outputShape.length == 2) {
            print('กำลังสร้าง tensor 2 มิติขนาด ${outputShape[0]}x${outputShape[1]}');
            
            outputBuffer = List<List<dynamic>>.filled(
              outputShape[0],
              List<dynamic>.filled(outputShape[1], 0.0, growable: false),
              growable: false
            );
          } else {
            print('รูปแบบ output (${outputShape.length} มิติ) ไม่ตรงกับที่คาดหวัง');
            return DetectionResult(
              success: false,
              error: 'รูปแบบ output ไม่ตรงกับที่คาดหวัง',
            );
          }
          
          // รัน inference
          print('กำลังรัน inference...');
          
          try {
            _interpreter!.run(inputTensor, outputBuffer);
            print('รัน inference สำเร็จ');
          } catch (runError) {
            print('ไม่สามารถรัน inference ได้: $runError');
            return DetectionResult(
              success: false,
              error: 'ไม่สามารถรัน inference ได้: $runError',
            );
          }
          
          // แปลงผลลัพธ์เป็น DetectedObject
          List<DetectedObject> detectionResults = _processOutput(outputBuffer, image.width, image.height, confidenceThreshold: 0.15);
          
          if (detectionResults.isEmpty) {
            print('ไม่พบวัตถุในภาพ กรุณาวัดด้วยตนเอง');
            return DetectionResult(
              success: false,
              error: 'ไม่พบวัตถุในภาพ กรุณาวัดด้วยตนเอง',
            );
          }
          
          return DetectionResult(
            success: true,
            objects: detectionResults,
          );
        } catch (e) {
          print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
          return DetectionResult(
            success: false,
            error: 'เกิดข้อผิดพลาดในการประมวลผล output: $e',
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

  // แปลงรูปภาพเป็น tensor
  List<List<List<List<double>>>> _imageToTensor(img.Image image) {
    try {
      print('กำลังแปลงรูปภาพเป็น tensor...');
      
      // สร้าง tensor เริ่มต้นขนาด [1, INPUT_SIZE, INPUT_SIZE, 3]
      var tensor = List.generate(
        1, // batch size
        (_) => List.generate(
          INPUT_SIZE, // height
          (_) => List.generate(
            INPUT_SIZE, // width
            (_) => List.generate(
              3, // channels (RGB)
              (_) => 0.0,
            ),
          ),
        ),
      );
      
      // แปลงรูปภาพเป็น tensor
      for (int y = 0; y < INPUT_SIZE; y++) {
        for (int x = 0; x < INPUT_SIZE; x++) {
          if (x < image.width && y < image.height) {
            try {
              final pixel = image.getPixel(x, y);
              
              // YOLOv8 ต้องการภาพในรูปแบบ RGB normalized (0-1)
              tensor[0][y][x][0] = pixel.r / 255.0; // Red
              tensor[0][y][x][1] = pixel.g / 255.0; // Green
              tensor[0][y][x][2] = pixel.b / 255.0; // Blue
            } catch (pixelError) {
              // กรณีที่มีปัญหากับพิกเซล ใช้ค่าเริ่มต้น
              print('เกิดข้อผิดพลาดกับพิกเซล ($x,$y): $pixelError');
              tensor[0][y][x][0] = 0.0; // Red
              tensor[0][y][x][1] = 0.0; // Green
              tensor[0][y][x][2] = 0.0; // Blue
            }
          } else {
            // กรณีที่ออกนอกขอบเขตของภาพ ใช้ค่า 0 (สีดำ)
            tensor[0][y][x][0] = 0.0; // Red
            tensor[0][y][x][1] = 0.0; // Green
            tensor[0][y][x][2] = 0.0; // Blue
          }
        }
      }
      
      print('แปลงรูปภาพเป็น tensor สำเร็จ');
      return tensor;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการสร้าง input tensor: $e');
      
      // สร้าง tensor เริ่มต้นในกรณีที่มีข้อผิดพลาด
      print('สร้าง tensor เริ่มต้นแทน');
      return List.generate(
        1, // batch size
        (_) => List.generate(
          INPUT_SIZE, // height
          (_) => List.generate(
            INPUT_SIZE, // width
            (_) => List.generate(
              3, // channels (RGB)
              (_) => 0.0,
            ),
          ),
        ),
      );
    }
  }
  
  // แปลง output จาก YOLOv8 เป็น DetectedObject
  List<DetectedObject> _processOutput(dynamic outputData, int imageWidth, int imageHeight, {double confidenceThreshold = 0.01}) {  
    List<DetectedObject> detectedObjects = [];
    
    try {
      print('กำลังประมวลผล output จากโมเดล...');
      
      // ตรวจสอบว่า outputData มีโครงสร้างที่ถูกต้อง
      if (outputData is List && outputData.length > 0) {
        print('รูปแบบ outputData: ${outputData.runtimeType}');
        
        // YOLOv8 มีรูปแบบ output เป็น [1, 7, 33600]
        // เมื่อ 7 คือ [x, y, w, h, confidence, class_score1, class_score2]
        var boxes;
        if (outputData[0] is List) {
          boxes = outputData[0];
          print('พบชุดข้อมูลในรูปแบบแรก [batch, data]');
        } else {
          boxes = outputData;
          print('พบชุดข้อมูลในรูปแบบที่สอง [data]');
        }
        
        if (boxes is List && boxes.length >= 5) {
          print('จำนวนมิติของ boxes: ${boxes.length}');
          
          var dataLength = 0;
          if (boxes[0] is List) {
            dataLength = boxes[0].length;
            print('จำนวนบ็อกซ์ที่ตรวจพบ: $dataLength');
          } else {
            print('ไม่พบข้อมูลบ็อกซ์ในรูปแบบที่เข้าใจได้');
            return [];
          }
          
          // เก็บวัตถุที่ตรวจพบทั้งหมดก่อนกรอง
          List<DetectedObject> allDetectedObjects = [];
          
          for (int i = 0; i < dataLength; i++) {
            try {
              double confidence = boxes[4][i].toDouble();
              
              if (confidence >= confidenceThreshold) {
                // หาประเภทของวัตถุ
                List<double> classScores = [];
                for (int j = 5; j < boxes.length; j++) {
                  classScores.add(boxes[j][i].toDouble());
                }
                
                // หาคลาสที่มีคะแนนสูงสุด
                int classId = 0;
                double maxScore = 0;
                for (int j = 0; j < classScores.length; j++) {
                  if (classScores[j] > maxScore) {
                    maxScore = classScores[j];
                    classId = j;
                  }
                }
                
                // ดึงค่าพิกัดของบ็อกซ์
                double x = boxes[0][i].toDouble();
                double y = boxes[1][i].toDouble();
                double w = boxes[2][i].toDouble();
                double h = boxes[3][i].toDouble();
                
                // แปลงเป็นพิกัด x1, y1, x2, y2 ตามการตรวจจับจริง
                double boxX1 = (x - w / 2) * imageWidth;
                double boxY1 = (y - h / 2) * imageHeight;
                double boxX2 = (x + w / 2) * imageWidth;
                double boxY2 = (y + h / 2) * imageHeight;
                
                // จำกัดพิกัดไม่ให้เกินขอบภาพ
                boxX1 = Math.max(0, Math.min(boxX1, imageWidth.toDouble()));
                boxY1 = Math.max(0, Math.min(boxY1, imageHeight.toDouble()));
                boxX2 = Math.max(0, Math.min(boxX2, imageWidth.toDouble()));
                boxY2 = Math.max(0, Math.min(boxY2, imageHeight.toDouble()));
                
                // ประกาศตัวแปรสำหรับเก็บพิกัดเส้น
                double x1, y1, x2, y2;

                int correctedClassId;
                    
                  // แก้ไขการแมปค่า classId
                  // แก้ไขการแมปค่า classId
                  if (classId == 0) {
                      correctedClassId = 2;  // หากโมเดลตรวจจับเป็น classId 0 ให้เป็น Body Length (2)
                  } else if (classId == 1) {
                      correctedClassId = 0;  // หากโมเดลตรวจจับเป็น classId 1 ให้เป็น Yellow Mark (0)
                  } else if (classId == 2) {
                      correctedClassId = 1;  // หากโมเดลตรวจจับเป็น classId 2 ให้เป็น Heart Girth (1)
                  } else {
                    correctedClassId = classId;  // กรณีอื่นๆ ให้คงเดิม
                  }
                
                // กำหนดประเภทของกรอบตามคลาสและกำหนดพิกัดใหม่ตามที่ต้องการ:
                if (correctedClassId == 0) {  // Yellow_mark: เส้นแนวนอนตามความยาวของไม้ที่แปะเทป
                  // ยังคงใช้ตามเดิม - ใช้ขอบซ้ายและขอบขวาของบ็อกซ์
                  x1 = boxX1;
                  y1 = (boxY1 + boxY2) / 2;
                  x2 = boxX2;
                  y2 = y1;
                } 
                else if (correctedClassId == 1) {  // Heart_Girth: เส้นแนวตั้งตามรอบอกของโค
                  // ปรับให้อยู่ทางซ้ายมากขึ้น (ขยับเข้าไปในตัวโค)
                  x1 = boxX1 + (boxX2 - boxX1) * 0.3;  // ขยับไปทางซ้ายประมาณ 30% ของความกว้างบ็อกซ์
                  y1 = boxY1;
                  x2 = x1;
                  y2 = boxY2;
                } 
                else if (correctedClassId == 2) {  // Body_Length: เส้นแนวเฉียงจากไหล่ถึงสะโพกโค
                  // ปรับให้เป็นเส้นเฉียงจากซ้ายล่างไปขวาบน ตามโครงสร้างของโค
                  x1 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_START_X; // เริ่มต้นที่ซ้ายล่าง (ใกล้ไหล่)
                  y1 = (boxY1 + boxY2) / 2 + (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET; // ปรับตำแหน่ง y ให้ต่ำลงเล็กน้อย
                  x2 = boxX1 + (boxX2 - boxX1) * BODY_LENGTH_END_X; // สิ้นสุดที่ขวาบน (ใกล้สะโพก)
                  y2 = (boxY1 + boxY2) / 2 - (boxY2 - boxY1) * BODY_LENGTH_Y_OFFSET; // ปรับตำแหน่ง y ให้สูงขึ้นเล็กน้อย
                } 
                else {
                  // ใช้บ็อกซ์ตามปกติสำหรับวัตถุที่ไม่รู้จัก
                  x1 = boxX1;
                  y1 = boxY1;
                  x2 = boxX2;
                  y2 = boxY2;
                }

                String className = '';
                if (correctedClassId == 0) {
                  className = "Yellow_Mark";
                } else if (correctedClassId == 1) {
                  className = "Heart_Girth";
                } else if (correctedClassId == 2) {
                  className = "Body_Length";
                } else {
                  className = "Unknown_${correctedClassId}";
                }

                // พิมพ์ค่าเพื่อตรวจสอบการแมป classId
                print('การแมปค่า classId: จากโมเดล=$classId แก้ไขเป็น=$correctedClassId ($className)');
                
                // เพิ่มวัตถุที่ตรวจพบ
                allDetectedObjects.add(DetectedObject(
                  classId: correctedClassId,
                  className: className,
                  confidence: confidence,
                  x1: x1,
                  y1: y1,
                  x2: x2,
                  y2: y2,
                ));
                
                print('ตรวจพบ $className: ความเชื่อมั่น ${(confidence * 100).toStringAsFixed(1)}%');
                print('  ตำแหน่งเส้น: (${x1.toInt()},${y1.toInt()}) - (${x2.toInt()},${y2.toInt()})');
                print('  ขอบเขตกรอบ: (${boxX1.toInt()},${boxY1.toInt()}) - (${boxX2.toInt()},${boxY2.toInt()})');
              }
            } catch (boxError) {
              print('เกิดข้อผิดพลาดในการประมวลผลบ็อกซ์ที่ $i: $boxError');
              continue; // ข้ามไปทำบ็อกซ์ถัดไป
            }
          }
          
          // กรองผลลัพธ์โดยเลือกเฉพาะวัตถุที่มีความเชื่อมั่นสูงสุดในแต่ละคลาส
          Map<int, DetectedObject> bestObjects = {};

          // ให้ความสำคัญกับ Yellow Mark (classId = 0) ก่อน
          List<DetectedObject> yellowMarks = allDetectedObjects
              .where((obj) => obj.classId == 0)
              .toList();

          if (yellowMarks.isNotEmpty) {
              // เรียงลำดับ Yellow Mark ตามความเชื่อมั่นจากมากไปน้อย
              yellowMarks.sort((a, b) => b.confidence.compareTo(a.confidence));
              // เลือก Yellow Mark ที่มีความเชื่อมั่นสูงสุด
              bestObjects[0] = yellowMarks.first;
              print('เลือก Yellow Mark ที่มีความเชื่อมั่นสูงสุด: ${yellowMarks.first.confidence}');
          }
          
          for (var obj in allDetectedObjects) {

            // ข้าม Yellow Mark เพราะจัดการไปแล้ว
            if (obj.classId == 0) continue;

            if (!bestObjects.containsKey(obj.classId) || 
                bestObjects[obj.classId]!.confidence < obj.confidence) {
              bestObjects[obj.classId] = obj;
            }
          }
          
          // เพิ่มวัตถุที่ดีที่สุดของแต่ละคลาสลงในรายการสุดท้าย
          detectedObjects = bestObjects.values.toList();

          // เรียงลำดับวัตถุตาม classId
          detectedObjects.sort((a, b) => a.classId.compareTo(b.classId));

        } else {
          print('รูปแบบข้อมูลไม่ตรงกับที่คาดหวัง');
          return [];
        }
      } else {
        print('ไม่พบข้อมูล output ที่ถูกต้อง');
        return [];
      }
      
      // หากยังไม่พบวัตถุใดเลย ส่งรายการว่างกลับไป
      if (detectedObjects.isEmpty) {
        print('ไม่พบวัตถุใดเลย');
        return [];
      }
      
      return detectedObjects;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมวลผล output: $e');
      return [];
    }
  }
  
  // ปล่อยทรัพยากร
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

// คลาสเก็บข้อมูลวัตถุที่ตรวจพบ
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

// คลาสเก็บผลลัพธ์การตรวจจับ
class DetectionResult {
  final bool success;
  final List<DetectedObject>? objects;
  final String? error;
  
  DetectionResult({
    required this.success,
    this.objects,
    this.error,
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