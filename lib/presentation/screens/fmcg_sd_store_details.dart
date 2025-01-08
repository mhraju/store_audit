import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:image/image.dart' as img; // Import the image package
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:store_audit/presentation/screens/store_close.dart';

class FmcgSdStoreDetails extends StatefulWidget {
  final Map<String, dynamic> item;

  FmcgSdStoreDetails({super.key, required this.item});

  @override
  _FmcgSdStoreDetailsState createState() => _FmcgSdStoreDetailsState();
}

class _FmcgSdStoreDetailsState extends State<FmcgSdStoreDetails> {
  bool isLocationWorking = false;
  bool otpVerified = false;
  File? _capturedImage; // Variable to store the captured or picked image
  final ImagePicker _picker = ImagePicker(); // Image picker instance
  late String _storeName; // Variable to track the store name

  bool isGeolocationEnabled = false;
  String locationStatus = "Waiting for location permission...";
  bool isInsideGeofence = false;
  bool isLoading = false;

  final double geofenceLatitude = 233.781923; // Example coordinates
  final double geofenceLongitude = 900.415613;
  final double geofenceRadius = 100; // 100 meters radius

  List<Map<String, dynamic>> _storedata = [];

  @override
  void initState() {
    super.initState();
    _checkLocationPermission();
    _storeName =
        widget.item['store_name']; // Initialize with the database value
  }

  Future<void> _checkLocationPermission() async {
    setState(() {
      isLoading = true;
      isInsideGeofence = false;
    });

    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
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

      if (permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse) {
        Position position = await Geolocator.getCurrentPosition();
        setState(() {
          locationStatus =
              "Latitude: ${position.latitude}, Longitude: ${position.longitude}";
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
        const SnackBar(
            content: Text(
                "You are outside the geofence area. Please move inside the geofence to proceed.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_storeName),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            onPressed: _checkLocationPermission,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder or captured image
            Center(
              child: Column(
                children: [
                  _capturedImage != null
                      ? Image.file(
                          _capturedImage!,
                          height: 130,
                          width: 300,
                          fit: BoxFit.cover,
                        )
                      : const Icon(Icons.image, size: 100, color: Colors.grey),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: _showEditBottomSheet,
                    child: Text(
                      _capturedImage == null ? 'Add Image' : 'Change Image',
                      style: const TextStyle(color: Colors.blue),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Store details
            Text(
              'Store Name: $_storeName',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text(
              'Store ID: ${widget.item['store_id'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Date: ${widget.item['date'] ?? 'N/A'}',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 10),
            Text(
              'Status: ${widget.item['status'] ?? 'N/A'}',
              style: TextStyle(
                fontSize: 16,
                color: widget.item['status']?.startsWith('Completed') == true
                    ? Colors.green
                    : widget.item['status']?.startsWith('Pending') == true
                        ? Colors.orange
                        : Colors.red,
              ),
            ),
            const SizedBox(height: 16),

            // Show loading or location status
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Text(
                locationStatus,
                style: const TextStyle(fontSize: 14),
              ),

            // Show OTP verification link if outside geofence
            if (!isInsideGeofence && !isLoading)
              GestureDetector(
                onTap: _showOtpDialog,
                child: const Text(
                  'GeoLocation not working, you can verify via OTP',
                  style: TextStyle(
                    color: Colors.red,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),

            const Spacer(),

            // Bottom navigation buttons
            if (otpVerified || (isInsideGeofence && !isLoading))
              Container(
                color: const Color(0xFFF5F7FA),
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _showEditBottomSheet,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Edit',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 24,
                      color: Colors.grey[400],
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          // ScaffoldMessenger.of(context).showSnackBar(
                          //   const SnackBar(
                          //       content: Text('Next action triggered!')),
                          // );

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  StoreClose(item: widget.item),
                            ),
                          );
                        },
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Next',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
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
                Navigator.pop(context); // Close the dialog
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  otpVerified = true; // Mark OTP as verified
                });
                Navigator.pop(context); // Close the dialog
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
    TextEditingController nameController = TextEditingController(
        text: _storeName); // Initialize with the current store name
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
                  const TextField(
                    decoration: InputDecoration(labelText: 'Contact'),
                    keyboardType: TextInputType.phone,
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Detail Address'),
                  ),
                  const TextField(
                    decoration: InputDecoration(labelText: 'Landmark'),
                  ),
                  const SizedBox(height: 16),

                  // Image picker and capture
                  Center(
                    child: GestureDetector(
                      onTap: _captureImage, // Open image picker
                      child: const Column(
                        children: [
                          Icon(
                            Icons.image,
                            size: 100,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please add a store image with signboard',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Update and Close buttons
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        if (nameController.text.isNotEmpty) {
                          _storeName =
                              nameController.text; // Update the store name
                        }
                      });
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Update'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context); // Close the bottom sheet
                    },
                    child: const Text('Close'),
                  ),
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
    final pickedFile = await _picker.pickImage(source: ImageSource.camera);
    if (pickedFile != null) {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String customPath = '${appDir.path}/CustomPhotos/Store';
      final Directory customDir = Directory(customPath);
      if (!customDir.existsSync()) {
        customDir.createSync(recursive: true);
      }

      // Resize the image to 600x600 before saving
      final img.Image? originalImage =
          img.decodeImage(await File(pickedFile.path).readAsBytes());
      if (originalImage != null) {
        final img.Image resizedImage =
            img.copyResize(originalImage, width: 800, height: 800);
        final File resizedFile = File('${pickedFile.path}_resized.jpg')
          ..writeAsBytesSync(img.encodeJpg(resizedImage));
        final String newPath =
            '$customPath/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final File newImage = await resizedFile.copy(newPath);

        setState(() {
          _capturedImage = newImage; // Update the captured image
        });
      }
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
