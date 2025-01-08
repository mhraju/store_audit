import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/fmcg_sd.dart';
import 'package:store_audit/presentation/screens/store_list.dart';
import 'package:store_audit/utility/assets_path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

// Function to copy the database from assets to a writable directory
Future<String> copyDatabase() async {
  try {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final dbPath = '${documentsDirectory.path}/store.sqlite';

    if (!File(dbPath).existsSync()) {
      final data = await rootBundle.load('assets/store.sqlite');
      final bytes =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

      await File(dbPath).writeAsBytes(bytes);
    }

    return dbPath;
  } catch (e) {
    throw Exception('Failed to copy database: $e');
  }
}

// Function to fetch data from the database
Future<List<Map<String, dynamic>>> fetchStores() async {
  try {
    final dbPath = await copyDatabase();
    final db = await openDatabase(dbPath);
    final stores = await db.query('stores');
    await db.close();
    return stores;
  } catch (e) {
    throw Exception('Failed to fetch stores: $e');
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Map<String, dynamic>>>? _storeData;
  String _auditorId = '';

  @override
  void initState() {
    super.initState();
    _loadAuditorId();
    _storeData = fetchStores();
  }

  Future<void> _loadAuditorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _auditorId = prefs.getString('auditorId') ?? 'No ID Found';
    });
  }

  Future<bool> _onWillPop() async {
    final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Exit App'),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  SystemNavigator.pop();
                },
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    return shouldClose;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: const Text(
            'Index',
            style: TextStyle(color: Colors.black),
          ),
          centerTitle: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.black),
              onPressed: () {
                // Add sync functionality if needed
              },
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 96),
              // Logo
              // App Title
              Image.asset(
                AssetsPath.appLogoSvg,
                width: 275,
                fit: BoxFit.fitWidth,
              ),
              const SizedBox(height: 10),

              // Subtitle
              const Text(
                'Data Collection Application',
                textAlign: TextAlign.center,
                style: TextStyle(
                  //color: Color(0xFF1E232C),
                  color: Colors.amber,
                  fontFamily: 'Lato',
                  fontSize: 19.5,
                  letterSpacing: 0.6,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildOptionCard(
                    icon: Icons.local_grocery_store,
                    label: 'FMCG SD',
                    onTap: () async {
                      if (_storeData != null) {
                        final storeData = await _storeData!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                FMCGSDStores(storeList: storeData),
                          ),
                        );
                      } else {
                        // Handle null case if needed
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                              content:
                                  Text('Store data is not available yet.')),
                        );
                      }
                    },
                  ),
                  const SizedBox(width: 20),
                  _buildOptionCard(
                    icon: Icons.smoking_rooms,
                    label: 'Tobacco',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => StoreListScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        height: 120,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              spreadRadius: 2,
              blurRadius: 10,
              offset: const Offset(2, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: Colors.blue),
            const SizedBox(height: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                color: Colors.blue[900],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
