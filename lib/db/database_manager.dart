import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:store_audit/utility/show_alert.dart';
import 'package:store_audit/utility/show_progress.dart';

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
      // if (File(dbPath).existsSync()) {
      //   print('Database already exists at $dbPath');
      //   return dbPath;
      // }

      // Download the database from the provided URL
      final http.Response response = await http.get(Uri.parse(databaseUrl));

      if (response.statusCode == 200) {
        // Save the database to the documents directory
        final File dbFile = File(dbPath);
        await dbFile.writeAsBytes(response.bodyBytes);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('dbPath', dbPath);
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

  // Call this func after Log in
  Future<List<Map<String, dynamic>>> loadFMcgSdStores(
      String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final storesWithSchedules = await db.rawQuery('''
  SELECT *
  FROM stores s
  JOIN store_schedules ss
  ON s.code = ss.store_code
  WHERE ss.employee_code = ?
  ORDER BY s.status, ss.date ASC;
''', [auditorId]);

      await db.close();
      return storesWithSchedules;
    } catch (e) {
      print('Failed to load stores and schedules: $e');
      return []; // Return empty list on failure
    }
  }

  // Function to update store details
  Future<void> updateStoreDetails(
    String dbPath,
    String storeCode,
    String name,
    String contact,
    String detailAddress,
    String landmark,
    String store_photo,
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
          'store_photo': store_photo,
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );

      print('✅ Store details updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }

  Future<void> closeStore(
    String dbPath,
    String storeCode,
    int status,
    int updateStatus,
    String statusName,
    String statusShortName,
    String selfie,
    String attachment,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      // Update the store
      await db.update(
        'stores', // Table name
        {
          'status': status,
          'update_status': updateStatus,
          'status_name': statusName,
          'status_short_name': statusShortName,
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );
      print('✅ Store table updated successfully for store_code: $storeCode');

      // Update the store schedule
      await db.update(
        'store_schedules', // Table name
        {
          'selfie': selfie,
          'attachment': attachment,
        },
        where:
            'store_code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );
      print(
          '✅ Store Schedules table updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }

  // Call this func to get Store SKU List
  Future<List<Map<String, dynamic>>> loadFMcgSdStoreSkuList(
      String dbPath, String storeCode) async {
    try {
      print('storecode: $storeCode');
      final db = await loadDatabase(dbPath);
      final storeProducts = await db.rawQuery('''
  SELECT 
    sp.*, 
    p.*, 
    COALESCE(fsu.id, 0) AS fmcg_update_id,
    COALESCE(fsu.date, '') AS update_date,
    COALESCE(fsu.panel, '') AS panel,
    COALESCE(fsu.employee_code, '') AS employee_code,
    COALESCE(fsu.openstock, 0) AS openstock,
    COALESCE(fsu.purchase, 0) AS purchase,
    COALESCE(fsu.closestock, 0) AS closestock,
    COALESCE(fsu.sale, 0) AS sale,
    COALESCE(fsu.wholesale, 0) AS wholesale,
    COALESCE(fsu.sale_last_month, 0) AS sale_last_month,
    COALESCE(fsu.status, '') AS status,
    COALESCE(fsu.status_code, '') AS status_code,
    COALESCE(fsu.audit_type, '') AS audit_type
  FROM store_products sp
  JOIN products p ON sp.product_code = p.code
  LEFT JOIN fmcg_store_updates fsu 
  ON sp.store_code = fsu.store_code AND sp.product_code = fsu.product_code
  WHERE sp.store_code = ?
  ORDER BY p.category_name, p.brand ASC;
''', [storeCode]);

      print(storeProducts);
      await db.close();
      return storeProducts;
    } catch (e) {
      print('Failed to load Store SKU list: $e');
      return []; // Return empty list on failure
    }
  }

  // Function to update SKU details
  Future<void> insertOrUpdateFmcgSdSkuDetails(
    String dbPath,
    String storeCode,
    String auditorId,
    String productCode,
    String openStock,
    String purchase,
    String closeStock,
    String sale,
    String wholesale,
    String mrp,
    String avgSaleLastMonth,
    String avgSaleLastToLastMonth,
  ) async {
    try {
      final Database db = await openDatabase(dbPath);

      // Check if the record exists
      List<Map<String, dynamic>> existingRows = await db.query(
        'fmcg_store_updates',
        where: 'store_code = ? AND product_code = ?',
        whereArgs: [storeCode, productCode],
      );

      if (existingRows.isNotEmpty) {
        // ✅ UPDATE existing record
        await db.update(
          'fmcg_store_updates',
          {
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'Sale_last_to_last_month': avgSaleLastToLastMonth,
            'updated_by': auditorId,
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'store_code = ? AND product_code = ?',
          whereArgs: [storeCode, productCode],
        );
        print('✅ Sku details updated successfully for store_code: $storeCode');
      } else {
        // ✅ INSERT new record
        await db.insert(
          'fmcg_store_updates',
          {
            'store_code': storeCode,
            'product_code': productCode,
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'Sale_last_to_last_month': avgSaleLastToLastMonth,
            'created_by': auditorId,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        print('✅ Sku details insert successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating Sku details: $e');
      throw Exception('Failed to update Sku details: $e');
    }
  }

  // Call this func after Log in
  Future<List<Map<String, dynamic>>> loadFMcgSdProductsAll(
      String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final fmcgSdProductsAll = await db
          .rawQuery('SELECT * FROM products ORDER BY category_name, brand;');
      await db.close();
      return fmcgSdProductsAll;
    } catch (e) {
      print('Failed to load all Fmcg and Sd products: $e');
      return []; // Return empty list on failure
    }
  }

  Future<List<String>> loadFmcgSdProductCategories(String dbPath) async {
    try {
      final db = await loadDatabase(dbPath);
      // Fetch DISTINCT category_name values sorted alphabetically
      final List<Map<String, dynamic>> result = await db.rawQuery(
          'SELECT DISTINCT category_name FROM products ORDER BY category_name ASC;');
      await db.close();
      // Convert to List<String>
      return result.map((row) => row['category_name'] as String).toList();
    } catch (e) {
      print('Failed to load categories: $e');
      return []; // Return an empty list if an error occurs
    }
  }

  // Insert a record into 'store_products' table
  Future<void> insertFMcgSdStoreProduct(
    String dbPath,
    String storeCode,
    String auditorId,
    String productCode,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      // Update the store details
      await db.insert(
        'store_products',
        {
          'store_code': storeCode,
          'product_code': productCode,
          'created_by': auditorId, // Nullable
          'updated_by': auditorId, // Nullable
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        },
      );

      print('✅ New entry is updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating new entry: $e');
      throw Exception('Failed to update new entry: $e');
    }
  }
}
