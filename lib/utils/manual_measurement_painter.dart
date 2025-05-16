import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import '../utils/cattle_detector.dart';

class ManualMeasurementPainter extends CustomPainter {
  final ui.Image? image;
  final List<DetectedObject> detectedObjects;
  final int selectedIndex;
  final Offset? startPoint;
  final Offset? endPoint;
  final bool isEditing;
  final int currentEditingObject;
  final double zoomScale;
  final double anchorPointRadius; // ขนาดจุดยึด (หมุด)
  final double pinScale; // ใช้ scale แทน boolean animation
  final bool showOriginalBoxes;

  ManualMeasurementPainter({
    required this.image,
    required this.detectedObjects,
    this.selectedIndex = -1,
    this.startPoint,
    this.endPoint,
    this.isEditing = false,
    this.currentEditingObject = -1,
    this.zoomScale = 1.0,
    this.anchorPointRadius = 12.0, // ค่าเริ่มต้นของหมุด
    this.pinScale = 1.0, // ค่าเริ่มต้น 1.0
    this.showOriginalBoxes = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ประกาศตัวแปรสำคัญเริ่มต้น
    double offsetX = 0;
    double offsetY = 0;
    double baseScale = 1.0;

    // ตรวจสอบว่า image ไม่เป็น null ก่อนที่จะวาด
    if (image == null) {
      // วาดพื้นหลังสำหรับกรณีที่ไม่มีรูปภาพ
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()..color = Colors.grey[300]!,
      );
      
      // วาดข้อความแจ้งเตือน
      final textStyle = TextStyle(
        color: Colors.black54,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      );
      
      final textSpan = TextSpan(text: "ไม่มีรูปภาพ", style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      final xCenter = (size.width - textPainter.width) / 2;
      final yCenter = (size.height - textPainter.height) / 2;
      textPainter.paint(canvas, Offset(xCenter, yCenter));
      
      return; // ออกจากเมธอดเพราะไม่มีรูปภาพ
    }

    // คำนวณอัตราส่วนเพื่อให้ภาพพอดีกับ Canvas
    final double scaleX = size.width / image!.width;
    final double scaleY = size.height / image!.height;
    baseScale = math.min(scaleX, scaleY);
    
    // คำนวณพิกัดเพื่อวางภาพไว้ตรงกลาง
    offsetX = (size.width - image!.width * baseScale) / 2;
    offsetY = (size.height - image!.height * baseScale) / 2;
    
    // วาดกรอบตรวจจับต้นฉบับ (bounding boxes)
    if (showOriginalBoxes) {
      for (int i = 0; i < detectedObjects.length; i++) {
        final obj = detectedObjects[i];
        
        // กำหนดสีตามประเภทวัตถุ
        Paint boxPaint = Paint()
          ..color = _getColorByObjectType(obj.classId).withOpacity(0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;
        
        // สร้างกรอบรอบพื้นที่การตรวจจับ
        Rect detectionBox;
        
        // ในกรณีของเส้น เราต้องสร้างกรอบรอบๆ เส้น
        if (obj.classId == 2) { // จุดอ้างอิง (Yellow Mark) - แนวนอน
          // สร้างกรอบยาวตามแนวนอน
          detectionBox = Rect.fromLTWH(
            offsetX + (obj.x1 - 10) * baseScale, 
            offsetY + (obj.y1 - 20) * baseScale,
            (obj.x2 - obj.x1 + 20) * baseScale, 
            40 * baseScale
          );
        } else if (obj.classId == 1) { // รอบอก (Heart Girth) - แนวตั้ง
          // สร้างกรอบสูงตามแนวตั้ง
          detectionBox = Rect.fromLTWH(
            offsetX + (obj.x1 - 20) * baseScale, 
            offsetY + obj.y1 * baseScale,
            40 * baseScale, 
            (obj.y2 - obj.y1) * baseScale
          );
        } else if (obj.classId == 0) { // ความยาวลำตัว (Body Length) - แนวนอน/เฉียง
          // สร้างกรอบยาวตามแนวนอน
          detectionBox = Rect.fromLTWH(
            offsetX + obj.x1 * baseScale, 
            offsetY + (obj.y1 - 20) * baseScale,
            (obj.x2 - obj.x1) * baseScale, 
            40 * baseScale
          );
        } else {
          // กรอบปกติสำหรับวัตถุไม่รู้จัก
          detectionBox = Rect.fromLTWH(
            offsetX + obj.x1 * baseScale, 
            offsetY + obj.y1 * baseScale,
            (obj.x2 - obj.x1) * baseScale, 
            (obj.y2 - obj.y1) * baseScale
          );
        }
        
        // วาดกรอบด้วยเส้นประ
        _drawDashedRect(canvas, detectionBox, boxPaint);
        
        // แสดงระดับความเชื่อมั่น
        final confidence = (obj.confidence * 100).toStringAsFixed(0) + '%';
        _drawLabel(
          canvas, 
          _getLabelByClassId(obj.classId) + ' ' + confidence, 
          detectionBox.left, 
          detectionBox.top - 5, 
          _getColorByObjectType(obj.classId)
        );
      }
    }
    
    // วาดภาพ
    final src = Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble());
    final dst = Rect.fromLTWH(offsetX, offsetY, image!.width * baseScale, image!.height * baseScale);
    
    // วาดภาพลงบน Canvas
    canvas.drawImageRect(image!, src, dst, Paint());
    
    // กำหนดสีตามประเภทของการวัด
    final Paint bodyLengthPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    final Paint heartGirthPaint = Paint()
      ..color = Colors.red
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    final Paint yellowMarkPaint = Paint()
      ..color = Colors.amber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
      
    final Paint selectedPaint = Paint()
      ..color = Colors.green
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
      
    final Paint editingPaint = Paint()
      ..color = _getColorByObjectType(currentEditingObject)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    
    // วาดเส้นสำหรับการวัดแต่ละประเภท
    for (int i = 0; i < detectedObjects.length; i++) {
      final obj = detectedObjects[i];
      
      // เลือกสีตามประเภทของวัตถุ
      Paint paint;
      switch (obj.classId) {
        case 2: // จุดอ้างอิง (Yellow Mark)
          paint = yellowMarkPaint;
          break;
        case 1: // รอบอก (Heart Girth)
          paint = heartGirthPaint;
          break;
        case 0: // ความยาวลำตัว (Body Length)
          paint = bodyLengthPaint;
          break;
        default:
          paint = Paint()..color = Colors.grey;
      }
      
      // ถ้าเป็นวัตถุที่เลือก ให้ใช้สีสำหรับวัตถุที่เลือก
      if (i == selectedIndex) {
        paint = selectedPaint;
      }
      
      // แปลงพิกัดให้ตรงกับขนาดของ Canvas
      final x1 = offsetX + obj.x1 * baseScale;
      final y1 = offsetY + obj.y1 * baseScale;
      final x2 = offsetX + obj.x2 * baseScale;
      final y2 = offsetY + obj.y2 * baseScale;
      
      // วาดเส้นตรง
      canvas.drawLine(
        Offset(x1, y1),
        Offset(x2, y2),
        paint..strokeWidth = 4
      );
      
      // วาดจุดยึดที่ปลายทั้งสองด้าน
      _drawAnchorPoint(canvas, Offset(x1, y1), paint, i == selectedIndex);
      _drawAnchorPoint(canvas, Offset(x2, y2), paint, i == selectedIndex);
      
      // คำนวณความยาวของเส้น
      final double lineLength = math.sqrt(math.pow(x2 - x1, 2) + math.pow(y2 - y1, 2));
      final double lengthInPixels = lineLength / baseScale; // แปลงกลับเป็นพิกเซลของภาพจริง
      
      // แสดงความยาวที่วัดได้
      final measureText = '${lengthInPixels.toStringAsFixed(0)} px';
      
      // คำนวณตำแหน่งแสดงค่า - ตรงกลางของเส้น
      final midX = (x1 + x2) / 2;
      final midY = (y1 + y2) / 2;
      
      // วาดข้อความแสดงความยาว
      _drawLabel(canvas, measureText, midX - 25, midY, _getColorByObjectType(obj.classId));
      
      // แสดงป้ายกำกับประเภทการวัด
      final String label = _getLabelByClassId(obj.classId);
      
      // ปรับตำแหน่งป้ายกำกับตามประเภทของเส้น
      double labelX, labelY;
      
      if (obj.classId == 2) { // จุดอ้างอิง (Yellow Mark)
        labelX = x1;
        labelY = y1 - 30; // แสดงเหนือเส้น
      } else if (obj.classId == 1) { // รอบอก (Heart Girth)
        labelX = x1 - 15; // ขยับไปทางซ้ายเล็กน้อย
        labelY = y1 - 5; // แสดงด้านบนของเส้น
      } else { // ความยาวลำตัว (Body Length)
        labelX = x1;
        labelY = y1 - 30; // แสดงเหนือเส้น
      }
      
      // แสดงป้ายกำกับประเภทการวัด
      _drawLabel(canvas, label, labelX, labelY, _getColorByObjectType(obj.classId));
    }
    
    // วาดเส้นที่กำลังสร้าง/แก้ไข
    if (isEditing && startPoint != null && endPoint != null) {
      // ปรับพิกัดของจุดเริ่มต้นและจุดสิ้นสุดตามการซูม
      final adjustedStartPoint = Offset(
        offsetX + startPoint!.dx * baseScale / zoomScale,
        offsetY + startPoint!.dy * baseScale / zoomScale
      );
      
      final adjustedEndPoint = Offset(
        offsetX + endPoint!.dx * baseScale / zoomScale,
        offsetY + endPoint!.dy * baseScale / zoomScale
      );
      
      // วาดเส้นตรง
      canvas.drawLine(adjustedStartPoint, adjustedEndPoint, editingPaint);
      
      // วาดจุดที่ปลายทั้งสองด้าน
      _drawAnchorPoint(canvas, adjustedStartPoint, editingPaint, true);
      _drawAnchorPoint(canvas, adjustedEndPoint, editingPaint, true);
      
      // คำนวณความยาวของเส้น
      final double lineLength = math.sqrt(
        math.pow(adjustedEndPoint.dx - adjustedStartPoint.dx, 2) + 
        math.pow(adjustedEndPoint.dy - adjustedStartPoint.dy, 2)
      );
      final double lengthInPixels = lineLength / baseScale; // แปลงกลับเป็นพิกเซลของภาพจริง
      
      // แสดงความยาวที่วัดได้
      final measureText = '${lengthInPixels.toStringAsFixed(0)} px';
      
      // ตำแหน่งแสดงค่า - ตรงกลางของเส้น
      final midX = (adjustedStartPoint.dx + adjustedEndPoint.dx) / 2;
      final midY = (adjustedStartPoint.dy + adjustedEndPoint.dy) / 2;
      
      _drawLabel(canvas, measureText, midX - 25, midY, _getColorByObjectType(currentEditingObject));
      
      // แสดงป้ายกำกับว่ากำลังวาดอะไร
      final String label = _getLabelByClassId(currentEditingObject);
      
      // แสดงป้ายกำกับที่จุดเริ่มต้น
      _drawLabel(canvas, label, adjustedStartPoint.dx, adjustedStartPoint.dy - 30, _getColorByObjectType(currentEditingObject));
    }
  }

  // เพิ่มฟังก์ชันสำหรับวาดกรอบสี่เหลี่ยมด้วยเส้นประ
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

  // ฟังก์ชันสำหรับวาดป้ายกำกับบนเส้น
  void _drawLabel(Canvas canvas, String text, double x, double y, Color color) {
    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 14,
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
      ],
    );
    
