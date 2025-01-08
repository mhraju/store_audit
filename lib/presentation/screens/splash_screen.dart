import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:store_audit/presentation/screens/home_screen.dart';
import 'package:store_audit/presentation/screens/login_screen.dart';
import 'package:store_audit/utility/assets_path.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    _moveToNextScreen();
  }

  Future<void> _moveToNextScreen() async {
    await Future.delayed(const Duration(seconds: 3));
    Get.to(() => LoginWidget());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
      child: Column(
        children: [
          const Spacer(),
          Image.asset(
            AssetsPath.appLogoSvg, // Add your logo in assets
            height: 100,
            fit: BoxFit.contain, // Adjust size
          ),
          const Spacer(),
          const CircularProgressIndicator(),
          const SizedBox(
            height: 16,
          ),
          const Text('Version: 1.0.0'),
          const SizedBox(
            height: 16,
          ),
        ],
      ),
    ));
  }
}
