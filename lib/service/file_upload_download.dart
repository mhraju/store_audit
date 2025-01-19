import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../utility/show_progress.dart';

class FileUploadDownload {
  Future<void> uploadFile(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final selectedFilePath = prefs.getString('dbPath');

    if (selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected.')),
      );
      return;
    }

    // Show the progress dialog
    ShowProgress.showProgressDialogWithMsg(context);

    const String apiUrl =
        'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-db';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Attach the file
      request.files.add(
        await http.MultipartFile.fromPath('file', selectedFilePath),
      );

      // Optionally, add other fields
      request.fields['code'] = '852456'; // Example field

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed. Status code: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      // Dismiss the progress dialog
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> uploadImages(BuildContext context) async {
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

    const String apiUrl =
        'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-user-files';

    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl))
        ..fields['code'] = '852456';

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
        for (String path in List.from(savedPaths)) {
          File(path).deleteSync();
        }

        await prefs.remove('imagePaths');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload completed successfully.')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed. Status: ${response.statusCode}')),
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