    final textSpan = TextSpan(text: text, style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    
    // วาดพื้นหลังสำหรับข้อความ
    final bgRect = Rect.fromLTWH(
      x,
      y - textPainter.height,
      textPainter.width + 8,
      textPainter.height + 4,
    );
    
    // สร้าง RRect เพื่อเพิ่มมุมโค้ง
    final rrect = RRect.fromRectAndRadius(bgRect, Radius.circular(4));
    
    canvas.drawRRect(
      rrect,
      Paint()..color = color.withOpacity(0.7)
    );
    
    // วาดข้อความ
    textPainter.paint(canvas, Offset(x + 4, y - textPainter.height + 2));
  }

  
  // ฟังก์ชันสำหรับวาดจุดยึด (หมุด)
  void _drawAnchorPoint(Canvas canvas, Offset position, Paint paint, bool isSelected) {
    // ขนาดของหมุด
    final double pinWidth = anchorPointRadius * 1.8;  // ขนาดความกว้าง
    final double pinHeight = anchorPointRadius * 2.5; // ขนาดความสูง
    
    // คำนวณขนาดเมื่อมีแอนิเมชัน
    final double animationScale = isSelected ? pinScale : 1.0;
    final double animatedPinWidth = pinWidth * animationScale;
    final double animatedPinHeight = pinHeight * animationScale;
    
    final Color pinColor = paint.color;
    final Color shadowColor = Colors.black.withOpacity(0.3);
    
    // คำนวณจุดศูนย์กลางของหมุด
    final Offset pinCenter = Offset(position.dx, position.dy - animatedPinHeight / 2);
    
    // สร้าง path สำหรับหมุด
    final path = Path();
    
    // เริ่มจากจุดบนสุดของหมุด
    path.moveTo(pinCenter.dx, pinCenter.dy - animatedPinHeight / 2);
    
    // ส่วนโค้งด้านซ้าย
    path.quadraticBezierTo(
      pinCenter.dx - animatedPinWidth / 2, pinCenter.dy - animatedPinHeight / 2 + animatedPinHeight / 4,
      pinCenter.dx - animatedPinWidth / 2, pinCenter.dy
    );
    
    // ส่วนล่างของหมุด (รูปหยดน้ำ)
    path.quadraticBezierTo(
      pinCenter.dx, pinCenter.dy + animatedPinHeight / 2,
      position.dx, position.dy
    );
    
    // ส่วนโค้งด้านขวา
    path.quadraticBezierTo(
      pinCenter.dx + animatedPinWidth / 2, pinCenter.dy,
      pinCenter.dx + animatedPinWidth / 2, pinCenter.dy - animatedPinHeight / 2 + animatedPinHeight / 4,
    );
    
    // ปิด path กลับไปจุดเริ่มต้น
    path.close();
    
    // วาดเงาด้านล่าง
    canvas.drawShadow(path, shadowColor, 3, true);
    
    // วาดตัวหมุด
    canvas.drawPath(
      path, 
      Paint()
        ..color = pinColor
        ..style = PaintingStyle.fill
    );
    
    // วาดขอบหมุด
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
    );
    
