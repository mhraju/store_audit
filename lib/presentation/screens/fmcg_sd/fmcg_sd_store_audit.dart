import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/show_alert.dart';
import '../../../utility/show_progress.dart';
import 'fmcg_sd_store_list.dart';

class FmcgSdStoreAudit extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  final String storeName;
  final String auditStart;
  const FmcgSdStoreAudit({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName, required this.auditStart,
  });

  @override
  State<FmcgSdStoreAudit> createState() => _FmcgSdStoreAuditState();
}

class _FmcgSdStoreAuditState extends State<FmcgSdStoreAudit> {
  final _remarksController = TextEditingController();
  final _storeAddressController = TextEditingController();
  final _storeClassController = TextEditingController();
  final _supplyIssuerController = TextEditingController();
  final _marketActivitiesController = TextEditingController();
  final List<File> _imageFiles = [];
  List<String> imagePaths = [];
  File? _selfieImage;
  final ImagePicker _picker = ImagePicker(); // Replace with your ImgBB API key
  bool _isUploading = false;
  final DatabaseManager dbManager = DatabaseManager();
  late Map<String, dynamic> _storeData;
  String? auditEnd;

  @override
  void initState() {
    super.initState();
    //_storeData = widget.storeData;
  }

  /// **Save images path in SharedPreferences when submitting**
  Future<void> _saveSkuUpdate() async {
    if (_selfieImage == null) {
      ShowAlert.showSnackBar(context, 'Please add a selfie before submitting.');
      return;
    }
    if (_remarksController.text.isEmpty) {
      ShowAlert.showSnackBar(context, 'Please write remarks before submitting.');
      return;
    }
    if (_storeAddressController.text.isEmpty) {
      ShowAlert.showSnackBar(context, 'Please write store address before submitting.');
      return;
    }
    if (_storeClassController.text.isEmpty) {
      ShowAlert.showSnackBar(context, 'Please write store class before submitting.');
      return;
    }
    if (_supplyIssuerController.text.isEmpty) {
      ShowAlert.showSnackBar(context, 'Please write supply issue before submitting.');
      return;
    }
    if (_marketActivitiesController.text.isEmpty) {
      ShowAlert.showSnackBar(context, 'Please write market activities before submitting.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    //List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];

    if (_imageFiles.isNotEmpty) {
      imagePaths = _imageFiles.map((file) => p.basename(file.path)).toList();
      //savedPaths = _imageFiles.map((file) => file.path).toList();
    }

    // if (_selfieImage != null) {
    //   imagePaths.add(p.basename(_selfieImage!.path));
    //   //savedPaths.add(_selfieImage!.path);
    // }

    // await prefs.setStringList(
    //     'imagePaths', imagePaths); // Save final image list
    // print("Final saved images: $imagePaths");

    final String? dbPath = prefs.getString('dbPath');
    if (dbPath == null) {
      ShowAlert.showSnackBar(context, 'Database path not found.');
      return;
    }

    await prefs.setStringList('editedItems', []);
    await prefs.setStringList('newEntry', []);

    auditEnd ??= DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());

    await dbManager.closeOrUpdateStore(
      dbPath,
      widget.storeCode,
      widget.auditorId,
      1,
      1,
      widget.option,
      widget.shortCode,
      p.basename(_selfieImage!.path),
      imagePaths.where((e) => e.trim().isNotEmpty).join(','), // Use comma-separated string
      1,
      widget.auditStart,
      auditEnd!,
      _remarksController.text,
      _storeAddressController.text,
      _storeClassController.text,
      _supplyIssuerController.text,
      _marketActivitiesController.text,
    );


    ShowAlert.showSnackBar(context, 'Store is updated successfully!');

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (context) => FMCGSDStores(
          dbPath: dbPath,
          auditorId: widget.auditorId,
        ),
      ),
      (route) => route.isFirst, // Keeps only the first route (HomeScreen)
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
      final img.Image? originalImage = img.decodeImage(await File(photo.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage = img.copyResize(originalImage, width: 500, height: 500);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String newFileName = 'selfie_${widget.auditorId}_${widget.storeCode}_$timestamp.jpg';

        final String newPath = '$customPath/$newFileName';
        final File resizedFile = File('${photo.path}_resized.jpg')..writeAsBytesSync(img.encodeJpg(resizedImage));
        final File newImage = await resizedFile.copy(newPath);

        final prefs = await SharedPreferences.getInstance();
        List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
        //  print('prev images $savedPaths');
        savedPaths.add(newFileName);
        await prefs.setStringList('imagePaths', savedPaths);

        //  print('new images $savedPaths');

        setState(() {
          _selfieImage = newImage;
        });
        //print('Image saved at: $newPath');
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
        final img.Image? originalImage = img.decodeImage(await File(pickedFile.path).readAsBytes());
        if (originalImage != null) {
          final img.Image resizedImage = img.copyResize(originalImage, width: 500, height: 500);
          final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
          final String newFileName = 'cash_memo_${widget.storeCode}_$timestamp.jpg';
          final String newPath = '$customPath/$newFileName';

          // Save resized image
          final File resizedFile = File('${pickedFile.path}_resized.jpg')..writeAsBytesSync(img.encodeJpg(resizedImage));
          final File newImage = await resizedFile.copy(newPath);

          // Save image path in SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
          savedPaths.add(newFileName);
          await prefs.setStringList('imagePaths', savedPaths);

          setState(() {
            _imageFiles.add(newImage);
          });
        }
      }
    } catch (e) {
      //print('❌ Error taking photo: $e');
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

    //print("🗑️ Removed Image: ${file.path}");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: Text(
          'Store Audit (${widget.storeName})',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        GestureDetector(
                          onTap: _takeSelfie,
                          child: Container(
                            height: 300,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(8.0),
                            ),
                            child: _selfieImage == null
                                ? const Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.camera_alt, size: 50, color: Colors.grey),
                                        Text('Add a selfie near the store location'),
                                      ],
                                    ),
                                  )
                                : Image.file(_selfieImage!, fit: BoxFit.fill),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        TextField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Remarks...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        TextField(
                          controller: _storeAddressController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Store Address...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        TextField(
                          controller: _storeClassController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Store Class...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        TextField(
                          controller: _supplyIssuerController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Supply Issue...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),

                        TextField(
                          controller: _marketActivitiesController,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            hintText: 'Market Activities...',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16.0),


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

                        Center(
                          child: ElevatedButton.icon(
                            onPressed: _takePhoto,
                            icon: const Icon(Icons.camera_alt, size: 24),
                            label: const Text('Add CashMemo Photos'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12.0),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24.0),

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
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          /// **Show Progress Indicator if Uploading**
          if (_isUploading)
            Positioned.fill(
              child: Container(
                color: Colors.black54, // ✅ Full-screen overlay
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
