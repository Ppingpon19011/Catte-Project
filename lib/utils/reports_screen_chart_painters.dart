// แก้ไขไฟล์ reports_screen_chart_painters.dart
import 'package:flutter/material.dart';
import 'dart:math' as math;

// Custom Painter สำหรับกราฟแท่ง
class BarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color barColor;
  final bool showValues;
  final String Function(double)? valueFormat;
  final bool useCustomColors;
  final bool isSmallScreen;  // เพิ่มตัวแปรเพื่อตรวจสอบหน้าจอขนาดเล็ก
  
  BarChartPainter({
    required this.data,
    required this.maxValue,
    required this.barColor,
    this.showValues = false,
    this.valueFormat,
    this.useCustomColors = false,
    this.isSmallScreen = false,  // ค่าเริ่มต้นคือไม่ใช่หน้าจอขนาดเล็ก
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    // ปรับขนาด padding ตามขนาดหน้าจอ
    final double padding = isSmallScreen ? 30 : 40;
    final double labelFontSize = isSmallScreen ? 10 : 12;
    final double valueFontSize = isSmallScreen ? 10 : 12;
    
    final double barWidth = ((size.width - padding * 2) / data.length) - (isSmallScreen ? 6 : 10);
    final double chartHeight = size.height - padding * 2;
    
    // วาดเส้นแกน
    final Paint axisPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // แกน Y
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    
    // แกน X
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );
    
    // วาดเส้นกริดแนวนอน
    for (int i = 1; i <= 5; i++) {
      final double y = padding + (chartHeight / 5) * (5 - i);
      
      // วาดเส้นกริด
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      
      // แสดงค่าบนแกน Y
      final double value = (maxValue / 5) * i;
      final String valueText = value < 10 
          ? value.toStringAsFixed(1) 
          : value.toStringAsFixed(0);
      
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: valueText,
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: labelFontSize,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(padding - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
    
    // ตัวแปรสำหรับการทำ animation
    final double animationValue = 1.0;
    
    // วาดแท่ง
    for (int i = 0; i < data.length; i++) {
      // ตรวจสอบว่าค่าไม่เป็นลบ (แก้ไขตรงนี้)
      final double value = data[i]['value'] as double;
      final double normalizedValue = math.max(0, value) / maxValue; // ใช้ค่าที่ไม่เป็นลบ
      
      final double barHeight = normalizedValue * chartHeight * animationValue;
      final double left = padding + i * ((size.width - padding * 2) / data.length) + (isSmallScreen ? 3 : 5);
      final double top = size.height - padding - barHeight;
      
      final Rect barRect = Rect.fromLTWH(left, top, barWidth, barHeight);
      
      // ใช้สีจากข้อมูลถ้ามีการกำหนดให้ใช้สีที่กำหนดเอง
      Color currentBarColor = barColor;
      if (useCustomColors && data[i].containsKey('color')) {
        currentBarColor = data[i]['color'] as Color;
      }
      
      // วาดแท่ง
      final Paint barPaint = Paint()
        ..color = currentBarColor
        ..style = PaintingStyle.fill;
      
      canvas.drawRect(barRect, barPaint);
      
      // เพิ่มขอบให้กับแท่ง
      final Paint strokePaint = Paint()
        ..color = currentBarColor.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      
      canvas.drawRect(barRect, strokePaint);
      
      // วาดชื่อ - แสดงแค่บางแท่งในหน้าจอเล็ก
      if (!isSmallScreen || i % 2 == 0 || i == data.length - 1) {
        final String labelText = isSmallScreen && (data[i]['label'] as String).length > 6
            ? (data[i]['label'] as String).substring(0, 6) + '..'
            : data[i]['label'] as String;
        
        final TextPainter labelPainter = TextPainter(
          text: TextSpan(
            text: labelText,
            style: TextStyle(
              color: Colors.black,
              fontSize: labelFontSize,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        labelPainter.layout();
        labelPainter.paint(
          canvas,
          Offset(
            left + (barWidth - labelPainter.width) / 2,
            size.height - padding + 4,
          ),
        );
      }
      
      // แสดงค่า
      if (showValues) {
        // แก้ไขการแสดงค่าเพื่อให้ไม่แสดงค่าติดลบ
        final String valueText = valueFormat != null
            ? valueFormat!(value > 0 ? value : 0)
            : (value > 0 ? value.toStringAsFixed(1) : "0.0");
        
        final TextPainter valuePainter = TextPainter(
          text: TextSpan(
            text: valueText,
            style: TextStyle(
              color: Colors.black,
              fontSize: valueFontSize,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        valuePainter.layout();
        
        // วาดพื้นหลังของค่า เฉพาะในกรณีที่กราฟมีความสูงพอ
        if (barHeight > valuePainter.height + 8) {
          final Paint bgPaint = Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..style = PaintingStyle.fill;
          
          // ปรับตำแหน่งให้อยู่ในแท่ง
          canvas.drawRect(
            Rect.fromLTWH(
              left + (barWidth - valuePainter.width) / 2 - 2,
              top + 4,
              valuePainter.width + 4,
              valuePainter.height + 2,
            ),
            bgPaint,
          );
          
          valuePainter.paint(
            canvas,
            Offset(
              left + (barWidth - valuePainter.width) / 2,
              top + 5,
            ),
          );
        } else {
          // ถ้าความสูงแท่งไม่พอ ให้แสดงค่าด้านบน
          final Paint bgPaint = Paint()
            ..color = Colors.white.withOpacity(0.8)
            ..style = PaintingStyle.fill;
          
          canvas.drawRect(
            Rect.fromLTWH(
              left + (barWidth - valuePainter.width) / 2 - 2,
              top - valuePainter.height - 6,
              valuePainter.width + 4,
              valuePainter.height + 4,
            ),
            bgPaint,
          );
          
          valuePainter.paint(
            canvas,
            Offset(
              left + (barWidth - valuePainter.width) / 2,
              top - valuePainter.height - 4,
            ),
          );
        }
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom Painter สำหรับกราฟเส้น (สำหรับแสดงประวัติการเติบโต)
class LineChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color lineColor;
  final bool showDots;
  
  LineChartPainter({
    required this.data,
    required this.maxValue,
    required this.lineColor,
    this.showDots = true,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final double padding = 40;
    final double chartWidth = size.width - padding * 2;
    final double chartHeight = size.height - padding * 2;
    
    // วาดเส้นแกน
    final Paint axisPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // แกน Y
    canvas.drawLine(
      Offset(padding, padding),
      Offset(padding, size.height - padding),
      axisPaint,
    );
    
    // แกน X
    canvas.drawLine(
      Offset(padding, size.height - padding),
      Offset(size.width - padding, size.height - padding),
      axisPaint,
    );
    
    // วาดเส้นกริดแนวนอน
    for (int i = 1; i <= 5; i++) {
      final double y = padding + (chartHeight / 5) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        Paint()
          ..color = Colors.grey[200]!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      
      // แสดงค่าน้ำหนักบนแกน Y
      final double weight = maxValue - (maxValue / 5) * i;
      final TextPainter textPainter = TextPainter(
        text: TextSpan(
          text: weight.toInt().toString(),
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 10,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(padding - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
    
    // วาดเส้นกราฟ
    final Paint linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    final Path path = Path();
    List<Offset> points = [];
    
    for (int i = 0; i < data.length; i++) {
      final double x = padding + (chartWidth / (data.length - 1)) * i;
      final double normalizedValue = (data[i]['weight'] as double) / maxValue;
      final double y = size.height - padding - (normalizedValue * chartHeight);
      
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      
      points.add(Offset(x, y));
      
      // แสดงวันที่บนแกน X
      if (i == 0 || i == data.length - 1 || i % (data.length ~/ 5 + 1) == 0) {
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: data[i]['date'] as String,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 10,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(x - textPainter.width / 2, size.height - padding + 5),
        );
      }
    }
    
    canvas.drawPath(path, linePaint);
    
    // วาดจุดบนกราฟ
    if (showDots) {
      final Paint dotPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      
      final Paint dotStrokePaint = Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      for (var point in points) {
        canvas.drawCircle(point, 5, dotPaint);
        canvas.drawCircle(point, 5, dotStrokePaint);
      }
    }
    
    // วาดพื้นที่ใต้กราฟ
    final Paint fillPaint = Paint()
      ..color = lineColor.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    final Path fillPath = Path();
    fillPath.moveTo(padding, size.height - padding);
    fillPath.lineTo(points.first.dx, points.first.dy);
    
    for (int i = 1; i < points.length; i++) {
      fillPath.lineTo(points[i].dx, points[i].dy);
    }
    
    fillPath.lineTo(points.last.dx, size.height - padding);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom Painter สำหรับกราฟวงกลม
class PieChartPainter extends CustomPainter {
  final List<double> data;
  final List<Color> colors;
  
  PieChartPainter({
    required this.data,
    required this.colors,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final double total = data.reduce((a, b) => a + b);
    final double radius = math.min(size.width, size.height) / 2;
    final Offset center = Offset(size.width / 2, size.height / 2);
    
    double startAngle = -math.pi / 2; // เริ่มที่ 12 นาฬิกา
    
    for (int i = 0; i < data.length; i++) {
      final double sweepAngle = (data[i] / total) * 2 * math.pi;
      
      final Paint paint = Paint()
        ..color = i < colors.length ? colors[i] : Colors.grey
        ..style = PaintingStyle.fill;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      
      // วาดเส้นขอบ
      final Paint strokePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        strokePaint,
      );
      
      // คำนวณตำแหน่งสำหรับแสดงเปอร์เซ็นต์
      if (data[i] / total > 0.05) { // แสดงเฉพาะส่วนที่มีขนาดเพียงพอ
        final double percentage = (data[i] / total) * 100;
        final double labelRadius = radius * 0.7;
        final double labelAngle = startAngle + sweepAngle / 2;
        
        final Offset labelPosition = Offset(
          center.dx + labelRadius * math.cos(labelAngle),
          center.dy + labelRadius * math.sin(labelAngle),
        );
        
        final TextPainter textPainter = TextPainter(
          text: TextSpan(
            text: '${percentage.toStringAsFixed(0)}%',
            style: TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [
                Shadow(
                  offset: Offset(1, 1),
                  blurRadius: 2,
                  color: Colors.black.withOpacity(0.5),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(
            labelPosition.dx - textPainter.width / 2,
            labelPosition.dy - textPainter.height / 2,
          ),
        );
      }
      
      startAngle += sweepAngle;
    }
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}

// Custom Painter สำหรับกราฟเรดาร์
class RadarChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> data;
  final double maxValue;
  final Color lineColor;
  
  RadarChartPainter({
    required this.data,
    required this.maxValue,
    required this.lineColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final int sides = data.length;
    final double radius = math.min(size.width, size.height) / 2 * 0.8;
    final Offset center = Offset(size.width / 2, size.height / 2);
    
    // วาดเส้นพื้นหลัง
    _drawRadarBackground(canvas, center, radius, sides);
    
    // วาดข้อมูล
    _drawRadarData(canvas, center, radius, sides);
  }
  
  void _drawRadarBackground(Canvas canvas, Offset center, double radius, int sides) {
    final Paint axisPaint = Paint()
      ..color = Colors.grey[300]!
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    
    // วาดวงกลมพื้นหลัง
    for (int i = 1; i <= 5; i++) {
      final double circleRadius = radius * i / 5;
      
      canvas.drawCircle(
        center,
        circleRadius,
        axisPaint,
      );
    }
    
    // วาดเส้นแกน
    for (int i = 0; i < sides; i++) {
      final double angle = (2 * math.pi * i / sides) - math.pi / 2;
      
      final Offset endpoint = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      
      canvas.drawLine(center, endpoint, axisPaint);
      
      // วาดชื่อ
      if (i < data.length) {
        final String label = data[i]['breed'] as String;
        
        final TextPainter labelPainter = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: Colors.black,
              fontSize: 12,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        
        labelPainter.layout();
        
        // ปรับตำแหน่งให้อยู่ด้านนอกของกราฟ
        final double textRadius = radius * 1.1;
        final Offset textPosition = Offset(
          center.dx + textRadius * math.cos(angle) - labelPainter.width / 2,
          center.dy + textRadius * math.sin(angle) - labelPainter.height / 2,
        );
        
        labelPainter.paint(canvas, textPosition);
      }
    }
  }
  
  void _drawRadarData(Canvas canvas, Offset center, double radius, int sides) {
    if (sides < 3) return; // ต้องมีอย่างน้อย 3 ด้าน
    
    final Paint dataPaint = Paint()
      ..color = lineColor.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    
    final Paint strokePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    final Path path = Path();
    
    // สร้างเส้นทางจากข้อมูล
    for (int i = 0; i < sides; i++) {
      // แก้ไขตรงนี้: ต้องแน่ใจว่า efficiency มีค่าเป็นบวกหรือ 0 เท่านั้น
      double efficiency = data[i]['efficiency'] as double;
      // ป้องกันค่าที่น้อยกว่า 0
      efficiency = math.max(0.0, efficiency);
      
      final double normalizedValue = (efficiency / maxValue).clamp(0.0, 1.0);
      final double angle = (2 * math.pi * i / sides) - math.pi / 2;
      final double distance = radius * normalizedValue;
      
      final Offset point = Offset(
        center.dx + distance * math.cos(angle),
        center.dy + distance * math.sin(angle),
      );
      
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
      
      // วาดจุด
      canvas.drawCircle(
        point,
        4,
        Paint()..color = lineColor,
      );
    }
    
    // ปิดเส้นทาง
    path.close();
    
    // วาดพื้นที่ข้อมูล
    canvas.drawPath(path, dataPaint);
    canvas.drawPath(path, strokePaint);
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}