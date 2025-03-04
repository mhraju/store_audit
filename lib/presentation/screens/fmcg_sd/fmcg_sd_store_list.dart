import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:store_audit/utility/show_alert.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';
import 'fmcg_sd_store_details.dart';

class FMCGSDStores extends StatefulWidget {
  final String dbPath;
  final String auditorId;

  const FMCGSDStores(
      {super.key, required this.dbPath, required this.auditorId});

  @override
  State<FMCGSDStores> createState() => _FMCGSDStoresState();
}

class _FMCGSDStoresState extends State<FMCGSDStores>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _data = [];
  final DatabaseManager dbManager = DatabaseManager();
  List<Map<String, dynamic>> _filteredData = [];
  TextEditingController _searchController = TextEditingController();
  bool isLoading = true; // Track loading state
  String _dbPath = '';
  String _auditorId = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData(); // Load data asynchronously
  }

  Future<void> _loadData() async {
    setState(() {
      isLoading = true; // Ensure UI shows loading state
    });

    await Future.delayed(const Duration(seconds: 1)); // Simulate delay

    _dbPath = widget.dbPath;
    _auditorId = widget.auditorId;

    await _refreshData(); // Ensure fresh data before UI update

    setState(() {
      isLoading = false; // Stop loading after data is fetched
    });
  }

  Future<void> _refreshData() async {
    print("Refreshing data..."); // Debugging

    final updatedData = await dbManager.loadFMcgSdStores(_dbPath, _auditorId);
    print("Updated data: $updatedData"); // Debugging

    setState(() {
      _data = updatedData;
      _filteredData = _data;
      isLoading = false;
    });
  }

  void _filterStores(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredData = _data;
      } else {
        _filteredData = _data.where((item) {
          return item['name'].toLowerCase().contains(query.toLowerCase()) ||
              item['code'].toString().contains(query);
        }).toList();
      }
    });
  }

  int _getCount(int status) {
    return _filteredData.where((item) {
      int itemStatus = int.tryParse(item['status'].toString()) ?? -1;
      return itemStatus == status;
    }).length;
  }

  List<Map<String, dynamic>> _getFilteredData(int status) {
    return _filteredData.where((item) {
      int itemStatus = int.tryParse(item['status'].toString()) ?? -1;
      return itemStatus == status;
    }).toList();
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
      body: isLoading
          ? const Center(
              child:
                  CircularProgressIndicator()) // Show loading indicator only initially
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Search Bar
        // Padding(
        //   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        //   child: TextField(
        //     controller: _searchController,
        //     decoration: InputDecoration(
        //       hintText: 'Search for Store',
        //       prefixIcon: const Icon(Icons.search),
        //       filled: true,
        //       fillColor: Colors.grey[200],
        //       border: OutlineInputBorder(
        //         borderRadius: BorderRadius.circular(30),
        //         borderSide: BorderSide.none,
        //       ),
        //     ),
        //     onChanged: (value) => _filterStores(value),
        //   ),
        // ),
        // Tabs
        PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: TabBar(
              controller: _tabController,
              labelColor: Colors.black,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Colors.blue,
              indicatorSize: TabBarIndicatorSize.tab,
              onTap: (_) => setState(() {}),
              tabs: [
                _buildTab('All', Icons.list_alt, _filteredData.length),
                _buildTab('Done', Icons.check_circle, _getCount(1),
                    color: Colors.green),
                _buildTab('Pending', Icons.pending_actions, _getCount(0),
                    color: Colors.red),
              ],
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildListView(_filteredData),
              _buildListView(_getFilteredData(1)),
              _buildListView(_getFilteredData(0)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, IconData icon, int count,
      {Color color = Colors.black}) {
    return Tab(
      child: Container(
        height: 80, // Set desired tab height here
        padding: const EdgeInsets.symmetric(horizontal: 0),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Icon(icon, color: color),
                const SizedBox(width: 7),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            Positioned(
              top: 0,
              right: 0,
              child: _buildBadge(count),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<Map<String, dynamic>> data) {
    if (data.isEmpty) {
      return const Center(child: Text('No results found'));
    }
    return ListView.builder(
      itemCount: data.length,
      itemBuilder: (context, index) {
        final item = data[index];
        int status = int.tryParse(item['status'].toString()) ?? -1;
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: ListTile(
            title: Text(
              item['name'],
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Store Code: ${item['code']}'),
                Text(DateFormat('dd MMM, yyyy')
                    .format(DateTime.parse(item['date']))),
              ],
            ),
            trailing: Text(
              status == 1
                  ? 'Done${item['status_short_name'] != null ? ' (${item['status_short_name']})' : ''}'
                  : 'Pending${item['status_short_name'] != null ? ' (${item['status_short_name']})' : ''}',
              style: TextStyle(
                color: status == 1 ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            // trailing: Column(
            //   mainAxisAlignment: MainAxisAlignment.center,
            //   crossAxisAlignment: CrossAxisAlignment.end,
            //   children: [
            //     Text(
            //       status == 1 ? 'Done' : 'Pending',
            //       style: TextStyle(
            //         color: status == 1 ? Colors.green : Colors.red,
            //         fontWeight: FontWeight.bold,
            //         fontSize: 15,
            //       ),
            //     ),
            //     const SizedBox(height: 4), // Adds spacing between the two texts
            //     Text(
            //       item['status_short_name'] ?? '',
            //       style: const TextStyle(
            //         color: Colors.black54,
            //         fontWeight: FontWeight.bold,
            //         fontSize: 13,
            //       ),
            //     ),
            //   ],
            // ),
            onTap: () {
              if (item['status_short_name'] != 'RA') {
                _showOptionsDialog(context, item);
              } else {
                ShowAlert.showSnackBar(
                    context, 'This store has already audited for this month');
              }
            },
          ),
        );
      },
    );
  }

  Widget _buildBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.red,
        borderRadius: BorderRadius.circular(20), // Creates the pill shape
      ),
      child: Text(
        count.toString(),
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
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
              _buildOption(context, 'Initial Audit (IA)', 'IA', item),
              const Divider(),
              _buildOption(context, 'Re Audit (RA)', 'RA', item),
              const Divider(),
              _buildOption(context, 'Temporary Closed (TC)', 'TC', item),
              const Divider(),
              _buildOption(context, 'Permanent Closed (PC)', 'PC', item),
              const Divider(),
              _buildOption(
                  context, 'Consider as New Store (CANS)', 'CANS', item),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOption(
      BuildContext context, String option, String shortCode, item) {
    return ListTile(
      title: Text(option),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => FmcgSdStoreDetails(
                  storeList: _data,
                  storeData: item,
                  dbPath: _dbPath,
                  auditorId: _auditorId,
                  option: option,
                  shortCode: shortCode)),
        ).then((value) {
          _refreshData(); // Call method to refresh database data
        });
      },
    );
  }

  // @override
  // Future<void> didChangeDependencies() async {
  //   super.didChangeDependencies();
  //   _data = await dbManager.loadFMcgSdStores(_dbPath, _auditorId);
  // }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }
}
