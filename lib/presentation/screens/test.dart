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
