import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../service/connectivity.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/assets_path.dart';

class TobaccoAuditScreen extends StatefulWidget {
  const TobaccoAuditScreen({super.key});

  @override
  State<TobaccoAuditScreen> createState() => _TobaccoAuditScreenState();
}

class _TobaccoAuditScreenState extends State<TobaccoAuditScreen> {
  final ConnectionCheck checkConnection = ConnectionCheck();
  bool _isLoading = false;
  String? _dbPath;
  Future<List<Map<String, dynamic>>>? _storeList;

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

    // if (dbPath != null && dbPath.isNotEmpty) {
    //   _dbPath = dbPath;
    //   _storeList = loadDB();
    // } else {
    //   _dbPath = null;
    //   _storeList = fetchStoresFromServer();
    // }

    setState(() {
      _isLoading = false; // Hide loading indicator
    });
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Function to navigate to different pages based on the card title
  void _navigateToNextPage(String title) {
    // switch (title) {
    //   case 'First Visit':
    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(builder: (context) => FirstVisitPage()),
    //     );
    //     break;
    //   case 'Second Visit':
    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(builder: (context) => SecondVisitPage()),
    //     );
    //     break;
    //   case 'Store Audit':
    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(builder: (context) => StoreAuditPage()),
    //     );
    //     break;
    //   default:
    //     // Default case to handle unexpected titles
    //     Navigator.push(
    //       context,
    //       MaterialPageRoute(builder: (context) => DefaultPage()),
    //     );
    //     break;
    // }
  }

  // Widget to build option cards with onTap functionality
  Widget _buildOptionCard(String title, int count, Color color) {
    return InkWell(
      onTap: () => _navigateToNextPage(title), // Navigate to the corresponding page
      splashColor: Colors.blue.withOpacity(0.3), // Splash effect color
      borderRadius: BorderRadius.circular(10), // Rounded corners for the splash effect
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              CircleAvatar(
                backgroundColor: color.withOpacity(0.2),
                child: Text(
                  '$count',
                  style: TextStyle(
                    color: color,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor, // Use your custom color
        elevation: 0,
        title: const Text('Tobacco Audit'),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.sync, color: Colors.black),
        //     onPressed: _syncDatabase,
        //   ),
        // ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  const SizedBox(height: 56),
                  Image.asset(
                    AssetsPath.appLogoSvg, // Replace with your actual asset
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
                  const SizedBox(height: 36),
                  _buildOptionCard('First Visit', 20, Colors.blue.shade900),
                  const SizedBox(height: 16),
                  _buildOptionCard('Second Visit', 40, Colors.blue.shade900),
                  const SizedBox(height: 16),
                  _buildOptionCard('Store Audit', 40, Colors.grey),
                ],
              ),
      ),
    );
  }
}
