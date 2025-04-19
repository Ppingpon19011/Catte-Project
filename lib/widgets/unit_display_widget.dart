import 'package:flutter/material.dart';
import '../utils/settings_utils.dart';

// Widget สำหรับแสดงข้อมูลน้ำหนักโดยดึงจากการตั้งค่าหน่วยวัด
class WeightDisplay extends StatelessWidget {
  final double weight;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final int decimalPlaces;
  final bool showUnit;

  const WeightDisplay({
    Key? key, 
    required this.weight,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.decimalPlaces = 1,
    this.showUnit = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _formatWeightWithUnit(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            '${weight.toStringAsFixed(decimalPlaces)} กก.',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Text(
            '${weight.toStringAsFixed(decimalPlaces)} กก.',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          );
        }
        
        return Text(
          snapshot.data ?? '${weight.toStringAsFixed(decimalPlaces)} กก.',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        );
      },
    );
  }

  Future<String> _formatWeightWithUnit() async {
    final settingsUtils = SettingsUtils();
    final unit = await settingsUtils.getWeightUnit();
    
    // แปลงหน่วยถ้าจำเป็น
    double convertedWeight = weight;
    if (unit == 'ปอนด์') {
      convertedWeight = weight * 2.20462;
    }
    
    String valueText = convertedWeight.toStringAsFixed(decimalPlaces);
    
    if (showUnit) {
      if (unit == 'กิโลกรัม') {
        return '$valueText กก.';
      } else {
        return '$valueText ปอนด์';
      }
    } else {
      return valueText;
    }
  }
}

// Widget สำหรับแสดงข้อมูลความยาวโดยดึงจากการตั้งค่าหน่วยวัด
class LengthDisplay extends StatelessWidget {
  final double length;
  final double fontSize;
  final FontWeight fontWeight;
  final Color? color;
  final int decimalPlaces;
  final bool showUnit;

  const LengthDisplay({
    Key? key, 
    required this.length,
    this.fontSize = 16.0,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.decimalPlaces = 1,
    this.showUnit = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _formatLengthWithUnit(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(
            '${length.toStringAsFixed(decimalPlaces)} ซม.',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Text(
            '${length.toStringAsFixed(decimalPlaces)} ซม.',
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: color,
            ),
          );
        }
        
        return Text(
          snapshot.data ?? '${length.toStringAsFixed(decimalPlaces)} ซม.',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
          ),
        );
      },
    );
  }

  Future<String> _formatLengthWithUnit() async {
    final settingsUtils = SettingsUtils();
    final unit = await settingsUtils.getLengthUnit();
    
    // แปลงหน่วยถ้าจำเป็น
    double convertedLength = length;
    if (unit == 'นิ้ว') {
      convertedLength = length / 2.54;
    }
    
    String valueText = convertedLength.toStringAsFixed(decimalPlaces);
    
    if (showUnit) {
      if (unit == 'เซนติเมตร') {
        return '$valueText ซม.';
      } else {
        return '$valueText นิ้ว';
      }
    } else {
      return valueText;
    }
  }
}