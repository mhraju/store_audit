import 'dart:async';
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
  final String storeName;
  const FmcgSdSkuList({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName,
  });

  @override
  State<FmcgSdSkuList> createState() => _FmcgSdSkuListState();
}

class _FmcgSdSkuListState extends State<FmcgSdSkuList> {
  List<Map<String, dynamic>> skuData = [];
  List<Map<String, dynamic>> filteredSkuData = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController(); // Store field updates
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

    final fetchedData = await dbManager.loadFMcgSdStoreSkuList(widget.dbPath, widget.storeCode);

    final prefs = await SharedPreferences.getInstance();
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];
    //print('color: checkList $editedItems');
    // ✅ Reload stored colors for each SKU item explicitly from editedItems
    Map<String, Color> restoredColors = {};
    for (var item in fetchedData) {
      String itemName = item['item_description'].trim();
      //print('color: check $itemName');
      if (editedItems.contains(itemName)) {
        int? colorValue = prefs.getInt("color_${widget.storeCode}_$itemName");
        restoredColors[itemName] = (colorValue != null) ? Color(colorValue) : Colors.grey.shade300;
        //print('color: ok ${restoredColors[itemName]}');
      } else {
        restoredColors[itemName] = Colors.grey.shade300;
        //print('color: Not ok ${restoredColors[itemName]}');
      }
    }

    setState(() {
      skuData = fetchedData;
      filteredSkuData = fetchedData;
      skuItemColors = restoredColors; // ✅ Restore colors here
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
    bool isProceed = false;

    // Helper function to prevent showing "0" and return an empty string instead
    String getTextFieldValue(dynamic value) {
      if (value == null || value.toString() == '') {
        return ''; // Return empty if value is null or "0"
      }
      return value.toString(); // Otherwise, return the actual value as a string
    }

// Initialize controllers with improved logic
    TextEditingController purchaseController = TextEditingController(text: getTextFieldValue(skuItem['purchase']));
    TextEditingController closingStockController = TextEditingController(text: getTextFieldValue(skuItem['closestock']));
    TextEditingController wholesaleController = TextEditingController(text: getTextFieldValue(skuItem['wholesale']));
    TextEditingController mrpController = TextEditingController(text: getTextFieldValue(skuItem['mrp']));
    TextEditingController avgSaleLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_last_month']));
    TextEditingController avgSaleLastToLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_last_to_last_month']));

    int saleValue = int.tryParse(skuItem['sale']?.toString() ?? '0') ?? 0; // Initialize properly

    void updateSaleValue() {
      int openingStock = int.tryParse((skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty)
              ? skuItem['openstock'].toString()
              : skuItem['prev_closestock'].toString()) ??
          0;

      int purchase = double.tryParse(purchaseController.text.trim())?.round() ?? 0;

      if (closingStockController.text.trim().isNotEmpty) {
        int closingStock = double.tryParse(closingStockController.text.trim())?.round() ?? 0;
        int calculatedSale = (openingStock + purchase) - closingStock;

        // if (calculatedSale < 0) {
        //   // ✅ Reset Closing Stock (CS) to 0
        //   setState(() {
        //     closingStockController.text = '0'; // Reset CS field
        //     saleValue = calculatedSale; // Reset Sale value
        //   });
        //
        //   ShowAlert.showAlertDialog(
        //       context, "Invalid Input", "Sale cannot be negative!\nClosing Stock (CS) has been reset to 0.\n\nPlease check your inputs.");
        // } else {
        //   // ✅ Update sale value correctly
        //   setState(() {
        //     saleValue = calculatedSale;
        //   });
        // }
        setState(() {
          saleValue = calculatedSale;
        });
      } else {
        print("Closing stock is empty on Sale");
        setState(() {
          saleValue = openingStock + purchase;
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

                    _buildNonEditableField(
                      'Opening Stock (OS)',
                      (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                              ? skuItem['openstock']
                              : skuItem['prev_closestock'])
                          .toString(),
                    ),

                    // Editable Fields
                    _buildEditableField('Purchase', skuItem['purchase']?.toString() ?? '', itemName, skuItem,
                        controller: purchaseController, onChanged: updateSaleValue),
                    _buildEditableField('Closing Stock (CS)', skuItem['closestock']?.toString() ?? '', itemName, skuItem,
                        controller: closingStockController, onChanged: updateSaleValue),

                    // Sale - Non Editable
                    _buildNonEditableField('Sale', saleValue.toString()),

                    _buildEditableField('Wholesale (WS)', skuItem['wholesale']?.toString() ?? '', itemName, skuItem,
                        controller: wholesaleController // ✅ Pass the roundUp parameter
                        ),
                    _buildEditableField('MRP', skuItem['mrp']?.toString() ?? '', itemName, skuItem, controller: mrpController),
                    _buildEditableField('Avg Sale Last Month', skuItem['sale_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleLastMonthController),
                    _buildEditableField('Avg Sale Last to Last Month', skuItem['sale_last_to_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleLastToLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (closingStockController.text.trim().isNotEmpty) {
                            print("Closing stock contains data.");
                            int closingStock = double.tryParse(closingStockController.text.trim())?.round() ?? 0;

                            if (closingStock == 0) {
                              mrpController.text = '0';
                            } else {
                              if (mrpController.text.trim().isNotEmpty) {
                                double? newMrp = double.tryParse(mrpController.text.trim());

                                double lastMrpFromDb = double.tryParse((skuItem['mrp']?.toString().isNotEmpty == true)
                                        ? skuItem['mrp'].toString()
                                        : (skuItem['prev_mrp']?.toString().isNotEmpty == true ? skuItem['prev_mrp'].toString() : '0')) ??
                                    0;

                                print('$newMrp _ $lastMrpFromDb _ ${skuItem['prev_mrp']}');

                                if (newMrp == null || newMrp < 0) {
                                  mrpController.text = lastMrpFromDb.toString();
                                  return;
                                }

                                if (lastMrpFromDb != 0.0) {
                                  double minAllowed = lastMrpFromDb * 0.8, maxAllowed = lastMrpFromDb * 1.2;

                                  if ((newMrp < minAllowed || newMrp > maxAllowed) && !isProceed) {
                                    _showConfirmationDialog(
                                            "Invalid MRP",
                                            "The new MRP ($newMrp) is outside the allowed 20% deviation range of previous MRP ($lastMrpFromDb).\n\n"
                                                "Allowed range: $minAllowed - $maxAllowed.\n"
                                                "Do you want to proceed anyway?")
                                        .then((proceed) {
                                      if (proceed) {
                                        // ✅ User chose "Continue", proceed with the update
                                        //_continueUpdateProcess();
                                        setState(() {
                                          isProceed = true;
                                          mrpController.text = newMrp.toString();
                                        });
                                      } else {
                                        // ✅ User chose "OK", reset MRP
                                        setState(() {
                                          isProceed = true;
                                          mrpController.text = lastMrpFromDb.toString();
                                        });
                                      }
                                    });
                                    return; // Prevent immediate continuation
                                  }
                                }
                              }
                            }

                            // Ensure MRP is provided if closing stock > 0
                            // if (closingStock > 0 && (double.tryParse(mrpController.text.trim()) ?? 0) == 0) {
                            //   ShowAlert.showAlertDialog(context, "MRP Required", "You must enter an MRP value when Closing Stock is greater than 0.");
                            // }

                            if (wholesaleController.text.trim().isNotEmpty) {
                              // wholesale check
                              int wholesale = double.tryParse(wholesaleController.text.trim())?.round() ?? 0;

                              print('sal: $saleValue _ $wholesale');
                              if (wholesale > saleValue) {
                                // ✅ Show an alert if Wholesale is greater than Sale
                                ShowAlert.showAlertDialog(
                                    context, "Invalid Input", "Wholesale cannot be more than Total Sales!\nPlease enter a valid value.");
                                return; // ✅ Stop execution if validation fails
                              }
                            }
                          } else {
                            print("Closing stock is empty.");
                          }

                          // ✅ Insert or Update SKU data in the database
                          await dbManager.insertOrUpdateFmcgSkuDetails(
                            widget.dbPath,
                            widget.storeCode,
                            widget.auditorId,
                            skuItem['product_code'],
                            (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                                    ? skuItem['openstock']
                                    : skuItem['prev_closestock'])
                                .toString(),
                            purchaseController.text.trim().isNotEmpty
                                ? (double.tryParse(purchaseController.text.trim())?.round() ?? 0).toString()
                                : '',
                            closingStockController.text.trim().isNotEmpty
                                ? (double.tryParse(closingStockController.text.trim())?.round() ?? 0).toString()
                                : '',
                            saleValue.toString(),
                            wholesaleController.text.trim().isNotEmpty
                                ? (double.tryParse(wholesaleController.text.trim())?.round() ?? 0).toString()
                                : '',
                            mrpController.text.trim().isNotEmpty ? mrpController.text : '',
                            avgSaleLastMonthController.text.trim().isNotEmpty
                                ? (double.tryParse(avgSaleLastMonthController.text.trim())?.round() ?? 0).toString()
                                : '',
                            avgSaleLastToLastMonthController.text.trim().isNotEmpty
                                ? (double.tryParse(avgSaleLastToLastMonthController.text.trim())?.round() ?? 0).toString()
                                : '',
                            skuItem['index'],
                          );

                          if (purchaseController.text.trim().isNotEmpty &&
                              closingStockController.text.trim().isNotEmpty &&
                              mrpController.text.trim().isNotEmpty &&
                              saleValue >= 0 &&
                              wholesaleController.text.trim().isNotEmpty &&
                              avgSaleLastMonthController.text.trim().isNotEmpty &&
                              avgSaleLastToLastMonthController.text.trim().isNotEmpty)
                          // (double.tryParse(avgSaleLastMonthController.text.trim())?.round() ?? 0) >= 0 &&
                          // (double.tryParse(avgSaleLastToLastMonthController.text.trim())?.round() ?? 0) >= 0)
                          {
                            _saveColorStatus(itemName, Colors.green.shade300);
                          } else if (purchaseController.text.trim().isNotEmpty ||
                              closingStockController.text.trim().isNotEmpty ||
                              mrpController.text.trim().isNotEmpty ||
                              avgSaleLastMonthController.text.trim().isNotEmpty ||
                              avgSaleLastToLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(itemName, Colors.yellow.shade300);
                          } else {
                            _saveColorStatus(itemName, Colors.grey.shade300);
                          }

                          ShowAlert.showSnackBar(context, 'SKU item updated successfully');
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

  void _showSdBottomSheet(Map<String, dynamic> skuItem) {
    // Extract values safely with default values
    String itemName = skuItem['item_description'] ?? 'Unknown Item';
    const SizedBox(height: 24);
    bool isProceed = false;

    // Helper function to prevent showing "0" and return an empty string instead
    String getTextFieldValue(dynamic value) {
      if (value == null || value.toString() == '') {
        return ''; // Return empty if value is null or "0"
      }
      return value.toString(); // Otherwise, return the actual value as a string
    }

// Initialize controllers with improved logic
    TextEditingController purchaseController = TextEditingController(text: getTextFieldValue(skuItem['purchase']));
    TextEditingController closingStockController = TextEditingController(text: getTextFieldValue(skuItem['closestock']));
    TextEditingController chilledStockController = TextEditingController(text: getTextFieldValue(skuItem['chilled_stock']));
    TextEditingController chilledFaceController = TextEditingController(text: getTextFieldValue(skuItem['chilled_face']));
    TextEditingController warmFaceController = TextEditingController(text: getTextFieldValue(skuItem['warm_face']));
    TextEditingController wholesaleController = TextEditingController(text: getTextFieldValue(skuItem['wholesale']));
    TextEditingController mrpController = TextEditingController(text: getTextFieldValue(skuItem['mrp']));
    TextEditingController avgSaleLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_last_month']));
    TextEditingController avgSaleLastToLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_last_to_last_month']));

    int saleValue = int.tryParse(skuItem['sale']?.toString() ?? '0') ?? 0; // Initialize properly

    void updateSaleValue() {
      int openingStock = int.tryParse((skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty)
              ? skuItem['openstock'].toString()
              : skuItem['prev_closestock'].toString()) ??
          0;

      int purchase = double.tryParse(purchaseController.text.trim())?.round() ?? 0;

      if (closingStockController.text.trim().isNotEmpty) {
        int closingStock = double.tryParse(closingStockController.text.trim())?.round() ?? 0;
        int calculatedSale = (openingStock + purchase) - closingStock;

        // if (calculatedSale < 0) {
        //   // ✅ Reset Closing Stock (CS) to 0
        //   setState(() {
        //     closingStockController.text = '0'; // Reset CS field
        //     saleValue = calculatedSale; // Reset Sale value
        //   });
        //
        //   ShowAlert.showAlertDialog(
        //       context, "Invalid Input", "Sale cannot be negative!\nClosing Stock (CS) has been reset to 0.\n\nPlease check your inputs.");
        // } else {
        //   // ✅ Update sale value correctly
        //   setState(() {
        //     saleValue = calculatedSale;
        //   });
        // }
        setState(() {
          saleValue = calculatedSale;
        });
      } else {
        print("Closing stock is empty on Sale");
        setState(() {
          saleValue = openingStock + purchase;
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

                    _buildNonEditableField(
                      'Opening Stock (OS)',
                      (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                              ? skuItem['openstock']
                              : skuItem['prev_closestock'])
                          .toString(),
                    ),

                    // Editable Fields
                    _buildEditableField('Purchase', skuItem['purchase']?.toString() ?? '', itemName, skuItem,
                        controller: purchaseController, onChanged: updateSaleValue),
                    _buildEditableField('Closing Stock (CS)', skuItem['closestock']?.toString() ?? '', itemName, skuItem,
                        controller: closingStockController, onChanged: updateSaleValue),

                    // Sale - Non Editable
                    _buildNonEditableField('Sale', saleValue.toString()),

                    _buildEditableField('Chilled Stock', skuItem['chilled_stock']?.toString() ?? '', itemName, skuItem,
                        controller: chilledStockController // ✅ Pass the roundUp parameter
                        ),
                    _buildEditableField('Chilled Face', skuItem['chilled_face']?.toString() ?? '', itemName, skuItem,
                        controller: chilledFaceController // ✅ Pass the roundUp parameter
                        ),
                    _buildEditableField('Warm Face', skuItem['warm_face']?.toString() ?? '', itemName, skuItem,
                        controller: warmFaceController // ✅ Pass the roundUp parameter
                        ),
                    _buildEditableField('Wholesale (WS)', skuItem['wholesale']?.toString() ?? '', itemName, skuItem,
                        controller: wholesaleController // ✅ Pass the roundUp parameter
                        ),
                    _buildEditableField('MRP', skuItem['mrp']?.toString() ?? '', itemName, skuItem, controller: mrpController),
                    _buildEditableField('Avg Sale Last Month', skuItem['sale_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleLastMonthController),
                    _buildEditableField('Avg Sale Last to Last Month', skuItem['sale_last_to_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleLastToLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          if (closingStockController.text.trim().isNotEmpty) {
                            print("Closing stock contains data.");
                            int closingStock = double.tryParse(closingStockController.text.trim())?.round() ?? 0;

                            if (closingStock == 0) {
                              mrpController.text = '0';
                            } else {
                              if (mrpController.text.trim().isNotEmpty) {
                                double? newMrp = double.tryParse(mrpController.text.trim());

                                double lastMrpFromDb = double.tryParse((skuItem['mrp']?.toString().isNotEmpty == true)
                                        ? skuItem['mrp'].toString()
                                        : (skuItem['prev_mrp']?.toString().isNotEmpty == true ? skuItem['prev_mrp'].toString() : '0')) ??
                                    0;

                                print('$newMrp _ $lastMrpFromDb _ ${skuItem['prev_mrp']}');

                                if (newMrp == null || newMrp < 0) {
                                  mrpController.text = lastMrpFromDb.toString();
                                  return;
                                }

                                if (lastMrpFromDb != 0.0) {
                                  double minAllowed = lastMrpFromDb * 0.8, maxAllowed = lastMrpFromDb * 1.2;

                                  if ((newMrp < minAllowed || newMrp > maxAllowed) && !isProceed) {
                                    _showConfirmationDialog(
                                            "Invalid MRP",
                                            "The new MRP ($newMrp) is outside the allowed 20% deviation range of previous MRP ($lastMrpFromDb).\n\n"
                                                "Allowed range: $minAllowed - $maxAllowed.\n"
                                                "Do you want to proceed anyway?")
                                        .then((proceed) {
                                      if (proceed) {
                                        // ✅ User chose "Continue", proceed with the update
                                        //_continueUpdateProcess();
                                        setState(() {
                                          isProceed = true;
                                          mrpController.text = newMrp.toString();
                                        });
                                      } else {
                                        // ✅ User chose "OK", reset MRP
                                        setState(() {
                                          isProceed = true;
                                          mrpController.text = lastMrpFromDb.toString();
                                        });
                                      }
                                    });
                                    return; // Prevent immediate continuation
                                  }
                                }
                              }
                            }

                            // Ensure MRP is provided if closing stock > 0
                            // if (closingStock > 0 && (double.tryParse(mrpController.text.trim()) ?? 0) == 0) {
                            //   ShowAlert.showAlertDialog(context, "MRP Required", "You must enter an MRP value when Closing Stock is greater than 0.");
                            // }

                            if (wholesaleController.text.trim().isNotEmpty) {
                              // wholesale check
                              int wholesale = double.tryParse(wholesaleController.text.trim())?.round() ?? 0;

                              print('sal: $saleValue _ $wholesale');
                              if (wholesale > saleValue) {
                                // ✅ Show an alert if Wholesale is greater than Sale
                                ShowAlert.showAlertDialog(
                                    context, "Invalid Input", "Wholesale cannot be more than Total Sales!\nPlease enter a valid value.");
                                return; // ✅ Stop execution if validation fails
                              }
                            }

                            if (chilledStockController.text.trim().isNotEmpty ||
                                chilledFaceController.text.trim().isNotEmpty ||
                                warmFaceController.text.trim().isNotEmpty) {
                              // wholesale check
                              int chilledStock = double.tryParse(chilledStockController.text.trim())?.round() ?? 0;
                              int chilledFace = double.tryParse(chilledFaceController.text.trim())?.round() ?? 0;
                              int warmFace = double.tryParse(warmFaceController.text.trim())?.round() ?? 0;

                              print('sd: $closingStock _ $chilledStock _ $chilledFace _ $warmFace');
                              if (chilledStock > closingStock) {
                                ShowAlert.showAlertDialog(
                                    context, "Invalid Input", "Chilled Stock cannot be more than Closing Stock!\nPlease enter a valid value.");
                                return; // ✅ Stop execution if validation fails
                              } else if (chilledStock + warmFace > closingStock) {
                                ShowAlert.showAlertDialog(context, "Invalid Input",
                                    "Chilled Stock & Warm Face cannot be more than Closing Stock!\nPlease enter a valid value.");
                                return;
                              } else if (chilledFace > chilledStock) {
                                ShowAlert.showAlertDialog(
                                    context, "Invalid Input", "Chilled Face cannot be more than Chilled Stock!\nPlease enter a valid value.");
                                return;
                              } else if (warmFace > closingStock) {
                                ShowAlert.showAlertDialog(
                                    context, "Invalid Input", "Warm Face cannot be more than Closing Stock!\nPlease enter a valid value.");
                                return;
                              }
                            }
                          } else {
                            print("Closing stock is empty.");
                          }

                          // ✅ Insert or Update SKU data in the database
                          await dbManager.insertOrUpdateSdSkuDetails(
                            widget.dbPath,
                            widget.storeCode,
                            widget.auditorId,
                            skuItem['product_code'],
                            (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                                    ? skuItem['openstock']
                                    : skuItem['prev_closestock'])
                                .toString(),
                            purchaseController.text.trim().isNotEmpty
                                ? (double.tryParse(purchaseController.text.trim())?.round() ?? 0).toString()
                                : '',
                            closingStockController.text.trim().isNotEmpty
                                ? (double.tryParse(closingStockController.text.trim())?.round() ?? 0).toString()
                                : '',
                            saleValue.toString(),
                            chilledStockController.text.trim().isNotEmpty
                                ? (double.tryParse(chilledStockController.text.trim())?.round() ?? 0).toString()
                                : '',
                            chilledFaceController.text.trim().isNotEmpty
                                ? (double.tryParse(chilledFaceController.text.trim())?.round() ?? 0).toString()
                                : '',
                            warmFaceController.text.trim().isNotEmpty
                                ? (double.tryParse(warmFaceController.text.trim())?.round() ?? 0).toString()
                                : '',
                            wholesaleController.text.trim().isNotEmpty
                                ? (double.tryParse(wholesaleController.text.trim())?.round() ?? 0).toString()
                                : '',
                            mrpController.text.trim().isNotEmpty ? mrpController.text : '',
                            avgSaleLastMonthController.text.trim().isNotEmpty
                                ? (double.tryParse(avgSaleLastMonthController.text.trim())?.round() ?? 0).toString()
                                : '',
                            avgSaleLastToLastMonthController.text.trim().isNotEmpty
                                ? (double.tryParse(avgSaleLastToLastMonthController.text.trim())?.round() ?? 0).toString()
                                : '',
                            skuItem['index'],
                          );

                          if (purchaseController.text.trim().isNotEmpty &&
                              closingStockController.text.trim().isNotEmpty &&
                              mrpController.text.trim().isNotEmpty &&
                              saleValue >= 0 &&
                              wholesaleController.text.trim().isNotEmpty &&
                              // (double.tryParse(chilledStockController.text.trim())?.round() ?? 0) >= 0 &&
                              // (double.tryParse(chilledFaceController.text.trim())?.round() ?? 0) >= 0 &&
                              // (double.tryParse(warmFaceController.text.trim())?.round() ?? 0) >= 0 &&
                              // (double.tryParse(avgSaleLastMonthController.text.trim())?.round() ?? 0) >= 0 &&
                              // (double.tryParse(avgSaleLastToLastMonthController.text.trim())?.round() ?? 0) >= 0
                              chilledStockController.text.trim().isNotEmpty &&
                              chilledFaceController.text.trim().isNotEmpty &&
                              warmFaceController.text.trim().isNotEmpty &&
                              avgSaleLastToLastMonthController.text.trim().isNotEmpty &&
                              avgSaleLastToLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(itemName, Colors.green.shade300);
                          } else if (purchaseController.text.trim().isNotEmpty ||
                              closingStockController.text.trim().isNotEmpty ||
                              mrpController.text.trim().isNotEmpty ||
                              chilledStockController.text.trim().isNotEmpty ||
                              chilledFaceController.text.trim().isNotEmpty ||
                              warmFaceController.text.trim().isNotEmpty ||
                              avgSaleLastMonthController.text.trim().isNotEmpty ||
                              avgSaleLastToLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(itemName, Colors.yellow.shade300);
                          } else {
                            _saveColorStatus(itemName, Colors.grey.shade300);
                          }

                          ShowAlert.showSnackBar(context, 'SKU item updated successfully');
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

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message, style: const TextStyle(fontSize: 14)),
          actions: [
            // ✅ "OK" Button - Resets MRP and dismisses
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Skip", style: TextStyle(color: Colors.blue)),
            ),
            // ✅ "Continue" Button - Proceeds with update
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Continue", style: TextStyle(color: Colors.green)),
            ),
          ],
        );
      },
    ).then((value) => value ?? false); // Ensure `false` if dialog is dismissed without choice
  }

  Widget _buildEditableField(String label, String value, String itemName, skuItem, {TextEditingController? controller, Function()? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller ?? TextEditingController(text: value),
        onChanged: (text) {
          onChanged?.call();
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
    await prefs.setInt("color_${widget.storeCode}_${itemName.trim()}", color.value);

    // Save item names list explicitly
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];
    if (!editedItems.contains(itemName)) {
      editedItems.add(itemName);
      await prefs.setStringList('editedItems', editedItems);
    }
  }

  bool _allCardsGreen() {
    return filteredSkuData
        .every((item) => skuItemColors.containsKey(item['item_description']) && skuItemColors[item['item_description']] == Colors.green.shade300);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.appBarColor,
        elevation: 0,
        title: Text(
          'SKU List (${widget.storeName})',
          style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.w500, fontFamily: 'Inter'),
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

                          return Dismissible(
                            key: Key(itemName), // Unique key for each item
                            direction: DismissDirection.horizontal,
                            background: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.blue, // Swipe right background (Edit)
                              alignment: Alignment.centerLeft,
                              padding: const EdgeInsets.only(left: 20),
                              child: const Icon(Icons.edit, color: Colors.white),
                            ),
                            secondaryBackground: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              color: Colors.red, // Swipe left background (Delete)
                              alignment: Alignment.centerRight,
                              padding: const EdgeInsets.only(right: 20),
                              child: const Icon(Icons.delete, color: Colors.white),
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                if (skuItem['index'] == 'SD') {
                                  _showSdBottomSheet(skuItem);
                                } else {
                                  _showBottomSheet(skuItem);
                                }
                                return false; // Prevent actual dismiss
                              } else if (direction == DismissDirection.endToStart) {
                                bool confirmDelete = await showDialog(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                                        SizedBox(width: 10),
                                        Text("Delete SKU Item", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    content: const Text("Are you sure you want to delete this Sku Item?"),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: const Text("Cancel"),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
                                        child: const Text("Delete", style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                                return confirmDelete; // Delete only if confirmed
                              }
                              return false;
                            },
                            onDismissed: (direction) {
                              if (direction == DismissDirection.endToStart) {
                                _deleteSKU(skuItem['product_code']); // Delete the SKU item
                              }
                            },
                            child: GestureDetector(
                              onTap: () {
                                if (skuItem['index'] == 'SD') {
                                  _showSdBottomSheet(skuItem);
                                } else {
                                  _showBottomSheet(skuItem);
                                }
                              },
                              child: _buildSkuItem(
                                itemName,
                                skuItemColors[itemName] ?? Colors.grey.shade300,
                              ),
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
                                    storeName: widget.storeName,
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
                            color: _allCardsGreen() ? Colors.white : Colors.grey,
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

  void _deleteSKU(String productCode) async {
    //await DBHelper.instance.delete(id);
    await dbManager.deleteFMcgSdStoreProduct(context, widget.dbPath, widget.auditorId, widget.storeCode, productCode);
    _fetchSkuData();
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
          storeName: widget.storeName,
        ),
      ),
    );
  }

  Widget _buildSkuItem(String title, Color backgroundColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      width: double.infinity,
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
