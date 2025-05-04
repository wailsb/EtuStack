import 'package:flutter/foundation.dart';
import '../models/product.dart';
import '../models/client.dart';
import '../models/cart.dart';
import '../models/cart_item.dart';
import 'database_helper.dart';

class CartProvider with ChangeNotifier {
  final dbHelper = DatabaseHelper();
  
  List<CartItem> _items = [];
  Client? _client;
  
  List<CartItem> get items => _items;
  Client? get client => _client;
  
  double get totalAmount {
    double total = 0;
    for (var item in _items) {
      total += item.quantity * item.priceAtSale;
    }
    return total;
  }
  
  int get itemCount {
    return _items.length;
  }
  
  void addProduct(Product product, {int quantity = 1}) {
    final existingIndex = _items.indexWhere((item) => item.productId == product.id);
    
    if (existingIndex >= 0) {
      // Update existing item quantity
      _items[existingIndex] = CartItem(
        cartId: _items[existingIndex].cartId,
        productId: _items[existingIndex].productId,
        quantity: _items[existingIndex].quantity + quantity,
        priceAtSale: product.sellPrice ?? 0,
      );
    } else {
      // Add new product to cart
      _items.add(
        CartItem(
          cartId: 0, // Temporary ID until the cart is saved
          productId: product.id!,
          quantity: quantity,
          priceAtSale: product.sellPrice ?? 0,
        ),
      );
    }
    notifyListeners();
  }
  
  void removeItem(int productId) {
    _items.removeWhere((item) => item.productId == productId);
    notifyListeners();
  }
  
  void updateQuantity(int productId, int quantity) {
    final index = _items.indexWhere((item) => item.productId == productId);
    if (index >= 0) {
      if (quantity <= 0) {
        removeItem(productId);
      } else {
        _items[index] = CartItem(
          cartId: _items[index].cartId,
          productId: _items[index].productId,
          quantity: quantity,
          priceAtSale: _items[index].priceAtSale,
        );
        notifyListeners();
      }
    }
  }
  
  void setClient(Client? client) {
    _client = client;
    notifyListeners();
  }
  
  void clear() {
    _items = [];
    _client = null;
    notifyListeners();
  }
  
  Future<bool> checkout() async {
    try {
      // Create a new cart record
      final cart = Cart(
        date: DateTime.now(),
        clientId: _client?.id,
        totalAmount: totalAmount,
      );
      
      // Insert the cart and get its ID
      final cartId = await dbHelper.insertCart(cart);
      
      // Insert all cart items with the cartId
      for (var item in _items) {
        final cartItem = CartItem(
          cartId: cartId,
          productId: item.productId,
          quantity: item.quantity,
          priceAtSale: item.priceAtSale,
        );
        await dbHelper.insertCartItem(cartItem);
        
        // Update product quantity in inventory
        final product = await dbHelper.getProductById(item.productId);
        if (product != null) {
          product.quantity -= item.quantity;
          await dbHelper.updateProduct(product);
        }
      }
      
      // Update client points if applicable
      if (_client != null) {
        _client!.points += (totalAmount / 10).floor(); // 1 point for every 10 in purchases
        await dbHelper.updateClient(_client!);
      }
      
      // Clear the cart
      clear();
      return true;
    } catch (e) {
      print('Error during checkout: $e');
      return false;
    }
  }
}
