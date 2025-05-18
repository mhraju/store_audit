// Future<List<Map<String, dynamic>>> loadFMcgSdStoreSkuList(String dbPath, String storeCode, String period) async {
//   try {
//     print('storecode: $storeCode');
//
//     // Get current device month as 'YYYY-MM'
//     DateTime now = DateTime.now();
//     String currentMonthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";
//
//     // Parse period value
//     int year = int.parse(period.substring(0, 4));
//     int month = int.parse(period.substring(4, 6));
//
//     // Previous 1 month
//     int prevMonth = month == 1 ? 12 : month - 1;
//     int prevMonthYear = month == 1 ? year - 1 : year;
//     String prevMonthStr = "$prevMonthYear-${prevMonth.toString().padLeft(2, '0')}";
//
//     // Previous 2 months
//     int prev2Month = (month <= 2) ? (12 + month - 2) : (month - 2);
//     int prev2MonthYear = (month == 1) ? year - 1 : (month == 2 ? year - 1 : year);
//     String prev2MonthStr = "$prev2MonthYear-${prev2Month.toString().padLeft(2, '0')}";
//
//     final db = await loadDatabase(dbPath);
//
//     final storeProducts = await db.rawQuery('''
//     SELECT
//       sp.*,
//       p.*,
//
//       -- Current month data (from device date)
//       COALESCE(fsu.id, 0) AS fmcg_update_id,
//       COALESCE(fsu.date, '') AS update_date,
//       COALESCE(fsu.panel, '') AS panel,
//       COALESCE(fsu.employee_code, '') AS employee_code,
//       -- ⬇️ These 2 come from period-based fsu_period
//       COALESCE(fsu_period.openstock, '') AS openstock,
//       COALESCE(fsu_period.mrp, '') AS mrp,
//       -- ⬇️ Rest from device month
//       COALESCE(fsu.purchase, '') AS purchase,
//       COALESCE(fsu.closestock, '') AS closestock,
//       COALESCE(fsu.sale, '') AS sale,
//       COALESCE(fsu.chilled_stock, '') AS chilled_stock,
//       COALESCE(fsu.chilled_face, '') AS chilled_face,
//       COALESCE(fsu.warm_face, '') AS warm_face,
//       COALESCE(fsu.wholesale, '') AS wholesale,
//       COALESCE(fsu.sale_last_month, '') AS sale_last_month,
//       COALESCE(fsu.sale_last_to_last_month, '') AS sale_last_to_last_month,
//       COALESCE(fsu.status, '') AS status,
//       COALESCE(fsu.audit_type, '') AS audit_type,
//
//       -- Fallback chain: current period, then 1 month back, then 2 months
//       CASE
//         WHEN fsu.closestock IS NOT NULL AND TRIM(fsu.closestock) != '' THEN fsu.closestock
//         WHEN prev1.closestock IS NOT NULL AND TRIM(prev1.closestock) != '' THEN prev1.closestock
//         WHEN prev2.closestock IS NOT NULL AND TRIM(prev2.closestock) != '' THEN prev2.closestock
//         ELSE ''
//       END AS prev_closestock,
//
//       CASE
//         WHEN fsu_period.mrp IS NOT NULL AND TRIM(fsu_period.mrp) != '' THEN fsu_period.mrp
//         WHEN prev1.mrp IS NOT NULL AND TRIM(prev1.mrp) != '' THEN prev1.mrp
//         WHEN prev2.mrp IS NOT NULL AND TRIM(prev2.mrp) != '' THEN prev2.mrp
//         ELSE ''
//       END AS prev_mrp
//
//     FROM store_products sp
//     JOIN products p ON sp.product_code = p.code
//
//     -- Current month based on device date
//     LEFT JOIN fmcg_store_updates fsu
//       ON sp.store_code = fsu.store_code
//       AND sp.product_code = fsu.product_code
//       AND substr(fsu.date, 1, 7) = ?
//
//     -- Period-based data for openstock and mrp
//     LEFT JOIN fmcg_store_updates fsu_period
//       ON sp.store_code = fsu_period.store_code
//       AND sp.product_code = fsu_period.product_code
//       AND fsu_period.period = ?
//
//     -- 1 month back
//     LEFT JOIN fmcg_store_updates prev1
//       ON sp.store_code = prev1.store_code
//       AND sp.product_code = prev1.product_code
//       AND substr(prev1.date, 1, 7) = ?
//
//     -- 2 months back
//     LEFT JOIN fmcg_store_updates prev2
//       ON sp.store_code = prev2.store_code
//       AND sp.product_code = prev2.product_code
//       AND substr(prev2.date, 1, 7) = ?
//
//     WHERE sp.store_code = ?
//     ORDER BY p.category_name, p.brand ASC;
//   ''', [currentMonthStr, period, prevMonthStr, prev2MonthStr, storeCode]);
//
//     print('Length: ${storeProducts.length} _ $storeProducts');
//     await db.close();
//     return storeProducts;
//   } catch (e) {
//     print('Failed to load Store SKU list: $e');
//     return [];
//   }
// }

