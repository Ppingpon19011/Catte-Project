import 'package:shared_preferences/shared_preferences.dart';

// คลาส singleton สำหรับการจัดการตั้งค่า
class SettingsUtils {
  static final SettingsUtils _instance = SettingsUtils._internal();
  factory SettingsUtils() => _instance;
  SettingsUtils._internal();

  // คีย์สำหรับเก็บค่าใน SharedPreferences
  static const String LENGTH_UNIT_KEY = 'length_unit';
  static const String WEIGHT_UNIT_KEY = 'weight_unit';

  // ค่าเริ่มต้น
  static const String DEFAULT_LENGTH_UNIT = 'เซนติเมตร';
  static const String DEFAULT_WEIGHT_UNIT = 'กิโลกรัม';

  // ฟังก์ชันโหลดการตั้งค่าหน่วยวัดความยาว
  Future<String> getLengthUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(LENGTH_UNIT_KEY) ?? DEFAULT_LENGTH_UNIT;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดหน่วยวัดความยาว: $e');
      return DEFAULT_LENGTH_UNIT;
    }
  }

  // ฟังก์ชันโหลดการตั้งค่าหน่วยวัดน้ำหนัก
  Future<String> getWeightUnit() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(WEIGHT_UNIT_KEY) ?? DEFAULT_WEIGHT_UNIT;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการโหลดหน่วยวัดน้ำหนัก: $e');
      return DEFAULT_WEIGHT_UNIT;
    }
  }

  // ฟังก์ชันบันทึกการตั้งค่าหน่วยวัดความยาว
  Future<bool> setLengthUnit(String unit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(LENGTH_UNIT_KEY, unit);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกหน่วยวัดความยาว: $e');
      return false;
    }
  }

  // ฟังก์ชันบันทึกการตั้งค่าหน่วยวัดน้ำหนัก
  Future<bool> setWeightUnit(String unit) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(WEIGHT_UNIT_KEY, unit);
    } catch (e) {
      print('เกิดข้อผิดพลาดในการบันทึกหน่วยวัดน้ำหนัก: $e');
      return false;
    }
  }

  // ฟังก์ชันรีเซ็ตการตั้งค่าทั้งหมด
  Future<bool> resetToDefaults() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(LENGTH_UNIT_KEY, DEFAULT_LENGTH_UNIT);
      await prefs.setString(WEIGHT_UNIT_KEY, DEFAULT_WEIGHT_UNIT);
      return true;
    } catch (e) {
      print('เกิดข้อผิดพลาดในการรีเซ็ตการตั้งค่า: $e');
      return false;
    }
  }

  // ฟังก์ชันแปลงหน่วยความยาว
  Future<double> convertLength(double value, {bool toDefault = false, String? fromUnit, String? toUnit}) async {
    String from = fromUnit ?? await getLengthUnit();
    String to = toUnit ?? (toDefault ? DEFAULT_LENGTH_UNIT : await getLengthUnit());

    if (from == to) return value;

    // แปลงจากเซนติเมตรเป็นนิ้ว
    if (from == 'เซนติเมตร' && to == 'นิ้ว') {
      return value / 2.54;
    }
    // แปลงจากนิ้วเป็นเซนติเมตร
    else if (from == 'นิ้ว' && to == 'เซนติเมตร') {
      return value * 2.54;
    }
    
    return value;
  }

  // ฟังก์ชันแปลงหน่วยน้ำหนัก
  Future<double> convertWeight(double value, {bool toDefault = false, String? fromUnit, String? toUnit}) async {
    String from = fromUnit ?? await getWeightUnit();
    String to = toUnit ?? (toDefault ? DEFAULT_WEIGHT_UNIT : await getWeightUnit());

    if (from == to) return value;

    // แปลงจากกิโลกรัมเป็นปอนด์
    if (from == 'กิโลกรัม' && to == 'ปอนด์') {
      return value * 2.20462;
    }
    // แปลงจากปอนด์เป็นกิโลกรัม
    else if (from == 'ปอนด์' && to == 'กิโลกรัม') {
      return value / 2.20462;
    }
    
    return value;
  }

  // ฟังก์ชันฟอร์แมตหน่วยความยาว
  Future<String> formatLength(double value, {int decimalPlaces = 1}) async {
    String unit = await getLengthUnit();
    String formattedValue = value.toStringAsFixed(decimalPlaces);
    
    if (unit == 'เซนติเมตร') {
      return '$formattedValue ซม.';
    } else if (unit == 'นิ้ว') {
      return '$formattedValue นิ้ว';
    }
    
    return '$formattedValue';
  }

  // ฟังก์ชันฟอร์แมตหน่วยน้ำหนัก
  Future<String> formatWeight(double value, {int decimalPlaces = 1}) async {
    String unit = await getWeightUnit();
    String formattedValue = value.toStringAsFixed(decimalPlaces);
    
    if (unit == 'กิโลกรัม') {
      return '$formattedValue กก.';
    } else if (unit == 'ปอนด์') {
      return '$formattedValue ปอนด์';
    }
    
    return '$formattedValue';
  }
}