import 'package:flutter/material.dart';

import '../../utility/app_colors.dart';

class FmcgSkuList extends StatefulWidget {
  const FmcgSkuList({super.key});

  @override
  State<FmcgSkuList> createState() => _FmcgSkuListState();
}

class _FmcgSkuListState extends State<FmcgSkuList> {
  List<Map<String, dynamic>> skuData = [];
  List<Map<String, dynamic>> filteredSkuData = [];
  bool isLoading = true;
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSkuData(); // Load data from the database
    searchController.addListener(_filterSkuData);
  }

  @override
  void dispose() {
    searchController.removeListener(_filterSkuData);
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSkuData() async {
    // Simulate database fetching with a delay
    await Future.delayed(const Duration(seconds: 2));

    // Mock data (replace this with your database query logic)
    final fetchedData = [
      {
        'name': 'Dabur Amla 3 Benefits Pbt 275M- Dabur-India',
        'status': 'available'
      },
      {
        'name': 'Sunsilk 160Ml Pbt Co-Creations Hair Fall Solution',
        'status': 'low_stock'
      },
      {'name': 'Cocacola 250 ml Pbt', 'status': 'out_of_stock'},
    ];

    setState(() {
      skuData = fetchedData;
      filteredSkuData = fetchedData; // Initially display all items
      isLoading = false;
    });
  }

  void _filterSkuData() {
    final query = searchController.text.toLowerCase();
    setState(() {
      filteredSkuData = skuData.where((item) {
        final name = item['name'].toLowerCase();
        return name.contains(query);
      }).toList();
    });
  }

  void _showBottomSheet(Map<String, dynamic> skuItem) {
    TextEditingController purchaseController =
        TextEditingController(text: '200');
    TextEditingController closingStockController =
        TextEditingController(text: '40');
    int saleValue = int.parse(purchaseController.text) +
        int.parse(closingStockController.text);

    // Listen for changes in inputs
    void _updateSaleValue() {
      int purchase = int.tryParse(purchaseController.text) ?? 0;
      int closingStock = int.tryParse(closingStockController.text) ?? 0;
      saleValue = purchase + closingStock;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            top: 16,
          ),
          child: SafeArea(
            // Wrap the content with SafeArea
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      skuItem['name'],
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildEditableField('Opening Stock (OS)', '40'),
                    _buildEditableField('Purchase', '200',
                        controller: purchaseController,
                        onChanged: _updateSaleValue),
                    _buildEditableField('Closing Stock (CS)', '40',
                        controller: closingStockController,
                        onChanged: _updateSaleValue),
                    _buildNonEditableField('Sale', saleValue.toString()),
                    _buildEditableField('Wholesale (WS)', '200'),
                    _buildEditableField('MRP', '200'),
                    _buildEditableField('Avg Sale Last Month', '200'),
                    _buildEditableField('Avg Sale Last to Last Month', '200'),
                    const SizedBox(height: 16),
                    Center(
                      child: ElevatedButton(
                        onPressed: () {
                          // Handle update logic here
                          Navigator.pop(context); // Close the bottom sheet
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              Colors.blue, // Set the background color to blue
                          foregroundColor:
                              Colors.white, // Set the text color to white
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

// Function to build an editable field
  Widget _buildEditableField(String label, String value,
      {TextEditingController? controller, Function()? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: controller ?? TextEditingController(text: value),
        onChanged: (text) => onChanged?.call(),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.number,
      ),
    );
  }

// Function to build a non-editable field
  Widget _buildNonEditableField(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        controller: TextEditingController(text: value),
        readOnly: true, // Make the field non-editable
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          filled: true,
          fillColor: Colors
              .grey.shade200, // Optional: Add a background color for clarity
        ),
      ),
    );
  }

  Color _getColorByStatus(String status) {
    switch (status) {
      case 'available':
        return Colors.green.shade300;
      case 'low_stock':
        return Colors.yellow.shade200;
      case 'out_of_stock':
        return Colors.grey.shade300;
      default:
        return Colors.grey.shade100;
    }
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
          // Search Bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Container(
              width:
                  double.infinity, // Ensures the TextField takes the full width
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size:
                        24, // Increase the size of the search icon (e.g., 24, 28, etc.)
                  ),
                  hintText: 'category, brand, sku type, sku size',
                  hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
                  isDense: true, // Reduces vertical padding for better fit
                  filled: true,
                  fillColor: const Color(0xFFEAEFF6),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.blueGrey, width: 1.0),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                        const BorderSide(color: Colors.blueGrey, width: 2.0),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),
          // SKU List
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredSkuData.isEmpty
                    ? const Center(child: Text('No data found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        itemCount: filteredSkuData.length,
                        itemBuilder: (context, index) {
                          final skuItem = filteredSkuData[index];
                          return GestureDetector(
                            onTap: () => _showBottomSheet(skuItem),
                            child: _buildSkuItem(
                              skuItem['name'],
                              _getColorByStatus(skuItem['status']),
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
                color: Color(0xFF60A7DA),
                border: Border(
                  top: BorderSide(color: Color(0xFF60A7DA)),
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
                            builder: (context) => const FmcgSkuList(),
                          ),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'New Entry',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.grey.shade400,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FmcgSkuList(),
                          ),
                        );
                      },
                      child: const Center(
                        child: Text(
                          'Next',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }
}
