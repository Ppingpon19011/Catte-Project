import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:math';
import '../models/cattle.dart';
import '../models/weight_record.dart';
import '../database/database_helper.dart';
import '../widgets/unit_display_widget.dart'; // เพิ่ม import นี้
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart';
import 'package:intl/intl.dart';

class WeightEstimateScreen extends StatefulWidget {
  final Cattle cattle;

  const WeightEstimateScreen({Key? key, required this.cattle}) : super(key: key);

  @override
  _WeightEstimateScreenState createState() => _WeightEstimateScreenState();
}

class _WeightEstimateScreenState extends State<WeightEstimateScreen> {
  File? _imageFile;
  bool _isProcessing = false;
  double? _estimatedWeight;
  final TextEditingController _notesController = TextEditingController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<WeightRecord> _weightRecords = [];
  bool _isLoadingHistory = true;

  @override
  void initState() {
    super.initState();
    _loadWeightHistory();
  }

  Future<void> _loadWeightHistory() async {
    setState(() {
      _isLoadingHistory = true;
    });

    try {
      final records = await _dbHelper.getWeightRecordsByCattleId(widget.cattle.id);
      setState(() {
        _weightRecords = records;
        _isLoadingHistory = false;
      });
    } catch (e) {
      print('Error loading weight history: $e');
      setState(() {
        _isLoadingHistory = false;
      });
      
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการโหลดประวัติน้ำหนัก'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _takePicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _isProcessing = true;
        _estimatedWeight = null;
      });
      
