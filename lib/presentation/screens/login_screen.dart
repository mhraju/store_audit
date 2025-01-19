import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Add http package
import 'package:store_audit/presentation/screens/home_screen.dart';
import '../../utility/assets_path.dart';
import '../../utility/show_progress.dart';

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

  // Function to make an API call
  Future<String?> _fetchDatabasePath(String auditorId) async {
    try {
      final url = Uri.parse(
          'https://mcdphp8.bol-online.com/luminaries-app/api/v1/syncdb?code=$auditorId');
      final response = await http.post(url);

      final responseData = json.decode(response.body);
      if (responseData['status'] == 1) {
        // Return the database path from the response
        return responseData['data']['path'];
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(responseData['message'])),
        );
      }
      // if (response.statusCode == 200) {

      // } else {
      //   ScaffoldMessenger.of(context).showSnackBar(
      //     const SnackBar(content: Text('Failed to connect to the server')),
      //   );
      // }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        //SnackBar(content: Text('Error: $e')),
        SnackBar(content: Text('Please, Connect the Internet')),
      );
    }
    return null; // Return null if an error occurs
  }

  // Navigate to the next screen
  void _navigateToNextScreen(BuildContext context) {
    Get.off(() => const HomeScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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
                  hintText: 'Give Auditor ID:',
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
                ShowProgress.showProgressDialog(context);
                final auditorId = _auditorIdController.text.trim();
                if (auditorId.isNotEmpty) {
                  await _saveAuditorId(auditorId);

                  // Make API call and fetch database path
                  final dbPath = await _fetchDatabasePath(auditorId);
                  if (dbPath != null) {
                    print('Database Path: $dbPath'); // Use this for debugging

                    // Save the database path if needed
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('dbUrl', dbPath);

                    _navigateToNextScreen(context);
                  }
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
