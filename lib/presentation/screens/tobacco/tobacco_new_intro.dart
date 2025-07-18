import 'dart:io';
import 'dart:math';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'package:store_audit/presentation/screens/tobacco/tobacco_new_entry.dart';
import 'package:store_audit/presentation/screens/tobacco/tobacco_sku_list.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/show_alert.dart';
import '../../../utility/show_progress.dart';
import 'package:dropdown_search/dropdown_search.dart';

class TobaccoNewIntro extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  final String storeName;
  final String period;
  final int priority;
  const TobaccoNewIntro({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName,
    required this.period,
    required this.priority,
  });

  @override
  State<TobaccoNewIntro> createState() => _TobaccoNewIntroState();
}

class _TobaccoNewIntroState extends State<TobaccoNewIntro> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  final DatabaseManager dbManager = DatabaseManager();
  String? selectedCompany;
  String? selectedPack;
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> companies = [];
  List<Map<String, dynamic>> packTypes = [];
  final ImagePicker _picker = ImagePicker();
  final List<File> _imageFiles = [];
  late List<String> savedImgPaths;
  String? selectedCategoryCode;
  String? selectedCategoryName;

  TextEditingController otherCompanyController = TextEditingController();

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
    final fetchedData = await dbManager.loadTobaccoProductData(widget.dbPath);
    setState(() {
      categories = fetchedData['categories'] ?? [];
      companies = fetchedData['companies'] ?? [];
      packTypes = fetchedData['packTypes'] ?? [];
      isLoading = false;
    });
  }

  TextEditingController countryController = TextEditingController();
  TextEditingController brandController = TextEditingController();
  TextEditingController itemDescriptionController = TextEditingController();
  TextEditingController packSizeController = TextEditingController();
  TextEditingController promotypeController = TextEditingController();
  TextEditingController mrpController = TextEditingController();

  void _showOtherCompanyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enter Company Name"),
        content: TextField(
          controller: otherCompanyController,
          decoration: const InputDecoration(
            hintText: "Company Name",
            hintStyle: TextStyle(
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // close the dialog
            },
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                selectedCompany = otherCompanyController.text;
              });
              Navigator.of(context).pop(); // close the dialog
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
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
          final String newFileName = 'product_$timestamp.jpg';
          final String newPath = '$customPath/$newFileName';

          // Save resized image
          final File resizedFile = File('${pickedFile.path}_resized.jpg')..writeAsBytesSync(img.encodeJpg(resizedImage));
          final File newImage = await resizedFile.copy(newPath);

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
    //print("🗑️ Removed Image: ${_imageFiles.length} hhhhhhhh ${file.path}   ");
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
    if (_formKey.currentState!.validate() && _imageFiles.isNotEmpty) {
      if (selectedCategoryName == null) {
        ShowAlert.showSnackBar(context, "Please select any Category.");
        return;
      }
      if (selectedCompany == null) {
        ShowAlert.showSnackBar(context, "Please select any Company.");
        return;
      }
      if (selectedPack == null) {
        ShowAlert.showSnackBar(context, "Please select any Pack Type.");
        return;
      }

      if (_imageFiles.length == 4) {
        String productCode = generateSecureSixDigitProductCode();
        productCode = 'temp_${widget.auditorId}_$productCode';
        // Save image path in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        savedImgPaths = prefs.getStringList('imagePaths') ?? []; // Get existing saved images
        if (_imageFiles.isNotEmpty) {
          List<String> newPaths = _imageFiles.map((file) => p.basename(file.path)).toList();
          savedImgPaths = {...savedImgPaths, ...newPaths}.toList();
        }
        await prefs.setStringList('imagePaths', savedImgPaths); //
        //print("Final saved images: $savedImgPaths");

        //productCode = 'temp_intro_$productCode';

        await dbManager.insertToProductIntro(
          widget.dbPath,
          widget.auditorId,
          'TOBACCO',
          productCode,
          selectedCategoryName!,
          selectedCompany!,
          countryController.text.trim().toUpperCase(),
          brandController.text.trim().toUpperCase(),
          itemDescriptionController.text.trim().toUpperCase(),
          selectedPack!,
          packSizeController.text.trim().toUpperCase(),
          promotypeController.text.trim().toUpperCase(),
          mrpController.text,
          savedImgPaths[0],
          savedImgPaths[1],
          savedImgPaths[2],
          savedImgPaths[3],
        );

        await dbManager.insertToStoreProduct(
          context,
          widget.dbPath,
          widget.storeCode,
          widget.auditorId,
          productCode,
          1,
        );

        await dbManager.insertToProducts(
          widget.dbPath,
          widget.auditorId,
          'TOBACCO',
          productCode,
          selectedCategoryCode!,
          selectedCategoryName!,
          selectedCompany!,
          brandController.text.trim().toUpperCase(),
          countryController.text.trim().toUpperCase(),
          itemDescriptionController.text.trim().toUpperCase(),
          selectedPack!,
          packSizeController.text.trim().toUpperCase(),
          promotypeController.text.trim().toUpperCase(),
          mrpController.text,
        );

        ShowAlert.showSnackBar(context, 'Product intro submitted successfully!');

        setState(() {
          selectedCompany = null;
          countryController.clear();
          brandController.clear();
          itemDescriptionController.clear();
          selectedPack = null;
          packSizeController.clear();
          promotypeController.clear();
          mrpController.clear();
          selectedCategoryCode = null;
          selectedCategoryName = null;
          _imageFiles.clear();
          savedImgPaths.clear();
        });
      } else {
        ShowAlert.showSnackBar(context, "You can upload 4 images.");
      }
    } else {
      ShowAlert.showSnackBar(context, "Please add images");
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
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          child: Form(
            key: _formKey,
            child: Column(
              // ✅ Replaced ListView with Column
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),

                /// **Dropdown for Category Selection**
                DropdownButtonFormField<String>(
                  value: selectedCategoryCode,
                  decoration: _inputDecoration("Select Category"),
                  items: categories
                      .map((cat) => DropdownMenuItem<String>(
                            value: cat['category_code'].toString(),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              child: Text(
                                '${cat['category_name']}',
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedCategoryCode = value;
                      selectedCategoryName = categories.firstWhere(
                        (cat) => cat['category_code'].toString() == value,
                      )['category_name'];
                    });
                  },
                  validator: (value) => value == null ? "Select a category" : null,
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),

                const SizedBox(height: 12),

                DropdownSearch<String>(
                  selectedItem: selectedCompany,
                  asyncItems: (String filter) async {
                    return [
                      'Others',
                      ...companies.map((c) => c['company'] as String),
                    ];
                  },
                  popupProps: const PopupProps.menu(
                    showSearchBox: true,
                    searchFieldProps: TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'search by company name',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  dropdownDecoratorProps: DropDownDecoratorProps(
                    dropdownSearchDecoration: _inputDecoration("Select Company"),
                  ),
                  onChanged: (value) {
                    if (value == 'Others') {
                      _showOtherCompanyDialog(context);
                    } else {
                      setState(() {
                        selectedCompany = value;
                      });
                    }
                  },
                  validator: (value) => value == null || value.isEmpty ? "Select a company" : null,
                ),

                const SizedBox(height: 12),

                /// **Input Fields**
                _buildTextField("Country", countryController),
                _buildTextField("Brand", brandController),
                _buildTextField("Item Description", itemDescriptionController),

                const SizedBox(height: 12),

                DropdownButtonFormField<String>(
                  value: selectedPack,
                  decoration: _inputDecoration("Select Pack Type"),
                  items: packTypes
                      .map((pack) => DropdownMenuItem<String>(
                            value: pack['pack_type'] as String, // Ensure correct key 'pack_type'
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 0),
                              child: Text(
                                pack['pack_type'] as String, // Display correct text
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.normal),
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedPack = value; // Correctly update selectedPack
                    });
                  },
                  validator: (value) => value == null ? "Select a pack type" : null, // Fix validation message
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),

                const SizedBox(height: 12),

                _buildTextField("Pack Size", packSizeController),
                _buildTextField("Promotype", promotypeController, isRequired: false),
                _buildTextField("MRP", mrpController, isNumeric: true),

                const SizedBox(height: 8),

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
                                  child: const Icon(Icons.remove_circle, color: Colors.red),
                                ),
                              ),
                            ],
                          ))
                      .toList(),
                ),

                const SizedBox(height: 12),

                /// **Take Photo Button**
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _takePhoto,
                    icon: const Icon(Icons.camera_alt, size: 24),
                    label: const Text('Take Product 4 Photos'),
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

                const SizedBox(height: 24),

                /// **Submit Button**
                ElevatedButton(
                  onPressed: _submitForm,
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

                const SizedBox(height: 200), // ✅ Extra space to prevent bottom overflow
              ],
            ),
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
                        builder: (context) => TobaccoNewEntry(
                          dbPath: widget.dbPath,
                          storeCode: widget.storeCode,
                          auditorId: widget.auditorId,
                          option: widget.option,
                          shortCode: widget.shortCode,
                          storeName: widget.storeName,
                          period: widget.period,
                          priority: widget.priority,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Text(
                      'New Entry',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
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
                        builder: (context) => TobaccoSkuList(
                          dbPath: widget.dbPath,
                          storeCode: widget.storeCode,
                          auditorId: widget.auditorId,
                          option: widget.option,
                          shortCode: widget.shortCode,
                          storeName: widget.storeName,
                          period: widget.period,
                          priority: widget.priority,
                        ),
                      ),
                    );
                  },
                  child: const Center(
                    child: Text(
                      'SKU Audit',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
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

  // Input Field Builder (Updated to allow optional validation)
  Widget _buildTextField(String label, TextEditingController controller, {bool isNumeric = false, bool isRequired = true}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
        decoration: _inputDecoration(label),
        validator: isRequired ? (value) => value!.isEmpty ? "$label is required" : null : null, // No validation if isRequired is false
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

  @override
  void dispose() {
    countryController.dispose();
    brandController.dispose();
    itemDescriptionController.dispose();
    packSizeController.dispose();
    promotypeController.dispose();
    mrpController.dispose();
    otherCompanyController.dispose();
    super.dispose();
  }
}
