import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../utils/cattle_detector.dart' as detector;

class ManualMeasurementPainter extends CustomPainter {
  final ui.Image image;
  final List<detector.DetectedObject> detectedObjects;
  final int selectedIndex;
  final Offset? startPoint;
  final Offset? endPoint;
  final bool isEditing;
  final int currentEditingObject;

  ManualMeasurementPainter({
    required this.image,
    required this.detectedObjects,
    this.selectedIndex = -1,
    this.startPoint,
    this.endPoint,
    this.isEditing = false,
    this.currentEditingObject = -1,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // คำนวณอัตราส่วนเพื่อให้ภาพพอดีกับ Canvas
    final double scaleX = size.width / image.width;
    final double scaleY = size.height / image.height;
    final double scale = math.min(scaleX, scaleY);
    
    // คำนวณพิกัดเพื่อวางภาพไว้ตรงกลาง
    final double offsetX = (size.width - image.width * scale) / 2;
    final double offsetY = (size.height - image.height * scale) / 2;
    
    // วาดภาพ
    final src = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
    final dst = Rect.fromLTWH(offsetX, offsetY, image.width * scale, image.height * scale);
    
    // วาดภาพลงบน Canvas
    canvas.drawImageRect(image, src, dst, Paint());
    
    // กำหนดสีตามประเภทของวัตถุ
    final Paint bodyLengthPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    final Paint heartGirthPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    final Paint yellowMarkPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
      
    final Paint selectedPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    final Paint editingPaint = Paint()
      ..color = _getColorByObjectType(currentEditingObject)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    
    // วาดกรอบแต่ละประเภท
    for (int i = 0; i < detectedObjects.length; i++) {
      final obj = detectedObjects[i];
      
      // เลือกสีตามประเภทของวัตถุ
      Paint paint;
      switch (obj.classId) {
        case 0: // Body Length
          paint = bodyLengthPaint;
          break;
        case 1: // Heart Girth
          paint = heartGirthPaint;
          break;
        case 2: // Yellow Mark
          paint = yellowMarkPaint;
          break;
        default:
          paint = Paint()..color = Colors.grey;
      }
      
      // ถ้าเป็นวัตถุที่เลือก ให้ใช้สีสำหรับวัตถุที่เลือก
      if (i == selectedIndex) {
        paint = selectedPaint;
      }
      
      // แปลงพิกัดให้ตรงกับขนาดของ Canvas
      final rect = Rect.fromLTRB(
        offsetX + obj.x1 * scale,
        offsetY + obj.y1 * scale,
        offsetX + obj.x2 * scale,
        offsetY + obj.y2 * scale,
      );
      
      // วาดกรอบ
      canvas.drawRect(rect, paint);
      
      // แสดงป้ายกำกับ
      final String label = _getLabelByClassId(obj.classId);
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
        ],
      );
      
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // วาดพื้นหลังป้ายกำกับ
      final bgPaint = Paint()..color = _getColorByObjectType(obj.classId).withOpacity(0.7);
      final bgRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      
      canvas.drawRect(bgRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
    }
    
    // วาดกรอบที่กำลังสร้าง/แก้ไข
    if (isEditing && startPoint != null && endPoint != null) {
      // วาดเส้นประเพื่อแสดงพื้นที่ที่กำลังเลือก
      final rect = Rect.fromPoints(startPoint!, endPoint!);
      
      // วาดกรอบแบบเส้นประ
      _drawDashedRect(canvas, rect, editingPaint);
      
      // แสดงป้ายกำกับว่ากำลังวาดอะไร
      final String label = _getLabelByClassId(currentEditingObject);
      final textStyle = TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        shadows: [
          Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
        ],
      );
      
      final textSpan = TextSpan(text: label, style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      
      // วาดพื้นหลังป้ายกำกับ
      final bgPaint = Paint()..color = _getColorByObjectType(currentEditingObject).withOpacity(0.7);
      final bgRect = Rect.fromLTWH(
        rect.left,
        rect.top - textPainter.height - 4,
        textPainter.width + 8,
        textPainter.height + 4,
      );
      
      canvas.drawRect(bgRect, bgPaint);
      textPainter.paint(canvas, Offset(rect.left + 4, rect.top - textPainter.height - 2));
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
  
  // ฟังก์ชันสำหรับดึงป้ายกำกับตามประเภทของวัตถุ
  String _getLabelByClassId(int classId) {
    switch (classId) {
      case 0:
        return 'ความยาวลำตัว';
      case 1:
        return 'รอบอก';
      case 2:
        return 'จุดอ้างอิง';
      default:
        return 'ไม่ทราบประเภท';
    }
  }
  
  // ฟังก์ชันสำหรับดึงสีตามประเภทของวัตถุ
  Color _getColorByObjectType(int objectType) {
    switch (objectType) {
      case 0:
        return Colors.blue;
      case 1:
        return Colors.red;
      case 2:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  @override
  bool shouldRepaint(covariant ManualMeasurementPainter oldDelegate) {
    return oldDelegate.image != image ||
           oldDelegate.detectedObjects != detectedObjects ||
           oldDelegate.selectedIndex != selectedIndex ||
           oldDelegate.startPoint != startPoint ||
           oldDelegate.endPoint != endPoint ||
           oldDelegate.isEditing != isEditing ||
           oldDelegate.currentEditingObject != currentEditingObject;
  }
}