import 'dart:async';
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:store_audit/presentation/screens/tobacco/tobacco_new_entry.dart';
import 'package:store_audit/presentation/screens/tobacco/tobacco_store_audit.dart';
import 'package:store_audit/utility/show_alert.dart';
import '../../../db/database_manager.dart';
import '../../../utility/app_colors.dart';

class TobaccoSkuList extends StatefulWidget {
  final String dbPath;
  final String storeCode;
  final String auditorId;
  final String option;
  final String shortCode;
  final String storeName;
  final String period;
  final int priority;
  const TobaccoSkuList({
    super.key,
    required this.dbPath,
    required this.storeCode,
    required this.auditorId,
    required this.option,
    required this.shortCode,
    required this.storeName,
    required this.period,
    required this.priority,
  });

  @override
  State<TobaccoSkuList> createState() => _TobaccoSkuListState();
}

class _TobaccoSkuListState extends State<TobaccoSkuList> {
  List<Map<String, dynamic>> skuData = [];
  List<Map<String, dynamic>> filteredSkuData = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController(); // Store field updates
  final DatabaseManager dbManager = DatabaseManager();
  Map<String, Color> skuItemColors = {}; // ✅ Store colors for each SKU item
  late List<String> savedSkus;

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

    final fetchedData = await dbManager.loadFMcgSdStoreSkuList(
      widget.dbPath,
      widget.storeCode,
      widget.period,
    );

