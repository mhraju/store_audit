import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/db/database_manager.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_sku_list.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_store_list.dart';
import 'package:store_audit/presentation/screens/login_screen.dart';
import 'package:store_audit/presentation/screens/tobacco/tobacco.dart';
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
  const HomeScreen({
    super.key,
    required this.fmcgStoreList,
    required this.dbPath,
    required this.auditorId,
  });

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

  @override
  void dispose() {
    // Example: dispose any controllers or close streams if added in future
    super.dispose();
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
      await fileUploadDownload.getSyncStatus(context, widget.dbPath, widget.auditorId, 'home');
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
            width: 250,
            fit: BoxFit.fitWidth, // Adjust size as needed
          ),
          automaticallyImplyLeading: false,
          actions: [
            IconButton(
              icon: const Icon(Icons.sync, color: Colors.black),
              onPressed: _syncDatabase,
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) async {
                if (value == 'profile') {
                  await loadUserDataFromPrefs();
                } else if (value == 'logout') {
                  _logout(context);
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                    value: 'profile',
                    child: Row(
                      children: [
                        Icon(Icons.person, size: 20),
                        SizedBox(width: 10),
                        Text('Show Profile'),
                      ],
                    )),
                const PopupMenuItem(
                  enabled: false,
                  height: 1, // minimal height
                  padding: EdgeInsets.zero,
                  child: Divider(
                    height: 0.5,
                    thickness: 0.8,
                    color: Colors.black12,
                  ),
                ),
                const PopupMenuItem(
                    value: 'logout',
                    child: Row(
                      children: [
                        Icon(Icons.logout, size: 20),
                        SizedBox(width: 10),
                        Text('Log Out'),
                      ],
                    )),
              ],
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

  Future<void> loadUserDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    _showProfileBottomSheet(context, prefs.getString('code'), prefs.getString('name'), prefs.getString('phone'), prefs.getString('designation'),
        prefs.getString('supervisor_name'), prefs.getString('zone'));
  }

  void _showProfileBottomSheet(BuildContext context, code, name, phone, designation, supervisor_name, zone) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true, // <-- important for avoiding overflow
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'User Profile',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(name),
                ),
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: Text(phone),
                ),
                ListTile(
                  leading: const Icon(Icons.code),
                  title: Text(code),
                ),
                ListTile(
                  leading: const Icon(Icons.badge),
                  title: Text(designation),
                ),
                ListTile(
                  leading: const Icon(Icons.star),
                  title: Text(supervisor_name),
                ),
                ListTile(
                  leading: const Icon(Icons.location_searching),
                  title: Text(zone),
                ),
                const SizedBox(height: 24), // Extra space at bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    final dbFile = File(widget.dbPath);
    if (await dbFile.exists()) {
      await dbFile.delete();
      //print('Database deleted');
    }
    await prefs.clear(); // Clear user data
    ShowAlert.showSnackBar(context, 'Logged out');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => LoginWidget()),
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
                    ShowAlert.showSnackBar(context, 'Database is not updated.');
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
                      builder: (context) => TobaccoAuditScreen(dbPath: widget.dbPath, auditorId: widget.auditorId),
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
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(15),
      elevation: 3,
      shadowColor: Colors.grey.withOpacity(0.3),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        splashColor: Colors.blue.withOpacity(0.3), // Add your splash color here
        child: Container(
          width: 150,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
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
      ),
    );
  }
}
