import 'dart:async';
import 'package:intl/intl.dart';
import 'database_helper.dart';

/// Dashboard helper class specifically for dashboard operations
class DatabaseHelperDashboard {
  static final DatabaseHelperDashboard _instance = DatabaseHelperDashboard._internal();
  factory DatabaseHelperDashboard() => _instance;
  
  // Reference to main database helper
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
  // Private constructor for singleton pattern
  DatabaseHelperDashboard._internal();
  
  // Initialize the database helper
  Future<void> initialize() async {
    // No initialization needed as we're using the main database helper
  }

  /// Get products with low stock for inventory alerts
  Future<List<Map<String, dynamic>>> getProductsWithLowStock(int limit, {int threshold = 5}) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) {
        print('Database is null, returning empty data');
        return [];
      }
      
      // First check if the products table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
      );
      
      if (tables.isEmpty) {
        return [];
      }
      
      // Check if the categories table exists
      final catTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='categories'"
      );
      
      // Check if the suppliers table exists
      final suppTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='suppliers'"
      );
      
      // Build query based on available tables
      String query = 'SELECT p.* ';
      List<String> joins = [];
      
      if (catTables.isNotEmpty) {
        query += ', c.name as category_name ';
        joins.add('LEFT JOIN categories c ON p.category_id = c.id');
      }
      
      if (suppTables.isNotEmpty) {
        query += ', s.name as supplier_name ';
        joins.add('LEFT JOIN suppliers s ON p.supplier_id = s.id');
      }
      
      query += 'FROM products p ';
      query += joins.join(' ');
      query += ' WHERE p.quantity <= ? ORDER BY p.quantity ASC LIMIT ?';
      
      final List<Map<String, dynamic>> result = await db.rawQuery(
        query, 
        [threshold, limit]
      );
      
      return result;
    } catch (e) {
      print('Error getting low stock products: $e');
      return []; // Return empty list instead of mock data
    }
  }
  
  /// Get recent receipts with details for the dashboard
  Future<Map<String, dynamic>> getReceiptsWithDetails(int limit) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) {
        print('Database is null, returning empty data');
        return {'receipts': <Map<String, dynamic>>[]};
      }
      
      // First check if receipts table exists
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='receipts'"
      );
      
      if (tables.isEmpty) {
        return {'receipts': <Map<String, dynamic>>[]};
      }
      
      // Get recent receipts with client names if clients table exists
      String query = '''
        SELECT r.*
      ''';
      
      // Check if clients table exists
      final clientTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='clients'"
      );
      
      if (clientTables.isNotEmpty) {
        query += ''', c.name as client_name
          FROM receipts r
          LEFT JOIN clients c ON r.client_id = c.id
        ''';
      } else {
        query += '''
          FROM receipts r
        ''';
      }
      
      query += '''
        ORDER BY r.date DESC
        LIMIT ?
      ''';
      
      final List<Map<String, dynamic>> receipts = await db.rawQuery(query, [limit]);
      
      // For each receipt, get its items if receipt_items table exists
      final itemTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='receipt_items'"
      );
      
      if (itemTables.isNotEmpty) {
        for (var receipt in receipts) {
          final receiptId = receipt['id'];
          
          // Check if products table exists
          final productTables = await db.rawQuery(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
          );
          
          String itemQuery;
          if (productTables.isNotEmpty) {
            itemQuery = '''
              SELECT ri.*, p.name as product_name, p.barcode as product_barcode
              FROM receipt_items ri
              JOIN products p ON ri.product_id = p.id
              WHERE ri.receipt_id = ?
            ''';
          } else {
            itemQuery = '''
              SELECT ri.*
              FROM receipt_items ri
              WHERE ri.receipt_id = ?
            ''';
          }
          
          final List<Map<String, dynamic>> items = await db.rawQuery(itemQuery, [receiptId]);
          receipt['items'] = items;
        }
      }
      
      return {'receipts': receipts};
    } catch (e) {
      print('Error fetching receipt details: $e');
      return {'receipts': <Map<String, dynamic>>[]};
    }
  }
  
  /// Get monthly sales summary for charts
  Future<List<Map<String, dynamic>>> getMonthlySalesSummary(int months) async {
    try {
      final db = await _dbHelper.database;
      if (db == null) {
        print('Database is null, returning empty data');
        return [];
      }
      
      final DateTime now = DateTime.now();
      final List<Map<String, dynamic>> result = [];
      
      // Check if tables exist
      final receiptTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='receipts'"
      );
      
      if (receiptTables.isEmpty) {
        return [];
      }
      
      final receiptItemTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='receipt_items'"
      );
      
      final productTables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='products'"
      );
      
      if (receiptItemTables.isEmpty || productTables.isEmpty) {
        return [];
      }
      
      for (int i = months - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month - i, 1);
        final nextMonth = i > 0 
          ? DateTime(now.year, now.month - i + 1, 1) 
          : DateTime(now.year, now.month + 1, 1);
        
        final startDateStr = DateFormat('yyyy-MM-dd').format(date);
        final endDateStr = DateFormat('yyyy-MM-dd').format(nextMonth.subtract(const Duration(days: 1)));
        
        // Query total sales for this month
        final sales = await db.rawQuery('''
          SELECT SUM(total) as revenue
          FROM receipts
          WHERE date BETWEEN ? AND ?
        ''', [startDateStr, endDateStr]);
        
        final revenue = sales.isNotEmpty && sales[0]['revenue'] != null 
          ? (sales[0]['revenue'] as num).toDouble() 
          : 0.0;
        
        // Query costs for this month to calculate profit
        final costs = await db.rawQuery('''
          SELECT SUM(ri.quantity * p.cost_price) as total_cost
          FROM receipt_items ri
          JOIN products p ON ri.product_id = p.id
          JOIN receipts r ON ri.receipt_id = r.id
          WHERE r.date BETWEEN ? AND ?
        ''', [startDateStr, endDateStr]);
        
        final totalCost = costs.isNotEmpty && costs[0]['total_cost'] != null 
          ? (costs[0]['total_cost'] as num).toDouble() 
          : 0.0;
        
        final profit = revenue - totalCost;
        
        result.add({
          'date': date,
          'month': DateFormat('MMM yyyy').format(date),
          'revenue': revenue,
          'profit': profit,
        });
      }
      
      return result;
    } catch (e) {
      print('Error getting monthly sales data: $e');
      return _generateMonthlySalesData(months);
    }
  }
}
