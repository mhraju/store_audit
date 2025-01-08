import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/home_screen.dart';

import '../../utility/assets_path.dart';

class LoginWidget extends StatefulWidget {
  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final TextEditingController _auditorIdController = TextEditingController();

  // Save input data to local storage
  Future<void> _saveAuditorId(String auditorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auditorId', auditorId);
  }

  // Navigate to the next screen
  void _navigateToNextScreen(BuildContext context) {
    Get.off(() => const HomeScreen());
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => const HomeScreen(),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            // Container(
            //   width: 95,
            //   height: 95,
            //   decoration: BoxDecoration(
            //     borderRadius: BorderRadius.circular(15),
            //     image: const DecorationImage(
            //       image: AssetImage('assets/images/splash_logo.png'),
            //       fit: BoxFit.cover,
            //     ),
            //   ),
            // ),
            const SizedBox(height: 15),

            // App Title
            Image.asset(
              AssetsPath.appLogoSvg,
              width: 275,
              fit: BoxFit.fitWidth,
            ),
            const SizedBox(height: 15),

            // Subtitle
            const Text(
              'Data Collection Application',
              textAlign: TextAlign.center,
              style: TextStyle(
                //color: Color(0xFF1E232C),
                color: Colors.amber,
                fontFamily: 'Lato',
                fontSize: 19.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.bold,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),

            // Input Field
            Container(
              width: 343,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: const Color(0xFFEAEFF6),
              ),
              child: TextField(
                controller: _auditorIdController,
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Give auditor ID:',
                  hintStyle: TextStyle(
                    color: Color(0xFF888EA2),
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Login Button
            GestureDetector(
              onTap: () async {
                final auditorId = _auditorIdController.text.trim();
                if (auditorId.isNotEmpty) {
                  await _saveAuditorId(auditorId);
                  _navigateToNextScreen(context);
                } else {
                  // Show a message if the input is empty
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter an Auditor ID')),
                  );
                }
              },
              child: Container(
                width: 343,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: const Color(0xFF314CA3),
                ),
                child: const Text(
                  'Log In',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Inter',
                    fontSize: 18,
                    fontWeight: FontWeight.normal,
                    height: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
