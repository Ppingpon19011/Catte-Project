// ไฟล์ common_widgets.dart

import 'package:flutter/material.dart';
import '../utils/theme_config.dart';

// Widget แสดงสถานะกำลังโหลด
class LoadingWidget extends StatelessWidget {
  final String? message;
  
  const LoadingWidget({Key? key, this.message}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: AppTheme.primaryColor),
          if (message != null) ...[
            SizedBox(height: 16),
            Text(message!, style: TextStyle(color: AppTheme.textSecondaryColor)),
          ],
        ],
      ),
    );
  }
}

// Widget แสดงข้อความเมื่อไม่พบข้อมูล
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final IconData icon;
  final VoidCallback? onActionPressed;
  final String? actionText;
  
  const EmptyStateWidget({
    Key? key,
    required this.title,
    required this.message,
    this.icon = Icons.search_off,
    this.onActionPressed,
    this.actionText,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: AppTheme.primaryColor.withOpacity(0.4),
          ),
          SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryDarkColor,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.textSecondaryColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onActionPressed != null) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onActionPressed,
              icon: Icon(actionText == 'เพิ่มโคใหม่' ? Icons.add : Icons.refresh),
              label: Text(actionText ?? 'ลองใหม่'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// Widget แสดงข้อความแจ้งเตือน
class ErrorMessageWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  
  const ErrorMessageWidget({
    Key? key,
    required this.message,
    this.onRetry,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppTheme.errorColor.withOpacity(0.7),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.textPrimaryColor,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh),
              label: Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}