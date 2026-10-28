import 'package:flutter/material.dart';

class ShiftMapTileConfig {
  static String getUrlTemplate(int currentMapType) {
    switch (currentMapType) {
      case 1:
        return 'https://mt1.google.com/vt/lyrs=y&x={x}&y={y}&z={z}';
      case 2:
        return 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png';
      case 0:
      default:
        return 'https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}';
    }
  }

  static List<String> getSubdomains(int currentMapType) {
    if (currentMapType == 2) {
      return const ['a', 'b', 'c', 'd'];
    }
    return const [];
  }

  static const List<String> mapTypeNames = [
    'Bản đồ đường phố',
    'Ảnh vệ tinh + Tên đường',
    'Bản đồ CartoDB Voyager',
  ];

  static void showMapTypeSnackBar(BuildContext context, int newMapType) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Đã chuyển sang: ${mapTypeNames[newMapType]}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}
