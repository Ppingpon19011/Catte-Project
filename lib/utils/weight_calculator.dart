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
      print("Error: ค่าการวัดไม่ถูกต้อง (heartGirth: $heartGirthInches, bodyLength: $bodyLengthInches)");
      return 0.0;
    }
    
    // คำนวณตามสูตร: weight (pounds) = ((heart girth in inches)^2 * body length in inches) / 300
    double weightInPounds = (pow(heartGirthInches, 2) * bodyLengthInches) / 300;
    
    // แปลงจากปอนด์เป็นกิโลกรัม
    double weightInKg = weightInPounds * 0.453592;
    
    print("ข้อมูลการคำนวณน้ำหนักจาก WeightCalculator:");
    print("- รอบอก: $heartGirthInches นิ้ว");
    print("- ความยาวลำตัว: $bodyLengthInches นิ้ว");
    print("- น้ำหนัก: $weightInPounds ปอนด์ ($weightInKg กก.)");
    
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
      // บันทึกค่าการวัดเพื่อตรวจสอบความถูกต้อง
      print("ข้อมูลการคำนวณจาก WeightCalculator.calculateWeightFromMeasurements:");
      print("- รอบอก: $heartGirthCm ซม.");
      print("- ความยาวลำตัว: $bodyLengthCm ซม.");
      print("- สายพันธุ์: $breed");
      print("- เพศ: $gender");
      print("- อายุ: $ageMonths เดือน");
      
      // แปลงหน่วยจากเซนติเมตรเป็นนิ้ว
      double heartGirthInches = cmToInches(heartGirthCm);
      double bodyLengthInches = cmToInches(bodyLengthCm);
      
      // คำนวณน้ำหนักด้วยสูตรหลัก
      double weightInKg = calculateWeight(heartGirthInches, bodyLengthInches);
      
      // บันทึกค่าน้ำหนักดิบที่คำนวณได้
      print("- น้ำหนักดิบที่คำนวณได้: $weightInKg กก.");
      
      return {
        'success': true,
        'heartGirthCm': heartGirthCm,
        'heartGirthInches': heartGirthInches,
        'bodyLengthCm': bodyLengthCm,
        'bodyLengthInches': bodyLengthInches,
        'rawWeight': weightInKg, // ส่งค่าน้ำหนักดิบที่คำนวณจากสูตรโดยตรง
        'adjustedWeight': adjustWeightByAgeAndGender(weightInKg, gender, ageMonths),
      };
    } catch (e) {
      print("เกิดข้อผิดพลาดในการคำนวณน้ำหนัก: $e");
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
      print('เริ่มประมาณน้ำหนักจากภาพด้วย WeightCalculator.estimateFromImage');
      
      // ค่าการวัดจำลอง (ในระบบจริงควรปรับให้เหมาะสม)
      double baseHeartGirth = 180 + (Random().nextDouble() * 20 - 10);
      double baseBodyLength = 150 + (Random().nextDouble() * 20 - 10);
      double height = 130 + (Random().nextDouble() * 20 - 10);
      
      print("estimateFromImage - ค่าจำลอง:");
      print("- รอบอก: $baseHeartGirth ซม.");
      print("- ความยาวลำตัว: $baseBodyLength ซม.");
      
      // แปลงเป็นนิ้ว
      double heartGirthInches = cmToInches(baseHeartGirth);
      double bodyLengthInches = cmToInches(baseBodyLength);
      
      // คำนวณน้ำหนักด้วยสูตรหลัก (เป็นการคำนวณโดยตรงไม่ผ่านการปรับแต่ง)
      double weightInKg = calculateWeight(heartGirthInches, bodyLengthInches);
      
      print("estimateFromImage - น้ำหนักที่คำนวณได้: $weightInKg กก.");
      
      // ส่งค่าที่ได้กลับไป
      return {
        'success': true,
        'heartGirth': baseHeartGirth,
        'bodyLength': baseBodyLength,
        'height': height,
        'rawWeight': weightInKg, // ส่งน้ำหนักดิบกลับไป
        'adjustedWeight': adjustWeightByAgeAndGender(weightInKg, gender, ageMonths),
        'confidence': 0.6,
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