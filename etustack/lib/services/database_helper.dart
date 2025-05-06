import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import '../models/category.dart';
import '../models/supplier.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';

/// A cross-platform database helper that works on web, mobile, and desktop
class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;

  static Database? _database;
  bool _isInitialized = false;
  bool _usingMemory = false;

  // In-memory storage for web and when SQLite fails
  final Map<String, List<dynamic>> _memoryDb = {
    'categories': <Category>[],
    'suppliers': <Supplier>[],
    'products': <Product>[],
    'clients': <Client>[],
    'carts': <Cart>[],
    'cart_items': <CartItem>[],
  };

  // Counter for auto-increment IDs
  final Map<String, int> _idCounters = {
    'categories': 1,
    'suppliers': 1,
    'products': 1,
    'clients': 1,
    'carts': 1,
    'cart_items': 1,
  };
  
  // Add sample data flag
  bool _sampleDataAdded = false;

  DatabaseHelper._internal();

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
          _database = await openDatabase(
            'inventory.db',
            version: 2, // Increased version for schema updates
            onCreate: _createDb,
            onUpgrade: _onUpgrade,
            onOpen: (db) async {
              // Check if all required tables exist
              await _ensureTablesExist(db);
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
      
      // Add sample data for demo purposes
      if (!_sampleDataAdded) {
        await _addSampleData();
        _sampleDataAdded = true;
      }
      
      // Ensure essential categories exist
      await _ensureEssentialCategories();
    }
  }
  
  // Ensure all required tables exist
  Future<void> _ensureTablesExist(Database db) async {
    // List of all table names
    final requiredTables = [
      'categories',
      'suppliers',
      'products',
      'clients',
      'carts',
      'cart_items',
      'receipts',
      'receipt_items'
    ];
    
    // Check each table exists
    for (final tableName in requiredTables) {
      final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='$tableName';");
      if (tables.isEmpty) {
        print('$tableName table missing, creating it now...');
        // Create the missing table
        await _createMissingTable(db, tableName);
      } else {
        // Ensure all required columns exist
        await _ensureColumnsExist(db, tableName);
      }
    }
  }
  
  // Create a specific missing table
  Future<void> _createMissingTable(Database db, String tableName) async {
    switch (tableName) {
      case 'categories':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS categories(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT
          )
        ''');
        break;
      case 'suppliers':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS suppliers(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            company TEXT,
            description TEXT,
            phone TEXT
          )
        ''');
        break;
      case 'products':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS products(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            barcode TEXT,
            name TEXT NOT NULL,
            description TEXT,
            quantity INTEGER NOT NULL DEFAULT 0,
            buy_price REAL,
            sell_price REAL,
            category_id INTEGER,
            supplier_id INTEGER,
            FOREIGN KEY (category_id) REFERENCES categories (id),
            FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
          )
        ''');
        break;
      case 'clients':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS clients(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            description TEXT,
            phone TEXT,
            points INTEGER NOT NULL DEFAULT 0
          )
        ''');
        break;
      case 'carts':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS carts(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            date DATETIME NOT NULL,
            client_id INTEGER,
            total_amount REAL NOT NULL DEFAULT 0,
            FOREIGN KEY (client_id) REFERENCES clients (id)
          )
        ''');
        break;
      case 'cart_items':
        await db.execute('''
          CREATE TABLE IF NOT EXISTS cart_items(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            cart_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            quantity INTEGER NOT NULL DEFAULT 1,
            price_at_sale REAL NOT NULL,
            FOREIGN KEY (cart_id) REFERENCES carts (id),
            FOREIGN KEY (product_id) REFERENCES products (id)
          )
        ''');
        break;
      case 'receipts':
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
        break;
      case 'receipt_items':
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
        break;
    }
  }
  
  // Ensure all required columns exist in a table
  Future<void> _ensureColumnsExist(Database db, String tableName) async {
    // Get current columns
    final columns = await db.rawQuery("PRAGMA table_info($tableName);");
    final columnNames = columns.map((c) => c['name'] as String).toList();
    
    switch (tableName) {
      case 'suppliers':
        if (!columnNames.contains('company')) {
          await db.execute("ALTER TABLE suppliers ADD COLUMN company TEXT;");
        }
        if (!columnNames.contains('description')) {
          await db.execute("ALTER TABLE suppliers ADD COLUMN description TEXT;");
        }
        break;
      case 'clients':
        if (!columnNames.contains('description')) {
          await db.execute("ALTER TABLE clients ADD COLUMN description TEXT;");
        }
        if (!columnNames.contains('points')) {
          await db.execute("ALTER TABLE clients ADD COLUMN points INTEGER NOT NULL DEFAULT 0;");
        }
        break;
      case 'receipts':
        if (!columnNames.contains('company')) {
          await db.execute("ALTER TABLE receipts ADD COLUMN company TEXT;");
        }
        if (!columnNames.contains('status')) {
          await db.execute("ALTER TABLE receipts ADD COLUMN status TEXT NOT NULL DEFAULT 'pending';");
        }
        break;
    }
  }
  
  // Handle database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Make sure all tables exist
      await _ensureTablesExist(db);
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

  // No default categories - users will add their own categories
  Future<void> _ensureEssentialCategories() async {
    // Method left empty to allow users to add their own categories
    print('No default categories added - users will manage their own categories');
  }

  // Create database tables
  Future<void> _createDb(Database db, int version) async {
    // Create Category table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS categories(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT
      )
    ''');

    // Create Supplier table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS suppliers(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        company TEXT,
        phone TEXT
      )
    ''');

    // Create Product table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS products(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        barcode TEXT,
        name TEXT NOT NULL,
        description TEXT,
        quantity INTEGER NOT NULL DEFAULT 0,
        buy_price REAL,
        sell_price REAL,
        category_id INTEGER,
        supplier_id INTEGER,
        FOREIGN KEY (category_id) REFERENCES categories (id),
        FOREIGN KEY (supplier_id) REFERENCES suppliers (id)
      )
    ''');

    // Create Client table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS clients(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        phone TEXT,
        points INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // Create Cart table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS carts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date DATETIME NOT NULL,
        client_id INTEGER,
        total_amount REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (client_id) REFERENCES clients (id)
      )
    ''');

    // Create CartItem table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS cart_items(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cart_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL DEFAULT 1,
        price_at_sale REAL NOT NULL,
        FOREIGN KEY (cart_id) REFERENCES carts (id),
        FOREIGN KEY (product_id) REFERENCES products (id)
      )
    ''');
  }

  // Category CRUD Operations
  Future<int> insertCategory(Category category) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('categories', category.toMap());
      },
      memoryOperation: () {
        // Add to in-memory storage
        final categories = _memoryDb['categories'] as List<Category>;
        if (category.id == null) {
          // Auto-increment ID
          category = Category(
            id: _idCounters['categories']!,
            name: category.name,
            description: category.description,
          );
          _idCounters['categories'] = _idCounters['categories']! + 1;
        }
        categories.add(category);
        return category.id!;
      },
    );
  }

  Future<List<Category>> getCategories() async {
    return _executeDbOperation<List<Category>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('categories');
        return List.generate(maps.length, (i) {
          return Category.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        return _memoryDb['categories'] as List<Category>;
      },
    );
  }

  Future<Category?> getCategoryById(int id) async {
    return _executeDbOperation<Category?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'categories',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          return Category.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final categories = _memoryDb['categories'] as List<Category>;
        try {
          return categories.firstWhere((cat) => cat.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateCategory(Category category) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'categories',
          category.toMap(),
          where: 'id = ?',
          whereArgs: [category.id],
        );
      },
      memoryOperation: () {
        final categories = _memoryDb['categories'] as List<Category>;
        final index = categories.indexWhere((cat) => cat.id == category.id);
        if (index != -1) {
          categories[index] = category;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteCategory(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'categories',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final categories = _memoryDb['categories'] as List<Category>;
        final initialLength = categories.length;
        _memoryDb['categories'] = categories.where((cat) => cat.id != id).toList();
        return initialLength - _memoryDb['categories']!.length;
      },
    );
  }

  // Product CRUD Operations
  Future<int> insertProduct(Product product) async {
    // Check if barcode already exists
    if (product.barcode != null && product.barcode!.isNotEmpty) {
      final existingProduct = await getProductByBarcode(product.barcode!);
      if (existingProduct != null) {
        // Barcode already exists, return error code
        return -1;
      }
    }
    
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('products', product.toMap());
      },
      memoryOperation: () {
        // Add to in-memory storage
        final products = _memoryDb['products'] as List<Product>;
        
        // Check for duplicate barcode in memory too
        if (product.barcode != null && product.barcode!.isNotEmpty) {
          bool duplicateBarcode = products.any((p) => 
              p.barcode != null && 
              p.barcode!.isNotEmpty && 
              p.barcode == product.barcode);
              
          if (duplicateBarcode) {
            return -1; // Error: duplicate barcode
          }
        }
        
        if (product.id == null) {
          // Auto-increment ID
          product = Product(
            id: _idCounters['products']!,
            name: product.name,
            description: product.description,
            barcode: product.barcode,
            quantity: product.quantity,
            buyPrice: product.buyPrice,
            sellPrice: product.sellPrice,
            categoryId: product.categoryId,
            supplierId: product.supplierId,
          );
          _idCounters['products'] = _idCounters['products']! + 1;
        }
        products.add(product);
        return product.id!;
      },
    );
  }

  Future<List<Product>> getProducts() async {
    return _executeDbOperation<List<Product>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('products');
        return List.generate(maps.length, (i) {
          return Product.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        return _memoryDb['products'] as List<Product>;
      },
    );
  }

  Future<Product?> getProductById(int id) async {
    return _executeDbOperation<Product?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'products',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          return Product.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final products = _memoryDb['products'] as List<Product>;
        try {
          return products.firstWhere((product) => product.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<Product?> getProductByBarcode(String barcode) async {
    if (barcode.isEmpty) return null;
  
    return _executeDbOperation<Product?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'products',
          where: 'barcode = ?',
          whereArgs: [barcode],
        );
        if (maps.isNotEmpty) {
          return Product.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final products = _memoryDb['products'] as List<Product>;
        try {
          return products.firstWhere((product) => product.barcode == barcode);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateProduct(Product product) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'products',
          product.toMap(),
          where: 'id = ?',
          whereArgs: [product.id],
        );
      },
      memoryOperation: () {
        final products = _memoryDb['products'] as List<Product>;
        final index = products.indexWhere((p) => p.id == product.id);
        if (index != -1) {
          products[index] = product;
          return 1;
        }
        return 0;
      },
    );
  }
  
  /// Updates the quantity of a product by its ID
  /// Returns the number of rows affected
  Future<int> updateProductQuantity(int productId, int quantityChange) async {
    // First get the current product
    final product = await getProductById(productId);
    if (product == null) return 0;
    
    // Update the quantity
    product.quantity += quantityChange;
    
    // Save the updated product
    return updateProduct(product);
  }
  
  /// Handles a product with a scanned barcode
  /// If the product exists, it returns the existing product
  /// If quantityChange is provided, it updates the product quantity
  Future<Product?> handleScannedBarcode(String barcode, {int quantityChange = 0}) async {
    if (barcode.isEmpty) return null;
    
    final product = await getProductByBarcode(barcode);
    
    if (product != null && quantityChange != 0) {
      product.quantity += quantityChange;
      await updateProduct(product);
    }
    
    return product;
  }

  Future<int> deleteProduct(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'products',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final products = _memoryDb['products'] as List<Product>;
        final initialLength = products.length;
        _memoryDb['products'] = products.where((p) => p.id != id).toList();
        return initialLength - _memoryDb['products']!.length;
      },
    );
  }

  // Supplier CRUD Operations
  Future<int> insertSupplier(Supplier supplier) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('suppliers', supplier.toMap());
      },
      memoryOperation: () {
        final suppliers = _memoryDb['suppliers'] as List<Supplier>;
        if (supplier.id == null) {
          supplier = Supplier(
            id: _idCounters['suppliers']!,
            name: supplier.name,
            company: supplier.company,
            description: supplier.description,
            phone: supplier.phone,
          );
          _idCounters['suppliers'] = _idCounters['suppliers']! + 1;
        }
        suppliers.add(supplier);
        return supplier.id!;
      },
    );
  }

  Future<List<Supplier>> getSuppliers() async {
    return _executeDbOperation<List<Supplier>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('suppliers');
        return List.generate(maps.length, (i) {
          return Supplier.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        return _memoryDb['suppliers'] as List<Supplier>;
      },
    );
  }

  Future<Supplier?> getSupplierById(int id) async {
    return _executeDbOperation<Supplier?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'suppliers',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          return Supplier.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final suppliers = _memoryDb['suppliers'] as List<Supplier>;
        try {
          return suppliers.firstWhere((supplier) => supplier.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateSupplier(Supplier supplier) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'suppliers',
          supplier.toMap(),
          where: 'id = ?',
          whereArgs: [supplier.id],
        );
      },
      memoryOperation: () {
        final suppliers = _memoryDb['suppliers'] as List<Supplier>;
        final index = suppliers.indexWhere((s) => s.id == supplier.id);
        if (index != -1) {
          suppliers[index] = supplier;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteSupplier(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'suppliers',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final suppliers = _memoryDb['suppliers'] as List<Supplier>;
        final initialLength = suppliers.length;
        _memoryDb['suppliers'] = suppliers.where((s) => s.id != id).toList();
        return initialLength - _memoryDb['suppliers']!.length;
      },
    );
  }

  // Client CRUD Operations
  Future<int> insertClient(Client client) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('clients', client.toMap());
      },
      memoryOperation: () {
        final clients = _memoryDb['clients'] as List<Client>;
        if (client.id == null) {
          client = Client(
            id: _idCounters['clients']!,
            name: client.name,
            description: client.description,
            phone: client.phone,
            points: client.points,
          );
          _idCounters['clients'] = _idCounters['clients']! + 1;
        }
        clients.add(client);
        return client.id!;
      },
    );
  }

  Future<List<Client>> getClients() async {
    return _executeDbOperation<List<Client>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('clients');
        return List.generate(maps.length, (i) {
          return Client.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        return _memoryDb['clients'] as List<Client>;
      },
    );
  }

  Future<Client?> getClientById(int id) async {
    return _executeDbOperation<Client?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'clients',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          return Client.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final clients = _memoryDb['clients'] as List<Client>;
        try {
          return clients.firstWhere((client) => client.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateClient(Client client) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'clients',
          client.toMap(),
          where: 'id = ?',
          whereArgs: [client.id],
        );
      },
      memoryOperation: () {
        final clients = _memoryDb['clients'] as List<Client>;
        final index = clients.indexWhere((c) => c.id == client.id);
        if (index != -1) {
          clients[index] = client;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteClient(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'clients',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final clients = _memoryDb['clients'] as List<Client>;
        final initialLength = clients.length;
        _memoryDb['clients'] = clients.where((c) => c.id != id).toList();
        return initialLength - _memoryDb['clients']!.length;
      },
    );
  }

  // Cart CRUD Operations
  Future<int> insertCart(Cart cart) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('carts', cart.toMap());
      },
      memoryOperation: () {
        final carts = _memoryDb['carts'] as List<Cart>;
        if (cart.id == null) {
          cart = Cart(
            id: _idCounters['carts']!,
            date: cart.date,
            clientId: cart.clientId,
            totalAmount: cart.totalAmount,
          );
          _idCounters['carts'] = _idCounters['carts']! + 1;
        }
        carts.add(cart);
        return cart.id!;
      },
    );
  }

  Future<List<Cart>> getCarts() async {
    return _executeDbOperation<List<Cart>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query('carts');
        return List.generate(maps.length, (i) {
          return Cart.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        return _memoryDb['carts'] as List<Cart>;
      },
    );
  }

  Future<Cart?> getCartById(int id) async {
    return _executeDbOperation<Cart?>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'carts',
          where: 'id = ?',
          whereArgs: [id],
        );
        if (maps.isNotEmpty) {
          return Cart.fromMap(maps.first);
        }
        return null;
      },
      memoryOperation: () {
        final carts = _memoryDb['carts'] as List<Cart>;
        try {
          return carts.firstWhere((cart) => cart.id == id);
        } catch (e) {
          return null;
        }
      },
    );
  }

  Future<int> updateCart(Cart cart) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'carts',
          cart.toMap(),
          where: 'id = ?',
          whereArgs: [cart.id],
        );
      },
      memoryOperation: () {
        final carts = _memoryDb['carts'] as List<Cart>;
        final index = carts.indexWhere((c) => c.id == cart.id);
        if (index != -1) {
          carts[index] = cart;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteCart(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'carts',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final carts = _memoryDb['carts'] as List<Cart>;
        final initialLength = carts.length;
        _memoryDb['carts'] = carts.where((c) => c.id != id).toList();
        return initialLength - _memoryDb['carts']!.length;
      },
    );
  }

  // CartItem CRUD Operations
  Future<int> insertCartItem(CartItem item) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.insert('cart_items', item.toMap());
      },
      memoryOperation: () {
        final items = _memoryDb['cart_items'] as List<CartItem>;
        if (item.id == null) {
          item = CartItem(
            id: _idCounters['cart_items']!,
            cartId: item.cartId,
            productId: item.productId,
            quantity: item.quantity,
            priceAtSale: item.priceAtSale,
          );
          _idCounters['cart_items'] = _idCounters['cart_items']! + 1;
        }
        items.add(item);
        return item.id!;
      },
    );
  }

  Future<List<CartItem>> getCartItems(int cartId) async {
    return _executeDbOperation<List<CartItem>>(
      dbOperation: (Database db) async {
        final List<Map<String, dynamic>> maps = await db.query(
          'cart_items',
          where: 'cart_id = ?',
          whereArgs: [cartId],
        );
        return List.generate(maps.length, (i) {
          return CartItem.fromMap(maps[i]);
        });
      },
      memoryOperation: () {
        final allItems = _memoryDb['cart_items'] as List<CartItem>;
        return allItems.where((item) => item.cartId == cartId).toList();
      },
    );
  }

  Future<int> updateCartItem(CartItem item) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.update(
          'cart_items',
          item.toMap(),
          where: 'id = ?',
          whereArgs: [item.id],
        );
      },
      memoryOperation: () {
        final items = _memoryDb['cart_items'] as List<CartItem>;
        final index = items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          items[index] = item;
          return 1;
        }
        return 0;
      },
    );
  }

  Future<int> deleteCartItem(int id) async {
    return _executeDbOperation<int>(
      dbOperation: (Database db) async {
        return await db.delete(
          'cart_items',
          where: 'id = ?',
          whereArgs: [id],
        );
      },
      memoryOperation: () {
        final items = _memoryDb['cart_items'] as List<CartItem>;
        final initialLength = items.length;
        _memoryDb['cart_items'] = items.where((i) => i.id != id).toList();
        return initialLength - _memoryDb['cart_items']!.length;
      },
    );
  }

  // Dashboard Methods

  /// Get total revenue within a date range
  Future<double> getTotalRevenueInRange(String startDate, String endDate) async {
    return _executeDbOperation<double>(
      dbOperation: (Database db) async {
        try {
          // Check if receipts table exists
          final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='receipts';");
          if (tables.isEmpty) {
            return 0.0;
          }
          
          final List<Map<String, dynamic>> result = await db.rawQuery(''' 
            SELECT SUM(total_amount) as total_revenue
            FROM receipts
            WHERE date BETWEEN ? AND ? 
          ''', [startDate, endDate]);
          
          if (result.isNotEmpty && result[0]['total_revenue'] != null) {
            return (result[0]['total_revenue'] as num).toDouble();
          }
          return 0.0;
        } catch (e) {
          print('Error getting total revenue: $e');
          return 0.0;
        }
      },
      memoryOperation: () {
        try {
          // Filter carts within the date range
          final carts = _memoryDb['carts'] as List<Cart>;
          final matchingCarts = carts.where((cart) {
            final cartDate = cart.date;
            final start = DateTime.parse(startDate);
            final end = DateTime.parse(endDate);
            return cartDate.isAfter(start) && cartDate.isBefore(end);
          }).toList();
          
          // Sum up total amounts
          return matchingCarts.fold<double>(0.0, (sum, cart) => sum + cart.totalAmount);
        } catch (e) {
          print('Error calculating revenue from memory: $e');
          return 0.0;
        }
      },
    );
  }

  /// Get total profit within a date range
  Future<double> getTotalProfitInRange(String startDate, String endDate) async {
    return _executeDbOperation<double>(
      dbOperation: (Database db) async {
        try {
          // Check if all required tables exist
          final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='receipts';");
          final itemTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cart_items';");
          final productTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='products';");
          
          if (tables.isEmpty || itemTables.isEmpty || productTables.isEmpty) {
            return 0.0;
          }
          
          // Calculate total revenue
          final List<Map<String, dynamic>> revenueResult = await db.rawQuery(''' 
            SELECT SUM(total_amount) as total_revenue
            FROM receipts
            WHERE date BETWEEN ? AND ? 
          ''', [startDate, endDate]);
          
          final double totalRevenue = revenueResult.isNotEmpty && revenueResult[0]['total_revenue'] != null
            ? (revenueResult[0]['total_revenue'] as num).toDouble()
            : 0.0;
          
          // Calculate total cost
          final List<Map<String, dynamic>> costResult = await db.rawQuery(''' 
            SELECT SUM(ci.quantity * p.buy_price) as total_cost
            FROM cart_items ci
            JOIN products p ON ci.product_id = p.id
            JOIN carts c ON ci.cart_id = c.id
            WHERE c.date BETWEEN ? AND ? 
          ''', [startDate, endDate]);
          
          final double totalCost = costResult.isNotEmpty && costResult[0]['total_cost'] != null
            ? (costResult[0]['total_cost'] as num).toDouble()
            : 0.0;
          
          return totalRevenue - totalCost;
        } catch (e) {
          print('Error getting total profit: $e');
          return 0.0;
        }
      },
      memoryOperation: () {
        try {
          // Calculate total revenue
          final carts = _memoryDb['carts'] as List<Cart>;
          final matchingCarts = carts.where((cart) {
            final cartDate = cart.date;
            final start = DateTime.parse(startDate);
            final end = DateTime.parse(endDate);
            return cartDate.isAfter(start) && cartDate.isBefore(end);
          }).toList();
          
          double totalRevenue = matchingCarts.fold<double>(0.0, (sum, cart) => sum + cart.totalAmount);
          
          // Calculate total cost
          double totalCost = 0.0;
          final cartItems = _memoryDb['cart_items'] as List<CartItem>;
          final products = _memoryDb['products'] as List<Product>;
          
          for (final cart in matchingCarts) {
            final cartId = cart.id!;
            final itemsInCart = cartItems.where((item) => item.cartId == cartId);
            
            for (final item in itemsInCart) {
              final productId = item.productId;
              final product = products.firstWhere(
                (p) => p.id == productId,
                orElse: () => Product(id: -1, name: '', quantity: 0)
              );
              
              if (product.id != -1) {
                totalCost += item.quantity * (product.buyPrice ?? 0);
              }
            }
          }
          
          return totalRevenue - totalCost;
        } catch (e) {
          print('Error calculating profit from memory: $e');
          return 0.0;
        }
      },
    );
  }

  /// Get top selling products
  Future<Map<String, dynamic>> getTopSellingProducts(int limit) async {
    return _executeDbOperation<Map<String, dynamic>>(
      dbOperation: (Database db) async {
        try {
          // Check if all required tables exist
          final tables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='cart_items';");
          final productTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='products';");
          
          if (tables.isEmpty || productTables.isEmpty) {
            return {'products': <Map<String, dynamic>>[], 'total_sold': 0};
          }
          
          // Get top selling products
          final List<Map<String, dynamic>> results = await db.rawQuery(''' 
            SELECT p.id, p.name, p.barcode, p.sell_price, 
                   SUM(ci.quantity) as quantity_sold,
                   SUM(ci.quantity * ci.price_at_sale) as total_sales
            FROM cart_items ci
            JOIN products p ON ci.product_id = p.id
            GROUP BY p.id
            ORDER BY quantity_sold DESC
            LIMIT ? 
          ''', [limit]);
          
          // Get total number of products sold
          final List<Map<String, dynamic>> totalResult = await db.rawQuery(''' 
            SELECT SUM(quantity) as total_sold
            FROM cart_items 
          ''');
          
          final int totalSold = totalResult.isNotEmpty && totalResult[0]['total_sold'] != null
            ? (totalResult[0]['total_sold'] as num).toInt()
            : 0;
          
          return {'products': results, 'total_sold': totalSold};
        } catch (e) {
          print('Error getting top selling products: $e');
          return {'products': <Map<String, dynamic>>[], 'total_sold': 0};
        }
      },
      memoryOperation: () {
        try {
          final cartItems = _memoryDb['cart_items'] as List<CartItem>;
          final products = _memoryDb['products'] as List<Product>;
          
          // Calculate quantity sold for each product
          final Map<int, int> quantitySold = {};
          final Map<int, double> totalSales = {};
          
          for (final item in cartItems) {
            final productId = item.productId;
            final quantity = item.quantity;
            final sale = quantity * item.priceAtSale;
            
            quantitySold[productId] = (quantitySold[productId] ?? 0) + quantity;
            totalSales[productId] = (totalSales[productId] ?? 0) + sale;
          }
          
          // Create result with product details
          final List<Map<String, dynamic>> results = [];
          
          for (final entry in quantitySold.entries) {
            final productId = entry.key;
            final quantity = entry.value;
            
            final product = products.firstWhere(
              (p) => p.id == productId,
              orElse: () => Product(id: -1, name: 'Unknown', quantity: 0)
            );
            
            if (product.id != -1) {
              results.add({
                'id': product.id,
                'name': product.name,
                'barcode': product.barcode,
                'sell_price': product.sellPrice,
                'quantity_sold': quantity,
                'total_sales': totalSales[productId] ?? 0,
              });
            }
          }
          
          // Sort by quantity sold and limit
          results.sort((a, b) => (b['quantity_sold'] as int).compareTo(a['quantity_sold'] as int));
          final limitedResults = results.take(limit).toList();
          
          // Calculate total sold
          final totalSold = cartItems.fold<int>(0, (sum, item) => sum + item.quantity);
          
          return {'products': limitedResults, 'total_sold': totalSold};
        } catch (e) {
          print('Error calculating top products from memory: $e');
          return {'products': <Map<String, dynamic>>[], 'total_sold': 0};
        }
      },
    );
  }

  /// Get top clients by purchase amount
  Future<Map<String, dynamic>> getTopClients(int limit) async {
    return _executeDbOperation<Map<String, dynamic>>(
      dbOperation: (Database db) async {
        try {
          // Check if all required tables exist
          final cartTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='carts';");
          final clientTables = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name='clients';");
          
          if (cartTables.isEmpty || clientTables.isEmpty) {
            return {'clients': <Map<String, dynamic>>[], 'total_sales': 0};
          }
          
          // Get top clients
          final List<Map<String, dynamic>> results = await db.rawQuery(''' 
            SELECT c.id, c.name, c.phone, c.points,
                   COUNT(ct.id) as order_count,
                   SUM(ct.total_amount) as total_spent
            FROM clients c
            JOIN carts ct ON c.id = ct.client_id
            GROUP BY c.id
            ORDER BY total_spent DESC
            LIMIT ? 
          ''', [limit]);
          
          // Get total sales across all clients
          final List<Map<String, dynamic>> totalResult = await db.rawQuery(''' 
            SELECT SUM(total_amount) as total_sales
            FROM carts
            WHERE client_id IS NOT NULL 
          ''');
          
          final double totalSales = totalResult.isNotEmpty && totalResult[0]['total_sales'] != null
            ? (totalResult[0]['total_sales'] as num).toDouble()
            : 0.0;
          
          return {'clients': results, 'total_sales': totalSales};
        } catch (e) {
          print('Error getting top clients: $e');
          return {'clients': <Map<String, dynamic>>[], 'total_sales': 0};
        }
      },
      memoryOperation: () {
        try {
          final carts = _memoryDb['carts'] as List<Cart>;
          final clients = _memoryDb['clients'] as List<Client>;
          
          // Group carts by client ID
          final Map<int?, List<Cart>> cartsByClient = {};
          
          for (final cart in carts) {
            if (cart.clientId != null) {
              if (!cartsByClient.containsKey(cart.clientId)) {
                cartsByClient[cart.clientId] = [];
              }
              cartsByClient[cart.clientId]!.add(cart);
            }
          }
          
          // Calculate metrics for each client
          final List<Map<String, dynamic>> results = [];
          
          for (final entry in cartsByClient.entries) {
            final clientId = entry.key;
            final clientCarts = entry.value;
            
            final client = clients.firstWhere(
              (c) => c.id == clientId,
              orElse: () => Client(id: -1, name: 'Unknown')
            );
            
            if (client.id != -1) {
              final orderCount = clientCarts.length;
              final totalSpent = clientCarts.fold<double>(0, (sum, cart) => sum + cart.totalAmount);
              
              results.add({
                'id': client.id,
                'name': client.name,
                'phone': client.phone,
                'points': client.points,
                'order_count': orderCount,
                'total_spent': totalSpent,
              });
            }
          }
          
          // Sort by total spent and limit
          results.sort((a, b) => (b['total_spent'] as double).compareTo(a['total_spent'] as double));
          final limitedResults = results.take(limit).toList();
          
          // Calculate total sales
          final totalSales = carts
            .where((cart) => cart.clientId != null)
            .fold<double>(0, (sum, cart) => sum + cart.totalAmount);
          
          return {'clients': limitedResults, 'total_sales': totalSales};
        } catch (e) {
          print('Error calculating top clients from memory: $e');
          return {'clients': <Map<String, dynamic>>[], 'total_sales': 0};
        }
      },
    );
  }

  // Empty method - we don't add sample data anymore, letting users manage their own data
  Future<void> _addSampleData() async {
    // No sample data is added, allowing users to start with a clean database
    print('Sample data addition skipped - users will start with a clean database');
  }
}
