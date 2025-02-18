import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/fmcg_sd_sku_list.dart';
import 'package:store_audit/presentation/screens/home_screen.dart';
import 'package:store_audit/presentation/screens/home_screen_two.dart';
import 'package:store_audit/presentation/screens/login_screen.dart';
import 'package:store_audit/presentation/screens/store_close.dart';
import 'package:store_audit/utility/assets_path.dart';

import '../../db/database_manager.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _auditorId = '';
  String _dbPath = '';
  String version = '';
  final DatabaseManager dbManager = DatabaseManager();
  List<Map<String, dynamic>>? fmcgStoreList;

  @override
  void initState() {
    super.initState();
    _getAppVersion(); // Fetch the app version
    _moveToNextScreen(); // Navigate to the next screen after the delay
  }

  // Fetch the app version and build number asynchronously
  Future<void> _getAppVersion() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String appVersion = packageInfo.version; // Version name (e.g., 1.0.0)
    String buildNumber = packageInfo.buildNumber; // Build number (e.g., 1)

    setState(() {
      version = appVersion; // Update the version
    });

    // Optional: Print version and build number to console for debugging
    print("App Version: $appVersion");
    print("Build Number: $buildNumber");
  }

  // Move to the next screen after a delay
  Future<void> _moveToNextScreen() async {
    await Future.delayed(const Duration(seconds: 7)); // Delay before moving
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _auditorId = prefs.getString('auditorId') ?? 'No ID Found';
      _dbPath = prefs.getString('dbPath') ?? 'No Path Found';
    });
    if (_auditorId == 'No ID Found' || _auditorId.isEmpty) {
      Get.to(() => LoginWidget());
    } else {
      fmcgStoreList = await dbManager.loadFMcgSdStores(_dbPath, _auditorId);
      Get.off(() => HomeScreen(fmcgStoreList: fmcgStoreList ?? []));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Image.asset(
              AssetsPath.appLogoSvg, // Add your logo in assets
              height: 100,
              fit: BoxFit.contain, // Adjust size as per your need
            ),
            const Spacer(),
            const CircularProgressIndicator(),
            const SizedBox(
              height: 16,
            ),
            // Show the version number dynamically when it is fetched
            version.isNotEmpty
                ? Text("Version: $version")
                : const SizedBox
                    .shrink(), // Don't show text if version is not fetched
            const SizedBox(
              height: 36,
            ),
          ],
        ),
      ),
    );
  }
}
