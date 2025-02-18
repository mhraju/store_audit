import 'package:flutter/material.dart';
import 'package:store_audit/presentation/screens/fmcg_sd_new_entry.dart';
import 'package:store_audit/utility/show_alert.dart';
import '../../db/database_manager.dart';
import '../../utility/app_colors.dart';

class FmcgSdSkuList extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  const FmcgSdSkuList({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
  });

  @override
  State<FmcgSdSkuList> createState() => _FmcgSdSkuListState();
}

class _FmcgSdSkuListState extends State<FmcgSdSkuList> {
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
        await dbManager.loadFMcgSdStoreSkuList(widget.dbPath, widget.storeCode);

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
        final name = item['item_description'].toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  void _showBottomSheet(Map<String, dynamic> skuItem) {
    // Extract values safely with default values
    String itemName = skuItem['item_description'] ?? 'Unknown Item';
    const SizedBox(height: 24);
    TextEditingController openingStockController =
        TextEditingController(text: skuItem['openstock']?.toString() ?? '0');
    TextEditingController purchaseController =
        TextEditingController(text: skuItem['purchase']?.toString() ?? '0');
    TextEditingController closingStockController =
        TextEditingController(text: skuItem['closestock']?.toString() ?? '0');
    TextEditingController wholesaleController =
        TextEditingController(text: skuItem['wholesale']?.toString() ?? '0');
    TextEditingController mrpController =
        TextEditingController(text: skuItem['mrp']?.toString() ?? '0');
    TextEditingController avgSaleLastMonthController = TextEditingController(
        text: skuItem['sale_last_month']?.toString() ?? '0');
    TextEditingController avgSaleLastToLastMonthController =
        TextEditingController(
            text: skuItem['Sale_last_to_last_month']?.toString() ?? '0');

    int saleValue = int.tryParse(skuItem['sale']?.toString() ?? '0') ??
        0; // Initialize properly

    void updateSaleValue() {
      int openingStock = int.tryParse(openingStockController.text.trim()) ?? 0;
      int purchase = int.tryParse(purchaseController.text.trim()) ?? 0;
      int closingStock = int.tryParse(closingStockController.text.trim()) ?? 0;

      int calculatedSale = (openingStock + purchase) - closingStock;
      print('calculatedSale: $calculatedSale'); // Debugging

      if (calculatedSale < 0) {
        // ✅ Reset Closing Stock (CS) to 0
        setState(() {
          closingStockController.text = '0'; // Reset CS field
          saleValue = 0; // Reset Sale value
        });

        // ✅ Show a beautiful AlertDialog
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red, size: 30),
                  SizedBox(width: 10),
                  Text(
                    "Invalid Input",
                    style: TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: const Text(
                "Sale cannot be negative!\nClosing Stock (CS) has been reset to 0.\n\nPlease check your inputs.",
                style: TextStyle(fontSize: 16),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close the dialog
                  },
                  child: const Text("OK", style: TextStyle(color: Colors.blue)),
                ),
              ],
            );
          },
        );
      } else {
        // ✅ Update sale value correctly
        setState(() {
          saleValue = calculatedSale;
          editStatus[itemName] = true;
          editedValues[itemName] = {
            'openstock': openingStock.toString(),
            'purchase': purchase.toString(),
            'closestock': closingStockController.text, // Save CS value
            'sale': saleValue.toString(),
          };
        });
      }
    }

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
                    const SizedBox(height: 16),

                    // Editable Fields
                    _buildEditableField('Opening Stock (OS)',
                        skuItem['openstock']?.toString() ?? '0', itemName,
                        controller: openingStockController),
                    _buildEditableField('Purchase',
                        skuItem['purchase']?.toString() ?? '0', itemName,
                        controller: purchaseController,
                        onChanged: updateSaleValue),
                    _buildEditableField('Closing Stock (CS)',
                        skuItem['closestock']?.toString() ?? '0', itemName,
                        controller: closingStockController,
                        onChanged: updateSaleValue),

                    // Sale - Non Editable
                    _buildNonEditableField('Sale', saleValue.toString()),

                    _buildEditableField('Wholesale (WS)',
                        skuItem['wholesale']?.toString() ?? '0', itemName,
                        controller: wholesaleController),
                    _buildEditableField(
                        'MRP', skuItem['mrp']?.toString() ?? '0', itemName,
                        controller: mrpController),
                    _buildEditableField('Avg Sale Last Month',
                        skuItem['sale_last_month']?.toString() ?? '0', itemName,
                        controller: avgSaleLastMonthController),
                    _buildEditableField(
                        'Avg Sale Last to Last Month',
                        skuItem['Sale_last_to_last_month']?.toString() ?? '0',
                        itemName,
                        controller: avgSaleLastToLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          setState(() {
                            editStatus[itemName] = true;
                            editedValues[itemName] = {
                              'openstock': openingStockController.text,
                              'purchase': purchaseController.text,
                              'closestock': closingStockController.text,
                              'wholesale': wholesaleController.text,
                              'mrp': mrpController.text,
                              'avgSaleLastMonth':
                                  avgSaleLastMonthController.text,
                              'avgSaleLastToLastMonth':
                                  avgSaleLastToLastMonthController.text,
                            };
                          });

                          // ✅ Insert or Update SKU data in the database
                          final dbManager = DatabaseManager();
                          await dbManager.insertOrUpdateFmcgSdSkuDetails(
                            widget.dbPath,
                            widget.storeCode,
                            widget.auditorId,
                            skuItem['product_code'],
                            openingStockController.text,
                            purchaseController.text,
                            closingStockController.text,
                            saleValue.toString(),
                            wholesaleController.text,
                            mrpController.text,
                            avgSaleLastMonthController.text,
                            avgSaleLastToLastMonthController.text,
                          );

                          ShowAlert.showSnackBar(
                              context, 'SKU details updated successfully');
                          Navigator.pop(context);
                          _fetchSkuData();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Update'),
                      ),
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

  Widget _buildEditableField(String label, String value, String itemName,
      {TextEditingController? controller, Function()? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller ?? TextEditingController(text: value),
        onChanged: (text) {
          onChanged?.call();
          setState(() {
            editStatus[itemName] = true;
            editedValues[itemName] = {
              ...?editedValues[itemName],
              label: text,
            };
          });
        },
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
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

  Color _getColorByEditStatus(String itemName) {
    if (editedValues.containsKey(itemName)) {
      // Check if all fields have values and are not 0
      bool allFieldsEdited = editedValues[itemName]!
              .values
              .where((value) => value != "0" && value.isNotEmpty)
              .length >=
          6;

      // Check if at least some fields have values and are not 0
      bool someFieldsEdited = editedValues[itemName]!
          .values
          .any((value) => value != "0" && value.isNotEmpty);

      if (allFieldsEdited) return Colors.green.shade300;
      if (someFieldsEdited) return Colors.yellow.shade300;
    }
    return Colors.grey.shade300;
  }

  bool _allCardsGreen() {
    return filteredSkuData.every((item) =>
        _getColorByEditStatus(item['item_description']) ==
        Colors.green.shade300);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text(
          'SKU Details',
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: filteredSkuData.length,
                        itemBuilder: (context, index) {
                          final skuItem = filteredSkuData[index];
                          return GestureDetector(
                            onTap: () => _showBottomSheet(skuItem),
                            child: _buildSkuItem(
                              skuItem['item_description'],
                              _getColorByEditStatus(
                                  skuItem['item_description']),
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
                              builder: (context) => FmcgSdNewEntry(
                                  dbPath: widget.dbPath,
                                  storeCode: 'ZQY5FM',
                                  auditorId: widget.storeCode)),
                        ).then((value) {
                          _fetchSkuData(); // Call method to refresh database data
                        });
                      },
                      child: const Center(
                        child: Text(
                          'New Entry',
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
                      onTap: _allCardsGreen() ? _navigateToNextPage : null,
                      child: Center(
                        child: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _allCardsGreen()
                                ? Colors.white
                                : Colors.grey, // Disable color if not green
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
    ShowAlert.showSnackBar(context, 'Audit Ok');
    // Navigator.push(
    //   context,
    //     MaterialPageRoute(
    //       builder: (context) => FmcgSdNewEntry(
    //           dbPath: widget.dbPath,
    //           storeCode: 'ZQY5FM',
    //           auditorId: widget.storeCode),
    //     ),
    // );
  }

  Widget _buildSkuItem(String title, Color backgroundColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
