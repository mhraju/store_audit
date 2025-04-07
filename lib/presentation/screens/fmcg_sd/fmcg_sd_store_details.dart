import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // Import the image package
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/db/database_manager.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_sku_list.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_store_audit.dart';

import '../../../utility/app_colors.dart';
import '../../../utility/show_alert.dart';

class FmcgSdStoreDetails extends StatefulWidget {
  final List<Map<String, dynamic>> storeList;
  final Map<String, dynamic> storeData;
  final String dbPath;
  final String auditorId;
  final String option;
  final String shortCode;
  const FmcgSdStoreDetails(
      {super.key,
      required this.storeList,
      required this.storeData,
      required this.dbPath,
      required this.auditorId,
      required this.option,
      required this.shortCode});

  @override
  State<FmcgSdStoreDetails> createState() => _FmcgSdStoreDetailsState();
}

class _FmcgSdStoreDetailsState extends State<FmcgSdStoreDetails> {
  bool isLocationWorking = false;
  bool otpVerified = false;
  File? _capturedImage; // Variable to store the captured or picked image
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  late String _geoCode; // Variable to track the store name
  bool isGeolocationEnabled = false;
  String locationStatus = "Waiting for location permission...";
  bool isInsideGeofence = false;
  bool isLoading = false;
  late String _option;
  String store_photo = "";

  late String _storeName;
  late String _contact;
  late String _detailAddress;
  late String _landmark;
  late TextEditingController nameController;
  late TextEditingController contactController;
  late TextEditingController detailAddressController;
  late TextEditingController landmarkController;

  //List<Map<String, dynamic>> _storedata = [];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _storeName = widget.storeData['name'] ?? '';
    _contact = widget.storeData['phone1'] ?? '';
    _detailAddress = widget.storeData['address'] ?? '';
    _landmark = widget.storeData['land_mark'] ?? '';
    store_photo = widget.storeData['store_photo'] ?? '';
    _option = widget.option;

