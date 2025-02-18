import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // Import the image package
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/utility/show_alert.dart';

import '../../db/database_manager.dart';
import '../../utility/app_colors.dart';
import '../../utility/show_progress.dart';
import 'fmcg_sd_store_list.dart';

class FmcgSdStoreClose extends StatefulWidget {
  final List<Map<String, dynamic>> storeList;
  final Map<String, dynamic> storeData;
  final String option;
  final String auditorId;

  const FmcgSdStoreClose(
      {super.key,
      required this.storeList,
      required this.storeData,
      required this.option,
      required this.auditorId});

  @override
  State<FmcgSdStoreClose> createState() => _FmcgSdStoreCloseState();
}

class _FmcgSdStoreCloseState extends State<FmcgSdStoreClose> {
  final _remarksController = TextEditingController();
  final List<File> _imageFiles = [];
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker(); // Replace with your ImgBB API key
  bool _isUploading = false;
  final DatabaseManager dbManager = DatabaseManager();
  late Map<String, dynamic> _storeData;

  @override
  void initState() {
    super.initState();
    _storeData = widget.storeData;
  }

  String sortStatus() {
    if (widget.option == 'Initial Audit (IA)') {
      return 'IA';
    } else if (widget.option == 'Re Audit (RA)') {
      return 'RA';
    } else if (widget.option == 'Temporary Closed (TC)') {
      return 'TC';
    } else if (widget.option == 'Permanent Closed (PC)') {
      return 'PC';
    } else {
      return 'CANS';
    }
  }

  /// **Load saved images from SharedPreferences**
  Future<void> _loadSavedImages() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
    setState(() {
      _imageFiles.addAll(savedPaths.map((path) => File(path)));
    });
  }

  /// **Save images path in SharedPreferences when submitting**
  Future<void> _saveSkuUpdate() async {
    if (_selfieImage == null) {
      ShowAlert.showSnackBar(context, 'Please add a selfie before submitting.');
      return;
    }
    if (_remarksController.text.isEmpty) {
      ShowAlert.showSnackBar(
          context, 'Please enter remarks before submitting.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    //List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
    List<String> imagePaths = [];

    if (_imageFiles.isNotEmpty) {
      imagePaths = _imageFiles.map((file) => file.path).toList();
      //savedPaths = _imageFiles.map((file) => file.path).toList();
    }

    if (_selfieImage != null) {
      imagePaths.add(_selfieImage!.path);
      //savedPaths.add(_selfieImage!.path);
    }

    // await prefs.setStringList(
    //     'imagePaths', imagePaths); // Save final image list
    // print("✅ Final saved images: $imagePaths");

    final String? dbPath = prefs.getString('dbPath');
    if (dbPath == null) {
      ShowAlert.showSnackBar(context, 'Database path not found.');
      return;
    }

    await dbManager.closeStore(
      dbPath,
      _storeData['code'],
      1,
      1,
      widget.option,
      sortStatus(),
      _selfieImage!.path,
      imagePaths.join(','), // ✅ Use comma-separated string
    );

    ShowAlert.showSnackBar(context, 'Store update submitted successfully!');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => FMCGSDStores(
          dbPath: dbPath,
          auditorId: widget.auditorId,
        ),
      ),
      (route) => route.isFirst, // ✅ Keeps only the first route (HomeScreen)
    );
  }

  Future<void> _takeSelfie() async {
    final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
    if (photo != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String customPath = appDir.path;
      final Directory customDir = Directory(customPath);
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }

      // Resize the image to 600x600 before saving
      final img.Image? originalImage =
          img.decodeImage(await File(photo.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage =
            img.copyResize(originalImage, width: 500, height: 500);
        final String timestamp =
            DateTime.now().millisecondsSinceEpoch.toString();
        final String newFileName = 'selfie_${widget.auditorId}_$timestamp.jpg';

        final String newPath = '$customPath/$newFileName';
        final File resizedFile = File('${photo.path}_resized.jpg')
          ..writeAsBytesSync(img.encodeJpg(resizedImage));
        final File newImage = await resizedFile.copy(newPath);

        final prefs = await SharedPreferences.getInstance();
        List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
        print('prev images $savedPaths');
        savedPaths.add(newPath);
        await prefs.setStringList('imagePaths', savedPaths);

        print('new images $savedPaths');

        setState(() {
          _selfieImage = newImage;
        });
        print('Image saved at: $newPath');
      }
    }
  }

  /// **Capture image, resize it & save the path**
  Future<void> _takePhoto() async {
    try {
      ShowProgress.showProgressDialog(context);

      final pickedFile = await _picker.pickImage(source: ImageSource.camera);
      if (pickedFile != null) {
        final directory = await getApplicationDocumentsDirectory();
        final customPath = directory.path;

        // Resize image
        final img.Image? originalImage =
            img.decodeImage(await File(pickedFile.path).readAsBytes());
        if (originalImage != null) {
          final img.Image resizedImage =
              img.copyResize(originalImage, width: 500, height: 500);
          final String timestamp =
              DateTime.now().millisecondsSinceEpoch.toString();
          final String newPath = '$customPath/product_$timestamp.jpg';

          // Save resized image
          final File resizedFile = File('${pickedFile.path}_resized.jpg')
            ..writeAsBytesSync(img.encodeJpg(resizedImage));
          final File newImage = await resizedFile.copy(newPath);

          // Save image path in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
          savedPaths.add(newPath);
          await prefs.setStringList('imagePaths', savedPaths);

          setState(() {
            _imageFiles.add(newImage);
          });
        }
      }
    } catch (e) {
      print('❌ Error taking photo: $e');
      ShowAlert.showSnackBar(context, 'Failed to take a photo.');
    } finally {
      Navigator.of(context).pop();
    }
  }

  /// **Remove Image & Update SharedPreferences**
  void _removeImage(File file) async {
    setState(() {
      _imageFiles.remove(file);
    });

    final prefs = await SharedPreferences.getInstance();
    List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
    savedPaths.remove(file.path);
    await prefs.setStringList('imagePaths', savedPaths);

    print("🗑️ Removed Image: ${file.path}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text('Store Close'),
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
                    child: _selfieImage == null
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
                        : Image.file(_selfieImage!, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16.0),

                const Text('Add Photos:'),
                const SizedBox(height: 8),

                /// **Image Display with Remove Option**
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _imageFiles
                      .map(
                        (file) => Stack(
                          children: [
                            Image.file(file, width: 100, height: 100),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(file),
                                // Updated function
                                child: const Icon(
                                  Icons.remove_circle,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                      .toList(),
                ),

                const SizedBox(height: 10),

                ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Take Photo'),
                ),

                const SizedBox(height: 16.0),

                /// **Submit & Save Images**
                ElevatedButton(
                  onPressed: _saveSkuUpdate,
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: const Color(0xFF314CA3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(double.infinity, 50),
                  ),
                  child: const Text(
                    'Submit',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// **Show Progress Indicator if Uploading**
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
