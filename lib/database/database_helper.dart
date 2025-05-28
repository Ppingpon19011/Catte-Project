import 'dart:ui' show VoidCallback;

import 'package:intl/intl.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:async';
import '../models/cattle.dart';
import '../models/weight_record.dart';
import 'package:uuid/uuid.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;

  // ชื่อตาราง
  final String tableNameCattle = 'cattle';
  final String tableNameWeightRecord = 'weight_records';

  // คอลัมน์ตาราง cattle
  final String columnId = 'id';
  final String columnName = 'name';
  final String columnBreed = 'breed';
  final String columnImageUrl = 'image_url';
  final String columnEstimatedWeight = 'estimated_weight';
  final String columnLastUpdated = 'last_updated';
  final String columnCattleNumber = 'cattle_number';
  final String columnGender = 'gender';
  final String columnBirthDate = 'birth_date';
  final String columnFatherNumber = 'father_number';
  final String columnMotherNumber = 'mother_number';
  final String columnBreeder = 'breeder';
  final String columnCurrentOwner = 'current_owner';
  final String columnColor = 'color'; // คอลัมน์สีของโค

  // คอลัมน์ตาราง weight_records
  final String columnRecordId = 'record_id';
  final String columnCattleId = 'cattle_id';
  final String columnWeight = 'weight';
  final String columnImagePath = 'image_path';
  final String columnDate = 'date';
  final String columnNotes = 'notes';

  // *** แก้ไข: เปลี่ยนจาก List<Function()> เป็น List<VoidCallback> ***
  static final List<VoidCallback> _changeListeners = [];

  DatabaseHelper._internal();

  Future<T> executeTransaction<T>(Future<T> Function(Transaction txn) action) async {
    final db = await database;
    return await db.transaction((txn) async {
      return await action(txn);
    });
  }

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, 'cattle_weight.db');
    
    return await openDatabase(
      path,
      version: 2, // เพิ่มเวอร์ชันเป็น 2 เพื่อรองรับการอัปเกรดฐานข้อมูล
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<bool> checkCattleNameExists(String name, [String? excludeId]) async {
    final db = await database;
    
    String query = 'SELECT COUNT(*) FROM cattle WHERE name = ?';
    List<dynamic> args = [name];
    
    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }
    
    final result = await db.rawQuery(query, args);
    final count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

  Future<bool> checkCattleNumberExists(String number, [String? excludeId]) async {
    final db = await database;
    
    String query = 'SELECT COUNT(*) FROM cattle WHERE $columnCattleNumber = ?';
    List<dynamic> args = [number];
    
    if (excludeId != null) {
      query += ' AND id != ?';
      args.add(excludeId);
    }
    
    final result = await db.rawQuery(query, args);
    final count = Sqflite.firstIntValue(result);
    return count != null && count > 0;
  }

  // *** แก้ไข: เปลี่ยนจาก Function() เป็น VoidCallback ***
  void addChangeListener(VoidCallback listener) {
    if (!_changeListeners.contains(listener)) {
      _changeListeners.add(listener);
      print('เพิ่ม change listener แล้ว (รวม: ${_changeListeners.length})');
    }
  }

  Future<void> checkDatabaseStructure() async {
    try {
      final db = await database;
      
      // ตรวจสอบโครงสร้างตาราง cattle
      final cattleTableInfo = await db.rawQuery("PRAGMA table_info($tableNameCattle)");
      print('โครงสร้างตาราง cattle:');
      for (var column in cattleTableInfo) {
        print('- ${column['name']}: ${column['type']}');
      }
      
      // ตรวจสอบโครงสร้างตาราง weight_records
      final weightTableInfo = await db.rawQuery("PRAGMA table_info($tableNameWeightRecord)");
      print('โครงสร้างตาราง weight_records:');
      for (var column in weightTableInfo) {
        print('- ${column['name']}: ${column['type']}');
      }
      
    } catch (e) {
      print('เกิดข้อผิดพลาดในการตรวจสอบโครงสร้างฐานข้อมูล: $e');
    }
  }

  /// อัปเดตน้ำหนักของโค
  Future<void> updateCattleWeight(String cattleId, double newWeight, DateTime lastUpdated) async {
    try {
      final db = await database;
      
      await db.update(
        'cattle',
        {
          'estimated_weight': newWeight,  // เปลี่ยนจาก 'estimatedWeight' เป็น 'estimated_weight'
          'last_updated': lastUpdated.toIso8601String(),  // เปลี่ยนจาก 'lastUpdated' เป็น 'last_updated'
        },
        where: 'id = ?',
        whereArgs: [cattleId],
      );
      
      print('อัปเดตน้ำหนักโค ID: $cattleId เป็น $newWeight กก. เรียบร้อย');
      
      // แจ้งเตือน listeners ว่ามีการเปลี่ยนแปลงข้อมูล
      _notifyChangeListeners();
      
    } catch (e) {
      print('เกิดข้อผิดพลาดในการอัปเดตน้ำหนักโค: $e');
      throw e;
    }
  }

  /// ฟังก์ชันช่วยในการแจ้งเตือน listeners (ถ้ายังไม่มี)
  void _notifyChangeListeners() {
    for (var listener in _changeListeners) {
      try {
        listener();
      } catch (e) {
        print('เกิดข้อผิดพลาดในการเรียก change listener: $e');
      }
    }
  }

  // *** แก้ไข: เปลี่ยนจาก Function() เป็น VoidCallback ***
  void removeChangeListener(VoidCallback listener) {
    if (_changeListeners.remove(listener)) {
      print('ลบ change listener แล้ว (เหลือ: ${_changeListeners.length})');
    }
  }
  
  // *** ปรับปรุง: เพิ่มการจัดการ error และ log ***
  void _notifyListeners() {
    print('กำลังแจ้งเตือน ${_changeListeners.length} listeners เกี่ยวกับการเปลี่ยนแปลงข้อมูล');
    for (var listener in _changeListeners) {
      try {
        listener();
      } catch (e) {
        print('เกิดข้อผิดพลาดในการแจ้งเตือน listener: $e');
      }
    }
  }

  Future<String> getSafeImagePath(String originalPath) async {
    // ถ้าเป็น asset ให้ใช้ path เดิม
    if (originalPath.startsWith('assets/')) {
      return originalPath;
    }
    
    // ตรวจสอบว่าไฟล์มีอยู่จริงหรือไม่
    File imageFile = File(originalPath);
    bool exists = await imageFile.exists();
    
    if (!exists) {
      // ถ้าไม่มีไฟล์ ให้ใช้ภาพเริ่มต้น
      return 'assets/images/cattle_default.jpg';
    }
    
    return originalPath;
  }

  // ฟังก์ชันสร้างฐานข้อมูลเมื่อติดตั้งแอปครั้งแรก
  Future<void> _onCreate(Database db, int version) async {
    // สร้างตาราง cattle
    await db.execute('''
      CREATE TABLE $tableNameCattle (
        $columnId TEXT PRIMARY KEY,
        $columnName TEXT NOT NULL,
        $columnBreed TEXT NOT NULL,
        $columnImageUrl TEXT NOT NULL,
        $columnEstimatedWeight REAL NOT NULL,
        $columnLastUpdated TEXT NOT NULL,
        $columnCattleNumber TEXT NOT NULL,
        $columnGender TEXT NOT NULL,
        $columnBirthDate TEXT NOT NULL,
        $columnFatherNumber TEXT,
        $columnMotherNumber TEXT,
        $columnBreeder TEXT NOT NULL,
        $columnCurrentOwner TEXT NOT NULL,
        $columnColor TEXT
      )
    ''');

    // สร้างตาราง weight_records
    await db.execute('''
      CREATE TABLE $tableNameWeightRecord (
        $columnRecordId TEXT PRIMARY KEY,
        $columnCattleId TEXT NOT NULL,
        $columnWeight REAL NOT NULL,
        $columnImagePath TEXT NOT NULL,
        $columnDate TEXT NOT NULL,
        $columnNotes TEXT,
        FOREIGN KEY ($columnCattleId) REFERENCES $tableNameCattle ($columnId) ON DELETE CASCADE
      )
    ''');
  }

  // ฟังก์ชันจัดการการอัปเกรดฐานข้อมูลเมื่อมีการเปลี่ยนแปลงโครงสร้าง
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    print('Upgrading database from version $oldVersion to $newVersion');

    if (oldVersion < 2) {
      // ตรวจสอบว่าคอลัมน์ color มีอยู่แล้วหรือไม่
      var tableInfo = await db.rawQuery("PRAGMA table_info($tableNameCattle)");
      bool hasColorColumn = tableInfo.any((column) => column['name'] == columnColor);

      if (!hasColorColumn) {
        // เพิ่มคอลัมน์ color ในตาราง cattle
        print('Adding color column to cattle table');
        await db.execute(
          'ALTER TABLE $tableNameCattle ADD COLUMN $columnColor TEXT'
        );
      }
    }
    
    // สามารถเพิ่มเงื่อนไขเพิ่มเติมสำหรับการอัปเกรดในอนาคตได้ที่นี่
    // ตัวอย่าง: if (oldVersion < 3) { ... }
  }

  // เพิ่มโค
  Future<String> insertCattle(Cattle cattle) async {
    Database db = await database;
    String id = const Uuid().v4();
    
    Map<String, dynamic> row = {
      columnId: id,
      columnName: cattle.name,
      columnBreed: cattle.breed,
      columnImageUrl: cattle.imageUrl,
      columnEstimatedWeight: cattle.estimatedWeight,
      columnLastUpdated: cattle.lastUpdated.toIso8601String(),
      columnCattleNumber: cattle.cattleNumber,
      columnGender: cattle.gender,
      columnBirthDate: cattle.birthDate.toIso8601String(),
      columnFatherNumber: cattle.fatherNumber,
      columnMotherNumber: cattle.motherNumber,
      columnBreeder: cattle.breeder,
      columnCurrentOwner: cattle.currentOwner,
      columnColor: cattle.color, // เพิ่มข้อมูลสีของโค
    };
    
    await db.insert(tableNameCattle, row);
    print('เพิ่มข้อมูลโคสำเร็จ: ${cattle.name} (ID: $id)');
    _notifyListeners();
    return id;
  }

  // *** ปรับปรุง: อัปเดตข้อมูลโค ***
  Future<int> updateCattle(Cattle cattle) async {
    Database db = await database;
    
    Map<String, dynamic> row = {
      columnName: cattle.name,
      columnBreed: cattle.breed,
      columnImageUrl: cattle.imageUrl,
      columnEstimatedWeight: cattle.estimatedWeight,
      columnLastUpdated: cattle.lastUpdated.toIso8601String(),
      columnCattleNumber: cattle.cattleNumber,
      columnGender: cattle.gender,
      columnBirthDate: cattle.birthDate.toIso8601String(),
      columnFatherNumber: cattle.fatherNumber,
      columnMotherNumber: cattle.motherNumber,
      columnBreeder: cattle.breeder,
      columnCurrentOwner: cattle.currentOwner,
      columnColor: cattle.color, // เพิ่มข้อมูลสีของโค
    };
    
    final result = await db.update(
      tableNameCattle,
      row,
      where: '$columnId = ?',
      whereArgs: [cattle.id],
    );

    print('อัปเดตข้อมูลโคสำเร็จ: ${cattle.name} - น้ำหนัก: ${cattle.estimatedWeight} กก.');
    _notifyListeners();
    return result;
  }

  // *** ปรับปรุง: ลบโค ***
  Future<int> deleteCattle(String id) async {
    Database db = await database;
    
    // ลบบันทึกน้ำหนักที่เกี่ยวข้องทั้งหมดก่อน (กรณีที่ FOREIGN KEY ไม่ทำงานใน SQLite)
    await db.delete(
      tableNameWeightRecord,
      where: '$columnCattleId = ?',
      whereArgs: [id],
    );
    
    // ลบข้อมูลโค
    final result = await db.delete(
      tableNameCattle,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    
    print('ลบข้อมูลโคสำเร็จ ID: $id');
    _notifyListeners();
    return result;
  }

  // ดึงข้อมูลโคทั้งหมด
  Future<List<Cattle>> getAllCattle() async {
    Database db = await database;
    
    List<Map<String, dynamic>> result = await db.query(tableNameCattle);
    
    return result.map((map) => _cattleFromMap(map)).toList();
  }

  // ดึงข้อมูลโคตามไอดี
  Future<Cattle?> getCattleById(String id) async {
    Database db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      tableNameCattle,
      where: '$columnId = ?',
      whereArgs: [id],
    );
    
    if (result.isNotEmpty) {
      return _cattleFromMap(result.first);
    }
    
    return null;
  }

  // *** ปรับปรุง: ลบบันทึกน้ำหนัก ***
  Future<int> deleteWeightRecord(String recordId) async {
    Database db = await database;
    final result = await db.delete(
      tableNameWeightRecord,
      where: '$columnRecordId = ?',
      whereArgs: [recordId],
    );
    
    print('ลบข้อมูลน้ำหนักสำเร็จ ID: $recordId');
    _notifyListeners();
    return result;
  }

  // แปลงข้อมูลจาก Map เป็น Cattle object
  Cattle _cattleFromMap(Map<String, dynamic> map) {
    return Cattle(
      id: map[columnId],
      name: map[columnName],
      breed: map[columnBreed],
      imageUrl: map[columnImageUrl],
      estimatedWeight: map[columnEstimatedWeight],
      lastUpdated: DateTime.parse(map[columnLastUpdated]),
      cattleNumber: map[columnCattleNumber],
      gender: map[columnGender],
      birthDate: DateTime.parse(map[columnBirthDate]),
      fatherNumber: map[columnFatherNumber] ?? '',
      motherNumber: map[columnMotherNumber] ?? '',
      breeder: map[columnBreeder],
      currentOwner: map[columnCurrentOwner],
      color: map[columnColor], // เพิ่มข้อมูลสีของโค
    );
  }

  // เพิ่มเมธอดใหม่
  Future<List<Map<String, dynamic>>> getRecentWeightRecords(
    String cattleId, 
    DateTime fromDate, 
    double weight, 
    {double weightTolerance = 0.5} // เพิ่มค่าเริ่มต้นเป็น 0.5 กก.
  ) async {
    final db = await database;
    
    return await db.query(
      tableNameWeightRecord,
      where: '$columnCattleId = ? AND $columnDate >= ? AND $columnWeight BETWEEN ? AND ?',
      whereArgs: [
        cattleId, 
        fromDate.toIso8601String(),
        weight - weightTolerance,
        weight + weightTolerance
      ],
    );
  }

  // *** ปรับปรุง: เพิ่มบันทึกน้ำหนัก พร้อมอัปเดตน้ำหนักโค ***
  Future<String> insertWeightRecord(WeightRecord record) async {
    final db = await database;
    String recordId = const Uuid().v4();

    // ตรวจสอบว่ามีข้อมูลซ้ำหรือไม่
    final existingRecords = await db.query(
      tableNameWeightRecord,
      where: '$columnCattleId = ? AND $columnWeight = ? AND $columnDate LIKE ?',
      whereArgs: [
        record.cattleId, 
        record.weight, 
        // ตรวจสอบเฉพาะ วัน-เดือน-ปี และชั่วโมง-นาที
        '${DateFormat('yyyy-MM-dd HH:mm').format(record.date)}%'
      ],
    );
    
    // ถ้าพบข้อมูลที่ซ้ำกัน ให้ใช้ข้อมูลเดิม
    if (existingRecords.isNotEmpty) {
      print('พบข้อมูลซ้ำ - ใช้ record ID เดิม: ${existingRecords.first[columnRecordId]}');
      return existingRecords.first[columnRecordId] as String;
    }

    print('กำลังบันทึกข้อมูลน้ำหนัก: ${record.weight} กก. ของโค ID: ${record.cattleId}');
    
    await db.transaction((txn) async {
      try {
        // สร้างข้อมูล WeightRecord
        Map<String, dynamic> row = {
          columnRecordId: recordId,
          columnCattleId: record.cattleId,
          columnWeight: record.weight,
          columnImagePath: record.imagePath,
          columnDate: record.date.toIso8601String(),
          columnNotes: record.notes,
        };
        
        // บันทึก WeightRecord - ใช้ txn ไม่ใช่ db
        await txn.insert(tableNameWeightRecord, row);
        print('บันทึกน้ำหนักสำเร็จ recordId: $recordId');
        
        // *** ส่วนสำคัญ: อัปเดตน้ำหนักของโคด้วย ***
        // ดึงข้อมูลโคปัจจุบัน
        List<Map<String, dynamic>> cattleResult = await txn.query(
          tableNameCattle,
          where: '$columnId = ?',
          whereArgs: [record.cattleId],
        );
        
        if (cattleResult.isNotEmpty) {
          // อัปเดตน้ำหนักล่าสุดของโค
          Map<String, dynamic> cattleRow = {
            columnEstimatedWeight: record.weight, // อัปเดตน้ำหนักใหม่
            columnLastUpdated: record.date.toIso8601String(), // อัปเดตวันที่
          };
          
          // ใช้ txn ไม่ใช่ db
          int updateResult = await txn.update(
            tableNameCattle,
            cattleRow,
            where: '$columnId = ?',
            whereArgs: [record.cattleId],
          );
          
          if (updateResult > 0) {
            print('อัปเดตน้ำหนักโคสำเร็จ - น้ำหนักใหม่: ${record.weight} กก.');
          } else {
            print('ไม่สามารถอัปเดตน้ำหนักโคได้');
          }
        } else {
          print('ไม่พบข้อมูลโค ID: ${record.cattleId}');
        }
      } catch (e) {
        print('เกิดข้อผิดพลาดใน transaction: $e');
        rethrow; // ให้ transaction ทำ rollback โดยอัตโนมัติ
      }
    });
    
    print('แจ้งเตือน listeners เกี่ยวกับการเปลี่ยนแปลงข้อมูล');
    _notifyListeners();
    return recordId;
  }

  // ดึงประวัติน้ำหนักของโค
  Future<List<WeightRecord>> getWeightRecordsByCattleId(String cattleId) async {
    Database db = await database;
    
    List<Map<String, dynamic>> result = await db.query(
      tableNameWeightRecord,
      where: '$columnCattleId = ?',
      whereArgs: [cattleId],
      orderBy: '$columnDate DESC',
    );
    
    return result.map((map) => _weightRecordFromMap(map)).toList();
  }

  // แปลงข้อมูลจาก Map เป็น WeightRecord object
  WeightRecord _weightRecordFromMap(Map<String, dynamic> map) {
    return WeightRecord(
      recordId: map[columnRecordId],
      cattleId: map[columnCattleId],
      weight: map[columnWeight],
      imagePath: map[columnImagePath],
      date: DateTime.parse(map[columnDate]),
      notes: map[columnNotes],
    );
  }

  // ลบข้อมูลทั้งหมดในฐานข้อมูล (ใช้สำหรับการรีเซ็ตหรือการทดสอบ)
  Future<void> deleteAllData() async {
    Database db = await database;
    await db.delete(tableNameWeightRecord);
    await db.delete(tableNameCattle);
    _notifyListeners();
  }

  // ตรวจสอบโครงสร้างฐานข้อมูล (ใช้สำหรับการดีบัก)
  Future<List<Map<String, dynamic>>> getTableInfo(String tableName) async {
    Database db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }
}