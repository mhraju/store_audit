import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../db/database_manager.dart';
import '../../utility/app_colors.dart';

class FmcgSdNewIntro extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  const FmcgSdNewIntro({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
  });

  @override
  _FmcgSdNewIntroState createState() => _FmcgSdNewIntroState();
}

class _FmcgSdNewIntroState extends State<FmcgSdNewIntro> {
  final _formKey = GlobalKey<FormState>();
  bool isLoading = true;
  final DatabaseManager dbManager = DatabaseManager();
  String? selectedCategory;
  List<String> categories = [];

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

  List<File> selectedImages = [];

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile>? images = await picker.pickMultiImage();

    if (images != null && images.length <= 4) {
      setState(() {
        selectedImages = images.map((image) => File(image.path)).toList();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("You can only select up to 4 images.")),
      );
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate() && selectedCategory != null) {
      print("Form Submitted with:");
      print("Category: $selectedCategory");
      print("Company: ${companyController.text}");
      print("Country: ${countryController.text}");
      print("Brand: ${brandController.text}");
      print("Item Description: ${itemDescriptionController.text}");
      print("Pack Type: ${packTypeController.text}");
      print("Pack Size: ${packSizeController.text}");
      print("Promotype: ${promotypeController.text}");
      print("MRP: ${mrpController.text}");
      print("Images Selected: ${selectedImages.length}");

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Form submitted successfully!")),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Please fill all fields and add images")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
            children: [
              const SizedBox(height: 16),
              // Dropdown for Category Selection
              DropdownButtonFormField<String>(
                value: selectedCategory,
                decoration: _inputDecoration("Select Category"),
                items: categories
                    .map((cat) => DropdownMenuItem(
                          value: cat,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                vertical: 0,
                                horizontal:
                                    0), // Padding inside dropdown options
                            child: Text(
                              cat,
                              style:
                                  TextStyle(fontSize: 15), // Adjust text size
                            ),
                          ),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategory = value;
                  });
                },
                validator: (value) =>
                    value == null ? "Select a category" : null,
                dropdownColor:
                    Colors.white, // Optional: Change dropdown background color
                borderRadius:
                    BorderRadius.circular(10), // Round dropdown corners
              ),

              SizedBox(height: 12),

              // Input Fields
              _buildTextField("Company", companyController),
              _buildTextField("Country", countryController),
              _buildTextField("Brand", brandController),
              _buildTextField("Item Description", itemDescriptionController),
              _buildTextField("Pack Type", packTypeController),
              _buildTextField("Pack Size", packSizeController),
              _buildTextField("Promotype", promotypeController),
              _buildTextField("MRP", mrpController, isNumeric: true),

              SizedBox(height: 16),

              // Image Picker
              GestureDetector(
                onTap: _pickImages,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: selectedImages.isEmpty
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.image, size: 40, color: Colors.black54),
                            Text("Add up to 4 images of the product"),
                          ],
                        )
                      : Wrap(
                          spacing: 10,
                          children: selectedImages
                              .map((image) => ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.file(image,
                                        width: 70,
                                        height: 70,
                                        fit: BoxFit.cover),
                                  ))
                              .toList(),
                        ),
                ),
              ),

              SizedBox(height: 16),

              // Submit Button
              ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text("Submit", style: TextStyle(fontSize: 16)),
              ),

              SizedBox(height: 24),
            ],
          ),
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: Colors.grey.shade200,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.black54,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: "SKU Audit"),
          BottomNavigationBarItem(icon: Icon(Icons.add), label: "New Entry"),
        ],
        onTap: (index) {
          if (index == 0) {
            print("Navigating to SKU Audit");
            // Add navigation to SKU Audit page
          } else if (index == 1) {
            print("New Entry Clicked");
            // Add navigation to New Entry page
          }
        },
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
