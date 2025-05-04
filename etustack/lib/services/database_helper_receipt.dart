import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';

/// Extension to database helper for receipt-related operations
class DatabaseHelperReceipt {
  static final DatabaseHelperReceipt _instance = DatabaseHelperReceipt._internal();
  factory DatabaseHelperReceipt() => _instance;

  static Database? _database;
  bool _isInitialized = false;
  bool _usingMemory = false;

  // In-memory storage for web and when SQLite fails
  final Map<String, List<dynamic>> _memoryDb = {
    'receipts': <Receipt>[],
    'receipt_items': <ReceiptItem>[],
  };

  // Counter for auto-increment IDs
  final Map<String, int> _idCounters = {
    'receipts': 1,
    'receipt_items': 1,
  };

  DatabaseHelperReceipt._internal();

  // Initialize the database
  Future<void> initialize() async {
    if (!_isInitialized) {
      if (kIsWeb) {
        // Using memory database for web
        _usingMemory = true;
        print('Using in-memory database for web platform');
      } else {
        try {
          // Try to initialize SQLite for mobile/desktop platforms
          final databasePath = await getDatabasesPath();
          final path = join(databasePath, 'inventory.db');
          
          // Check if database exists (useful for debugging)
          await databaseExists(path);
          
          _database = await openDatabase(
            path,
            version: 2, // Increased version for schema updates
            onCreate: _createDb,
            onUpgrade: _onUpgrade,
            onOpen: (db) async {
              // Critical: Always check if receipts table exists when opening the database
              // This handles cases where the table might not have been created properly
              final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='receipts';");
              if (tables.isEmpty) {
                print('Receipts table missing, creating it now...');
                // Force create the receipts table if it doesn't exist
                await _createDb(db, 2);
              }
            },
          );
          print('SQLite database initialized successfully');
        } catch (e) {
          print('SQLite initialization failed: $e');
          _usingMemory = true;
          print('Falling back to in-memory storage');
        }
      }
      
      _isInitialized = true;
    }
  }

  // For compatibility with existing code
  Future<Database?> get database async {
    await initialize();
    return _database;
  }
  
  // Generic method to handle database operations with fallback to in-memory storage
  Future<T> _executeDbOperation<T>({
    required Future<T> Function(Database) dbOperation, 
    required T Function() memoryOperation
  }) async {
    await initialize();
    
    if (_usingMemory) {
      return memoryOperation();
    } else {
      final db = _database;
      if (db != null) {
        return dbOperation(db);
      } else {
        _usingMemory = true;
        return memoryOperation();
      }
    }
  }

  // Implementation for missing method referenced in extension class
  // (Not used directly - see the getReceiptsWithClientNames implementation below)