    final prefs = await SharedPreferences.getInstance();
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];

    // Restore stored colors
    Map<String, Color> restoredColors = {};
    for (var item in fetchedData) {
      String productCode = item['product_code'];
      if (editedItems.contains(productCode)) {
        int? colorValue = prefs.getInt("color_${widget.storeCode}_$productCode");
        restoredColors[productCode] = (colorValue != null) ? Color(colorValue) : Colors.grey.shade300;
      } else {
        restoredColors[productCode] = Colors.grey.shade300;
      }
    }

    savedSkus = prefs.getStringList('newEntry') ?? [];

    // Make a mutable copy of fetchedData for sorting
    final mutableFetchedData = List<Map<String, dynamic>>.from(fetchedData);

    // Sort based on color priority: Grey -> Yellow -> Green
    mutableFetchedData.sort((a, b) {
      String codeA = a['product_code'];
      String codeB = b['product_code'];
      Color colorA = restoredColors[codeA] ?? Colors.grey.shade300;
      Color colorB = restoredColors[codeB] ?? Colors.grey.shade300;

      int getColorPriority(Color color) {
        final int grey = Colors.grey.shade300.value;
        final int yellow = Colors.yellow.shade300.value;
        final int green = Colors.green.shade300.value;

        if (color.value == grey) return 0;
        if (color.value == yellow) return 1;
        if (color.value == green) return 2;
        return 3; // fallback for any other color
      }

      return getColorPriority(colorA).compareTo(getColorPriority(colorB));
    });

    setState(() {
      skuData = mutableFetchedData;
      filteredSkuData = mutableFetchedData;
      skuItemColors = restoredColors;
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
    TextEditingController stickPriceController = TextEditingController(text: getTextFieldValue(skuItem['stick_price']));
    TextEditingController packPriceController = TextEditingController(text: getTextFieldValue(skuItem['pack_price']));
    TextEditingController avgSaleDailyThisWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_this_week']));
    TextEditingController avgSaleDailyLastWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_week']));
    TextEditingController avgSaleDailyLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_month']));

    void showValueEntryPopup(BuildContext context, TextEditingController targetController) {
      final TextEditingController inputController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Enter value",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: inputController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              hintText: "type 42+12-5+2",
              hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  Parser p = Parser();
                  Expression exp = p.parse(inputController.text.trim());
                  double result = exp.evaluate(EvaluationType.REAL, ContextModel());

                  double prevValue = double.tryParse(targetController.text) ?? 0;
                  double total = prevValue + result;
                  targetController.text = total.toStringAsFixed(0);

                  //updateSaleValue();
                  Navigator.pop(context);
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid expression")),
                  );
                }
              },
              child: const Text("Add"),
            )
          ],
        ),
      );
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
                      'Last Audit Date',
                      (skuItem['last_audit'] != null && skuItem['last_audit'].toString().trim().isNotEmpty
                              ? skuItem['last_audit']
                              : skuItem['last_audit'])
                          .toString(),
                    ),

                    // Editable Fields
                    _buildCustomEditableField(
                      'Purchase',
                      skuItem['purchase']?.toString() ?? '',
                      itemName,
                      skuItem,
                      controller: purchaseController,
                      onTap: () => showValueEntryPopup(context, purchaseController),
                    ),


                    _buildEditableField('Pack Price', skuItem['pack_price']?.toString() ?? '', itemName, skuItem, controller: packPriceController),
                    _buildEditableField('Stick Price', skuItem['stick_price']?.toString() ?? '', itemName, skuItem, controller: stickPriceController),
                    _buildEditableField('Avg Daily Sale This Week', skuItem['sale_daily_this_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyThisWeekController),
                    _buildEditableField('Avg Daily Sale Last Week', skuItem['sale_daily_last_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastWeekController),
                    _buildEditableField('Avg Daily Sale Last Month', skuItem['sale_daily_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          // ✅ Insert or Update SKU data in the database
                          // await dbManager.insertOrUpdateFmcgSkuDetails(
                          //   widget.dbPath,
                          //   widget.storeCode,
                          //   widget.auditorId,
                          //   skuItem['product_code'],
                          //   (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                          //           ? skuItem['openstock']
                          //           : skuItem['prev_closestock'])
                          //       .toString(),
                          //   purchaseController.text.trim().isNotEmpty
                          //       ? (double.tryParse(purchaseController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   packPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(packPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   stickPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(stickPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyThisWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyThisWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastMonthController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastMonthController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   skuItem['index'],
                          //   widget.period,
                          //   1,
                          // );

                          if (purchaseController.text.trim().isNotEmpty &&
                              packPriceController.text.trim().isNotEmpty &&
                              stickPriceController.text.trim().isNotEmpty &&
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else if (purchaseController.text.trim().isNotEmpty ||
                              packPriceController.text.trim().isNotEmpty ||
                              stickPriceController.text.trim().isNotEmpty ||
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else {
                            _saveColorStatus(skuItem['product_code'], Colors.grey.shade300);
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

  void _showBottomSheetForTwo(Map<String, dynamic> skuItem) {
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
    TextEditingController stickPriceController = TextEditingController(text: getTextFieldValue(skuItem['stick_price']));
    TextEditingController packPriceController = TextEditingController(text: getTextFieldValue(skuItem['pack_price']));
    TextEditingController avgSaleDailyThisWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_this_week']));
    TextEditingController avgSaleDailyLastWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_week']));
    TextEditingController avgSaleDailyLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_month']));

    void showValueEntryPopup(BuildContext context, String type) {
      final TextEditingController inputController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Enter value",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              )),
          content: TextField(
            controller: inputController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              hintText: "type 42+12-5+2",
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  // Evaluate expression
                  Parser p = Parser();
                  Expression exp = p.parse(inputController.text);
                  double result = exp.evaluate(EvaluationType.REAL, ContextModel());
                  double prevValue = double.tryParse(purchaseController.text) ?? 0;
                  double total = prevValue + result;
                  purchaseController.text = total.toStringAsFixed(0);
                  Navigator.pop(context);
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid expression")),
                  );
                }
              },
              child: const Text("Add"),
            )
          ],
        ),
      );
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
                      'Last Audit Date',
                      (skuItem['last_audit'] != null && skuItem['last_audit'].toString().trim().isNotEmpty
                              ? skuItem['last_audit']
                              : skuItem['last_audit'])
                          .toString(),
                    ),
                    _buildNonEditableField(
                      'Last Purchase',
                      (skuItem['last_purchase'] != null && skuItem['last_purchase'].toString().trim().isNotEmpty
                              ? skuItem['last_purchase']
                              : skuItem['last_purchase'])
                          .toString(),
                    ),

                    // Editable Fields
                    _buildEditableField(
                      'New Purchase',
                      skuItem['purchase']?.toString() ?? '',
                      itemName,
                      skuItem,
                      controller: purchaseController,
                      onTap: () => showValueEntryPopup(context, 'ps'),
                    ),

                    _buildEditableField('Pack Price', skuItem['pack_price']?.toString() ?? '', itemName, skuItem, controller: packPriceController),
                    _buildEditableField('Stick Price', skuItem['stick_price']?.toString() ?? '', itemName, skuItem, controller: stickPriceController),
                    _buildEditableField('Avg Daily Sale This Week', skuItem['sale_daily_this_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyThisWeekController),
                    _buildEditableField('Avg Daily Sale Last Week', skuItem['sale_daily_last_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastWeekController),
                    _buildEditableField('Avg Daily Sale Last Month', skuItem['sale_daily_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          // ✅ Insert or Update SKU data in the database
                          // await dbManager.insertOrUpdateFmcgSkuDetails(
                          //   widget.dbPath,
                          //   widget.storeCode,
                          //   widget.auditorId,
                          //   skuItem['product_code'],
                          //   (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                          //           ? skuItem['openstock']
                          //           : skuItem['prev_closestock'])
                          //       .toString(),
                          //   purchaseController.text.trim().isNotEmpty
                          //       ? (double.tryParse(purchaseController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   packPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(packPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   stickPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(stickPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyThisWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyThisWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastMonthController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastMonthController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   skuItem['index'],
                          //   widget.period,
                          //   1,
                          // );

                          if (purchaseController.text.trim().isNotEmpty &&
                              packPriceController.text.trim().isNotEmpty &&
                              stickPriceController.text.trim().isNotEmpty &&
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else if (purchaseController.text.trim().isNotEmpty ||
                              packPriceController.text.trim().isNotEmpty ||
                              stickPriceController.text.trim().isNotEmpty ||
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else {
                            _saveColorStatus(skuItem['product_code'], Colors.grey.shade300);
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

  void _showBottomSheetForThree(Map<String, dynamic> skuItem) {
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
    TextEditingController stickPriceController = TextEditingController(text: getTextFieldValue(skuItem['stick_price']));
    TextEditingController packPriceController = TextEditingController(text: getTextFieldValue(skuItem['pack_price']));
    TextEditingController avgSaleDailyThisWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_this_week']));
    TextEditingController avgSaleDailyLastWeekController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_week']));
    TextEditingController avgSaleDailyLastMonthController = TextEditingController(text: getTextFieldValue(skuItem['sale_daily_last_month']));

    void showValueEntryPopup(BuildContext context, String type) {
      final TextEditingController inputController = TextEditingController();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          title: const Text("Enter value",
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.bold,
              )),
          content: TextField(
            controller: inputController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
            decoration: InputDecoration(
              hintText: "type 42+12-5+2",
              hintStyle: const TextStyle(
                color: Colors.grey,
                fontSize: 14,
              ),
              filled: true,
              fillColor: Colors.grey.shade200,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                try {
                  // Evaluate expression
                  Parser p = Parser();
                  Expression exp = p.parse(inputController.text);
                  double result = exp.evaluate(EvaluationType.REAL, ContextModel());
                  double prevValue = double.tryParse(purchaseController.text) ?? 0;
                  double total = prevValue + result;
                  purchaseController.text = total.toStringAsFixed(0);
                  Navigator.pop(context);
                } catch (e) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Invalid expression")),
                  );
                }
              },
              child: const Text("Add"),
            )
          ],
        ),
      );
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
                      'Last Audit Date',
                      (skuItem['last_audit'] != null && skuItem['last_audit'].toString().trim().isNotEmpty
                          ? skuItem['last_audit']
                          : skuItem['last_audit'])
                          .toString(),
                    ),
                    _buildNonEditableField(
                      'Last Purchase',
                      (skuItem['last_purchase'] != null && skuItem['last_purchase'].toString().trim().isNotEmpty
                          ? skuItem['last_purchase']
                          : skuItem['last_purchase'])
                          .toString(),
                    ),

                    // Editable Fields
                    _buildEditableField(
                      'New Purchase',
                      skuItem['purchase']?.toString() ?? '',
                      itemName,
                      skuItem,
                      controller: purchaseController,
                      onTap: () => showValueEntryPopup(context, 'ps'),
                    ),

                    _buildEditableField('Pack Price', skuItem['pack_price']?.toString() ?? '', itemName, skuItem, controller: packPriceController),
                    _buildEditableField('Stick Price', skuItem['stick_price']?.toString() ?? '', itemName, skuItem, controller: stickPriceController),
                    _buildEditableField('Avg Daily Sale This Week', skuItem['sale_daily_this_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyThisWeekController),
                    _buildEditableField('Avg Daily Sale Last Week', skuItem['sale_daily_last_week']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastWeekController),
                    _buildEditableField('Avg Daily Sale Last Month', skuItem['sale_daily_last_month']?.toString() ?? '', itemName, skuItem,
                        controller: avgSaleDailyLastMonthController),

                    const SizedBox(height: 16),

                    // Update Button
                    Center(
                      child: ElevatedButton(
                        onPressed: () async {
                          // ✅ Insert or Update SKU data in the database
                          // await dbManager.insertOrUpdateFmcgSkuDetails(
                          //   widget.dbPath,
                          //   widget.storeCode,
                          //   widget.auditorId,
                          //   skuItem['product_code'],
                          //   (skuItem['openstock'] != null && skuItem['openstock'].toString().trim().isNotEmpty
                          //           ? skuItem['openstock']
                          //           : skuItem['prev_closestock'])
                          //       .toString(),
                          //   purchaseController.text.trim().isNotEmpty
                          //       ? (double.tryParse(purchaseController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   packPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(packPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   stickPriceController.text.trim().isNotEmpty
                          //       ? (double.tryParse(stickPriceController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyThisWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyThisWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastWeekController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastWeekController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   avgSaleDailyLastMonthController.text.trim().isNotEmpty
                          //       ? (double.tryParse(avgSaleDailyLastMonthController.text.trim())?.round() ?? 0).toString()
                          //       : '',
                          //   skuItem['index'],
                          //   widget.period,
                          //   1,
                          // );

                          if (purchaseController.text.trim().isNotEmpty &&
                              packPriceController.text.trim().isNotEmpty &&
                              stickPriceController.text.trim().isNotEmpty &&
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty &&
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else if (purchaseController.text.trim().isNotEmpty ||
                              packPriceController.text.trim().isNotEmpty ||
                              stickPriceController.text.trim().isNotEmpty ||
                              avgSaleDailyThisWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastWeekController.text.trim().isNotEmpty ||
                              avgSaleDailyLastMonthController.text.trim().isNotEmpty) {
                            _saveColorStatus(skuItem['product_code'], Colors.yellow.shade300);
                          } else {
                            _saveColorStatus(skuItem['product_code'], Colors.grey.shade300);
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


  Widget _buildCustomEditableField(
      String label,
      String value,
      String itemName,
      Map<String, dynamic> skuItem, {
        required TextEditingController controller,
        required VoidCallback onTap,
      }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16.0), // spacing between fields
        child: AbsorbPointer(
          child: TextField(
            controller: TextEditingController(
                text: controller.text.isNotEmpty ? controller.text : value),
            enabled: false, // disables editing but keeps look
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(
                color: Colors.black54,  // <-- label color
                //fontWeight: FontWeight.w600,
              ),
              filled: true,
              //fillColor: Colors.white, // matches your light bg
              border: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.grey.shade200,
                  width: 1,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
            ),
            style: const TextStyle(
              fontSize: 16,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEditableField(
    String label,
    String value,
    String itemName,
    skuItem, {
    TextEditingController? controller,
    Function()? onChanged,
    Function()? onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller ?? TextEditingController(text: value),
        onChanged: (text) {
          onChanged?.call();
        },
        onTap: onTap,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
        // keyboardType: onTap != null
        //     ? TextInputType.text // if onTap is defined, use text
        //     : TextInputType.number, // else use number
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

  Future<void> _saveColorStatus(String productCode, Color color) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt("color_${widget.storeCode}_$productCode", color.value);

    // Save item names list explicitly
    List<String> editedItems = prefs.getStringList('editedItems') ?? [];
    if (!editedItems.contains(productCode)) {
      editedItems.add(productCode);
      await prefs.setStringList('editedItems', editedItems);
    }
  }

  bool _allCardsGreen() {
    return filteredSkuData
        .every((item) => skuItemColors.containsKey(item['product_code']) && skuItemColors[item['product_code']] == Colors.green.shade300);
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
                  borderSide: BorderSide.none,
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
                          // String itemName = "${skuItem['product_code']} - ${skuItem['item_description']}";
                          String productCode = skuItem['product_code'];

                          return Dismissible(
                            key: Key(productCode), // Unique key for each item
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
                                if (widget.priority == 1) {
                                  _showBottomSheetForTwo(skuItem);
                                } else if (widget.priority == 2) {
                                  _showBottomSheet(skuItem);
                                } else {
                                  //_showBottomSheetForThree(skuItem);
                                }
                                return false; // Prevent actual dismiss
                              } else if (direction == DismissDirection.endToStart) {
                                if (!(productCode.contains('temp') || savedSkus.contains(productCode))) {
                                  ShowAlert.showSnackBar(context, "You can't delete this SKU item");
                                  return false; // Do not show dialog or dismiss
                                }

                                bool confirmDelete = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Row(
                                          children: [
                                            Icon(Icons.warning_amber_rounded, color: Colors.red, size: 30),
                                            SizedBox(width: 10),
                                            Text(
                                              "Delete SKU Item",
                                              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                                            ),
                                          ],
                                        ),
                                        content: const Text("Are you sure you want to delete this SKU item?"),
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
                                    ) ??
                                    false;

                                return confirmDelete; // Dismiss only if confirmed
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
                                if (widget.priority == 1) {
                                  _showBottomSheetForTwo(skuItem);
                                } else if (widget.priority == 2) {
                                  _showBottomSheet(skuItem);
                                } else {
                                  //_showBottomSheetForThree(skuItem);
                                }
                              },
                              child: _buildSkuItem(
                                itemName,
                                skuItemColors[productCode] ?? Colors.grey.shade300,
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
                              builder: (context) => TobaccoNewEntry(
                                    dbPath: widget.dbPath,
                                    storeCode: widget.storeCode,
                                    auditorId: widget.auditorId,
                                    option: widget.option,
                                    shortCode: widget.shortCode,
                                    storeName: widget.storeName,
                                    period: widget.period,
                                    priority: widget.priority,
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
        builder: (context) => TobaccoStoreAudit(
          dbPath: widget.dbPath,
          storeCode: widget.storeCode,
          auditorId: widget.auditorId,
          option: widget.option,
          shortCode: widget.shortCode,
          storeName: widget.storeName,
          priority: widget.priority,
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
