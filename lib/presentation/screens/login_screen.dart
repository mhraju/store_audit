import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/home_screen.dart';

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HomeScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFF3F4F6),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo
            Container(
              width: 95,
              height: 95,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                image: DecorationImage(
                  image: AssetImage('assets/images/splash_logo.png'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 15),

            // App Title
            Image.asset(
              'assets/images/splash_logo.png',
              width: 275,
              fit: BoxFit.fitWidth,
            ),
            SizedBox(height: 10),

            // Subtitle
            Text(
              'Data Collection Application',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF1E232C),
                fontFamily: 'Lato',
                fontSize: 19.5,
                letterSpacing: 0.6,
                fontWeight: FontWeight.normal,
                height: 1.5,
              ),
            ),
            SizedBox(height: 40),

            // Input Field
            Container(
              width: 343,
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                color: Color(0xFFEAEFF6),
              ),
              child: TextField(
                controller: _auditorIdController,
                decoration: InputDecoration(
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
            SizedBox(height: 20),

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
                    SnackBar(content: Text('Please enter an Auditor ID')),
                  );
                }
              },
              child: Container(
                width: 343,
                height: 50,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(50),
                  color: Color(0xFF314CA3),
                ),
                child: Text(
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
