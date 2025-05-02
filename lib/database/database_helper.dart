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

  DatabaseHelper._internal();

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
    return id;
  }

  // อัปเดตข้อมูลโค
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
    
    return await db.update(
      tableNameCattle,
      row,
      where: '$columnId = ?',
      whereArgs: [cattle.id],
    );
  }

  // ลบโค
  Future<int> deleteCattle(String id) async {
    Database db = await database;
    
    // ลบบันทึกน้ำหนักที่เกี่ยวข้องทั้งหมดก่อน (กรณีที่ FOREIGN KEY ไม่ทำงานใน SQLite)
    await db.delete(
      tableNameWeightRecord,
      where: '$columnCattleId = ?',
      whereArgs: [id],
    );
    
    // ลบข้อมูลโค
    return await db.delete(
      tableNameCattle,
      where: '$columnId = ?',
      whereArgs: [id],
    );
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

  // ลบบันทึกน้ำหนัก
  Future<int> deleteWeightRecord(String recordId) async {
    Database db = await database;
    return await db.delete(
      tableNameWeightRecord,
      where: '$columnRecordId = ?',
      whereArgs: [recordId],
    );
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

  // เพิ่มบันทึกน้ำหนัก
  Future<String> insertWeightRecord(WeightRecord record) async {
    Database db = await database;
    String recordId = const Uuid().v4();
    
    Map<String, dynamic> row = {
      columnRecordId: recordId,
      columnCattleId: record.cattleId,
      columnWeight: record.weight,
      columnImagePath: record.imagePath,
      columnDate: record.date.toIso8601String(),
      columnNotes: record.notes,
    };
    
    await db.insert(tableNameWeightRecord, row);
    
    // อัปเดตน้ำหนักล่าสุดของโค
    Cattle? cattle = await getCattleById(record.cattleId);
    if (cattle != null) {
      cattle = Cattle(
        id: cattle.id,
        name: cattle.name,
        breed: cattle.breed,
        imageUrl: cattle.imageUrl,
        estimatedWeight: record.weight, // อัปเดตน้ำหนักใหม่
        lastUpdated: record.date, // อัปเดตวันที่
        cattleNumber: cattle.cattleNumber,
        gender: cattle.gender,
        birthDate: cattle.birthDate,
        fatherNumber: cattle.fatherNumber,
        motherNumber: cattle.motherNumber,
        breeder: cattle.breeder,
        currentOwner: cattle.currentOwner,
        color: cattle.color, // รักษาข้อมูลสีของโค
      );
      await updateCattle(cattle);
    }
    
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
  }

  // ตรวจสอบโครงสร้างฐานข้อมูล (ใช้สำหรับการดีบัก)
  Future<List<Map<String, dynamic>>> getTableInfo(String tableName) async {
    Database db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }
}