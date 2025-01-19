import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:store_audit/presentation/screens/fmcg_sd_store_details.dart';
import 'package:store_audit/presentation/screens/store_close.dart';
import 'package:intl/intl.dart';

import '../../utility/app_colors.dart';

class FMCGSDStores extends StatefulWidget {
  final List<Map<String, dynamic>> storeList;
  const FMCGSDStores({super.key, required this.storeList});

  @override
  State<FMCGSDStores> createState() => _FMCGSDStoresState();
}

class _FMCGSDStoresState extends State<FMCGSDStores>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _data = [];
  String _searchQuery = "";
  late Database _database;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (mounted) {
        setState(() {}); // Ensure UI updates when tab changes
      }
    });
    _data = widget.storeList;
  }

  int _getCount(String status) {
    if (status.isEmpty) {
      return _data.length;
    }
    return _data.where((item) => item['status'].startsWith(status)).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text(
          'FMCG SD Stores',
          style: TextStyle(color: Colors.black),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search for Store',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          // Tabs with badges
          PreferredSize(
            preferredSize: const Size.fromHeight(70), // Adjust TabBar height
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  vertical: 8.0, horizontal: 4.0), // Adjust padding
              child: TabBar(
                controller: _tabController,
                labelColor: Colors.black,
                unselectedLabelColor: Colors.grey,
                indicatorColor: Colors.blue,
                indicatorSize: TabBarIndicatorSize
                    .tab, // Ensures the indicator spans full tab width
                onTap: (_) => setState(() {}),
                tabs: [
                  Tab(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.list_alt),
                            SizedBox(width: 7, height: 5),
                            Text(
                              'All',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ), // Adjust font size if needed
                            ),
                          ],
                        ),
                        Positioned(
                          top: -8,
                          right: 0,
                          child: _buildBadge(_getCount('')),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.check_circle),
                            SizedBox(width: 7, height: 5),
                            Text(
                              'Done',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ), // Adjust font size if needed
                            ),
                          ],
                        ),
                        Positioned(
                          top: -8,
                          right: 0,
                          child: _buildBadge(_getCount('Completed')),
                        ),
                      ],
                    ),
                  ),
                  Tab(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            Icon(Icons.pending_actions),
                            SizedBox(width: 7, height: 5),
                            Text(
                              'Pending',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ), // Adjust font size if needed
                            ),
                          ],
                        ),
                        Positioned(
                          top: -8,
                          right: 0,
                          child: _buildBadge(_getCount('Pending')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: List.generate(
                3,
                (_) {
                  final filteredData = _getFilteredData();
                  return filteredData.isNotEmpty
                      ? ListView.builder(
                          itemCount: filteredData.length,
                          itemBuilder: (context, index) {
                            final item = filteredData[index];
                            return Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 8),
                              child: ListTile(
                                title: Text(
                                  item['name'],
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Store Code: ${item['code']}'),
                                    Text(item['address']),
                                    // Parse the input date string into a DateTime object
                                    //   DateTime dateTime = DateTime.parse(item['created_at'])
                                    //
                                    // // Format the date into the desired format
                                    // String formattedDate = DateFormat('dd MMM, yyyy').format(dateTime);

                                    // print(formattedDate); // Output: 06 Jan, 2025
                                    Text(item['created_at']),
                                  ],
                                ),
                                trailing: Text(
                                  item['status'],
                                  style: TextStyle(
                                    color: item['status']
                                            .startsWith('Completed')
                                        ? Colors.green
                                        : item['status'].startsWith('Pending')
                                            ? Colors.orange
                                            : Colors.red,
                                  ),
                                ),
                                onTap: () {
                                  _showOptionsDialog(context, item);
                                  // Navigate to the new page with the item data
                                  // Navigator.push(
                                  //   context,
                                  //   MaterialPageRoute(
                                  //     builder: (context) =>
                                  //         FmcgSdStoreDetails(item: item),
                                  //   ),
                                  // );
                                },
                              ),
                            );
                          },
                        )
                      : const Center(
                          child: Text('No results found'),
                        );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOptionsDialog(BuildContext context, item) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Choose an Option'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildOption(context, 'Re Audit (RA)', item),
              const Divider(),
              _buildOption(context, 'Temporary Closed (TC)', item),
              const Divider(),
              _buildOption(context, 'Permanent Closed (PC)', item),
              const Divider(),
              _buildOption(context, 'Consider as New Store (CANS)', item),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(BuildContext context, String option, item) {
    return ListTile(
      title: Text(option),
      onTap: () {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('You selected: $option')),
        // );
        // Navigate to the new page with the item data
        // Dismiss any active dialog or overlay first
        // if (Navigator.canPop(context)) {
        //   Navigator.pop(context); // Close the dialog
        // }

        // Get.back(); // Dismiss the dialog
        // if (option == 'Temporary Closed (TC)' ||
        //     option == 'Permanent Closed (PC)') {
        //   Get.to(() => StoreClose(item: item));
        // } else {
        //   //Get.to(() => FmcgSdStoreDetails(storeData: item)); // Navigate
        // }
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: const BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredData() {
    String filter = _tabController.index == 1
        ? 'Completed'
        : _tabController.index == 2
            ? 'Pending'
            : '';

    List<Map<String, dynamic>> filteredData = _data;
    if (filter.isNotEmpty) {
      filteredData =
          _data.where((item) => item['status'].startsWith(filter)).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredData = filteredData
          .where((item) =>
              item['store_name']
                  .toLowerCase()
                  .contains(_searchQuery.toLowerCase()) ||
              item['store_id'].contains(_searchQuery))
          .toList();
    }

    return filteredData;
  }

  @override
  void dispose() {
    _tabController.removeListener(() {}); // Remove listener before disposing
    _tabController.dispose();
    super.dispose();
  }
}
