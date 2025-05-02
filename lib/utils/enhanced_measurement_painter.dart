import 'package:flutter/material.dart';
import '../utils/cattle_detector.dart' as detector;

class EnhancedMeasurementPainter extends CustomPainter {
  final List<detector.DetectedObject> objects;
  final Size? originalImageSize;
  final Size? renderSize;

  EnhancedMeasurementPainter(
    this.objects, {
    this.originalImageSize,
    this.renderSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    print('EnhancedMeasurementPainter: กำลังวาด ${objects.length} วัตถุ');

    // กำหนดสีและสไตล์ของเส้น - ปรับให้ชัดเจนยิ่งขึ้น
    final Paint bodyLengthPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final Paint heartGirthPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    final Paint yellowMarkPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;

    // คำนวณอัตราส่วนการปรับขนาด
    double scaleX = 1.0;
    double scaleY = 1.0;

    if (originalImageSize != null && renderSize != null) {
      scaleX = renderSize!.width / originalImageSize!.width;
      scaleY = renderSize!.height / originalImageSize!.height;
    } else if (originalImageSize != null) {
      scaleX = size.width / originalImageSize!.width;
      scaleY = size.height / originalImageSize!.height;
    }

    // วาดกรอบสำหรับแต่ละวัตถุที่ตรวจพบ
    for (var obj in objects) {
      Rect rect;
      Paint paint;
      String label;

      // กำหนดสีและป้ายกำกับตามประเภทของวัตถุ
      switch (obj.classId) {
        case 0: // Body Length
          paint = bodyLengthPaint;
          label = 'ความยาวลำตัว';
          break;
        case 1: // Heart Girth
          paint = heartGirthPaint;
          label = 'รอบอก';
          break;
        case 2: // Yellow Mark
          paint = yellowMarkPaint;
          label = 'จุดอ้างอิง';
          break;
        default:
          paint = bodyLengthPaint; // Default fallback
          label = 'ไม่ทราบประเภท';
      }

      // ปรับขนาดพิกัดตามอัตราส่วนการแสดงผล
      double x1 = obj.x1 * scaleX;
      double y1 = obj.y1 * scaleY;
      double x2 = obj.x2 * scaleX;
      double y2 = obj.y2 * scaleY;

      rect = Rect.fromLTRB(x1, y1, x2, y2);

      // แสดงกรอบที่ประมาณค่าเป็นเส้นประ
      if (obj.className.contains('Estimated')) {
        _drawDashedRect(canvas, rect, paint);
      } else {
        canvas.drawRect(rect, paint);
      }

      // แสดงข้อความระบุประเภท
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(
            offset: Offset(1.0, 1.0),
            blurRadius: 3.0,
            color: Colors.black,
          ),
        ],
      );

      final textSpan = TextSpan(
        text: label,
        style: textStyle,
      );

      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();

      // สร้างพื้นหลังสำหรับข้อความ
      final bgRect = Rect.fromLTWH(
        x1, 
        y1 - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      // สีพื้นหลังตามประเภทวัตถุ
      Color bgColor;
      switch (obj.classId) {
        case 0: // Body Length
          bgColor = Colors.blue.withOpacity(0.7);
          break;
        case 1: // Heart Girth
          bgColor = Colors.red.withOpacity(0.7);
          break;
        case 2: // Yellow Mark
          bgColor = Colors.amber.withOpacity(0.7);
          break;
        default:
          bgColor = Colors.grey.withOpacity(0.7);
      }

      final bgPaint = Paint()..color = bgColor;
      canvas.drawRect(bgRect, bgPaint);
      textPainter.paint(canvas, Offset(x1 + 4, y1 - textPainter.height - 2));
    }
  }

  // ฟังก์ชันสำหรับวาดเส้นประ
  void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
    final double dashWidth = 5;
    final double dashSpace = 3;
    
    // วาดเส้นด้านบน
    double startX = rect.left;
    final double topY = rect.top;
    while (startX < rect.right) {
      double endX = startX + dashWidth;
      if (endX > rect.right) endX = rect.right;
      canvas.drawLine(Offset(startX, topY), Offset(endX, topY), paint);
      startX = endX + dashSpace;
    }
    
    // วาดเส้นด้านล่าง
    startX = rect.left;
    final double bottomY = rect.bottom;
    while (startX < rect.right) {
      double endX = startX + dashWidth;
      if (endX > rect.right) endX = rect.right;
      canvas.drawLine(Offset(startX, bottomY), Offset(endX, bottomY), paint);
      startX = endX + dashSpace;
    }
    
    // วาดเส้นด้านซ้าย
    double startY = rect.top;
    final double leftX = rect.left;
    while (startY < rect.bottom) {
      double endY = startY + dashWidth;
      if (endY > rect.bottom) endY = rect.bottom;
      canvas.drawLine(Offset(leftX, startY), Offset(leftX, endY), paint);
      startY = endY + dashSpace;
    }
    
    // วาดเส้นด้านขวา
    startY = rect.top;
    final double rightX = rect.right;
    while (startY < rect.bottom) {
      double endY = startY + dashWidth;
      if (endY > rect.bottom) endY = rect.bottom;
      canvas.drawLine(Offset(rightX, startY), Offset(rightX, endY), paint);
      startY = endY + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant EnhancedMeasurementPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.originalImageSize != originalImageSize ||
        oldDelegate.renderSize != renderSize;
  }
}