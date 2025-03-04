import 'package:flutter/material.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_new_intro.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_sku_list.dart';

import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';
import '../../../utility/show_alert.dart';

class FmcgSdNewEntry extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  final String storeName;
  const FmcgSdNewEntry({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName,
  });

  @override
  State<FmcgSdNewEntry> createState() => _FmcgSdNewEntryState();
}

class _FmcgSdNewEntryState extends State<FmcgSdNewEntry> {
  List<Map<String, dynamic>> skuData = [];
  List<Map<String, dynamic>> filteredSkuData = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();
  Map<String, bool> editStatus = {}; // Track edited status
  Map<String, Map<String, dynamic>> editedValues = {}; // Store field updates
  final DatabaseManager dbManager = DatabaseManager();

  @override
  void initState() {
    super.initState();
    _fetchSkuData();
    searchController.addListener(_filterSkuData);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterSkuData);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkuData() async {
    setState(() {
      isLoading = true; // Ensure UI shows loading state
    });
    await Future.delayed(const Duration(seconds: 1));
    final fetchedData =
        await dbManager.loadFMcgSdProductsAll(widget.dbPath, widget.storeCode);

    setState(() {
      skuData = fetchedData;
      filteredSkuData = fetchedData;
      isLoading = false;
    });
  }

  void _filterSkuData() {
    final query = searchController.text.toLowerCase();

    setState(() {
      filteredSkuData = skuData.where((item) {
        final name = item['item_description']?.toLowerCase() ?? '';
        final brand = item['brand']?.toLowerCase() ?? '';
        final sub_brand = item['sub_brand']?.toLowerCase() ?? '';
        final company = item['company']?.toLowerCase() ?? '';
        final category = item['category_name']?.toLowerCase() ?? '';
        final packType = item['pack_type']?.toLowerCase() ?? '';
        final packSize = item['pack_size']?.toLowerCase() ?? '';

        return name.contains(query) ||
            brand.contains(query) ||
            sub_brand.contains(query) ||
            company.contains(query) ||
            category.contains(query) ||
            packType.contains(query) ||
            packSize.contains(query);
      }).toList();
    });
  }

  void _showBottomSheet(Map<String, dynamic> skuItem) {
    // Extract values safely with default values
    String itemName = skuItem['item_description'] ?? 'Unknown Item';
    const SizedBox(height: 24);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      itemName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      "Do you want to add this item in this store?",
                      style: TextStyle(
                        fontSize: 16,
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Buttons Row
                    Row(
                      mainAxisAlignment:
                          MainAxisAlignment.spaceEvenly, // Align left & right
                      children: [
                        // Close Button (Left Aligned)
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context); // Close the bottom sheet
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Colors.blue, // Set background color
                            foregroundColor: Colors.white, // Set text color
                          ),
                          child: const Text('No'),
                        ),

                        // Add Item Button (Right Aligned)
                        ElevatedButton(
                          onPressed: () async {
                            // ✅ Insert or Update SKU data in the database
                            await dbManager.insertFMcgSdStoreProduct(
                              context,
                              widget.dbPath,
                              widget.storeCode,
                              widget.auditorId,
                              skuItem['code'],
                            );

                            // await dbManager.insertOrUpdateFmcgSdSkuDetails(
                            //   widget.dbPath,
                            //   widget.storeCode,
                            //   widget.auditorId,
                            //   skuItem['code'],
                            //   skuItem['openstock']?.toString() ?? '0',
                            //   skuItem['purchase']?.toString() ?? '0',
                            //   skuItem['closestock']?.toString() ?? '0',
                            //   skuItem['sale']?.toString() ?? '0',
                            //   skuItem['wholesale']?.toString() ?? '0',
                            //   skuItem['mrp']?.toString() ?? '0',
                            //   skuItem['sale_last_month']?.toString() ?? '0',
                            //   skuItem['Sale_last_to_last_month']?.toString() ??
                            //       '0',
                            // );

                            // ShowAlert.showSnackBar(context,
                            //     'New SKU inserted and updated successfully');
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Yes'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNonEditableField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: TextEditingController(text: value),
        readOnly: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors.grey.shade200,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text(
          'New Entry',
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: TextField(
              controller: searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                hintText: 'category, brand, sku type, sku size',
                hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFFEAEFF6),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSkuData.isEmpty
                    ? const Center(
                        child: Text(
                          "No Data Found",
                          style: TextStyle(
                            fontSize: 14,
                            //fontWeight: FontWeight.bold,
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemCount: filteredSkuData.length,
                        itemBuilder: (context, index) {
                          final skuItem = filteredSkuData[index];
                          return GestureDetector(
                            onTap: () => _showBottomSheet(skuItem),
                            child: _buildSkuItem(
                              skuItem['item_description'],
                            ),
                          );
                        },
                      ),
          ),

          // Bottom Navigation
          SafeArea(
            child: Container(
              height: 60,
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
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => FmcgSdSkuList(
                              dbPath: widget.dbPath,
                              storeCode: widget.storeCode,
                              auditorId: widget.auditorId,
                              option: widget.option,
                              shortCode: widget.shortCode,
                              storeName: widget.storeName,
                            ),
                          ),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'SKU Audit',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
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
                      onTap: _navigateToNextPage,
                      child: const Center(
                        child: Text(
                          'New Introduction',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white // Disable color if not green
                              ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToNextPage() {
    ShowAlert.showSnackBar(context, 'Development on going');
    // Uncomment if you want to navigate to another page
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => FmcgSdNewIntro(
    //       dbPath: widget.dbPath,
    //       storeCode: widget.storeCode,
    //       auditorId: widget.auditorId,
    //       option: widget.option,
    //       shortCode: widget.shortCode,
    //     ),
    //   ),
    // );
  }

  Widget _buildSkuItem(String title) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.grey.shade300,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
