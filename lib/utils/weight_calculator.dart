import 'dart:math';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class WeightCalculator {
  // ค่าคงที่สำหรับแต่ละสายพันธุ์ในสูตร Schaeffer
  static const Map<String, double> breedConstants = {
    'Beefmaster': 650.0,
    'Brahman': 660.0,
    'Charolais': 630.0,
    'Angus': 645.0,
    'Hereford': 655.0,
    'Simmental': 640.0,
    'Limousin': 635.0,
    'Holstein': 640.0,
    'Jersey': 670.0,
    'Sahiwal': 665.0,
    'พื้นเมืองไทย': 680.0,
    'ลูกผสมบราห์มัน': 665.0,
    'ลูกผสมชาร์โรเลส์': 640.0,
    'อื่นๆ': 650.0,
  };

  // สูตรคำนวณน้ำหนักโคจากรอบอกและความยาวลำตัว (Schaeffer's formula)
  // น้ำหนัก (กก.) = (รอบอก (ซม.)^2 × ความยาว (ซม.)) / K
  static double calculateWeightByBreed(double heartGirth, double bodyLength, String breed) {
    // หาค่า K จากสายพันธุ์
    double k = breedConstants[breed] ?? 650.0; // ใช้ค่าเริ่มต้นถ้าไม่พบสายพันธุ์
    
    // ตรวจสอบเพื่อป้องกันค่าติดลบหรือเป็นศูนย์
    if (heartGirth <= 0 || bodyLength <= 0) {
      return 0.0;
    }
    
    // คำนวณตามสูตร Schaeffer
    return (pow(heartGirth, 2) * bodyLength) / k;
  }

  // คำนวณจากเพศและอายุเพิ่มเติม
  static double adjustWeightByAgeAndGender(double calculatedWeight, String gender, int ageMonths) {
    double adjustedWeight = calculatedWeight;
    
    // ปรับค่าตามเพศ
    if (gender == 'เพศผู้') {
      // โคเพศผู้มักจะหนักกว่าเพศเมียประมาณ 5-10%
      adjustedWeight *= 1.05;
    }
    
    // ปรับค่าตามอายุ (อายุน้อยมีความคลาดเคลื่อนสูงกว่า)
    if (ageMonths < 12) {
      adjustedWeight *= 0.98; // ปรับลง 2% สำหรับลูกโค
    } else if (ageMonths > 36) {
      adjustedWeight *= 1.02; // ปรับขึ้น 2% สำหรับโคโตเต็มวัย
    }
    
    return adjustedWeight;
  }

  // จำลองการประมาณจากภาพถ่าย (ในระบบจริงควรใช้ ML model)
  static Future<Map<String, dynamic>> estimateFromImage(File imageFile, String breed, String gender, int ageMonths) async {
    try {
      // จำลองการวัดสัดส่วนจากภาพ
      Map<String, double> dimensions = await estimateProportionsFromImage(imageFile);
      
      // คำนวณน้ำหนักจากสัดส่วน
      double heartGirth = dimensions['heartGirth'] ?? 0.0;
      double bodyLength = dimensions['bodyLength'] ?? 0.0;
      
      // คำนวณน้ำหนักโดยใช้สูตร Schaeffer
      double weight = calculateWeightByBreed(heartGirth, bodyLength, breed);
      
      // ปรับค่าตามเพศและอายุ
      double adjustedWeight = adjustWeightByAgeAndGender(weight, gender, ageMonths);
      
      return {
        'success': true,
        'heartGirth': heartGirth,
        'bodyLength': bodyLength,
        'rawWeight': weight,
        'adjustedWeight': adjustedWeight,
        'confidence': 0.85, // ระดับความเชื่อมั่น (ในระบบจริงควรคำนวณจากโมเดล)
      };
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมาณน้ำหนัก: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  // จำลองการวัดสัดส่วนจากภาพ
  // ในระบบจริงควรใช้ Computer Vision หรือ ML model
  static Future<Map<String, double>> estimateProportionsFromImage(File imageFile) async {
    // ในระบบจริง นี่จะส่งภาพไปยัง ML model แล้วได้ผลลัพธ์กลับมา
    // แต่ในตัวอย่างนี้ เราจะจำลองการวัดขนาดจากภาพ
    try {
      // ดึงขนาดภาพจริง
      final bytes = await imageFile.readAsBytes();
      final image = img.decodeImage(bytes);
      final imageWidth = image?.width ?? 0;
      final imageHeight = image?.height ?? 0;
      
      // สร้าง Random เพื่อจำลองความแปรปรวน
      final Random random = Random();
      
      // จำลองการวัดรอบอก (ในระบบจริงจะได้จากการวิเคราะห์ภาพ)
      // สมมติว่ารอบอกมีค่าระหว่าง 150-200 ซม. (แปรผันตามขนาดภาพ)
      double baseHeartGirth = 150 + (imageHeight / 1000 * 50);
      double heartGirth = baseHeartGirth + (random.nextDouble() * 20 - 10);
      
      // จำลองการวัดความยาวลำตัว (ในระบบจริงจะได้จากการวิเคราะห์ภาพ)
      // สมมติว่าความยาวมีค่าระหว่าง 120-180 ซม. (แปรผันตามขนาดภาพ)
      double baseBodyLength = 120 + (imageWidth / 1000 * 60);
      double bodyLength = baseBodyLength + (random.nextDouble() * 20 - 10);
      
      // จำลองความสูง
      double height = 120 + (random.nextDouble() * 30);
      
      return {
        'heartGirth': heartGirth,
        'bodyLength': bodyLength,
        'height': height,
      };
    } catch (e) {
      print('เกิดข้อผิดพลาดในการวัดสัดส่วน: $e');
      // ส่งค่าเริ่มต้นหากเกิดข้อผิดพลาด
      return {
        'heartGirth': 170.0,
        'bodyLength': 150.0,
        'height': 130.0,
      };
    }
  }

  // คำนวณอายุโคเป็นเดือนจากวันเกิด
  static int calculateAgeInMonths(DateTime birthDate) {
    final now = DateTime.now();
    final difference = now.difference(birthDate);
    return (difference.inDays / 30).floor(); // ประมาณเดือนจากจำนวนวัน
  }

  // คำนวณอัตราการเจริญเติบโตเฉลี่ยต่อวัน (Average Daily Gain)
  static double calculateADG(double startWeight, double endWeight, int daysBetween) {
    if (daysBetween <= 0) return 0;
    return (endWeight - startWeight) / daysBetween;
  }
}