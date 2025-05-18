import 'package:flutter/material.dart';
import '../utils/cattle_detector.dart' as detector;

// Widget สำหรับแสดงผลการตรวจจับในหน้า weight_estimate_screen.dart
class DetectionResultDisplay extends StatelessWidget {
  final detector.DetectionResult detectionResult;
  final VoidCallback onContinue;
  
  const DetectionResultDisplay({
    Key? key,
    required this.detectionResult,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // ตรวจสอบว่าพบวัตถุแต่ละประเภทหรือไม่
    bool hasYellowMark = false;
    bool hasHeartGirth = false;
    bool hasBodyLength = false;
    
    if (detectionResult.objects != null) {
      for (var obj in detectionResult.objects!) {
        if (obj.classId == 2) hasYellowMark = true;
        else if (obj.classId == 1) hasHeartGirth = true;
        else if (obj.classId == 0) hasBodyLength = true;
      }
    }
    
    return Card(
      margin: EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ผลการตรวจจับ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            
            // แสดงสถานะการตรวจพบแต่ละชนิด
            _buildDetectionStatusRow('จุดอ้างอิง (Yellow Mark)', hasYellowMark),
            _buildDetectionStatusRow('รอบอก (Heart Girth)', hasHeartGirth),
            _buildDetectionStatusRow('ความยาวลำตัว (Body Length)', hasBodyLength),
            
            SizedBox(height: 16),
            
            // ข้อความแนะนำตามผลการตรวจจับ
            _buildRecommendationText(hasYellowMark, hasHeartGirth, hasBodyLength),
            
            SizedBox(height: 16),
            
            // ปุ่มดำเนินการ
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    // ปิด dialog หรือทำอย่างอื่น
                    Navigator.of(context).pop();
                  },
                  child: Text('ปิด'),
                ),
                SizedBox(width: 8),
                ElevatedButton(
                  onPressed: onContinue,
                  child: Text('ไปหน้าวัดด้วยตนเอง'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  // สร้างแถวแสดงสถานะการตรวจจับ
  Widget _buildDetectionStatusRow(String label, bool detected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(
            detected ? Icons.check_circle : Icons.cancel,
            color: detected ? Colors.green : Colors.red,
            size: 24,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '$label: ${detected ? 'ตรวจพบ' : 'ไม่พบ'}',
              style: TextStyle(
                fontWeight: detected ? FontWeight.normal : FontWeight.bold,
                color: detected ? Colors.black87 : Colors.red[700],
              ),
            ),
          ),
          if (detected)
            _buildConfidenceDisplay(label),
        ],
      ),
    );
  }
  
  // แสดงค่าความเชื่อมั่นของการตรวจจับ
  Widget _buildConfidenceDisplay(String label) {
    // หาค่าความเชื่อมั่นของวัตถุตามชนิด
    int classId = -1;
    if (label.contains("จุดอ้างอิง") || label.contains("Yellow Mark")) {
      classId = 2;
    } else if (label.contains("รอบอก") || label.contains("Heart Girth")) {
      classId = 1;
    } else if (label.contains("ความยาวลำตัว") || label.contains("Body Length")) {
      classId = 0;
    }
    
    if (classId == -1 || detectionResult.objects == null) return Container();
    
    // หาวัตถุที่มี classId ตรงกัน
    detector.DetectedObject? targetObject;
    for (var obj in detectionResult.objects!) {
      if (obj.classId == classId) {
        targetObject = obj;
        break;
      }
    }
    
    if (targetObject == null) return Container();
    
    // แปลงความเชื่อมั่นเป็นเปอร์เซ็นต์
    int confidencePercent = (targetObject.confidence * 100).round();
    
    // กำหนดสีตามระดับความเชื่อมั่น
    Color confidenceColor = Colors.green;
    if (confidencePercent < 50) {
      confidenceColor = Colors.red;
    } else if (confidencePercent < 75) {
      confidenceColor = Colors.orange;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: confidenceColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: confidenceColor, width: 1),
      ),
      child: Text(
        '$confidencePercent%',
        style: TextStyle(
          color: confidenceColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  // สร้างข้อความแนะนำตามผลการตรวจจับ
  Widget _buildRecommendationText(bool hasYellowMark, bool hasHeartGirth, bool hasBodyLength) {
    if (hasYellowMark && hasHeartGirth && hasBodyLength) {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'ตรวจพบวัตถุครบถ้วนทั้ง 3 ประเภท คุณสามารถดำเนินการวัดต่อได้',
                style: TextStyle(color: Colors.green[800]),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'ตรวจพบวัตถุไม่ครบถ้วน',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'คุณจะต้องทำการวัดส่วนที่ไม่พบด้วยตนเองในหน้าถัดไป:',
              style: TextStyle(color: Colors.grey[700]),
            ),
            SizedBox(height: 8),
            if (!hasYellowMark)
              Text('• จุดอ้างอิง (Yellow Mark) - จำเป็นสำหรับการคำนวณสัดส่วน'),
            if (!hasHeartGirth)
              Text('• รอบอก (Heart Girth) - จำเป็นสำหรับการคำนวณน้ำหนัก'),
            if (!hasBodyLength)
              Text('• ความยาวลำตัว (Body Length) - จำเป็นสำหรับการคำนวณน้ำหนัก'),
          ],
        ),
      );
    }
  }
}