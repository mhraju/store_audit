import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../db/database_manager.dart';
import '../utility/show_alert.dart';
import '../utility/show_progress.dart';

class FileUploadDownload {
  Future<void> getSyncStatus(BuildContext context, String dbPath, String auditorId) async {
    try {
      final DatabaseManager dbManager = DatabaseManager();
      final FileUploadDownload fileUploadDownload = FileUploadDownload();

      final url = Uri.parse('https://mcdphp8.bol-online.com/luminaries-app/api/v1/get-sync-status?code=$auditorId');
      final response = await http.post(url);

      final responseData = json.decode(response.body);
      if (responseData['status'] == 1) {
        final SharedPreferences prefs = await SharedPreferences.getInstance();

        int dwStatus = responseData['data']['download_status'];
        int upStatus = responseData['data']['upload_status'];
        String lastDownload = responseData['data']['last_download']; // Ensure it's a String

        await prefs.setInt('dwStatus', dwStatus);
        await prefs.setInt('upStatus', upStatus);
        await prefs.setString('last_download', lastDownload); // Store as String

        if (upStatus == 1) {
          await fileUploadDownload.uploadFile(context, dbPath, auditorId);
          await fileUploadDownload.uploadImages(context, dbPath, auditorId);
        }

        // DateTime lastDownloadDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(lastDownload);
        // DateTime today = DateTime.now();
        // bool isSameDate = lastDownloadDate.year == today.year && lastDownloadDate.month == today.month && lastDownloadDate.day == today.day;
        // if (isSameDate && dwStatus == 1) {
        if (dwStatus == 1) {
          String dbUrl = await downloadUpdateDB(context, auditorId);
          await prefs.setString('dbUrl', dbUrl);
          await dbManager.downloadAndSaveUserDatabase();
          await prefs.setInt('dwStatus', 0);
          ShowAlert.showSnackBar(context, 'Database sync successfully');
        } else {
          ShowAlert.showSnackBar(context, 'Database already updated for today');
        }
      } else {
        ShowAlert.showSnackBar(context, responseData['message']);
      }
    } catch (e) {
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error on sync status: $e')),
      );
    }
  }

  Future<String> downloadUpdateDB(BuildContext context, String auditorId) async {
    try {
      final url = Uri.parse('https://mcdphp8.bol-online.com/luminaries-app/api/v1/download-db?code=$auditorId');
      final response = await http.post(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);

        if (responseData['status'] == 1) {
          print('DbPath okkk');
          // Ensure 'data' and 'path' exist before accessing
          if (responseData['data'] != null && responseData['data']['path'] != null) {
            return responseData['data']['path'];
          } else {
            ShowAlert.showSnackBar(context, 'Invalid response structure');
            return '';
          }
        } else {
          ShowAlert.showSnackBar(context, responseData['message']);
          return '';
        }
      } else {
        ShowAlert.showSnackBar(context, 'Server error: ${response.statusCode}');
        return '';
      }
    } catch (e) {
      ShowAlert.showSnackBar(context, 'Error: $e');
      return ''; // Ensure an empty string is returned on error
    }
  }

  Future<void> uploadFile(BuildContext context, String selectedFilePath, String auditorId) async {
    try {
      final file = File(selectedFilePath);
      if (!file.existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File not found. Please check the path.')),
        );
        return;
      }

      // Show the progress dialog
      ShowProgress.showProgressDialogWithMsg(context);

      const String apiUrl = 'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-db';

      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Attach the file
      request.files.add(
        await http.MultipartFile.fromPath('file', selectedFilePath),
      );

      // Add extra parameters
      request.fields['code'] = auditorId;

      // Send the request
      var response = await request.send();

      // Hide the progress dialog safely
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      // Handle response
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ File uploaded successfully!')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('⚠️ Upload failed. Status code: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      // Ensure progress dialog is closed on error
      if (Navigator.canPop(context)) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Error uploading file: $e')),
      );
    }
  }

  Future<void> uploadImages(BuildContext context, String dbPath, String auditorId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];

    if (savedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to upload.')),
      );
      return;
    }

    // Show the progress dialog
    ShowProgress.showProgressDialogWithMsg(context);

    const String apiUrl = 'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-user-files';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl))..fields['code'] = auditorId;

      print("Total Image Paths:  $savedPaths");

      for (String path in List.from(savedPaths)) {
        File imageFile = File(path);

        if (await imageFile.exists()) {
          request.files.add(await http.MultipartFile.fromPath('files[]', path));
        } else {
          savedPaths.remove(path);
        }
      }

      if (request.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid images to upload.')),
        );
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss the dialog
        return;
      }

      var response = await request.send();

      if (response.statusCode == 200) {
        // for (String path in List.from(savedPaths)) {
        //   File(path).deleteSync();
        // }

        await prefs.remove('imagePaths');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Image upload completed successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed. Status: ${response.statusCode}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    } finally {
      // Dismiss the progress dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
  }
}
