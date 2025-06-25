import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // Add http package
import 'package:store_audit/presentation/screens/home_screen.dart';
import 'package:store_audit/service/file_upload_download.dart';
import 'package:store_audit/utility/app_version.dart';
import '../../db/database_manager.dart';
import '../../utility/assets_path.dart';
import '../../utility/show_progress.dart';

class LoginWidget extends StatefulWidget {
  @override
  _LoginWidgetState createState() => _LoginWidgetState();
}

class _LoginWidgetState extends State<LoginWidget> {
  final TextEditingController _auditorIdController = TextEditingController();
  final DatabaseManager dbManager = DatabaseManager();
  final FileUploadDownload fileUploadDownload = FileUploadDownload();
  List<Map<String, dynamic>>? fmcgStoreList;
  String _dbPath = '';
  String _auditorId = '';
  String dbUrl = '';
  String version = '';

  @override
  void initState() {
    super.initState();
    version = AppVersion.getVersion();
  }

  @override
  void dispose() {
    // Example: dispose any controllers or close streams if added in future
    super.dispose();
  }

  //late Map<String, dynamic> userData;

  // Save input data to local storage
  Future<void> _saveAuditorId(String auditorId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auditorId', auditorId);
  }

  Future<void> saveUserDataToPrefs(userData, settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('code', userData['code']);
    await prefs.setString('name', userData['name']);
    await prefs.setString('phone', userData['phone']);
    await prefs.setString('designation', userData['designation']);
    await prefs.setString('supervisor_name', userData['supervisor_name']);
    await prefs.setString('zone', userData['zone']);
    await prefs.setInt('geo_fence', settings['geo_fance_radius']);
  }

  // Function to make an API call
  Future<void> _fetchDatabasePath(String auditorId) async {
    try {
      final url = Uri.parse('${AssetsPath.baseUrl}api/v1/download-db?code=$auditorId&app_version=$version');
      final response = await http.post(url);

      final responseData = json.decode(response.body);
      if (responseData['status'] == 1) {
        //print('DbPath okkk');
        // Return the database path from the response
        dbUrl = responseData['data']['path'];
        await _saveAuditorId(auditorId);
      } else {
        ShowProgress.hideProgressDialog(context);
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
      ShowProgress.hideProgressDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        //SnackBar(content: Text('Error: $e')),
        const SnackBar(content: Text('Please, Connect the Internet')),
      );
    }
    return; // Return null if an error occurs
  }

  Future<void> _checkLogin(String auditorId) async {
    try {
      final url = Uri.parse('${AssetsPath.baseUrl}api/v1/login?code=$auditorId&app_version=$version');
      final response = await http.post(url);

      final responseData = json.decode(response.body);
      if (responseData['status'] == 1) {
        // print('Loginn okkk');
        // Return the database path from the response
        await saveUserDataToPrefs(responseData['data'], responseData['settings']);
        await _fetchDatabasePath(auditorId);
      } else {
        ShowProgress.hideProgressDialog(context);
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
      ShowProgress.hideProgressDialog(context);
      ScaffoldMessenger.of(context).showSnackBar(
        //SnackBar(content: Text('Error: $e')),
        const SnackBar(content: Text('Please, Connect the Internet')),
      );
    } // Return null if an error occurs
  }

  // Navigate to the next screen
  Future<void> _navigateToNextScreen(BuildContext context) async {
    fmcgStoreList = await dbManager.loadFMcgSdStores(_dbPath, _auditorId);
    //print('Dataaa  $fmcgStoreList');
    ShowProgress.hideProgressDialog(context);
    Get.off(() => HomeScreen(
          fmcgStoreList: fmcgStoreList ?? [],
          dbPath: _dbPath,
          auditorId: _auditorId,
        ));
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
                  hintText: 'Auditor ID',
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
                ShowProgress.showProgressDialogWithMsg(context);
                final auditorId = _auditorIdController.text.trim();
                if (auditorId.isNotEmpty) {
                  // Make API call and fetch database path
                  await _checkLogin(auditorId);

                  //print('Database Path: $dbUrl'); // Use this for debugging

                  // Save the database path if needed
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('dbUrl', dbUrl);

                  final dbPath = await dbManager.downloadAndSaveUserDatabase();
                  _dbPath = dbPath;
                  _auditorId = auditorId;
                  await fileUploadDownload.getSyncStatus(context, _dbPath, _auditorId, 'login', version);
                  _navigateToNextScreen(context);
                } else {
                  ShowProgress.hideProgressDialog(context);
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