      // ในระบบจริง จะต้องส่งรูปภาพไปยัง ML model เพื่อประมาณน้ำหนัก
      // แต่ในตัวอย่างนี้จะจำลองการวิเคราะห์รูปภาพด้วยการสุ่มน้ำหนักจากน้ำหนักล่าสุด
      await _analyzeImage();
    }
  }

  Future<void> _selectPicture() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 85,
    );
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
        _isProcessing = true;
        _estimatedWeight = null;
      });
      
      // จำลองการวิเคราะห์รูปภาพ
      await _analyzeImage();
    }
  }

  Future<void> _analyzeImage() async {
    try {
      // จำลองการประมวลผลด้วยการหน่วงเวลา
      await Future.delayed(Duration(seconds: 2));
      
      // จำลองน้ำหนักโดยสุ่มจาก +/-10% ของน้ำหนักปัจจุบัน
      final Random random = Random();
      final double variation = (random.nextDouble() * 0.2) - 0.1; // -10% to +10%
      final double randomWeight = widget.cattle.estimatedWeight * (1 + variation);
      
      setState(() {
        _isProcessing = false;
        _estimatedWeight = randomWeight;
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาดในการวิเคราะห์ภาพ'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveWeightRecord() async {
    if (_estimatedWeight == null || _imageFile == null) {
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('กรุณาถ่ายภาพหรือเลือกภาพก่อนบันทึก'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      // บันทึกรูปภาพลงในพื้นที่แอป
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await _imageFile!.copy('${appDir.path}/$fileName');

      // สร้างและบันทึกข้อมูลน้ำหนัก
      final WeightRecord record = WeightRecord(
        recordId: '', // จะถูกสร้างโดย DatabaseHelper
        cattleId: widget.cattle.id,
        weight: _estimatedWeight!,
        imagePath: savedImage.path,
        date: DateTime.now(),
        notes: _notesController.text.isNotEmpty ? _notesController.text : null,
      );

      await _dbHelper.insertWeightRecord(record);

      // โหลดข้อมูลประวัติใหม่
      await _loadWeightHistory();

      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('บันทึกน้ำหนักเรียบร้อยแล้ว'),
          backgroundColor: Colors.green,
        ),
      );

      // รีเซ็ตสถานะ
      setState(() {
        _imageFile = null;
        _estimatedWeight = null;
        _notesController.clear();
        _isProcessing = false;
      });
      
      // ส่งค่ากลับว่าบันทึกสำเร็จเพื่อให้หน้า detail รีเฟรชข้อมูล
      Navigator.pop(context as BuildContext, true);
    } catch (e) {
      setState(() {
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context as BuildContext).showSnackBar(
        SnackBar(
          content: Text('เกิดข้อผิดพลาด: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text('ประมาณน้ำหนักด้วยภาพถ่าย'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'ประมาณน้ำหนัก'),
              Tab(text: 'ประวัติการชั่งน้ำหนัก'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            // แท็บประมาณน้ำหนัก
            SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'โค: ${widget.cattle.name}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'ถ่ายภาพหรือเลือกภาพโคจากด้านข้างเพื่อประมาณน้ำหนัก',
                      style: TextStyle(fontSize: 16),
                    ),
                    SizedBox(height: 20),
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: _imageFile != null
                          ? Image.file(
                              _imageFile!,
                              fit: BoxFit.contain,
                            )
                          : Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.camera_alt,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'ไม่มีภาพ',
                                    style: TextStyle(fontSize: 16, color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                    ),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _takePicture,
                            icon: Icon(Icons.camera_alt),
                            label: Text('ถ่ายภาพ'),
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _isProcessing ? null : _selectPicture,
                            icon: Icon(Icons.photo_library),
                            label: Text('เลือกจากแกลเลอรี'),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    if (_isProcessing)
                      Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('กำลังประมวลผลภาพ...'),
                          ],
                        ),
                      )
                    else if (_estimatedWeight != null)
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'น้ำหนักโดยประมาณ',
                              style: TextStyle(fontSize: 18),
                            ),
                            SizedBox(height: 8),
                            // ใช้ WeightDisplay แทน Text
                            WeightDisplay(
                              weight: _estimatedWeight!,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.green[700],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ความแม่นยำอาจแตกต่างกันไปขึ้นอยู่กับคุณภาพของภาพและตำแหน่งของโค',
                              textAlign: TextAlign.center,
                              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                            ),
                            SizedBox(height: 24),
                            TextField(
                              controller: _notesController,
                              decoration: InputDecoration(
                                labelText: 'บันทึกเพิ่มเติม (ถ้ามี)',
                                border: OutlineInputBorder(),
                                hintText: 'เช่น สภาพของโค, การให้อาหาร, ฯลฯ',
                              ),
                              maxLines: 3,
                            ),
                            SizedBox(height: 16),
                            Container(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _saveWeightRecord,
                                icon: Icon(Icons.save),
                                label: Text('บันทึกข้อมูลน้ำหนัก'),
                                style: ElevatedButton.styleFrom(
                                  padding: EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // แท็บประวัติการชั่งน้ำหนัก
            _isLoadingHistory
                ? Center(child: CircularProgressIndicator())
                : _weightRecords.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'ไม่มีประวัติการชั่งน้ำหนัก',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadWeightHistory,
                        child: ListView.builder(
                          itemCount: _weightRecords.length,
                          itemBuilder: (context, index) {
                            final record = _weightRecords[index];
                            return Card(
                              margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: ListTile(
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.file(
                                    File(record.imagePath),
                                    width: 60,
                                    height: 60,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: WeightDisplay(
                                  weight: record.weight,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(record.date)}',
                                    ),
                                    if (record.notes != null && record.notes!.isNotEmpty)
                                      Text(
                                        'บันทึก: ${record.notes}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                                onTap: () {
                                  // แสดงรายละเอียดบันทึกน้ำหนัก
                                  _showWeightRecordDetail(record);
                                },
                              ),
                            );
                          },
                        ),
                      ),
          ],
        ),
      ),
    );
  }

  void _showWeightRecordDetail(WeightRecord record) {
    showDialog(
      context: context as BuildContext,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              child: Image.file(
                File(record.imagePath),
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: WeightDisplay(
                      weight: record.weight,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  SizedBox(height: 16),
                  Text(
                    'วันที่: ${DateFormat('dd/MM/yyyy HH:mm').format(record.date)}',
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  if (record.notes != null && record.notes!.isNotEmpty) ...[
                    Text(
                      'บันทึกเพิ่มเติม:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      record.notes!,
                      style: TextStyle(fontSize: 16),
                    ),
                  ],
                  SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        child: Text('ปิด'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }
}