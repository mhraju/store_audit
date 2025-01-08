import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:sqflite/sqflite.dart';

// Function to copy the database from assets to a writable directory
Future<String> copyDatabase() async {
  // Get the writable directory for the app
  final documentsDirectory = await getApplicationDocumentsDirectory();
  final dbPath = '${documentsDirectory.path}/store.sqlite';

  // Check if the database already exists
  if (!File(dbPath).existsSync()) {
    // Copy from assets
    final data = await rootBundle.load('assets/store.sqlite');
    final bytes =
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);

    // Write the database file to the documents directory
    await File(dbPath).writeAsBytes(bytes);
  }

  return dbPath;
}

// Function to fetch data from the database
Future<List<Map<String, dynamic>>> fetchStores() async {
  final dbPath =
      await copyDatabase(); // Ensure the database is in the writable directory
  final db = await openDatabase(dbPath);
  final stores = await db.query('stores'); // Query your table
  await db.close();
  return stores;
}

// Function to update the name column in the database
Future<void> updateStoreName(int id, String newName) async {
  final dbPath =
      await copyDatabase(); // Ensure the database is in the writable directory
  final db = await openDatabase(dbPath);
  await db.update(
    'stores',
    {'name': newName},
    where: 'id = ?',
    whereArgs: [id],
  );
  await db.close();
}

// Main app widget
void main() {
  runApp(MaterialApp(
    home: StoreListScreen(),
  ));
}

class StoreListScreen extends StatefulWidget {
  @override
  _StoreListScreenState createState() => _StoreListScreenState();
}

class _StoreListScreenState extends State<StoreListScreen> {
  Future<List<Map<String, dynamic>>>? _storeData;

  @override
  void initState() {
    super.initState();
    _storeData = fetchStores();
  }

  void _editStoreName(int id) {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController nameController = TextEditingController();

        return AlertDialog(
          title: Text('Update Store Name'),
          content: TextField(
            controller: nameController,
            decoration: InputDecoration(labelText: 'New Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text;
                if (newName.isNotEmpty) {
                  updateStoreName(id, newName).then((_) {
                    setState(() {
                      _storeData = fetchStores(); // Refresh the data
                    });
                  });
                }
                Navigator.of(context).pop();
              },
              child: Text('Update'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Stores')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _storeData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No data found.'));
          } else {
            final stores = snapshot.data!;
            return ListView.builder(
              itemCount: stores.length,
              itemBuilder: (context, index) {
                final store = stores[index];
                return ListTile(
                  title: Text(store['name'] ?? 'Unknown'),
                  subtitle: Text(store['address'] ?? 'No address'),
                  trailing: IconButton(
                    icon: Icon(Icons.edit),
                    onPressed: () => _editStoreName(store['id']),
                  ),
                );
              },
            );
          }
        },
      ),
    );
  }
}