    // วาดวงกลมส่วนกลางของหมุด (เหมือนใน Google Maps)
    canvas.drawCircle(
      Offset(pinCenter.dx, pinCenter.dy),
      animatedPinWidth / 3,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill
    );
    
    // ถ้าเป็นจุดที่เลือกอยู่ ให้เพิ่มเอฟเฟกต์
    if (isSelected) {
      // วาดขอบสว่างรอบหมุด
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.white.withOpacity(0.5)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
      );
      
      // วาดจุดกลางที่เล็กลงเมื่อเลือก
      canvas.drawCircle(
        Offset(pinCenter.dx, pinCenter.dy),
        animatedPinWidth / 4,
        Paint()
          ..color = pinColor
          ..style = PaintingStyle.fill
      );
    } else {
      // วาดจุดกลางปกติ
      canvas.drawCircle(
        Offset(pinCenter.dx, pinCenter.dy),
        animatedPinWidth / 4,
        Paint()
          ..color = pinColor.withOpacity(0.8)
          ..style = PaintingStyle.fill
      );
    }
  }
  
  // ฟังก์ชันสำหรับดึงป้ายกำกับตามประเภทของวัตถุ
  String _getLabelByClassId(int classId) {
    switch (classId) {
      case 2:
        return 'จุดอ้างอิง'; // Yellow Mark
      case 1:
        return 'รอบอก'; // Heart Girth
      case 0:
        return 'ความยาวลำตัว'; // Body Length
      default:
        return 'ไม่ทราบประเภท';
    }
  }
  
  // ฟังก์ชันสำหรับดึงสีตามประเภทของวัตถุ
  Color _getColorByObjectType(int objectType) {
    switch (objectType) {
      case 2:
        return Colors.amber; // Yellow Mark
      case 1:
        return Colors.red; // Heart Girth
      case 0:
        return Colors.blue; // Body Length
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
           oldDelegate.currentEditingObject != currentEditingObject ||
           oldDelegate.zoomScale != zoomScale || 
           oldDelegate.anchorPointRadius != anchorPointRadius ||
           oldDelegate.pinScale != pinScale ||
           oldDelegate.showOriginalBoxes != showOriginalBoxes;
  }
}