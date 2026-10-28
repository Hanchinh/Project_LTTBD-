import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/core/constants/map_config.dart';

export 'package:delivery_marker_mobile/core/constants/map_config.dart';

/// Lớp cấu hình tile bản đồ cho ca (chuyển tiếp sang MapConfig tập trung)
class ShiftMapTileConfig {
  static String getUrlTemplate(int currentMapType) => MapConfig.getUrlTemplate(currentMapType);

  static List<String> getSubdomains(int currentMapType) => MapConfig.getSubdomains(currentMapType);

  static const List<String> mapTypeNames = MapConfig.mapTypeNames;

  static void showMapTypeSnackBar(BuildContext context, int newMapType) {
    MapConfig.showMapTypeSnackBar(context, newMapType);
  }
}