    // Initialize the controllers
    nameController = TextEditingController(text: _storeName);
    contactController = TextEditingController(text: _contact);
    detailAddressController = TextEditingController(text: _detailAddress);
    landmarkController = TextEditingController(text: _landmark);
  }

  @override
  void dispose() {
    // Dispose of any TextEditingController instances to release resources
    nameController.dispose();
    contactController.dispose();
    detailAddressController.dispose();
    landmarkController.dispose();
    // Dispose of any listeners or subscriptions, if necessary
    super.dispose();
  }

  Future<void> _checkLocationPermission() async {
    setState(() {
      isLoading = true;
      isInsideGeofence = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.denied) {
          _showSnackBar("Location permission denied.");
          setState(() {
            isLoading = false;
          });
          return;
        }

        if (permission == LocationPermission.deniedForever) {
          _showSnackBar("Permission permanently denied.");
          setState(() {
            isLoading = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          locationStatus = "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
        });

        _checkIfInsideGeofence(position.latitude, position.longitude);
      } else {
        _showSnackBar("Location permission not granted.");
        setState(() {
          isInsideGeofence = false;
        });
      }
    } catch (e) {
      _showSnackBar("Error fetching location: $e");
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _checkIfInsideGeofence(double userLatitude, double userLongitude) {
    _geoCode = widget.storeData['geo'];

    // Split the string by the comma to extract latitude and longitude
    List<String> coordinates = _geoCode.split(',');

    // Parse the latitude and longitude as doubles
    double geofenceLatitude = double.parse(coordinates[0]);
    double geofenceLongitude = double.parse(coordinates[1]);
    const double geofenceRadius = 100; // 100 meters radius

    print('Latitude: $geofenceLatitude ....    $userLatitude');
    print('Longitude: $geofenceLongitude ..... $userLongitude');

    double distance = Geolocator.distanceBetween(
      userLatitude,
      userLongitude,
      geofenceLatitude,
      geofenceLongitude,
    );

    setState(() {
      isInsideGeofence = distance <= geofenceRadius;
    });

    if (!isInsideGeofence) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You are outside the geofence area. Please move inside the geofence to proceed.")),
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
          'Store Details',
          style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _checkLocationPermission,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Image placeholder or captured image

                    Center(
                      child: isLoading
                          ? const SizedBox(
                              height: 130,
                              width: 300,
                              child: Center(child: CircularProgressIndicator()),
                            )
                          : _capturedImage != null
                              ? Image.file(
                                  _capturedImage!,
                                  height: 130,
                                  width: 300,
                                  fit: BoxFit.cover,
                                )
                              : (store_photo.isNotEmpty && File(store_photo).existsSync())
                                  ? Image.file(
                                      File(
                                          '/data/user/0/com.luminaries_research.store_audit/app_flutter/$store_photo'), // ✅ Load image from file path
                                      height: 130,
                                      width: 300,
                                      fit: BoxFit.cover,
                                    )
                                  : const Icon(Icons.image, size: 100, color: Colors.grey), // Default icon
                    ),

                    const SizedBox(height: 16),

                    // Store details
                    Center(
                      child: Text(
                        '$_storeName',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Store Code: ${widget.storeData['code'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Contact Number: $_contact',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Division: ${widget.storeData['division'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'District: ${widget.storeData['district'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Thana: ${widget.storeData['thana'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Area: ${widget.storeData['area_village_name'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Union: ${widget.storeData['union_ward'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Address: $_detailAddress',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Landmark: ${widget.storeData['land_mark'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Shop type: ${widget.storeData['shop_type'] ?? 'N/A'}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 16),

                    // Show loading or location status
                    if (isLoading) const Center(child: CircularProgressIndicator()),

                    // Show OTP verification link if outside geofence
                    if (!isInsideGeofence && !isLoading && !otpVerified)
                      GestureDetector(
                        onTap: _showOtpDialog,
                        child: const Center(
                          child: Text(
                            'GeoLocation not working, you can verify via OTP',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Bottom navigation buttons
          if (otpVerified || (isInsideGeofence && !isLoading))
            Container(
              height: 80,
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewPadding.bottom > 0
                    ? MediaQuery.of(context).viewPadding.bottom
                    : 16, // Ensure enough space if no padding exists
              ),
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
                  Expanded(
                    child: InkWell(
                      onTap: _showEditBottomSheet,
                      child: const Center(
                        child: Text(
                          'Edit',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade200,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // Navigator.push(
                        //   context,
                        //   MaterialPageRoute(
                        //     builder: (context) => const StoreClose(),
                        //   ),
                        // );
                        if (_option == 'Temporary Closed (TC)' || _option == 'Permanent Closed (PC)') {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FmcgSdStoreAudit(
                                dbPath: widget.dbPath,
                                storeCode: widget.storeData['code'],
                                auditorId: widget.auditorId,
                                option: widget.option,
                                shortCode: widget.shortCode,
                                storeName: _storeName,
                              ),
                            ),
                          );
                          //Get.to(() => StoreClose(item: item));
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => FmcgSdSkuList(
                                dbPath: widget.dbPath,
                                storeCode: widget.storeData['code'],
                                auditorId: widget.auditorId,
                                option: _option,
                                shortCode: widget.shortCode,
                                storeName: _storeName,
                              ),
                            ),
                          );
                        }
                      },
                      child: const Center(
                        child: Text(
                          'Next',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // OTP Verification Dialog
  void _showOtpDialog() {
    TextEditingController otpController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('OTP Verify'),
          content: TextField(
            controller: otpController,
            decoration: const InputDecoration(hintText: 'Enter OTP'),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                String enteredOtp = otpController.text.trim();
                String? storedOtp = widget.storeData['geo_otp']?.toString(); // ✅ Ensure it's a string

                if (enteredOtp.isEmpty) {
                  ShowAlert.showSnackBar(context, 'Please enter an OTP.');
                  return;
                }

                if (enteredOtp == storedOtp) {
                  setState(() {
                    otpVerified = true;
                  });
                  ShowAlert.showSnackBar(context, 'OTP verified successfully!');
                  Navigator.pop(context); //
                } else {
                  ShowAlert.showSnackBar(context, 'Invalid OTP. Please try again.');
                }
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
  }

  // Bottom sheet for editing details and capturing an image
  void _showEditBottomSheet() {
    TextEditingController nameController = TextEditingController(text: _storeName);
    TextEditingController contactController = TextEditingController(text: _contact);
    TextEditingController detailAddressController = TextEditingController(text: _detailAddress);
    TextEditingController landmarkController = TextEditingController(text: _landmark); // Initialize with the current store name
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Editable fields
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Store Name'),
                  ),
                  TextField(
                    controller: contactController,
                    decoration: const InputDecoration(labelText: 'Contact'),
                    keyboardType: TextInputType.phone,
                  ),
                  TextField(
                    controller: detailAddressController,
                    decoration: const InputDecoration(labelText: 'Detail Address'),
                  ),
                  TextField(
                    controller: landmarkController,
                    decoration: const InputDecoration(labelText: 'Landmark'),
                  ),
                  const SizedBox(height: 24),

                  // Image capture
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: _captureImage, // Call the image capture function
                      icon: const Icon(Icons.camera_alt, size: 24), // Camera icon
                      label: const Text('Take Store Photo'), // Button label
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue, // Button background color
                        foregroundColor: Colors.white, // Text and icon color
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align left & right
                    children: [
                      // Update and Close buttons
                      ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context); // Close the bottom sheet
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Set the background color to blue
                          foregroundColor: Colors.white, // Set the text color to white
                        ),
                        child: const Text('Close'),
                      ),
                      ElevatedButton(
                        onPressed: () async {
                          final newName = nameController.text.trim();
                          final newContact = contactController.text.trim();
                          final newDetailAddress = detailAddressController.text.trim();
                          final newLandmark = landmarkController.text.trim();

                          if (newName.isNotEmpty || newContact.isNotEmpty || newDetailAddress.isNotEmpty || newLandmark.isNotEmpty) {
                            setState(() {
                              _storeName = newName;
                              _contact = newContact;
                              _detailAddress = newDetailAddress;
                              _landmark = newLandmark;
                            });

                            // Update the store data in the database
                            final dbManager = DatabaseManager();
                            await dbManager.updateFmcgSdStoreDetails(
                                widget.dbPath,
                                widget.storeData['code'],
                                widget.auditorId, // Store ID
                                newName,
                                newContact,
                                newDetailAddress,
                                newLandmark,
                                store_photo);

                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Store details updated successfully')),
                            );
                          }

                          Navigator.pop(context); // Close the bottom sheet
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue, // Set the background color to blue
                          foregroundColor: Colors.white, // Set the text color to white
                        ),
                        child: const Text('Update'),
                      ),
                    ],
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Function to capture an image using the device camera
  Future<void> _captureImage() async {
    try {
      final photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo == null) {
        print('No image captured.');
        return;
      }
      setState(() {
        isLoading = true; // Start loading
      });

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String customPath = appDir.path;
      final Directory customDir = Directory(customPath);

      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }

      final img.Image? originalImage = img.decodeImage(await File(photo.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage = img.copyResize(originalImage, width: 500, height: 500);
        final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        final String newFileName = 'store_${widget.storeData['store_code']}_$timestamp.jpg';

        final String newPath = '$customPath/$newFileName';
        final File resizedFile = File('${photo.path}_resized.jpg')..writeAsBytesSync(img.encodeJpg(resizedImage));
        final File newImage = await resizedFile.copy(newPath);

        final prefs = await SharedPreferences.getInstance();
        List<String> savedStoreImgPaths = prefs.getStringList('storeImagePaths') ?? [];
        List<String> savedPaths = prefs.getStringList('imagePaths') ?? [];
        // Check if 'store_photo' exists in the list & remove it
        if (store_photo.trim().isNotEmpty) {
          // Debugging: Print current paths
          print("Existing savedPaths: $savedStoreImgPaths");
          print("Existing savedPaths: $savedPaths");
          print("store_photo to check: $store_photo");

          // Normalize paths before checking
          String normalizedStorePhoto = store_photo.trim();
          savedStoreImgPaths.removeWhere((path) => path.trim() == normalizedStorePhoto);
          savedPaths.removeWhere((path) => path.trim() == normalizedStorePhoto);

          print("Updated savedPaths after removal: $savedStoreImgPaths");
        }
        // Add the new path
        savedStoreImgPaths.add(newFileName);
        savedPaths.add(newFileName);
        // Save updated list to SharedPreferences
        await prefs.setStringList('storeImagePaths', savedStoreImgPaths);
        await prefs.setStringList('imagePaths', savedPaths);
        print("Updated Image Paths:  $savedPaths"); // Debugging

        store_photo = newPath;

        setState(() {
          _capturedImage = newImage; // Update with the captured image
        });
        print('Image saved at: $newPath');
      } else {
        print('Failed to decode the image.');
      }
    } catch (e) {
      print('Error capturing image: $e');
    } finally {
      setState(() {
        isLoading = false; // Stop loading
      });
    }
  }

  // Function to pick an image from the gallery
  Future<void> _pickImage() async {
    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _capturedImage = File(pickedFile.path); // Update with picked image
      });
    }
  }
}
