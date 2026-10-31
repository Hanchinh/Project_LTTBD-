import 'package:flutter/material.dart';
import 'package:delivery_marker_mobile/app/app.dart';

export 'package:delivery_marker_mobile/app/app.dart';
export 'package:delivery_marker_mobile/app/auth_splash_view.dart';
export 'package:delivery_marker_mobile/app/home_shell_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DeliveryLocationMarkerApp());
}