  // Create database tables
  Future<void> _createDb(Database db, int version) async {
    // Check if receipts table exists
    final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='receipts';");
    
    if (tables.isEmpty) {
      // Create Receipt table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipts(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          date DATETIME NOT NULL,
          client_id INTEGER,
          company TEXT,
          total_amount REAL NOT NULL DEFAULT 0,
          status TEXT NOT NULL DEFAULT 'pending',
          FOREIGN KEY (client_id) REFERENCES clients (id)
        )
      ''');
      print('Receipts table created successfully');
    }
    
    // Check if receipt_items table exists
    final itemTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='receipt_items';");
    
    if (itemTables.isEmpty) {
      // Create ReceiptItem table if it doesn't exist
      await db.execute('''
        CREATE TABLE IF NOT EXISTS receipt_items(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          receipt_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL DEFAULT 1,
          price_at_sale REAL NOT NULL,
          total REAL NOT NULL,
          FOREIGN KEY (receipt_id) REFERENCES receipts (id),
          FOREIGN KEY (product_id) REFERENCES products (id)
        )
      ''');
      print('Receipt_items table created successfully');
    }
  }
  
  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add receipt-related tables if upgrading from version 1
      await _createDb(db, newVersion);
    }
    
    // Check if company column exists in receipts table
    try {
      final pragma = await db.rawQuery("PRAGMA table_info(receipts)");
      bool hasCompanyColumn = false;
      
      for (var column in pragma) {
        if (column['name'] == 'company') {
          hasCompanyColumn = true;
          break;
        }
      }
      
      if (!hasCompanyColumn) {
        // Add company column if it doesn't exist
        await db.execute("ALTER TABLE receipts ADD COLUMN company TEXT;");
        print('Added company column to receipts table');
      }
    } catch (e) {
      print('Error checking/adding company column: $e');
    }
  }

  // Receipt CRUD Operations
  Future<int> insertReceipt(Receipt receipt) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('receipts', receipt.toMap());
      },
      memoryOperation: () {
        // Add to in-memory storage
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        if (receipt.id == null) {
          // Auto-increment ID
          receipt = Receipt(
            id: _idCounters['receipts']!,
            date: receipt.date,
            clientId: receipt.clientId,
            totalAmount: receipt.totalAmount,
            status: receipt.status,
          );
          _idCounters['receipts'] = _idCounters['receipts']! + 1;
        }
        receipts.add(receipt);
        return receipt.id!;
      },
    );
  }

  Future<List<Receipt>> getReceipts() async {
    return _executeDbOperation<List<Receipt>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('receipts', orderBy: 'date DESC');
        return List.generate(maps.length, (i) {
          return Receipt.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        // Retrieve from in-memory storage
        return (_memoryDb['receipts'] as List<Receipt>).toList();
      },
    );
  }

  Future<Receipt?> getReceipt(int id) async {
    return _executeDbOperation<Receipt?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'receipts',
          where: 'id = ?',
          whereArgs: [id],
        );
        
        if (maps.isNotEmpty) {
          return Receipt.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        // Retrieve from in-memory storage
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        try {
          return receipts.firstWhere((receipt) => receipt.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateReceipt(Receipt receipt) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'receipts',
          receipt.toMap(),
          where: 'id = ?',
          whereArgs: [receipt.id],
        );
      },
      memoryOperation: () {
        // Update in-memory storage
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        final index = receipts.indexWhere((r) => r.id == receipt.id);
        
        if (index != -1) {
          receipts[index] = receipt;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteReceipt(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        // First delete associated receipt items
        await db.delete(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [id],
        );
        
        // Then delete the receipt
        return await db.delete(
          'receipts',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        // Update in-memory storage
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        final receiptItems = _memoryDb['receipt_items'] as List<ReceiptItem>;
        
        // Remove related receipt items
        receiptItems.removeWhere((item) => item.receiptId == id);
        
        // Remove receipt
        final initialLength = receipts.length;
        receipts.removeWhere((receipt) => receipt.id == id);
        return initialLength - receipts.length;
      },
    );
  }

  // Receipt Item CRUD Operations
  Future<int> insertReceiptItem(ReceiptItem item) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('receipt_items', item.toMap());
      },
      memoryOperation: () {
        // Add to in-memory storage
        final items = _memoryDb['receipt_items'] as List<ReceiptItem>;
        if (item.id == null) {
          // Auto-increment ID
          item = ReceiptItem(
            id: _idCounters['receipt_items']!,
            receiptId: item.receiptId,
            productId: item.productId,
            quantity: item.quantity,
            priceAtSale: item.priceAtSale,
            total: item.total,
          );
          _idCounters['receipt_items'] = _idCounters['receipt_items']! + 1;
        }
        items.add(item);
        return item.id!;
      },
    );
  }

  Future<List<ReceiptItem>> getReceiptItems(int receiptId) async {
    return _executeDbOperation<List<ReceiptItem>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'receipt_items',
          where: 'receipt_id = ?',
          whereArgs: [receiptId],
        );
        return List.generate(maps.length, (i) {
          return ReceiptItem.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        // Retrieve from in-memory storage
        final items = _memoryDb['receipt_items'] as List<ReceiptItem>;
        return items.where((item) => item.receiptId == receiptId).toList();
      },
    );
  }

  Future<int> updateReceiptItem(ReceiptItem item) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'receipt_items',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      },
      memoryOperation: () {
        // Update in-memory storage
        final items = _memoryDb['receipt_items'] as List<ReceiptItem>;
        final index = items.indexWhere((i) => i.id == item.id);
        
        if (index != -1) {
          items[index] = item;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteReceiptItem(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'receipt_items',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        // Update in-memory storage
        final items = _memoryDb['receipt_items'] as List<ReceiptItem>;
        final initialLength = items.length;
        items.removeWhere((item) => item.id == id);
        return initialLength - items.length;
      },
    );
  }

  // Advanced query: Get receipt with items and product details
  Future<Map<String, dynamic>> getReceiptWithDetails(int receiptId) async {
    return _executeDbOperation<Map<String, dynamic>>(
      dbOperation: (Database db) async {
        // Get the receipt
        final receiptResult = await db.query(
          'receipts',
          where: 'id = ?',
          whereArgs: [receiptId],
        );
        
        if (receiptResult.isEmpty) {
          return {'receipt': null, 'items': <Map<String, dynamic>>[]};
        }
        
        final receipt = Receipt.fromMap(receiptResult.first);
        
        // Get receipt items with product details
        final List<Map<String, dynamic>> itemsWithDetails = await db.rawQuery('''
          SELECT ri.*, p.name as product_name, p.barcode as product_barcode
          FROM receipt_items ri
          JOIN products p ON ri.product_id = p.id
          WHERE ri.receipt_id = ?
        ''', [receiptId]);
        
        // Get client info if available
        Map<String, dynamic>? clientInfo;
        if (receipt.clientId != null) {
          final clientResult = await db.query(
            'clients',
            where: 'id = ?',
            whereArgs: [receipt.clientId],
          );
          
          if (clientResult.isNotEmpty) {
            clientInfo = clientResult.first;
          }
        }
        
        return {
          'receipt': receipt.toMap(),
          'items': itemsWithDetails,
          'client': clientInfo,
        };
      },
      memoryOperation: () {
        // This is complex to implement in memory, but we'll do a simplified version
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        final receiptItems = _memoryDb['receipt_items'] as List<ReceiptItem>;
        
        // Find receipt
        final receipt = receipts.firstWhere(
          (r) => r.id == receiptId,
          orElse: () => Receipt(date: DateTime.now()),
        );
        
        if (receipt.id == null) {
          return {'receipt': null, 'items': <Map<String, dynamic>>[]};
        }
        
        // Find items
        final items = receiptItems
            .where((item) => item.receiptId == receiptId)
            .map((item) => item.toMap())
            .toList();
        
        return {
          'receipt': receipt.toMap(),
          'items': items,
          'client': null, // We don't have access to clients in memory mode
        };
      },
    );
  }

  // Query to get all receipts with client names
  Future<List<Map<String, dynamic>>> getReceiptsWithClientNames() async {
    return _executeDbOperation<List<Map<String, dynamic>>>(
      dbOperation: (Database db) async {
        return await db.rawQuery('''
          SELECT r.*, c.name as client_name
          FROM receipts r
          LEFT JOIN clients c ON r.client_id = c.id
          ORDER BY r.date DESC
        ''');
      },
      memoryOperation: () {
        // Simplified in-memory implementation
        final receipts = _memoryDb['receipts'] as List<Receipt>;
        return receipts.map((r) => {
          ...r.toMap(),
          'client_name': 'Unknown', // Cannot join with clients in memory
        }).toList();
      },
    );
  }
}
