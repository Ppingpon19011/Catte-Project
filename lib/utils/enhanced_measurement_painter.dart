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

      // วาดเส้นตรงสำหรับการวัด
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        paint,
      );

      // วาดจุดที่ปลายทั้งสองด้าน (หมุด)
      _drawEndpoint(canvas, Offset(x1, y1), paint);
      _drawEndpoint(canvas, Offset(x2, y2), paint);

      // คำนวณความยาวของเส้น
      final double length = (Offset(x2, y2) - Offset(x1, y1)).distance;
      
      // คำนวณจุดกึ่งกลางของเส้น
      final double midX = (x1 + x2) / 2;
      final double midY = (y1 + y2) / 2;
      
      // วาดชื่อและความยาวของเส้น
      _drawLabel(canvas, label, x1, y1 - 20, paint.color);
      _drawLabel(canvas, '${(length / scaleX).toStringAsFixed(1)} px', midX, midY, paint.color);
    }
  }

  // วาดจุดที่ปลายของเส้น
  void _drawEndpoint(Canvas canvas, Offset position, Paint paint) {
    canvas.drawCircle(
      position,
      8.0, // ขนาดจุด
      Paint()
        ..color = paint.color.withOpacity(0.7)
        ..style = PaintingStyle.fill
    );
    canvas.drawCircle(
      position,
      8.0, // ขนาดจุด
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
    );
  }

  // วาดป้ายกำกับใต้เส้น
  void _drawLabel(Canvas canvas, String text, double x, double y, Color color) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
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
      text: text,
      style: textStyle,
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    // สร้างพื้นหลังสำหรับข้อความ
    final bgRect = Rect.fromLTWH(
      x, 
      y - textPainter.height - 4,
      textPainter.width + 8,
      textPainter.height + 4,
    );

    // สีพื้นหลังตามประเภทวัตถุ
    Color bgColor = color.withOpacity(0.7);

    final bgPaint = Paint()..color = bgColor;
    
    // วาดพื้นหลังแบบมีมุมโค้ง
    final rrect = RRect.fromRectAndRadius(bgRect, Radius.circular(4));
    canvas.drawRRect(rrect, bgPaint);
    
    textPainter.paint(canvas, Offset(x + 4, y - textPainter.height - 2));
  }

  @override
  bool shouldRepaint(covariant EnhancedMeasurementPainter oldDelegate) {
    return oldDelegate.objects != objects ||
        oldDelegate.originalImageSize != originalImageSize ||
        oldDelegate.renderSize != renderSize;
  }
}