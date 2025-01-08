import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // Import the image package
import 'package:http/http.dart' as http;

class StoreClose extends StatefulWidget {
  //final List<Map<String, dynamic>> selectedItems;
  final Map<String, dynamic> item;

  const StoreClose({super.key, required this.item});

  @override
  State<StoreClose> createState() => _StoreCloseState();
}

class _StoreCloseState extends State<StoreClose> {
  final _remarksController = TextEditingController();

  File? _image;
  final ImagePicker _picker = ImagePicker();
  final String uploadUrl =
      'https://api.imgbb.com/1/upload'; // Replace with your API endpoint
  final String apiKey =
      '47dcd96ff79dc95188c37d2170490762'; // Replace with your ImgBB API key
  bool _isUploading = false;

  Future<void> _takeSelfie() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String customPath = '${appDir.path}/CustomPhotos';
      final Directory customDir = Directory(customPath);
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }

      // Resize the image to 600x600 before saving
      final img.Image? originalImage =
          img.decodeImage(await File(photo.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage =
            img.copyResize(originalImage, width: 600, height: 600);
        final File resizedFile = File('${photo.path}_resized.jpg')
          ..writeAsBytesSync(img.encodeJpg(resizedImage));
        final String newPath =
            '$customPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File newImage = await resizedFile.copy(newPath);

        setState(() {
          _image = newImage;
        });
      }
    }
  }

  Future<void> _uploadImage() async {
    if (_image == null) {
      _showAlertDialog('Error', 'No image to upload.');
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final request =
          http.MultipartRequest('POST', Uri.parse('$uploadUrl?key=$apiKey'));
      request.files.add(await http.MultipartFile.fromPath(
          'image', _image!.path)); // 'image' is the required parameter name

      final response = await request.send();

      if (response.statusCode == 200) {
        final responseData = await http.Response.fromStream(response);
        print('Upload successful: ${responseData.body}');
        _showAlertDialog('Success', 'Image uploaded successfully!');
      } else {
        print('Upload failed with status code: ${response.statusCode}');
        _showAlertDialog('Error', 'Failed to upload image.');
      }
    } catch (e) {
      print('Error uploading image: $e');
      _showAlertDialog('Error', 'An error occurred while uploading the image.');
    }

    setState(() {
      _isUploading = false;
    });
  }

  void _showAlertDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _saveSkuUpdate() {
    if (_image == null || _remarksController.text.isEmpty) {
      _showSnackbar('Please add a selfie and enter remarks before submitting.');
      return;
    }

    // Logic to save data in the database
    print('Remarks: ${_remarksController.text}');
    print('Image Path: ${_image!.path}');
    print('Previous Page Data: ${widget.item}');
    _uploadImage();
    // _showSnackbar('SKU update submitted successfully!');
    //Navigator.pop(context); // Navigate back after submission
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SKU Update'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _remarksController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Remarks...',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16.0),
                GestureDetector(
                  onTap: _takeSelfie,
                  child: Container(
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    child: _image == null
                        ? const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt,
                                    size: 50, color: Colors.grey),
                                Text(
                                    'Please add a selfie near the store location'),
                              ],
                            ),
                          )
                        : Image.file(_image!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16.0),
                ElevatedButton(
                  onPressed: _saveSkuUpdate,
                  child: const Text('Submit'),
                ),
              ],
            ),
          ),
          if (_isUploading)
            Center(
              child: Container(
                color: Colors.black54,
                child: const CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
