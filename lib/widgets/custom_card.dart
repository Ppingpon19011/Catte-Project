import 'package:flutter/material.dart';
import '../utils/theme_config.dart';
// ส่วนของอัมพอร์ตที่จำเป็น
import 'dart:io';

class CattleCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? imageUrl;
  final VoidCallback onTap;
  final Widget? trailing;
  final VoidCallback? onDelete;

  const CattleCard({
    Key? key,
    required this.title,
    required this.subtitle,
    this.imageUrl,
    required this.onTap,
    this.trailing,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Material(
              color: Colors.transparent,
              child: onDelete != null
                  ? Dismissible(
                      key: Key(title),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20.0),
                        color: AppTheme.errorColor,
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                        ),
                      ),
                      confirmDismiss: (direction) async {
                        return await showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('ยืนยันการลบ'),
                            content: Text('คุณต้องการลบ "$title" หรือไม่?'),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(false),
                                child: const Text('ยกเลิก'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(true),
                                child: Text(
                                  'ลบ',
                                  style: TextStyle(color: AppTheme.errorColor),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                      onDismissed: (direction) {
                        onDelete!();
                      },
                      child: _buildCardContent(),
                    )
                  : _buildCardContent(),
            ),
          ),
        ),
      ),
    );
  }

  // เพิ่มในไฟล์ custom_card.dart หรือที่มีการแสดงภาพ
  Widget _buildImageWidget(String? imageUrl) {
      if (imageUrl == null) {
          return Container(
              color: Colors.grey[200],
              child: Icon(Icons.image_not_supported, color: Colors.grey),
          );
      }
      
      if (imageUrl.startsWith('assets/')) {
          return Image.asset(
              imageUrl,
              fit: BoxFit.cover,
          );
      } else {
          final file = File(imageUrl);
          // ตรวจสอบว่าไฟล์มีอยู่จริงหรือไม่
          return FutureBuilder<bool>(
              future: file.exists(),
              builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasData && snapshot.data == true) {
                      return Image.file(
                          file,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                              return Container(
                                  color: Colors.grey[200],
                                  child: Icon(Icons.broken_image, color: Colors.grey),
                              );
                          },
                      );
                  } else {
                      return Container(
                          color: Colors.grey[200],
                          child: Icon(Icons.image_not_supported, color: Colors.grey),
                      );
                  }
              },
          );
      }
  }

  Widget _buildCardContent() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          if (imageUrl != null) _buildAvatar(),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDarkColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textSecondaryColor,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withOpacity(0.2),
          width: 2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: imageUrl!.startsWith('assets/')
            ? Image.asset(
                imageUrl!,
                fit: BoxFit.cover,
              )
            : Image.file(
                File(imageUrl!),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Center(
                    child: Icon(
                      Icons.broken_image,
                      color: AppTheme.primaryColor.withOpacity(0.5),
                    ),
                  );
                },
              ),
      ),
    );
  }
}


// สำหรับหน้ารายละเอียด
class DetailCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const DetailCard({
    Key? key,
    required this.title,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryDarkColor,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}

// สำหรับหน้าเพิ่มข้อมูล/แก้ไขข้อมูล
class FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const FormSection({
    Key? key,
    required this.title,
    required this.children,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 10.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 20,
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDarkColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Divider(
                thickness: 1,
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}