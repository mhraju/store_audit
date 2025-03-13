import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../utility/show_alert.dart';

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
        throw Exception('Failed to download database. HTTP status: ${response.statusCode}');
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
  Future<List<Map<String, dynamic>>> loadFMcgSdStores(String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final storesWithSchedules = await db.rawQuery('''
      SELECT *
      FROM stores s
      JOIN store_schedules ss
      ON s.code = ss.store_code
      WHERE s.status = 0 AND ss.employee_code = ?
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
  Future<void> updateFmcgSdStoreDetails(
    String dbPath,
    String storeCode,
    String auditorId,
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
          'updated_by': auditorId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );

      print('Store details updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }

  Future<void> closeOrUpdateFmcgSdStore(
    String dbPath,
    String storeCode,
    String auditorId,
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
          'update_status': updateStatus,
          'status_name': statusName,
          'status_short_name': statusShortName,
          'updated_by': auditorId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );
      print('Store table updated successfully for store_code: $storeCode');

      // Update the store schedule
      await db.update(
        'store_schedules', // Table name
        {
          'selfie': selfie,
          'attachment': attachment,
          'updated_by': auditorId,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'store_code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );
      print('Store Schedules table updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }

  // Call this func to get Store SKU List
  Future<List<Map<String, dynamic>>> loadFMcgSdStoreSkuList(String dbPath, String storeCode) async {
    try {
      print('storecode: $storeCode');
      final db = await loadDatabase(dbPath);

      final storeProducts = await db.rawQuery('''
  SELECT 
    sp.*, 
    p.*, 

    -- ✅ Keep current month fields, show '0' or empty if missing
    COALESCE(fsu.id, 0) AS fmcg_update_id,
    COALESCE(fsu.date, '') AS update_date,
    COALESCE(fsu.panel, '') AS panel,
    COALESCE(fsu.employee_code, '') AS employee_code,
    COALESCE(fsu.openstock, '') AS openstock,
    COALESCE(fsu.purchase, '') AS purchase,
    COALESCE(fsu.closestock, '') AS closestock,
    COALESCE(fsu.mrp, '') AS mrp,
    COALESCE(fsu.sale, '') AS sale,
    COALESCE(fsu.wholesale, '') AS wholesale,
    COALESCE(fsu.sale_last_month, '') AS sale_last_month,
    COALESCE(fsu.sale_last_to_last_month, '') AS sale_last_to_last_month,
    COALESCE(fsu.status, '') AS status,
    COALESCE(fsu.status_code, '') AS status_code,
    COALESCE(fsu.audit_type, '') AS audit_type,

    -- ✅ Always keep last month's `mrp` and `closestock` separately
    COALESCE(prev_fsu.mrp, '') AS prev_mrp,
    COALESCE(prev_fsu.closestock, '') AS prev_closestock

  FROM store_products sp
  JOIN products p ON sp.product_code = p.code

  -- ✅ Current month data from 'fmcg_store_updates'
  LEFT JOIN fmcg_store_updates fsu 
    ON sp.store_code = fsu.store_code 
    AND sp.product_code = fsu.product_code
    AND substr(fsu.date, 1, 7) = strftime('%Y-%m', 'now')  -- Current month

  -- ✅ Last month’s data from 'fmcg_store_updates' (always fetched separately)
  LEFT JOIN fmcg_store_updates prev_fsu
    ON sp.store_code = prev_fsu.store_code 
    AND sp.product_code = prev_fsu.product_code
    AND substr(prev_fsu.date, 1, 7) = strftime('%Y-%m', 'now', '-1 month')  -- Last month

  WHERE sp.store_code = ? 
  ORDER BY p.category_name, p.brand ASC;
''', [storeCode]);

      print('Length: ${storeProducts.length} _ $storeProducts');
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
    String panel,
  ) async {
    try {
      final Database db = await openDatabase(dbPath);

      // Check if the record exists
      List<Map<String, dynamic>> existingRows = await db.query(
        'fmcg_store_updates',
        where: 'store_code = ? AND product_code = ? AND substr(date, 1, 7) = strftime("%Y-%m", "now")',
        whereArgs: [storeCode, productCode],
      );

      print('mrp: $mrp');

      if (existingRows.isNotEmpty) {
        // UPDATE existing record
        await db.update(
          'fmcg_store_updates',
          {
            'date': DateTime.now().toLocal().toIso8601String().substring(0, 10), // Ensures YYYY-MM-DD format
            'panel': panel,
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'sale_last_to_last_month': avgSaleLastToLastMonth,
            'updated_by': auditorId,
            'updated_at': DateTime.now().toLocal().toIso8601String(), // Ensures timezone consistency
          },
          where: '''
    store_code = ? 
    AND product_code = ? 
    AND substr(date, 1, 7) = strftime('%Y-%m', 'now')
  ''',
          whereArgs: [storeCode, productCode],
        );
        print('Sku details updated successfully for store_code: $storeCode');
      } else {
        // INSERT new record
        await db.insert(
          'fmcg_store_updates',
          {
            'date': DateTime.now().toLocal().toIso8601String().substring(0, 10),
            'panel': panel,
            'store_code': storeCode,
            'employee_code': auditorId,
            'product_code': productCode,
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'sale_last_to_last_month': avgSaleLastToLastMonth,
            'created_by': auditorId,
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        print('Sku details insert successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating Sku details: $e');
      throw Exception('Failed to update Sku details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadFMcgSdProductsAll(String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final fmcgSdProductsAll = await db.rawQuery('SELECT * FROM products ORDER BY category_name, brand;');
      await db.close();
      return fmcgSdProductsAll;
    } catch (e) {
      print('Failed to load all Fmcg and Sd products: $e');
      return []; // Return empty list on failure
    }
  }

  // Future<List<Map<String, dynamic>>> loadFmcgSdProductCategories(String dbPath) async {
  //   try {
  //     final db = await loadDatabase(dbPath);
  //     final fmcgSdProductCategories = await db.rawQuery('''
  //     SELECT DISTINCT category_code, category_name
  //     FROM products
  //     ORDER BY category_name;
  //   ''');
  //     await db.close();
  //     return fmcgSdProductCategories;
  //   } catch (e) {
  //     print('Failed to load FMCG and SD product categories: $e');
  //     return []; // Return empty list on failure
  //   }
  // }

  Future<Map<String, List<Map<String, dynamic>>>> loadFmcgSdProductData(String dbPath) async {
    try {
      final db = await loadDatabase(dbPath);

      // Query to get distinct category_code and category_name
      final categories = await db.rawQuery('''
      SELECT DISTINCT category_code, category_name 
      FROM products 
      ORDER BY category_name;
    ''');

      // Query to get distinct company list
      final companies = await db.rawQuery('''
      SELECT DISTINCT company 
      FROM products 
      ORDER BY company;
    ''');

      // Query to get distinct pack types
      final packTypes = await db.rawQuery('''
      SELECT DISTINCT pack_type 
      FROM products 
      ORDER BY pack_type;
    ''');

      await db.close();

      return {
        'categories': categories,
        'companies': companies,
        'packTypes': packTypes,
      };
    } catch (e) {
      print('Failed to load FMCG and SD product data: $e');
      return {
        'categories': [],
        'companies': [],
        'packTypes': [],
      }; // Return empty lists on failure
    }
  }

  // Insert a record into 'store_products' table
  Future<void> insertFMcgSdStoreProduct(
    BuildContext context,
    String dbPath,
    String storeCode,
    String auditorId,
    String productCode,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      // Check if the record exists
      List<Map<String, dynamic>> existingRows = await db.query(
        'store_products',
        where: 'store_code = ? AND product_code = ?',
        whereArgs: [storeCode, productCode],
      );

      if (existingRows.isNotEmpty) {
        ShowAlert.showSnackBar(context, 'This item is already present to this store SKU list');
      } else {
        // Update the store details
        await db.insert(
          'store_products',
          {
            'store_code': storeCode,
            'product_code': productCode,
            'created_by': auditorId, // Nullable
            'created_at': DateTime.now().toIso8601String(),
          },
        );
        ShowAlert.showSnackBar(context, 'New SKU inserted successfully');
        print('New entry is inserted successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error inserting new entry: $e');
      throw Exception('Failed to insert new entry: $e');
    }
  }

  // Insert a record into 'product_introductions' table
  Future<void> insertFMcgSdProductIntro(
    String dbPath,
    String auditorId,
    String index,
    String productCode,
    String category,
    String company,
    String country,
    String brand,
    String description,
    String packType,
    String packSize,
    String promoType,
    String mrp,
    String photo1,
    String photo2,
    String photo3,
    String photo4,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      await db.insert(
        'product_introductions',
        {
          'employee_code': auditorId,
          'index': index,
          'update_code': productCode,
          'category': category,
          'company': company,
          'country': country,
          'brand': brand,
          'description': description,
          'pack_type': packType,
          'pack_size': packSize,
          'promotype': promoType,
          'mrp': mrp,
          'photo1': photo1,
          'photo2': photo2,
          'photo3': photo3,
          'photo4': photo4,
          'update_status': 1,
          'created_by': auditorId,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      print('New Intro is inserted successfully');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating new entry: $e');
      throw Exception('Failed to update new entry: $e');
    }
  }

  Future<void> insertFMcgSdProducts(
    String dbPath,
    String auditorId,
    String index,
    String productCode,
    String categoryCode,
    String categoryName,
    String company,
    String brand,
    String subBrand,
    String description,
    String packType,
    String packSize,
    String promoType,
    String mrp,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      await db.insert(
        'products',
        {
          'index': index,
          'code': productCode,
          'category_code': categoryCode,
          'category_name': categoryName,
          'company': company,
          'brand': brand,
          'sub_brand': subBrand,
          'item_description': description,
          'pack_type': packType,
          'pack_size': packSize,
          'promotype': promoType,
          'price': mrp,
          'update_status': 1,
          'created_by': auditorId,
          'created_at': DateTime.now().toIso8601String(),
        },
      );

      print('New Product is inserted successfully');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error updating new entry: $e');
      throw Exception('Failed to update new entry: $e');
    }
  }

  Future<Map<String, String>> getPrevMrpAndStockFmcgSd(
    String dbPath,
    String auditorId,
    String storeCode,
    String productCode,
  ) async {
    // Open the database
    final Database db = await openDatabase(dbPath);

    // Default values in case no data is found
    String prevMrp = '50';
    String prevClosingStock = '50';

    final result = await db.rawQuery('''
    SELECT mrp, closestock 
    FROM fmcg_store_updates 
    WHERE store_code = ? 
      AND product_code = ? 
      AND date LIKE strftime('%Y-%m', 'now', '-1 month') || '%'
    LIMIT 1;
  ''', [storeCode, productCode]);

    print(result);

    // If data exists, assign the values
    if (result.isNotEmpty) {
      if (result.first['mrp'] != null) {
        prevMrp = result.first['mrp'].toString();
      }
      if (result.first['closestock'] != null) {
        prevClosingStock = result.first['closestock'].toString();
      }
    }
    print('prev data $prevClosingStock _ $prevMrp');

    return {'prevMrp': prevMrp, 'prevClosingStock': prevClosingStock};
  }

  Future<void> deleteFMcgSdStoreProduct(
    BuildContext context,
    String dbPath,
    String auditorId,
    String storeCode,
    String productCode,
  ) async {
    try {
      // Open the database
      final Database db = await openDatabase(dbPath);

      // Perform delete operation
      int rowsDeleted = await db.delete(
        'store_products',
        where: 'store_code = ? AND product_code = ?',
        whereArgs: [storeCode, productCode],
      );

      // Show success message if any row was deleted
      if (rowsDeleted > 0) {
        ShowAlert.showSnackBar(context, 'The SKU has been deleted successfully');
        print('The SKU for store_code: $storeCode was deleted successfully.');
      } else {
        ShowAlert.showSnackBar(context, 'No matching SKU found to delete.');
        print('No SKU found for store_code: $storeCode and product_code: $productCode.');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      print('Error deleting SKU: $e');
      throw Exception('Failed to delete SKU: $e');
    }
  }
}
