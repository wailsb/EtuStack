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
            version: 1,
            onCreate: _createDb,
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
        phone TEXT
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
            phone: client.phone,
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

  // Empty method - we don't add sample data anymore, letting users manage their own data
  Future<void> _addSampleData() async {
    // No sample data is added, allowing users to start with a clean database
    print('Sample data addition skipped - users will start with a clean database');
  }
}
