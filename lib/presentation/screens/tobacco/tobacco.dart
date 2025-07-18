import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/tobacco/tobacco_store_list.dart';
import 'package:store_audit/utility/show_alert.dart';

import '../../../db/database_manager.dart';
import '../../../service/connectivity.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/assets_path.dart';

class TobaccoAuditScreen extends StatefulWidget {
  final String dbPath;
  final String auditorId;
  const TobaccoAuditScreen({super.key, required this.dbPath, required this.auditorId});

  @override
  State<TobaccoAuditScreen> createState() => _TobaccoAuditScreenState();
}

class _TobaccoAuditScreenState extends State<TobaccoAuditScreen> {
  final ConnectionCheck checkConnection = ConnectionCheck();
  bool _isLoading = false;
  String? _dbPath;
  final DatabaseManager dbManager = DatabaseManager();
  List<Map<String, dynamic>>? tobaccoStoreList1;
  List<Map<String, dynamic>>? tobaccoStoreList2;
  List<Map<String, dynamic>>? tobaccoStoreList3;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true; // Show loading indicator
    });
    tobaccoStoreList1 = await dbManager.loadTobaccoStores(widget.dbPath, widget.auditorId, 1);
    print(tobaccoStoreList1);
    tobaccoStoreList2 = await dbManager.loadTobaccoStores(widget.dbPath, widget.auditorId, 2);
    print(tobaccoStoreList2);
    tobaccoStoreList3 = await dbManager.loadTobaccoStores(widget.dbPath, widget.auditorId, 3);
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
    switch (title) {
      case 'First Visit':
        if (tobaccoStoreList1!.length > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TobaccoStoreList(dbPath: widget.dbPath, auditorId: widget.auditorId, priority: 1),
            ),
          );
        } else {
          ShowAlert.showSnackBar(context, 'No store is assigned yet');
        }
        break;
      case 'Second Visit':
        if (tobaccoStoreList2!.length > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TobaccoStoreList(dbPath: widget.dbPath, auditorId: widget.auditorId, priority: 2),
            ),
          );
        } else {
          ShowAlert.showSnackBar(context, 'No store is assigned yet');
        }
        break;
      case 'Store Audit':
        if (tobaccoStoreList3!.length > 0) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TobaccoStoreList(dbPath: widget.dbPath, auditorId: widget.auditorId, priority: 3),
            ),
          );
        } else {
          ShowAlert.showSnackBar(context, 'No store is assigned yet');
        }
        break;
      default:
        // Default case to handle unexpected titles
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TobaccoStoreList(dbPath: widget.dbPath, auditorId: widget.auditorId, priority: 1),
          ),
        );
        break;
    }
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
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
                    width: 250,
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
                  _buildOptionCard('First Visit', tobaccoStoreList1?.length ?? 0, Colors.blue.shade900),
                  const SizedBox(height: 16),
                  _buildOptionCard('Second Visit', tobaccoStoreList2?.length ?? 0, Colors.blue.shade900),
                  const SizedBox(height: 16),
                  _buildOptionCard('Store Audit', tobaccoStoreList3?.length ?? 0, Colors.blue.shade900),
                ],
              ),
      ),
    );
  }

  @override
  void dispose() {
    // If you have any controllers or listeners to clean up, do it here.
    // Example: someController.dispose();

    super.dispose();
  }
}
