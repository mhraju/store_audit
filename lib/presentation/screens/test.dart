import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class FileUploadExample extends StatefulWidget {
  @override
  _FileUploadExampleState createState() => _FileUploadExampleState();
}

class _FileUploadExampleState extends State<FileUploadExample> {
  File? _selectedFile;
  bool _isUploading = false;

  // Function to upload the file to the server
  Future<void> _uploadFile() async {
    final prefs = await SharedPreferences.getInstance();
    final selectedFilePath = prefs.getString('dbPath');

    if (selectedFilePath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No file selected.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    const String apiUrl =
        'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-db'; // Replace with your API URL

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
        print('File uploaded successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File uploaded successfully')),
        );
      } else {
        print('Failed to upload file. Status code: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload failed. Status code: ${response.statusCode}'),
          ),
        );
      }
    } catch (e) {
      print('Error uploading file: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading file: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _uploadImages() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];

    if (savedPaths.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No images to upload.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    const String apiUrl =
        'https://mcdphp8.bol-online.com/luminaries-app/api/v1/upload-user-files';

    try {
      // Create the request and add the fields only once
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl))
        ..fields['code'] = '852456';

      for (String path in List.from(savedPaths)) {
        File imageFile = File(path);

        if (await imageFile.exists()) {
          // Add files to the request
          request.files.add(await http.MultipartFile.fromPath('files[]', path));
        } else {
          print('File not found: $path');
          savedPaths.remove(path); // Remove invalid path
        }
      }

      if (request.files.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No valid images to upload.')),
        );
        setState(() {
          _isUploading = false;
        });
        return;
      }

      // Send the request
      var response = await request.send();

      if (response.statusCode == 200) {
        print('All images uploaded successfully.');

        // Remove all uploaded files from the device
        for (String path in List.from(savedPaths)) {
          File(path).deleteSync();
        }

        // Clear paths from SharedPreferences
        await prefs.remove('imagePaths');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image upload completed successfully.')),
        );
      } else {
        print('Failed to upload images. Status: ${response.statusCode}');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Upload failed. Status: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error uploading images: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error uploading images: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('File Upload'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_selectedFile != null)
              Column(
                children: [
                  Image.file(
                    _selectedFile!,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            if (_isUploading)
              const CircularProgressIndicator()
            else
              Column(
                children: [
                  ElevatedButton(
                    onPressed: _uploadImages,
                    child: const Text('Image File'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _uploadFile,
                    child: const Text('Upload File'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
