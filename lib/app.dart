import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:store_audit/presentation/screens/splash_screen.dart';
import 'package:store_audit/utility/app_colors.dart';

class StoreAudit extends StatelessWidget {
  const StoreAudit({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      home: SplashScreen(),
      theme: ThemeData(
        colorSchemeSeed: AppColors.primaryColor,
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(color: AppColors.primaryColor),
        textTheme: const TextTheme(
            headlineLarge: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
            headlineSmall: TextStyle(
              fontSize: 14,
              color: Colors.blueGrey,
            )),
      ),
    );
  }
}
