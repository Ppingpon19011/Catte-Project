import 'dart:math';

class WeightCalculator {
  // สูตรอย่างง่ายในการประมาณน้ำหนักโค (Schaeffer's formula)
  // น้ำหนัก (กก.) = (รอบอก (ซม.)^2 × ความยาว (ซม.)) / 300
  // สูตรนี้เป็นเพียงสูตรทั่วไป ในทางปฏิบัติต้องใช้โมเดล ML ที่เรียนรู้จากข้อมูลจริง
  
  // จำลองการได้รับค่าจากภาพถ่าย
  static double estimateWeightFromImage(String imagePath, double currentWeight) {
    // ในระบบจริง นี่จะส่งภาพไปยัง ML model แล้วได้ผลลัพธ์กลับมา
    // แต่ในตัวอย่างนี้ เราจะจำลองการวัดขนาดจากภาพ
    
    // สร้าง Random เพื่อจำลองความแปรปรวน
    final Random random = Random();
    
    // จำลองการวัดรอบอก (ในระบบจริงจะได้จากการวิเคราะห์ภาพ)
    double chesCircumference = 150 + random.nextDouble() * 50; // 150-200 cm
    
    // จำลองการวัดความยาวลำตัว (ในระบบจริงจะได้จากการวิเคราะห์ภาพ)
    double bodyLength = 120 + random.nextDouble() * 60; // 120-180 cm
    
    // คำนวณน้ำหนักตามสูตร Schaeffer โดยเพิ่มความแปรปรวนเล็กน้อย
    double calculatedWeight = 
        (pow(chesCircumference, 2) * bodyLength) / (300 * (0.9 + random.nextDouble() * 0.2));
    
    // ในระบบจริง ควรมีการปรับสูตรตามสายพันธุ์, เพศ, อายุ และอื่นๆ
    
    // ให้น้ำหนักที่คำนวณได้อยู่ในช่วงที่สมเหตุสมผลจากน้ำหนักปัจจุบัน (±15%)
    double minWeight = currentWeight * 0.85;
    double maxWeight = currentWeight * 1.15;
    
    if (calculatedWeight < minWeight) calculatedWeight = minWeight + (random.nextDouble() * (currentWeight - minWeight));
    if (calculatedWeight > maxWeight) calculatedWeight = currentWeight + (random.nextDouble() * (maxWeight - currentWeight));
    
    return calculatedWeight;
  }
}