// final TextEditingController purchaseController = TextEditingController();
//
// void _showValueEntryPopup(BuildContext context) {
//   final TextEditingController inputController = TextEditingController();
//
//   showDialog(
//     context: context,
//     builder: (context) => AlertDialog(
//       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//       title: const Text("Enter value", textAlign: TextAlign.center),
//       content: TextField(
//         controller: inputController,
//         keyboardType: TextInputType.number,
//         decoration: InputDecoration(
//           hintText: "e.g. 42+12+48+9+1",
//           filled: true,
//           fillColor: Colors.grey.shade200,
//           border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
//         ),
//       ),
//       actions: [
//         ElevatedButton(
//           onPressed: () {
//             String input = inputController.text;
//
//             // Parse and sum the expression
//             List<String> parts = input.split('+');
//             double sum = parts.fold(0, (prev, val) {
//               double? parsed = double.tryParse(val.trim());
//               return parsed != null ? prev + parsed : prev;
//             });
//
//             // Add to previous value
//             double prevValue = double.tryParse(purchaseController.text) ?? 0;
//             double total = prevValue + sum;
//
//             purchaseController.text = total.toStringAsFixed(0); // or keep .toString() for full float
//
//             Navigator.pop(context); // Close dialog
//           },
//           child: const Text("Add"),
//         )
//       ],
//     ),
//   );
// }
//
// TextFormField(
// controller: purchaseController,
// readOnly: true,
// onTap: () => _showValueEntryPopup(context),
// decoration: InputDecoration(labelText: 'Purchase'),
// )
//
//
//
//
// dependencies:
// math_expressions: ^2.2.0
//
//
// import 'package:math_expressions/math_expressions.dart';
//
// void _showValueEntryPopup(BuildContext context) {
// final TextEditingController inputController = TextEditingController();
//
// showDialog(
// context: context,
// builder: (context) => AlertDialog(
// shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
// title: const Text("Enter value", textAlign: TextAlign.center),
// content: TextField(
// controller: inputController,
// keyboardType: TextInputType.text,
// decoration: InputDecoration(
// hintText: "e.g. 42+12-5*2",
// filled: true,
// fillColor: Colors.grey.shade200,
// border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
// ),
// ),
// actions: [
// ElevatedButton(
// onPressed: () {
// try {
// // Evaluate expression
// Parser p = Parser();
// Expression exp = p.parse(inputController.text);
// double result = exp.evaluate(EvaluationType.REAL, ContextModel());
//
// // Add to previous value
// double prevValue = double.tryParse(purchaseController.text) ?? 0;
// double total = prevValue + result;
//
// purchaseController.text = total.toStringAsFixed(0);
// Navigator.pop(context);
// } catch (e) {
// Navigator.pop(context);
// ScaffoldMessenger.of(context).showSnackBar(
// const SnackBar(content: Text("Invalid expression")),
// );
// }
// },
// child: const Text("Add"),
// )
// ],
// ),
// );
// }
//
//
