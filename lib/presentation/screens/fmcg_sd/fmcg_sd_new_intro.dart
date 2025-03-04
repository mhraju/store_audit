import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_new_entry.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_sku_list.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/show_alert.dart';
import '../../../utility/show_progress.dart';

class FmcgSdNewIntro extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  final String storeName;
  const FmcgSdNewIntro({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName,
  });

  @override
  State<FmcgSdNewIntro> createState() => _FmcgSdNewIntroState();
}

class _FmcgSdNewIntroState extends State<FmcgSdNewIntro> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  final DatabaseManager dbManager = DatabaseManager();
  String? selectedCategory;
  List<Map<String, dynamic>> categories = [];
  final ImagePicker _picker = ImagePicker();
  final List<File> _imageFiles = [];
  String? selectedCategoryCode;
  String? selectedCategoryName;

  @override
  void initState() {
    super.initState();
    _loadCategory(); // Load data asynchronously
  }

  Future<void> _loadCategory() async {
    setState(() {
      isLoading = true; // Ensure UI shows loading state
    });
    // await Future.delayed(const Duration(seconds: 1));
    final fetchedData =
        await dbManager.loadFmcgSdProductCategories(widget.dbPath);
    setState(() {
      categories = fetchedData;
      isLoading = false;
    });
  }

  TextEditingController companyController = TextEditingController();
  TextEditingController countryController = TextEditingController();
  TextEditingController brandController = TextEditingController();
  TextEditingController itemDescriptionController = TextEditingController();
  TextEditingController packTypeController = TextEditingController();
  TextEditingController packSizeController = TextEditingController();
  TextEditingController promotypeController = TextEditingController();
  TextEditingController mrpController = TextEditingController();

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
    print("🗑️ Removed Image: ${_imageFiles.length} hhhhhhhh ${file.path}   ");
  }

  String generateSecureSixDigitProductCode() {
    final Random random = Random.secure();
    final Uint8List bytes = Uint8List(3);
    for (int i = 0; i < bytes.length; i++) {
      bytes[i] = random.nextInt(256);
    }
    final int code = base64Url.encode(bytes).hashCode.abs() % 900000 + 100000;
    return code.toString();
  }

  Future<void> _submitForm() async {
    if (_formKey.currentState!.validate() &&
        selectedCategoryName != null &&
        _imageFiles.isNotEmpty) {
      print("Form Submitted with:");
      print("Category: $selectedCategoryName");
      print("Category Code: $selectedCategoryCode");
      print("Company: ${companyController.text}");
      print("Country: ${countryController.text}");
      print("Brand: ${brandController.text}");
      print("Item Description: ${itemDescriptionController.text}");
      print("Pack Type: ${packTypeController.text}");
      print("Pack Size: ${packSizeController.text}");
      print("Promotype: ${promotypeController.text}");
      print("MRP: ${mrpController.text}");
      print("Images Selected: ${_imageFiles.length}");

      if (_imageFiles.length == 4) {
        // Save image path in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        List<String> savedPaths = prefs.getStringList('imagePaths') ??
            []; // Get existing saved images
        if (_imageFiles.isNotEmpty) {
          List<String> newPaths = _imageFiles.map((file) => file.path).toList();
          savedPaths = {...savedPaths, ...newPaths}.toList();
        }
        await prefs.setStringList('imagePaths', savedPaths); //
        print("✅ Final saved images: $savedPaths");

        String productCode = generateSecureSixDigitProductCode();

        await dbManager.insertFMcgSdProductIntro(
          widget.dbPath,
          widget.auditorId,
          productCode,
          selectedCategoryName!,
          companyController.text,
          countryController.text,
          brandController.text,
          itemDescriptionController.text,
          packTypeController.text,
          packSizeController.text,
          promotypeController.text,
          mrpController.text,
          _imageFiles[0].path,
          _imageFiles[1].path,
          _imageFiles[2].path,
          _imageFiles[3].path,
        );

        await dbManager.insertFMcgSdStoreProduct(
          context,
          widget.dbPath,
          widget.storeCode,
          widget.auditorId,
          productCode,
        );

        await dbManager.insertFMcgSdProducts(
          widget.dbPath,
          widget.auditorId,
          'FMCG',
          productCode,
          selectedCategoryCode!,
          selectedCategoryName!,
          companyController.text,
          brandController.text,
          countryController.text,
          itemDescriptionController.text,
          packTypeController.text,
          packSizeController.text,
          promotypeController.text,
          mrpController.text,
        );

        ShowAlert.showSnackBar(context, 'Form submitted successfully!');
      } else {
        ShowAlert.showSnackBar(context, "You can only select up to 4 images.");
      }
    } else {
      ShowAlert.showSnackBar(context, "Please fill all fields and add images");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      /// Prevents the UI from resizing when the keyboard is open
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text(
          'New Introduction',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(
                bottom: 100), // 👈 Ensure space for bottom navigation
            children: [
              const SizedBox(height: 16),

              // const Text(
              //   'Add 4 images:',
              //   style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              // ),
              // const SizedBox(height: 8),

              /// **Image Display with Remove Option**
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _imageFiles
                    .map((file) => Stack(
                          children: [
                            Image.file(file, width: 100, height: 100),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: GestureDetector(
                                onTap: () => _removeImage(file),
                                child: const Icon(Icons.remove_circle,
                                    color: Colors.red),
                              ),
                            ),
                          ],
                        ))
                    .toList(),
              ),

              const SizedBox(height: 10),

              Center(
                child: ElevatedButton.icon(
                  onPressed: _takePhoto,
                  icon: const Icon(Icons.camera_alt, size: 24),
                  label: const Text('Take Product 4 Photos'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        vertical: 12, horizontal: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              /// **Dropdown for Category Selection**

              DropdownButtonFormField<String>(
                value:
                    selectedCategoryCode, // This stores the selected category code
                decoration: _inputDecoration("Select Category"),
                items: categories
                    .map((cat) => DropdownMenuItem<String>(
                          value: cat['category_code']
                              .toString(), // Store category_code
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 0),
                            child: Text(
                              '${cat['category_name']}',
                              style: const TextStyle(fontSize: 15),
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategoryCode = value; // Save selected category code
                    selectedCategoryName = categories.firstWhere(
                      (cat) => cat['category_code'].toString() == value,
                    )['category_name']; // Find and save category name
                  });
                },
                validator: (value) =>
                    value == null ? "Select a category" : null,
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(10),
              ),

              const SizedBox(height: 12),

              /// **Input Fields**
              _buildTextField("Company", companyController),
              _buildTextField("Country", countryController),
              _buildTextField("Brand", brandController),
              _buildTextField("Item Description", itemDescriptionController),
              _buildTextField("Pack Type", packTypeController),
              _buildTextField("Pack Size", packSizeController),
              _buildTextField("Promotype", promotypeController),
              _buildTextField("MRP", mrpController, isNumeric: true),

              const SizedBox(height: 16),

              /// **Submit Button**
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF314CA3),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(50.0),
                  ),
                ),
                child: const Text("Submit", style: TextStyle(fontSize: 15)),
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),

      /// **Bottom Navigation (SafeArea)**
      bottomSheet: SafeArea(
        child: Container(
          height: 60,
          decoration: const BoxDecoration(
            color: AppColors.bottomNavBarColor,
            border: Border(
              top: BorderSide(
                color: AppColors.bottomNavBorderColor,
              ),
            ),
          ),
          child: Row(
            children: [
              /// **New Entry Button**
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FmcgSdNewEntry(
                          dbPath: widget.dbPath,
                          storeCode: widget.storeCode,
                          auditorId: widget.auditorId,
                          option: widget.option,
                          shortCode: widget.shortCode,
                          storeName: widget.storeName,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Text(
                      'New Entry',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),

              Container(width: 1, height: 40, color: Colors.grey.shade200),

              /// **Next Button**
              Expanded(
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FmcgSdSkuList(
                          dbPath: widget.dbPath,
                          storeCode: widget.storeCode,
                          auditorId: widget.auditorId,
                          option: widget.option,
                          shortCode: widget.shortCode,
                          storeName: widget.storeName,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Text(
                      'SKU Audit',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Input Field Builder
  Widget _buildTextField(String label, TextEditingController controller,
      {bool isNumeric = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(label),
        validator: (value) => value!.isEmpty ? "$label is required" : null,
      ),
    );
  }

  // Input Decoration
  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white70,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        //borderSide: BorderSide.merge(a, b),
      ),
    );
  }
}
