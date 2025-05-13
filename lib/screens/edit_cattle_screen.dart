import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/cattle.dart';
import '../database/database_helper.dart';

class EditCattleScreen extends StatefulWidget {
  final Cattle cattle;

  const EditCattleScreen({Key? key, required this.cattle}) : super(key: key);

  @override
  _EditCattleScreenState createState() => _EditCattleScreenState();
}

class _EditCattleScreenState extends State<EditCattleScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _cattleNumberController;
  late TextEditingController _birthDateController;
  late TextEditingController _fatherNumberController;
  late TextEditingController _motherNumberController;
  late TextEditingController _breederController;
  late TextEditingController _currentOwnerController;
  late TextEditingController _estimatedWeightController;
  late TextEditingController _colorController; // เพิ่มช่องกรอกสี

  late String _selectedGender;
  List<String> _genderOptions = ['เพศผู้', 'เพศเมีย'];
  
  // เพิ่มตัวแปรสำหรับสายพันธุ์แบบเลือก
  late String _selectedBreed;
  List<String> _breedOptions = ['Beefmaster', 'Brahman', 'Charolais'];
  
  late DateTime _birthDate;
  File? _imageFile;
  late String _currentImagePath;
  bool _isLoading = false;

  final DatabaseHelper _dbHelper = DatabaseHelper();

  @override
  void initState() {
    super.initState();
    
    // ตั้งค่าข้อมูลเริ่มต้นจาก Cattle ที่ได้รับ
    _nameController = TextEditingController(text: widget.cattle.name);
    _cattleNumberController = TextEditingController(text: widget.cattle.cattleNumber);
    _birthDate = widget.cattle.birthDate;
    _birthDateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(_birthDate));
    _fatherNumberController = TextEditingController(text: widget.cattle.fatherNumber);
    _motherNumberController = TextEditingController(text: widget.cattle.motherNumber);
    _breederController = TextEditingController(text: widget.cattle.breeder);
    _currentOwnerController = TextEditingController(text: widget.cattle.currentOwner);
    _estimatedWeightController = TextEditingController(text: widget.cattle.estimatedWeight.toString());
    _colorController = TextEditingController(text: widget.cattle.color ?? ''); // เพิ่มการตั้งค่าสีโค
    
    _selectedGender = widget.cattle.gender;
    _currentImagePath = widget.cattle.imageUrl;
    
    // หากสายพันธุ์ที่มีอยู่ไม่ตรงกับตัวเลือกใดเลย ให้ใช้ตัวเลือกแรก
    _selectedBreed = _breedOptions.contains(widget.cattle.breed) 
        ? widget.cattle.breed 
        : _breedOptions[0];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('แก้ไขข้อมูลโค'),
      ),
      body: _isLoading 
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ส่วนของรูปภาพ
                      Center(
                        child: Stack(
                          children: [
                            Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                                image: DecorationImage(
                                  fit: BoxFit.cover,
                                  image: _imageFile != null
                                      ? FileImage(_imageFile!) as ImageProvider
                                      : (_currentImagePath.startsWith('assets/')
                                          ? AssetImage(_currentImagePath)
                                          : FileImage(File(_currentImagePath))) as ImageProvider,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                height: 40,
                                width: 40,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Theme.of(context).primaryColor,
                                ),
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: Icon(Icons.camera_alt, color: Colors.white),
                                  onPressed: _pickImage,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 32),

                      // ข้อมูลทั่วไป
                      _buildSectionHeader('ข้อมูลทั่วไป'),
                      TextFormField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อโค *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกชื่อโค';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _cattleNumberController,
                        decoration: InputDecoration(
                          labelText: 'หมายเลขโค *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกหมายเลขโค';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // เปลี่ยนจาก TextFormField เป็น DropdownButtonFormField สำหรับสายพันธุ์
                      DropdownButtonFormField<String>(
                        value: _selectedBreed,
                        decoration: InputDecoration(
                          labelText: 'สายพันธุ์ *',
                          border: OutlineInputBorder(),
                        ),
                        items: _breedOptions.map((String breed) {
                          return DropdownMenuItem<String>(
                            value: breed,
                            child: Text(breed),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedBreed = newValue!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาเลือกสายพันธุ์';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      // เพิ่มช่องกรอกสีของโค
                      TextFormField(
                        controller: _colorController,
                        decoration: InputDecoration(
                          labelText: 'สีของโค *',
                          border: OutlineInputBorder(),
                          hintText: 'เช่น น้ำตาล, ดำ-ขาว, แดง',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกสีของโค';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: _selectedGender,
                        decoration: InputDecoration(
                          labelText: 'เพศ *',
                          border: OutlineInputBorder(),
                        ),
                        items: _genderOptions.map((String gender) {
                          return DropdownMenuItem<String>(
                            value: gender,
                            child: Text(gender),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _selectedGender = newValue!;
                          });
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _birthDateController,
                        decoration: InputDecoration(
                          labelText: 'วันเกิด *',
                          border: OutlineInputBorder(),
                          suffixIcon: Icon(Icons.calendar_today),
                        ),
                        readOnly: true,
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _birthDate,
                            firstDate: DateTime(2010),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null && picked != _birthDate) {
                            setState(() {
                              _birthDate = picked;
                              _birthDateController.text = DateFormat('dd/MM/yyyy').format(picked);
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณาเลือกวันเกิด';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _estimatedWeightController,
                        decoration: InputDecoration(
                          labelText: 'น้ำหนักโดยประมาณ (กก.) *',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกน้ำหนักโดยประมาณ';
                          }
                          try {
                            double.parse(value);
                            return null;
                          } catch (e) {
                            return 'กรุณากรอกตัวเลข';
                          }
                        },
                      ),
                      SizedBox(height: 32),

                      // ข้อมูลสายพันธุ์
                      _buildSectionHeader('ข้อมูลสายพันธุ์'),
                      TextFormField(
                        controller: _fatherNumberController,
                        decoration: InputDecoration(
                          labelText: 'หมายเลขพ่อพันธุ์',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _motherNumberController,
                        decoration: InputDecoration(
                          labelText: 'หมายเลขแม่พันธุ์',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 32),

                      // ข้อมูลการเป็นเจ้าของ
                      _buildSectionHeader('ข้อมูลการเป็นเจ้าของ'),
                      TextFormField(
                        controller: _breederController,
                        decoration: InputDecoration(
                          labelText: 'ชื่อผู้เลี้ยง *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกชื่อผู้เลี้ยง';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),
                      TextFormField(
                        controller: _currentOwnerController,
                        decoration: InputDecoration(
                          labelText: 'เจ้าของปัจจุบัน *',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'กรุณากรอกชื่อเจ้าของปัจจุบัน';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 32),

                      // ปุ่มบันทึก
                      Container(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _updateCattle,
                          child: Text(
                            'บันทึกการแก้ไข',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await showDialog<XFile?>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('เลือกแหล่งที่มาของภาพ'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: Text('กล้องถ่ายรูป'),
                  onTap: () async {
                    Navigator.of(context).pop(
                      await picker.pickImage(source: ImageSource.camera),
                    );
                  },
                ),
                Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: Text('แกลเลอรี่'),
                  onTap: () async {
                    Navigator.of(context).pop(
                      await picker.pickImage(source: ImageSource.gallery),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).primaryColor,
            ),
          ),
          Divider(thickness: 1),
        ],
      ),
    );
  }

  Future<void> _updateCattle() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {

        final name = _nameController.text;
        final cattleNumber = _cattleNumberController.text;
        final currentId = widget.cattle.id;
        
        // ตรวจสอบชื่อซ้ำ (ไม่นับตัวเอง)
        bool nameExists = await _dbHelper.checkCattleNameExists(name, currentId);
        if (nameExists) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ชื่อโค "$name" มีอยู่ในระบบแล้ว กรุณาใช้ชื่ออื่น'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        
        // ตรวจสอบหมายเลขซ้ำ (ไม่นับตัวเอง)
        bool numberExists = await _dbHelper.checkCattleNumberExists(cattleNumber, currentId);
        if (numberExists) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('หมายเลขโค "$cattleNumber" มีอยู่ในระบบแล้ว กรุณาใช้หมายเลขอื่น'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }

        // อัปเดต Cattle
        final updatedCattle = Cattle(
          id: widget.cattle.id,
          name: _nameController.text,
          breed: _selectedBreed, // ใช้ค่าที่เลือกจาก dropdown
          imageUrl: _imageFile != null ? _imageFile!.path : _currentImagePath,
          estimatedWeight: double.parse(_estimatedWeightController.text),
          lastUpdated: DateTime.now(),
          cattleNumber: _cattleNumberController.text,
          gender: _selectedGender,
          birthDate: _birthDate,
          fatherNumber: _fatherNumberController.text,
          motherNumber: _motherNumberController.text,
          breeder: _breederController.text,
          currentOwner: _currentOwnerController.text,
          color: _colorController.text, // เพิ่มข้อมูลสีโค
        );

        // บันทึกลงฐานข้อมูล
        await _dbHelper.updateCattle(updatedCattle);
        
        // ส่งข้อมูลกลับไปยังหน้าแสดงรายละเอียด
        Navigator.pop(context, updatedCattle);
        
        // แสดงข้อความแจ้งเตือน
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('อัปเดตข้อมูลโคเรียบร้อยแล้ว'),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        // แสดงข้อความผิดพลาด
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาด: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _cattleNumberController.dispose();
    _birthDateController.dispose();
    _fatherNumberController.dispose();
    _motherNumberController.dispose();
    _breederController.dispose();
    _currentOwnerController.dispose();
    _estimatedWeightController.dispose();
    _colorController.dispose(); // เพิ่ม dispose สำหรับช่องกรอกสี
    super.dispose();
  }
}