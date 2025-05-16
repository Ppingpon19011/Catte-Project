import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Widget สำหรับแสดงรูปภาพ Debug ล่าสุดจากการปรับขนาดรูปภาพใน tensor
class DebugImageWidget extends StatefulWidget {
  final double height;
  final double width;
  final BoxFit fit;
  final bool showTitle;

  const DebugImageWidget({
    Key? key,
    this.height = 200,
    this.width = 200,
    this.fit = BoxFit.contain,
    this.showTitle = true,
  }) : super(key: key);

  @override
  _DebugImageWidgetState createState() => _DebugImageWidgetState();
}

class _DebugImageWidgetState extends State<DebugImageWidget> {
  File? _latestImage;
  Timer? _refreshTimer;
  String _lastModified = "";
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _findLatestImage();
    // ตั้งเวลาดึงรูปใหม่ทุก 5 วินาที
    _refreshTimer = Timer.periodic(Duration(seconds: 5), (_) => _findLatestImage());
  }
  
  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _findLatestImage() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final appDir = await getApplicationDocumentsDirectory();
      final debugDir = Directory('${appDir.path}/debug_images');
      
      if (await debugDir.exists()) {
        final List<FileSystemEntity> entities = await debugDir.list().toList();
        final List<File> files = entities
            .whereType<File>()
            .where((file) => file.path.endsWith('.jpg'))
            .toList();
        
        if (files.isNotEmpty) {
          // เรียงลำดับไฟล์ตามเวลาที่สร้าง (ใหม่สุดก่อน)
          files.sort((a, b) => b.statSync().modified.compareTo(a.statSync().modified));
          
          final latestFile = files.first;
          final lastModified = latestFile.statSync().modified;
          
          if (mounted) {
            setState(() {
              _latestImage = latestFile;
              _lastModified = _formatDateTime(lastModified);
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error finding latest debug image: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _formatDateTime(DateTime dateTime) {
    // แปลงเวลาเป็นรูปแบบที่อ่านง่าย
    return "${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}:${dateTime.second.toString().padLeft(2, '0')}";
  }
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: widget.width,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.showTitle)
            Container(
              padding: EdgeInsets.symmetric(vertical: 4),
              width: double.infinity,
              color: Colors.blue[50],
              child: Text(
                'รูปปรับขนาด (640x640)',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _latestImage != null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(
                            _latestImage!,
                            fit: widget.fit,
                          ),
                          Positioned(
                            bottom: 4,
                            right: 4,
                            child: Container(
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _lastModified,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image_not_supported, size: 36, color: Colors.grey[400]),
                            SizedBox(height: 8),
                            Text(
                              'ยังไม่มีรูป debug',
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}