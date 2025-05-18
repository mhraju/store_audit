import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:store_audit/presentation/screens/splash_screen.dart';
import 'package:store_audit/utility/app_colors.dart';

class StoreAudit extends StatefulWidget {
  const StoreAudit({super.key});

  @override
  _StoreAuditState createState() => _StoreAuditState();
}

class _StoreAuditState extends State<StoreAudit> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      //print("App is inactive (User switched apps or locked screen)");
    } else if (state == AppLifecycleState.paused) {
      //print("App is in the background");
    } else if (state == AppLifecycleState.resumed) {
      //print("App is active again! Refreshing data...");
      refreshData(); // Example: Reload API or Database
    }
  }

  void refreshData() {
    //print("Fetching latest data...");
    // Add API calls or Database reinitialization if needed
  }

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
      theme: ThemeData(
        colorSchemeSeed: AppColors.primaryColor,
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: AppColors.primaryColor),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
          headlineSmall: TextStyle(
            fontSize: 14,
            color: Colors.blueGrey,
          ),
        ),
      ),
    );
  }
}
