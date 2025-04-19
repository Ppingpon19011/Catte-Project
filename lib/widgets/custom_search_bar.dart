import 'package:flutter/material.dart';
import '../utils/theme_config.dart';

class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final Function()? onClear;
  final bool isSearching;

  const CustomSearchBar({
    Key? key,
    required this.controller,
    required this.hintText,
    this.onClear,
    this.isSearching = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(40), // เพิ่มความมน
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect( // เพิ่ม ClipRRect เพื่อให้แน่ใจว่าเนื้อหาภายในจะถูกตัดตามความโค้งมน
        borderRadius: BorderRadius.circular(40),
        child: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: TextStyle(color: Colors.grey[400]),
            prefixIcon: Icon(
              Icons.search,
              color: AppTheme.primaryColor,
              size: 22,
            ),
            suffixIcon: isSearching
                ? IconButton(
                    icon: Icon(
                      Icons.clear,
                      color: Colors.grey[500],
                      size: 20,
                    ),
                    onPressed: onClear,
                  )
                : null,
            fillColor: Colors.white,
            filled: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
          ),
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textPrimaryColor,
          ),
        ),
      ),
    );
  }
}