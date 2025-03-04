import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_new_entry.dart';
import 'package:store_audit/presentation/screens/fmcg_sd/fmcg_sd_store_audit.dart';
import 'package:store_audit/utility/show_alert.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';

class FmcgSdSkuList extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  const FmcgSdSkuList({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
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
  Map<String, Color> skuItemColors = {}; // ✅ Store colors for each SKU item

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
      isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    final fetchedData =
        await dbManager.loadFMcgSdStoreSkuList(widget.dbPath, widget.storeCode);

    final prefs = await SharedPreferences.getInstance();
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];

    // ✅ Reload stored colors for each SKU item explicitly from editedItems
    Map<String, Color> restoredColors = {};
    for (var item in fetchedData) {
      String itemName = item['item_description'].trim();

      if (editedItems.contains(itemName)) {
        int? colorValue = prefs.getInt("color_${widget.storeCode}_$itemName");
        restoredColors[itemName] =
            (colorValue != null) ? Color(colorValue) : Colors.grey.shade300;
      } else {
        restoredColors[itemName] = Colors.grey.shade300;
      }
    }

    setState(() {
      skuData = fetchedData;
      filteredSkuData = fetchedData;
      skuItemColors = restoredColors; // ✅ Restore colors here
      isLoading = false;
    });
  }

  // void _filterSkuData() {
  //   final query = searchController.text.toLowerCase();
  //   setState(() {
  //     filteredSkuData = skuData.where((item) {
  //       final name = item['item_description'].toLowerCase();
  //       return name.contains(query);
  //     }).toList();
  //   });
  // }

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
            text: skuItem['sale_last_to_last_month']?.toString() ?? '0');
//     // Helper function to prevent showing "0" and return an empty string instead
//     String getTextFieldValue(dynamic value) {
//       if (value == null || value.toString() == '0') {
//         return ''; // Return empty if value is null or "0"
//       }
//       return value.toString(); // Otherwise, return the actual value as a string
//     }
//
// // Initialize controllers with improved logic
//     TextEditingController openingStockController =
//         TextEditingController(text: getTextFieldValue(skuItem['openstock']));
//     TextEditingController purchaseController =
//         TextEditingController(text: getTextFieldValue(skuItem['purchase']));
//     TextEditingController closingStockController =
//         TextEditingController(text: getTextFieldValue(skuItem['closestock']));
//     TextEditingController wholesaleController =
//         TextEditingController(text: getTextFieldValue(skuItem['wholesale']));
//     TextEditingController mrpController =
//         TextEditingController(text: getTextFieldValue(skuItem['mrp']));
//     TextEditingController avgSaleLastMonthController = TextEditingController(
//         text: getTextFieldValue(skuItem['sale_last_month']));
//     TextEditingController avgSaleLastToLastMonthController =
//         TextEditingController(
//             text: getTextFieldValue(skuItem['sale_last_to_last_month']));

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
                        skuItem['sale_last_to_last_month']?.toString() ?? '0',
                        itemName,
                        controller: avgSaleLastToLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          int wholesale =
                              int.tryParse(wholesaleController.text.trim()) ??
                                  0;

                          if (wholesale > saleValue) {
                            // ✅ Show an alert if Wholesale is greater than Sale
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
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ],
                                  ),
                                  content: const Text(
                                    "Wholesale cannot be more than Total Sales!\nPlease enter a valid value.",
                                    style: TextStyle(fontSize: 16),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () {
                                        Navigator.pop(
                                            context); // Close the dialog
                                      },
                                      child: const Text("OK",
                                          style: TextStyle(color: Colors.blue)),
                                    ),
                                  ],
                                );
                              },
                            );
                            return; // ✅ Stop execution if validation fails
                          }

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
                            skuItem['index'],
                          );

                          ShowAlert.showSnackBar(
                              context, 'SKU item updated successfully');
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
            if (!editedValues.containsKey(itemName)) {
              editedValues[itemName] = {};
            }
            editedValues[itemName]![label] = text;

            // ✅ Trigger immediate color update
            _updateColorStatus(itemName);
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

  Future<void> _saveColorStatus(String itemName, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
        "color_${widget.storeCode}_${itemName.trim()}", color.value);

    // Save item names list explicitly
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];
    if (!editedItems.contains(itemName)) {
      editedItems.add(itemName);
      await prefs.setStringList('editedItems', editedItems);
    }
  }

  Future<Color> _getSavedColor(String itemName) async {
    final prefs = await SharedPreferences.getInstance();
    int? colorValue = prefs.getInt("color_$itemName");

    if (colorValue != null) {
      return Color(colorValue);
    }

    return Colors.grey.shade300; // Default color if no saved data
  }

  void _updateColorStatus(String itemName) {
    if (!mounted) return;

    if (!editedValues.containsKey(itemName) ||
        editedValues[itemName]!.isEmpty) {
      setState(() {
        skuItemColors[itemName] = Colors.grey.shade300;
      });
      return;
    }

    // ✅ Count total editable fields dynamically
    int totalEditableFields = editedValues[itemName]!.keys.length;

    // ✅ Count how many fields have valid (non-zero, non-empty) values
    int editedFieldCount = editedValues[itemName]!
        .values
        .where((value) => value.trim().isNotEmpty && value != "0")
        .length;

    // ✅ Determine color based on edits
    bool allFieldsEdited = editedFieldCount == totalEditableFields;
    bool someFieldsEdited =
        editedFieldCount > 0 && editedFieldCount < totalEditableFields;

    Color color;
    if (allFieldsEdited) {
      color = Colors.green.shade300;
    } else if (someFieldsEdited) {
      color = Colors.yellow.shade300;
    } else {
      color = Colors.grey.shade300;
    }

    setState(() {
      skuItemColors[itemName] = color;
    });

    _saveColorStatus(itemName, color); // ✅ Save immediately
  }

  bool _allCardsGreen() {
    return filteredSkuData.every((item) =>
        skuItemColors.containsKey(item['item_description']) &&
        skuItemColors[item['item_description']] == Colors.green.shade300);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: const Text(
          'SKU List',
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
                          style: TextStyle(fontSize: 14, color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        itemCount: filteredSkuData.length,
                        itemBuilder: (context, index) {
                          final skuItem = filteredSkuData[index];
                          String itemName = skuItem['item_description'];

                          return GestureDetector(
                            onTap: () {
                              _showBottomSheet(skuItem);
                            },
                            child: _buildSkuItem(
                              itemName,
                              skuItemColors[itemName] ?? Colors.grey.shade300,
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
                                    storeCode: widget.storeCode,
                                    auditorId: widget.auditorId,
                                    option: widget.option,
                                    shortCode: widget.shortCode,
                                    storeName: '',
                                  )),
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
                            color:
                                _allCardsGreen() ? Colors.white : Colors.grey,
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
    //ShowAlert.showSnackBar(context, 'Audit Ok');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FmcgSdStoreAudit(
          dbPath: widget.dbPath,
          storeCode: widget.storeCode,
          auditorId: widget.auditorId,
          option: widget.option,
          shortCode: widget.shortCode,
        ),
      ),
    );
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
