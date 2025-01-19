import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/db/database_manager.dart';
import 'package:store_audit/presentation/screens/fmcg_sd.dart';
import 'package:store_audit/presentation/screens/fmcg_sd_store_details.dart';
import 'package:store_audit/presentation/screens/home_screen_two.dart';
import 'package:store_audit/presentation/screens/store_close.dart';
import 'package:store_audit/service/file_upload_download.dart';
import 'package:store_audit/utility/assets_path.dart';

import '../../service/connectivity.dart';
import '../../utility/app_colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ConnectionCheck checkConnection = ConnectionCheck();
  final DatabaseManager dbManager = DatabaseManager();
  final FileUploadDownload fileUploadDownload = FileUploadDownload();
  Future<List<Map<String, dynamic>>>? _storeList;
  String _auditorId = '';
  String? _dbPath;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadDbpath();
  }

  Future<void> _loadDbpath() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });

    final prefs = await SharedPreferences.getInstance();
    final dbPath = prefs.getString('dbPath');

    String? pDbPath = prefs.getString('databasePath');

    //print('newPath: $dbPath ....   oldPath: $pDbPath');

    if (dbPath != null && dbPath.isNotEmpty) {
      _dbPath = dbPath;
      _storeList = loadDB();
    } else {
      _dbPath = null;
      _storeList = fetchStoresFromServer();
    }

    setState(() {
      _isLoading = false; // Hide loading indicator
    });
  }

  Future<List<Map<String, dynamic>>> fetchStoresFromServer() async {
    try {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      final dbPath = await dbManager.downloadAndSaveUserDatabase();
      _dbPath = dbPath;
      final db = await dbManager.loadDatabase(dbPath);
      final stores = await db.query('stores');
      await db.close();
      _saveDbPath(dbPath);
      _showSnackBar("Store updated");

      return stores;
    } catch (e) {
      print('Failed to fetch stores: $e');
      return [];
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  Future<List<Map<String, dynamic>>> loadDB() async {
    try {
      setState(() {
        _isLoading = true; // Show loading indicator
      });

      final db = await dbManager.loadDatabase(_dbPath!);
      final stores = await db.query('stores');
      await db.close();
      _showSnackBar("Store loaded");

      return stores;
    } catch (e) {
      print('Failed to load stores: $e');
      return [];
    } finally {
      setState(() {
        _isLoading = false; // Hide loading indicator
      });
    }
  }

  Future<void> _saveDbPath(String dbPath) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('dbPath', dbPath);
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
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Exit'),
              ),
            ],
          ),
        ) ??
        false;

    return shouldClose;
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _syncDatabase() async {
    try {
      // await fetchStoresFromServer();
      await checkConnection.checkConnection(context);
      // await fileUploadDownload.uploadFile(context);
      // await fileUploadDownload.uploadImages(context);
      // _showSnackBar('Database synchronized successfully.');
    } catch (e) {
      _showSnackBar('Error syncing database: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.appBarColor,
          elevation: 0,
          title: SvgPicture.asset(
            AssetsPath.appBarLogoSvg, // Replace with your SVG file path
            width: 260,
            fit: BoxFit.fitWidth, // Adjust size as needed
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.black),
              onPressed: _syncDatabase,
            ),
          ],
        ),
        body: Stack(
          children: [
            // Main content
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _storeList,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                } else if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading stores: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final storeList = snapshot.data!;
                  if (storeList.isEmpty) {
                    return const Center(child: Text('No stores found.'));
                  }
                  return _buildHomeContent(storeList);
                } else {
                  return const Center(
                    child: Text('Store data is not available yet.'),
                  );
                }
              },
            ),

            // Full-screen loading overlay
            if (_isLoading)
              Container(
                color: Colors.black.withOpacity(0.5), // Dim background
                child: const Center(
                  child: CircularProgressIndicator(
                    color: Colors.white, // Visible spinner
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeContent(List<Map<String, dynamic>> storeList) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 126),
          Image.asset(
            AssetsPath.appLogoSvg,
            width: 275,
            fit: BoxFit.fitWidth,
          ),
          const SizedBox(height: 16),
          const Text(
            'Data Collection Application',
            textAlign: TextAlign.center,
            style: TextStyle(
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
                onTap: () {
                  if (_dbPath != null) {
                    Navigator.push(
                      context,
                      // MaterialPageRoute(
                      //   builder: (context) => FmcgSdStoreDetails(
                      //     storeData: storeList[1],
                      //     dbPath: _dbPath!,
                      //   ),
                      // ),
                      MaterialPageRoute(
                        builder: (context) =>
                            FMCGSDStores(storeList: storeList),
                      ),
                    );
                  } else {
                    _showSnackBar('Database path is not set.');
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
                      builder: (context) => StoreClose(),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
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

  Future<void> _loadAuditorId() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _auditorId = prefs.getString('auditorId') ?? 'No ID Found';
    });
  }
}
