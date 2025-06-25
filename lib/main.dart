import 'package:flutter/material.dart';
import 'package:store_audit/app.dart';
import 'package:store_audit/utility/app_version.dart';

// void main() {
//   runApp(const StoreAudit());
// }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppVersion.init();
  runApp(const StoreAudit());
}

