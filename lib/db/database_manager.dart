import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
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
        //print('Database downloaded and saved at $dbPath');
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
      //print('Database loaded successfully from $dbPath');
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
      WHERE s.status = 1 AND (ss.`index` = "FMCG" OR ss.`index` = "Fmcg" OR ss.`index` = "SD" OR ss.`index` = "Sd") AND ss.employee_code = ?
      ORDER BY s.status, ss.date ASC;
    ''', [auditorId]);

      await db.close();
      return storesWithSchedules;
    } catch (e) {
      //print('Failed to load stores and schedules: $e');
      return []; // Return empty list on failure
    }
  }

  // Function to update store details
  Future<void> updateStoreDetails(
    String dbPath,
    String storeCode,
    String auditorId,
    String name,
    String contact,
    String detailAddress,
    String landmark,
    String store_photo,
    String newGeo,
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
          'new_geo': newGeo,
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );

      //print('Store details updated successfully for store_code: $storeCode');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error updating store details: $e');
      throw Exception('Failed to update store details: $e');
    }
  }

  Future<void> closeOrUpdateStore(
    String dbPath,
    String storeCode,
    String auditorId,
    int status,
    int updateStatus,
    String statusName,
    String statusShortName,
    String selfie,
    String attachment,
    int priority,
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
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        where: 'code COLLATE NOCASE = ?', // Ensures case-insensitive matching
        whereArgs: [storeCode],
      );

      // Update the store schedule
      await db.update(
        'store_schedules', // Table name
        {
          'priority': priority,
          'selfie': selfie,
          'status': status,
          'attachment': attachment,
          'update_status': updateStatus,
          'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
        where: 'store_code COLLATE NOCASE = ? AND priority = ?', // Combined condition
        whereArgs: [storeCode, priority],
      );

      // Close the database
      await db.close();
    } catch (e) {
      throw Exception('Failed to update store details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadFMcgSdStoreSkuList(String dbPath, String storeCode, String period) async {
    try {
      //print('period: $period');

      // Get current device month as 'YYYY-MM'
      DateTime now = DateTime.now();
      String currentMonthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      // Parse period value
      int year = int.parse(period.substring(0, 4));
      int month = int.parse(period.substring(4, 6));

      // Previous 1 month
      int prevMonth = month == 1 ? 12 : month - 1;
      int prevMonthYear = month == 1 ? year - 1 : year;
      String prevMonthStr = "$prevMonthYear-${prevMonth.toString().padLeft(2, '0')}";

      // Previous 2 months
      int prev2Month = (month <= 2) ? (12 + month - 2) : (month - 2);
      int prev2MonthYear = (month == 1) ? year - 1 : (month == 2 ? year - 1 : year);
      String prev2MonthStr = "$prev2MonthYear-${prev2Month.toString().padLeft(2, '0')}";

      final db = await loadDatabase(dbPath);

      final storeProducts = await db.rawQuery('''
    SELECT
      sp.*,
      p.*,

      -- Current month data (from device date)
      COALESCE(fsu.id, 0) AS fmcg_update_id,
      COALESCE(fsu.date, '') AS update_date,
      COALESCE(fsu.panel, '') AS panel,
      COALESCE(fsu.employee_code, '') AS employee_code,
      COALESCE(fsu.openstock, '') AS openstock,
      COALESCE(fsu.mrp, '') AS mrp,
      COALESCE(fsu.purchase, '') AS purchase,
      COALESCE(fsu.closestock, '') AS closestock,
      COALESCE(fsu.sale, '') AS sale,
      COALESCE(fsu.chilled_stock, '') AS chilled_stock,
      COALESCE(fsu.chilled_face, '') AS chilled_face,
      COALESCE(fsu.warm_face, '') AS warm_face,
      COALESCE(fsu.wholesale, '') AS wholesale,
      COALESCE(fsu.sale_last_month, '') AS sale_last_month,
      COALESCE(fsu.sale_last_to_last_month, '') AS sale_last_to_last_month,
      COALESCE(fsu.status, '') AS status,
      COALESCE(fsu.audit_type, '') AS audit_type,

      -- Fallback chain: current period, then 1 month back, then 2 months
      CASE
        WHEN fsu_period.closestock IS NOT NULL AND TRIM(fsu_period.closestock) != '' THEN fsu_period.closestock
        WHEN prev1.closestock IS NOT NULL AND TRIM(prev1.closestock) != '' THEN prev1.closestock
        WHEN prev2.closestock IS NOT NULL AND TRIM(prev2.closestock) != '' THEN prev2.closestock
        ELSE ''
      END AS prev_closestock,

      CASE
        WHEN fsu_period.mrp IS NOT NULL AND TRIM(fsu_period.mrp) != '' THEN fsu_period.mrp
        WHEN prev1.mrp IS NOT NULL AND TRIM(prev1.mrp) != '' THEN prev1.mrp
        WHEN prev2.mrp IS NOT NULL AND TRIM(prev2.mrp) != '' THEN prev2.mrp
        ELSE ''
      END AS prev_mrp

    FROM store_products sp
    JOIN products p ON sp.product_code = p.code

    -- Current month based on device date
    LEFT JOIN fmcg_store_updates fsu
      ON sp.store_code = fsu.store_code
      AND sp.product_code = fsu.product_code
      AND substr(fsu.date, 1, 7) = ?

    -- Period-based data for openstock and mrp
    LEFT JOIN fmcg_store_updates fsu_period
      ON sp.store_code = fsu_period.store_code
      AND sp.product_code = fsu_period.product_code
      AND fsu_period.period = ?

    -- 1 month back
    LEFT JOIN fmcg_store_updates prev1
      ON sp.store_code = prev1.store_code
      AND sp.product_code = prev1.product_code
      AND substr(prev1.date, 1, 7) = ?

    -- 2 months back
    LEFT JOIN fmcg_store_updates prev2
      ON sp.store_code = prev2.store_code
      AND sp.product_code = prev2.product_code
      AND substr(prev2.date, 1, 7) = ?

    WHERE sp.store_code = ?
    ORDER BY p.category_name, p.brand ASC;
  ''', [currentMonthStr, period, prevMonthStr, prev2MonthStr, storeCode]);

      //print('Length: ${storeProducts.length} _ $storeProducts');
      await db.close();
      return storeProducts;
    } catch (e) {
      //print('Failed to load Store SKU list: $e');
      return [];
    }
  }

  // Call this func to get Store SKU List
//   Future<List<Map<String, dynamic>>> loadFMcgSdStoreSkuList(String dbPath, String storeCode, String period) async {
//     try {
//       print('storecode: $storeCode');
//       final db = await loadDatabase(dbPath);
//
//       final storeProducts = await db.rawQuery('''
//   SELECT
//     sp.*,
//     p.*,
//
//     -- ✅ Keep current month fields, show '0' or empty if missing
//     COALESCE(fsu.id, 0) AS fmcg_update_id,
//     COALESCE(fsu.date, '') AS update_date,
//     COALESCE(fsu.panel, '') AS panel,
//     COALESCE(fsu.employee_code, '') AS employee_code,
//     COALESCE(fsu.openstock, '') AS openstock,
//     COALESCE(fsu.purchase, '') AS purchase,
//     COALESCE(fsu.closestock, '') AS closestock,
//     COALESCE(fsu.mrp, '') AS mrp,
//     COALESCE(fsu.sale, '') AS sale,
//     COALESCE(fsu.chilled_stock, '') AS chilled_stock,
//     COALESCE(fsu.chilled_face, '') AS chilled_face,
//     COALESCE(fsu.warm_face, '') AS warm_face,
//     COALESCE(fsu.wholesale, '') AS wholesale,
//     COALESCE(fsu.sale_last_month, '') AS sale_last_month,
//     COALESCE(fsu.sale_last_to_last_month, '') AS sale_last_to_last_month,
//     COALESCE(fsu.status, '') AS status,
//     COALESCE(fsu.audit_type, '') AS audit_type,
//
//     -- ✅ Always keep last month's `mrp` and `closestock` separately
//     COALESCE(prev_fsu.mrp, '') AS prev_mrp,
//     COALESCE(prev_fsu.closestock, '') AS prev_closestock
//
//   FROM store_products sp
//   JOIN products p ON sp.product_code = p.code
//
//   -- ✅ Current month data from 'fmcg_store_updates'
//   LEFT JOIN fmcg_store_updates fsu
//     ON sp.store_code = fsu.store_code
//     AND sp.product_code = fsu.product_code
//     AND substr(fsu.date, 1, 7) = strftime('%Y-%m', 'now')  -- Current month
//
//   -- ✅ Last month’s data from 'fmcg_store_updates' (always fetched separately)
//   LEFT JOIN fmcg_store_updates prev_fsu
//     ON sp.store_code = prev_fsu.store_code
//     AND sp.product_code = prev_fsu.product_code
//     AND substr(prev_fsu.date, 1, 7) = strftime('%Y-%m', 'now', '-1 month')  -- Last month
//
//   WHERE sp.store_code = ?
//   ORDER BY p.category_name, p.brand ASC;
// ''', [storeCode]);
//
//       print('Length: ${storeProducts.length} _ $storeProducts');
//       await db.close();
//       return storeProducts;
//     } catch (e) {
//       print('Failed to load Store SKU list: $e');
//       return []; // Return empty list on failure
//     }
//   }

  // Function to update Fmcg SKU details
  Future<void> insertOrUpdateFmcgSkuDetails(
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
    String period,
    int updateStatus,
  ) async {
    try {
      final Database db = await openDatabase(dbPath);

      // Check if the record exists
      List<Map<String, dynamic>> existingRows = await db.query(
        'fmcg_store_updates',
        where: '''
    store_code = ? AND
    product_code = ? AND
    date(substr(date, 1, 7) || '-01') >= date('now', '-1 month', 'start of month')
  ''',
        whereArgs: [storeCode, productCode],
        orderBy: 'date DESC',
      );

      //print('mrp: $mrp');

      if (existingRows.isNotEmpty) {
        // UPDATE existing record
        await db.update(
          'fmcg_store_updates',
          {
            'period': period,
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
            'status': '1',
            'update_status': updateStatus,
            'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          },
          where: '''
    store_code = ? 
    AND product_code = ? 
    AND date(substr(date, 1, 7) || '-01') >= date('now', '-1 month', 'start of month')
  ''',
          whereArgs: [storeCode, productCode],
        );
        //print('Sku details updated successfully for store_code: $storeCode');
      } else {
        // INSERT new record
        await db.insert(
          'fmcg_store_updates',
          {
            'period': period,
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
            'status': '0',
            'update_status': updateStatus,
            'created_by': auditorId,
            'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          },
        );
        //print('Sku details insert successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error updating Sku details: $e');
      throw Exception('Failed to update Sku details: $e');
    }
  }

  // Function to update SD SKU details
  Future<void> insertOrUpdateSdSkuDetails(
    String dbPath,
    String storeCode,
    String auditorId,
    String productCode,
    String openStock,
    String purchase,
    String closeStock,
    String sale,
    String chilledStock,
    String chilledFace,
    String warmFace,
    String wholesale,
    String mrp,
    String avgSaleLastMonth,
    String avgSaleLastToLastMonth,
    String panel,
    String period,
    int updateStatus,
  ) async {
    try {
      final Database db = await openDatabase(dbPath);

      // Check if the record exists
      List<Map<String, dynamic>> existingRows = await db.query(
        'fmcg_store_updates',
        where: '''
    store_code = ? AND
    product_code = ? AND
    date(substr(date, 1, 7) || '-01') >= date('now', '-1 month', 'start of month')
  ''',
        whereArgs: [storeCode, productCode],
        orderBy: 'date DESC',
      );

      //print('mrp: $mrp');

      if (existingRows.isNotEmpty) {
        // UPDATE existing record
        await db.update(
          'fmcg_store_updates',
          {
            'period': period,
            'date': DateTime.now().toLocal().toIso8601String().substring(0, 10), // Ensures YYYY-MM-DD format
            'panel': panel,
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'chilled_stock': chilledStock,
            'chilled_face': chilledFace,
            'warm_face': warmFace,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'sale_last_to_last_month': avgSaleLastToLastMonth,
            'status': '1',
            'update_status': updateStatus,
            'updated_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          },
          where: '''
    store_code = ? 
    AND product_code = ? 
    AND date(substr(date, 1, 7) || '-01') >= date('now', '-1 month', 'start of month')
  ''',
          whereArgs: [storeCode, productCode],
        );
        //print('Sku details updated successfully for store_code: $storeCode');
      } else {
        // INSERT new record
        await db.insert(
          'fmcg_store_updates',
          {
            'period': period,
            'date': DateTime.now().toLocal().toIso8601String().substring(0, 10),
            'panel': panel,
            'store_code': storeCode,
            'employee_code': auditorId,
            'product_code': productCode,
            'openstock': openStock,
            'purchase': purchase,
            'closestock': closeStock,
            'sale': sale,
            'chilled_stock': chilledStock,
            'chilled_face': chilledFace,
            'warm_face': warmFace,
            'wholesale': wholesale,
            'mrp': mrp,
            'sale_last_month': avgSaleLastMonth,
            'sale_last_to_last_month': avgSaleLastToLastMonth,
            'status': '0',
            'update_status': updateStatus,
            'created_by': auditorId,
            'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          },
        );
        //print('Sku details insert successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error updating Sku details: $e');
      throw Exception('Failed to update Sku details: $e');
    }
  }

  Future<List<Map<String, dynamic>>> loadFmcgSdProductsAll(String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final fmcgSdProductsAll = await db.rawQuery(
          'SELECT * FROM products WHERE `index` = "FMCG" OR `index` = "Fmcg" OR `index` = "SD" OR `index` = "Sd" ORDER BY category_name, brand;');
      await db.close();
      return fmcgSdProductsAll;
    } catch (e) {
      // print('Failed to load FMCG and SD products: $e');
      return []; // Return an empty list on failure
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadFmcgSdProductData(String dbPath) async {
    try {
      final db = await loadDatabase(dbPath);

      final fmcgCategories = await db.rawQuery('''
  SELECT DISTINCT category_code, category_name 
  FROM products 
  WHERE "index" = "FMCG" OR "index" = "Fmcg"
  ORDER BY category_name;
''');

      final sdCategories = await db.rawQuery('''
  SELECT DISTINCT category_code, category_name 
  FROM products 
  WHERE "index" = "SD" OR "index" = "Sd"
  ORDER BY category_name;
''');

      final companies = await db.rawQuery('''
  SELECT DISTINCT company 
  FROM products 
  WHERE "index" = "FMCG" OR "index" = "Fmcg" OR "index" = "SD" OR "index" = "Sd"
  ORDER BY company;
''');

      final packTypes = await db.rawQuery('''
  SELECT DISTINCT pack_type 
  FROM products 
  WHERE "index" = "FMCG" OR "index" = "Fmcg" OR "index" = "SD" OR "index" = "Sd"
  ORDER BY pack_type;
''');

      await db.close();

      return {
        'fmcgCategories': fmcgCategories,
        'sdCategories': sdCategories,
        'companies': companies,
        'packTypes': packTypes,
      };
    } catch (e) {
      //print('Failed to load FMCG and SD product data: $e');
      return {
        'fmcgCategories': [],
        'sdCategories': [],
        'companies': [],
        'packTypes': [],
      }; // Return empty lists on failure
    }
  }

  // Insert a record into 'store_products' table
  Future<void> insertToStoreProduct(
    BuildContext context,
    String dbPath,
    String storeCode,
    String auditorId,
    String productCode,
    int updateStatus,
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
            'update_status': updateStatus,
            'store_code': storeCode,
            'product_code': productCode,
            'created_by': auditorId, // Nullable
            'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
          },
        );
        ShowAlert.showSnackBar(context, 'New SKU inserted successfully');
        //print('New entry is inserted successfully for store_code: $storeCode');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error inserting new entry: $e');
      throw Exception('Failed to insert new entry: $e');
    }
  }

  // Insert a record into 'product_introductions' table
  Future<void> insertToProductIntro(
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
          'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
      );

      //print('New Intro is inserted successfully');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error updating new intro: $e');
      throw Exception('Failed to update new intro: $e');
    }
  }

  Future<void> insertToProducts(
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
          'created_at': DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now()),
        },
      );

      //print('New Product is inserted successfully');

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error updating new entry: $e');
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

    //print(result);

    // If data exists, assign the values
    if (result.isNotEmpty) {
      if (result.first['mrp'] != null) {
        prevMrp = result.first['mrp'].toString();
      }
      if (result.first['closestock'] != null) {
        prevClosingStock = result.first['closestock'].toString();
      }
    }
    //print('prev data $prevClosingStock _ $prevMrp');

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
        //print('The SKU for store_code: $storeCode was deleted successfully.');
      } else {
        ShowAlert.showSnackBar(context, 'No matching SKU found to delete.');
        //print('No SKU found for store_code: $storeCode and product_code: $productCode.');
      }

      // Close the database
      await db.close();
    } catch (e) {
      // Handle errors
      //print('Error deleting SKU: $e');
      throw Exception('Failed to delete SKU: $e');
    }
  }

  // func after Log in for Tobacco
  Future<List<Map<String, dynamic>>> loadTobaccoStores(String dbPath, String auditorId, int priority) async {
    try {
      print(priority);
      final db = await loadDatabase(dbPath);
      final storesWithSchedules = await db.rawQuery('''
      SELECT *
      FROM stores s
      JOIN store_schedules ss ON s.code = ss.store_code
      WHERE s.status = 1
        AND ss.priority = ?
        AND (ss.`index` = "TOBACCO" OR ss.`index` = "Tobacco")
        AND ss.employee_code = ?
      ORDER BY s.status, ss.date ASC;
    ''', [priority, auditorId]);

      await db.close();
      return storesWithSchedules;
    } catch (e) {
      // print('Failed to load stores and schedules: $e');
      return []; // Return empty list on failure
    }
  }

  Future<List<Map<String, dynamic>>> loadTobaccoStoreSkuList(String dbPath, String storeCode, String period) async {
    try {
      //print('period: $period');

      // Get current device month as 'YYYY-MM'
      DateTime now = DateTime.now();
      String currentMonthStr = "${now.year}-${now.month.toString().padLeft(2, '0')}";

      // Parse period value
      int year = int.parse(period.substring(0, 4));
      int month = int.parse(period.substring(4, 6));

      // Previous 1 month
      int prevMonth = month == 1 ? 12 : month - 1;
      int prevMonthYear = month == 1 ? year - 1 : year;
      String prevMonthStr = "$prevMonthYear-${prevMonth.toString().padLeft(2, '0')}";

      // Previous 2 months
      int prev2Month = (month <= 2) ? (12 + month - 2) : (month - 2);
      int prev2MonthYear = (month == 1) ? year - 1 : (month == 2 ? year - 1 : year);
      String prev2MonthStr = "$prev2MonthYear-${prev2Month.toString().padLeft(2, '0')}";

      final db = await loadDatabase(dbPath);

      final storeProducts = await db.rawQuery('''
    SELECT
      sp.*,
      p.*,

      -- Current month data (from device date)
      COALESCE(tsu.id, 0) AS fmcg_update_id,
      COALESCE(tsu.date, '') AS update_date,
      COALESCE(tsu.panel, '') AS panel,
      COALESCE(tsu.employee_code, '') AS employee_code,
      COALESCE(tsu.openstock, '') AS openstock,
      COALESCE(tsu.purchase, '') AS purchase,
      COALESCE(tsu.closestock, '') AS closestock,
      COALESCE(tsu.sale, '') AS sale,
      COALESCE(tsu.stick_sell_price, '') AS stick_sell_price,
      COALESCE(tsu.pack_sell_price, '') AS pack_sell_price,
      COALESCE(tsu.wholesale, '') AS wholesale,
      COALESCE(tsu.avg_daily_sale_this_week, '') AS avg_daily_sale_this_week,
      COALESCE(tsu.avg_daily_sale_last_week, '') AS avg_daily_sale_last_week,
      COALESCE(tsu.status, '') AS status,
      COALESCE(tsu.audit_type, '') AS audit_type,

      -- Fallback chain: current period, then 1 month back, then 2 months
      CASE
        WHEN tsu_period.closestock IS NOT NULL AND TRIM(tsu_period.closestock) != '' THEN tsu_period.closestock
        WHEN prev1.closestock IS NOT NULL AND TRIM(prev1.closestock) != '' THEN prev1.closestock
        WHEN prev2.closestock IS NOT NULL AND TRIM(prev2.closestock) != '' THEN prev2.closestock
        ELSE ''
      END AS prev_closestock

    FROM store_products sp
    JOIN products p ON sp.product_code = p.code

    -- Current month based on device date
    LEFT JOIN tobacco_store_updates tsu
      ON sp.store_code = tsu.store_code
      AND sp.product_code = tsu.product_code
      AND substr(tsu.date, 1, 7) = ?

    -- Period-based data for openstock and mrp
    LEFT JOIN tobacco_store_updates tsu_period
      ON sp.store_code = tsu_period.store_code
      AND sp.product_code = tsu_period.product_code
      AND tsu_period.period = ?

    -- 1 month back
    LEFT JOIN tobacco_store_updates prev1
      ON sp.store_code = prev1.store_code
      AND sp.product_code = prev1.product_code
      AND substr(prev1.date, 1, 7) = ?

    -- 2 months back
    LEFT JOIN tobacco_store_updates prev2
      ON sp.store_code = prev2.store_code
      AND sp.product_code = prev2.product_code
      AND substr(prev2.date, 1, 7) = ?

    WHERE sp.store_code = ?
    ORDER BY p.category_name, p.brand ASC;
  ''', [currentMonthStr, period, prevMonthStr, prev2MonthStr, storeCode]);

      //print('Length: ${storeProducts.length} _ $storeProducts');
      await db.close();
      return storeProducts;
    } catch (e) {
      //print('Failed to load Store SKU list: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> loadTobaccoProductsAll(String dbPath, String auditorId) async {
    try {
      final db = await loadDatabase(dbPath);
      final tobaccoProductsAll =
          await db.rawQuery('SELECT * FROM products WHERE `index` = "TOBACCO" OR `index` = "Tobacco" ORDER BY category_name, brand;');
      await db.close();
      return tobaccoProductsAll;
    } catch (e) {
      // Optionally log the error
      // print('Failed to load tobacco products: $e');
      return []; // Return an empty list on failure
    }
  }

  Future<Map<String, List<Map<String, dynamic>>>> loadTobaccoProductData(String dbPath) async {
    try {
      final db = await loadDatabase(dbPath);

      final categories = await db.rawQuery('''
  SELECT DISTINCT category_code, category_name 
  FROM products 
  WHERE "index" = "TOBACCO" OR "index" = "Tobacco"
  ORDER BY category_name;
''');

      final companies = await db.rawQuery('''
  SELECT DISTINCT company 
  FROM products 
  WHERE "index" = "TOBACCO" OR "index" = "Tobacco"
  ORDER BY company;
''');

      final packTypes = await db.rawQuery('''
  SELECT DISTINCT pack_type 
  FROM products 
  WHERE "index" = "TOBACCO" OR "index" = "Tobacco"
  ORDER BY pack_type;
''');

      await db.close();

      return {
        'categories': categories,
        'companies': companies,
        'packTypes': packTypes,
      };
    } catch (e) {
      //print('Failed to load FMCG and SD product data: $e');
      return {
        'categories': [],
        'companies': [],
        'packTypes': [],
      }; // Return empty lists on failure
    }
  }
}
