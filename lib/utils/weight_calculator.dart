import 'dart:math';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

class WeightCalculator {
  // ความยาวมาตรฐานของจุดอ้างอิง (เซนติเมตร)
  static const double REFERENCE_MARK_LENGTH_CM = 100; // 1 เมตร
  
  // สูตรคำนวณน้ำหนักโค (น้ำหนักเป็นปอนด์)
  // weight (pounds) = ((heart girth in inches)^2 * body length in inches) / 300
  static double calculateWeight(double heartGirthInches, double bodyLengthInches) {
    if (heartGirthInches <= 0 || bodyLengthInches <= 0) {
      return 0.0;
    }
    
    // คำนวณตามสูตร
    double weightInPounds = (pow(heartGirthInches, 2) * bodyLengthInches) / 300;
    
    // แปลงจากปอนด์เป็นกิโลกรัม
    double weightInKg = weightInPounds * 0.453592;
    
    return weightInKg;
  }
  
  // แปลงหน่วยจากเซนติเมตรเป็นนิ้ว
  static double cmToInches(double cm) {
    return cm * 0.393701;
  }
  
  // แปลงหน่วยจากนิ้วเป็นเซนติเมตร
  static double inchesToCm(double inches) {
    return inches * 2.54;
  }

  // ปรับค่าน้ำหนักตามเพศและอายุ
  static double adjustWeightByAgeAndGender(double calculatedWeight, String gender, int ageMonths) {
    double adjustedWeight = calculatedWeight;
    
    // ปรับค่าตามเพศ
    if (gender == 'เพศผู้') {
      // โคเพศผู้มักจะหนักกว่าเพศเมียประมาณ 5-10%
      adjustedWeight *= 1.05;
    }
    
    // ปรับค่าตามอายุ
    if (ageMonths < 12) {
      adjustedWeight *= 0.98; // ปรับลง 2% สำหรับลูกโค
    } else if (ageMonths > 36) {
      adjustedWeight *= 1.02; // ปรับขึ้น 2% สำหรับโคโตเต็มวัย
    }
    
    return adjustedWeight;
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
  
  // คำนวณน้ำหนักจากขนาดของโค
  static Map<String, dynamic> calculateWeightFromMeasurements(
    double heartGirthCm, 
    double bodyLengthCm, 
    String breed, 
    String gender, 
    int ageMonths
  ) {
    try {
      // แปลงหน่วยจากเซนติเมตรเป็นนิ้ว
      double heartGirthInches = cmToInches(heartGirthCm);
      double bodyLengthInches = cmToInches(bodyLengthCm);
      
      // คำนวณน้ำหนักด้วยสูตรหลัก
      double weightInKg = calculateWeight(heartGirthInches, bodyLengthInches);
      
      // ปรับค่าตามเพศและอายุ
      double adjustedWeight = adjustWeightByAgeAndGender(weightInKg, gender, ageMonths);
      
      return {
        'success': true,
        'heartGirthCm': heartGirthCm,
        'heartGirthInches': heartGirthInches,
        'bodyLengthCm': bodyLengthCm,
        'bodyLengthInches': bodyLengthInches,
        'rawWeight': weightInKg,
        'adjustedWeight': adjustedWeight,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // คำนวณมาตราส่วนจากจุดอ้างอิง
  static double calculateScaleFromReference(double referenceMarkPixels) {
    if (referenceMarkPixels <= 0) return 0.0;
    return REFERENCE_MARK_LENGTH_CM / referenceMarkPixels;
  }
  
  // แก้ไขการคำนวณรอบอกจากภาพวัด
  static double calculateHeartGirthFromHeight(double heartGirthHeight) {
    // รอบอกคือ π * ความสูงของรอบอก
    // แทนที่จะใช้ค่าความสูงโดยตรง ให้ใช้สูตรเส้นรอบวงของวงรี
    // สมมติให้ความกว้างของวงรีเป็น heartGirthHeight/2 
    // และความสูงของวงรีเป็น heartGirthHeight/2
    // เส้นรอบวงของวงรี ≈ 2π * √((a² + b²)/2) โดย a และ b คือรัศมีแกนหลักและแกนรอง

    // ในกรณีนี้ เราตั้งสมมติฐานว่าวงรีของการตัดขวางลำตัวโคมีความกว้างเท่ากับความสูง
    // ทำให้การคำนวณเหลือเพียง 2π * √((r² + r²)/2) = 2π * r
    // ซึ่งก็คือเส้นรอบวงของวงกลม = 2πr

    // นั่นคือ เราสามารถประมาณรอบอกได้จาก π * heartGirthHeight
    return math.pi * heartGirthHeight;
  }
  
  // จำลองการประมาณจากภาพถ่าย (ในระบบจริงควรใช้ ML model)
  static Future<Map<String, dynamic>> estimateFromImage(
      File imageFile, String breed, String gender, int ageMonths) async {
    try {
      // อ่านข้อมูลภาพ
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);
      
      if (image == null) {
        return {
          'success': false,
          'error': 'ไม่สามารถอ่านรูปภาพได้',
        };
      }
      
      // สร้าง Random เพื่อจำลองความแปรปรวน
      final Random random = Random();
      
      // ข้อความแจ้งเตือนว่าค่านี้เป็นค่าสมมติ
      print('หมายเหตุ: ค่านี้เป็นค่าจำลอง ควรใช้การวัดด้วยตนเองเพื่อความแม่นยำ');
      
      // จำลองการวัดรอบอก
      double baseHeartGirth = 180 + (random.nextDouble() * 20 - 10);
      
      // จำลองการวัดความยาวลำตัว
      double baseBodyLength = 150 + (random.nextDouble() * 20 - 10);
      
      // จำลองความสูง
      double height = 130 + (random.nextDouble() * 20 - 10);
      
      // แปลงเป็นนิ้ว
      double heartGirthInches = cmToInches(baseHeartGirth);
      double bodyLengthInches = cmToInches(baseBodyLength);
      
      // คำนวณน้ำหนัก
      double weightInKg = calculateWeight(heartGirthInches, bodyLengthInches);
      
      // ปรับค่าตามเพศและอายุ
      double adjustedWeight = adjustWeightByAgeAndGender(weightInKg, gender, ageMonths);
      
      return {
        'success': true,
        'heartGirth': baseHeartGirth,
        'bodyLength': baseBodyLength,
        'height': height,
        'rawWeight': weightInKg,
        'adjustedWeight': adjustedWeight,
        'confidence': 0.6, // ค่าความเชื่อมั่นต่ำเนื่องจากเป็นค่าสมมติ
        'message': 'ค่านี้เป็นค่าจำลอง ควรใช้การวัดด้วยตนเองเพื่อความแม่นยำ',
      };
    } catch (e) {
      print('เกิดข้อผิดพลาดในการประมาณน้ำหนัก: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }
  
  // คำนวณน้ำหนักที่ควรจะเป็นตามอายุและสายพันธุ์
  static double calculateIdealWeight(String breed, String gender, int ageMonths) {
    double baseWeight = 0.0;
    
    // กำหนดน้ำหนักพื้นฐานตามสายพันธุ์
    if (breed == 'Brahman' || breed == 'บราห์มัน') {
      baseWeight = 35 + (ageMonths * 15); // เริ่มที่ 35 กก. และเพิ่ม 15 กก. ต่อเดือน
    } else if (breed == 'Charolais' || breed == 'ชาร์โรเลส์') {
      baseWeight = 40 + (ageMonths * 18); // เริ่มที่ 40 กก. และเพิ่ม 18 กก. ต่อเดือน
    } else if (breed == 'Angus' || breed == 'แองกัส') {
      baseWeight = 38 + (ageMonths * 17); // เริ่มที่ 38 กก. และเพิ่ม 17 กก. ต่อเดือน
    } else {
      baseWeight = 35 + (ageMonths * 14); // ค่าเริ่มต้นสำหรับสายพันธุ์อื่นๆ
    }
    
    // ปรับค่าตามเพศ
    if (gender == 'เพศผู้') {
      baseWeight *= 1.1; // เพศผู้หนักกว่าเพศเมียประมาณ 10%
    }
    
    // จำกัดค่าสูงสุดตามอายุ
    if (ageMonths > 36) {
      // โคโตเต็มวัย (อายุมากกว่า 3 ปี)
      double maxWeight = 0.0;
      
      if (breed == 'Brahman' || breed == 'บราห์มัน') {
        maxWeight = (gender == 'เพศผู้') ? 800 : 650;
      } else if (breed == 'Charolais' || breed == 'ชาร์โรเลส์') {
        maxWeight = (gender == 'เพศผู้') ? 1000 : 750;
      } else if (breed == 'Angus' || breed == 'แองกัส') {
        maxWeight = (gender == 'เพศผู้') ? 900 : 700;
      } else {
        maxWeight = (gender == 'เพศผู้') ? 750 : 600;
      }
      
      // ไม่ให้น้ำหนักเกินค่าสูงสุด
      if (baseWeight > maxWeight) {
        baseWeight = maxWeight;
      }
    }
    
    return baseWeight;
  }
  
  // วิเคราะห์ข้อมูลน้ำหนักเทียบกับเกณฑ์
  static Map<String, dynamic> analyzeWeight(double currentWeight, String breed, String gender, int ageMonths) {
    double idealWeight = calculateIdealWeight(breed, gender, ageMonths);
    double weightRatio = currentWeight / idealWeight * 100;
    
    String status = "";
    String recommendation = "";
    
    if (weightRatio < 80) {
      status = "น้ำหนักต่ำกว่าเกณฑ์";
      recommendation = "ควรเพิ่มปริมาณอาหารและเสริมโภชนาการ";
    } else if (weightRatio < 90) {
      status = "น้ำหนักค่อนข้างต่ำ";
      recommendation = "ควรปรับปรุงโภชนาการเล็กน้อย";
    } else if (weightRatio <= 110) {
      status = "น้ำหนักอยู่ในเกณฑ์ปกติ";
      recommendation = "ดูแลอาหารและสุขภาพตามปกติ";
    } else if (weightRatio <= 120) {
      status = "น้ำหนักค่อนข้างสูง";
      recommendation = "ควรระวังปริมาณอาหารไม่ให้มากเกินไป";
    } else {
      status = "น้ำหนักสูงเกินเกณฑ์";
      recommendation = "ควรปรับลดปริมาณอาหารและเพิ่มการเคลื่อนไหว";
    }
    
    return {
      'currentWeight': currentWeight,
      'idealWeight': idealWeight,
      'weightRatio': weightRatio,
      'status': status,
      'recommendation': recommendation,
    };
  }
}