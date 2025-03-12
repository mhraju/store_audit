import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/db/database_manager.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_sku_list.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_store_list.dart';
import 'package:store_audit/service/file_upload_download.dart';
import 'package:store_audit/utility/assets_path.dart';
import 'package:store_audit/utility/show_alert.dart';

import '../../service/connectivity.dart';
import '../../utility/app_colors.dart';
import '../../utility/show_progress.dart';

class HomeScreen extends StatefulWidget {
  final List<Map<String, dynamic>> fmcgStoreList;
  final String dbPath;
  final String auditorId;
  const HomeScreen({super.key, required this.fmcgStoreList, required this.dbPath, required this.auditorId});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ConnectionCheck checkConnection = ConnectionCheck();
  final FileUploadDownload fileUploadDownload = FileUploadDownload();
  List<Map<String, dynamic>> _fmcgStoreList = [];
  bool _isLoading = false;
  String lastDownload = '';
  int? downloadStatus;

  @override
  void initState() {
    super.initState();
    _fmcgStoreList = widget.fmcgStoreList;
    _getSP();
  }

  Future<void> _getSP() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      lastDownload = prefs.getString('last_download') ?? '';
      downloadStatus = prefs.getInt('dwStatus');
    });
  }

  Future<bool> _onWillPop() async {
    final shouldClose = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                SizedBox(width: 10),
                Text('Exit App', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
              ],
            ),
            content: const Text('Are you sure you want to close the app?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => SystemNavigator.pop(),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    return shouldClose;
  }

  Future<void> _syncDatabase() async {
    if (await checkConnection.checkConnection(context) == 'data' || await checkConnection.checkConnection(context) == 'wifi') {
      ShowProgress.showProgressDialogWithMsg(context);
      await fileUploadDownload.getSyncStatus(context, widget.dbPath, widget.auditorId);
      ShowProgress.hideProgressDialog(context);
    } else {
      ShowAlert.showSnackBar(context, await checkConnection.checkConnection(context));
    }
    // try {
    //
    //   if (lastDownload.isNotEmpty) {
    //     DateTime lastDownloadDate = DateFormat("yyyy-MM-dd HH:mm:ss").parse(lastDownload);
    //     DateTime today = DateTime.now();
    //     bool isSameDate = lastDownloadDate.year == today.year && lastDownloadDate.month == today.month && lastDownloadDate.day == today.day;
    //     if (isSameDate && downloadStatus == 1) {
    //       await checkConnection.checkConnection(context, widget.dbPath, widget.auditorId);
    //       ShowAlert.showSnackBar(context, 'Database sync successfully');
    //     } else {
    //       ShowAlert.showSnackBar(context, 'Database already updated for today');
    //     }
    //   }
    //   ShowProgress.hideProgressDialog(context);
    // } catch (e) {
    //   ShowAlert.showSnackBar(context, 'Please enable internet: $e');
    // }
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
              future: Future.value(_fmcgStoreList),
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
                  if (downloadStatus != 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FMCGSDStores(
                            //storeList: storeList,
                            dbPath: widget.dbPath,
                            auditorId: widget.auditorId),
                      ),
                    );
                  } else {
                    ShowAlert.showSnackBar(context, 'Database is not loaded.');
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
                      builder: (context) => FmcgSdSkuList(
                          dbPath: widget.dbPath,
                          storeCode: 'ZQY5FM',
                          auditorId: widget.auditorId,
                          option: 'Test',
                          shortCode: 'RA',
                          storeName: 'Sadek Departmental Store'),
                    ),
                  );

                  //ShowAlert.showSnackBar(context, 'Development On Going');
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Last updated at: $lastDownload',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.grey,
              fontFamily: 'Inter',
              fontSize: 14,
              letterSpacing: 0.6,
              fontWeight: FontWeight.w500,
              height: 1.5,
            ),
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
}
