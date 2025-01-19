import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseManager {
  // Get the database URL dynamically using the auditor ID
  Future<String> _getDatabaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final String? dbUrl = prefs.getString('dbUrl');
    if (dbUrl == null) {
      throw Exception('Database URL is not available in SharedPreferences.');
    }
    return dbUrl;
  }

  // Function to download the database and save it locally
  Future<String> downloadAndSaveUserDatabase() async {
    try {
      // Get the database URL dynamically
      final String databaseUrl = await _getDatabaseUrl();

      // Get the app's documents directory
      final Directory appDocDir = await getApplicationDocumentsDirectory();
      final String dbPath = '${appDocDir.path}/user.sqlite';

      // Check if the database already exists
      if (File(dbPath).existsSync()) {
        print('Database already exists at $dbPath');
        return dbPath;
      }

      // Download the database from the provided URL
      final http.Response response = await http.get(Uri.parse(databaseUrl));

      if (response.statusCode == 200) {
        // Save the database to the documents directory
        final File dbFile = File(dbPath);
        await dbFile.writeAsBytes(response.bodyBytes);
        print('Database downloaded and saved at $dbPath');
        return dbPath;
      } else {
        throw Exception(
            'Failed to download database. HTTP status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error downloading database: $e');
    }
  }

  // Function to load the SQLite database
  Future<Database> loadDatabase(String dbPath) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);
      print('Database loaded successfully from $dbPath');
      return db;
    } catch (e) {
      throw Exception('Error loading database: $e');
    }
  }

  // Function to update store details
  Future<void> updateStoreDetails(
    String dbPath,
    int storeId,
    String name,
    String contact,
    String detailAddress,
    String landmark,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      // Update the store details
      await db.update(
        'stores', // Table name
        {
          'name': name,
          'phone1': contact,
          'address': detailAddress,
          'land_mark': landmark,
        },
        where: 'id = ?', // Condition to match the specific row
        whereArgs: [storeId], // Arguments for the condition
      );

      print('Store details updated successfully for store ID: $storeId');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }
}
