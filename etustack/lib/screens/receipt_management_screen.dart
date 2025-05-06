import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/receipt.dart';
import '../models/receipt_item.dart';
import '../models/client.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../utils/app_constants.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class ReceiptManagementScreen extends StatefulWidget {
  const ReceiptManagementScreen({Key? key}) : super(key: key);

  @override
  State<ReceiptManagementScreen> createState() => _ReceiptManagementScreenState();
}

class _ReceiptManagementScreenState extends State<ReceiptManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Map<String, dynamic>> _receipts = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadReceipts();
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final receipts = await _dbHelper.getReceiptsWithClientNames();
      setState(() {
        _receipts = receipts;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipts: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredReceipts = _receipts.where((receipt) {
      final searchLower = _searchQuery.toLowerCase();
      final clientName = receipt['client_name']?.toString().toLowerCase() ?? '';
      final receiptId = receipt['id']?.toString() ?? '';
      final date = receipt['date'] != null
          ? DateFormat('yyyy-MM-dd').format(DateTime.parse(receipt['date']))
          : '';
      
      return clientName.contains(searchLower) ||
             receiptId.contains(searchLower) ||
             date.contains(searchLower);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Management'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search Receipts',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredReceipts.isEmpty
                    ? const Center(
                        child: Text('No receipts found'),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadReceipts,
                        child: ListView.builder(
                          itemCount: filteredReceipts.length,
                          itemBuilder: (context, index) {
                            final receipt = filteredReceipts[index];
                            final date = DateTime.parse(receipt['date']);
                            final status = receipt['status'] ?? 'pending';
                            final totalAmount = receipt['total_amount'] != null
                                ? receipt['total_amount'].toDouble()
                                : 0.0;
                            final clientName = receipt['client_name'] ?? 'Walk-in Customer';

                            return Slidable(
                              endActionPane: ActionPane(
                                motion: const ScrollMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (context) {
                                      _viewReceiptDetails(receipt['id']);
                                    },
                                    backgroundColor: Colors.blue,
                                    foregroundColor: Colors.white,
                                    icon: Icons.visibility,
                                    label: 'View',
                                  ),
                                  SlidableAction(
                                    onPressed: (context) {
                                      _deleteReceipt(receipt['id']);
                                    },
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete,
                                    label: 'Delete',
                                  ),
                                ],
                              ),
                              child: Card(
                                margin: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: _getStatusColor(status),
                                    child: Icon(
                                      _getStatusIcon(status),
                                      color: Colors.white,
                                    ),
                                  ),
                                  title: Text('Receipt #${receipt['id']}'),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Date: ${DateFormat('MMM d, y').format(date)}'),
                                      Text('Client: $clientName'),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '\$${totalAmount.toStringAsFixed(2)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        status.toUpperCase(),
                                        style: TextStyle(
                                          color: _getStatusColor(status),
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _createNewReceipt,
        tooltip: 'Create Receipt',
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      case 'pending':
      default:
        return Icons.pending;
    }
  }

  Future<void> _createNewReceipt() async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ReceiptFormScreen(),
      ),
    ).then((_) => _loadReceipts());
  }

  void _viewReceiptDetails(int receiptId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReceiptDetailScreen(receiptId: receiptId),
      ),
    );
  }

  void _deleteReceipt(int receiptId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Receipt'),
        content: Text('Are you sure you want to delete receipt #$receiptId?'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              try {
                await _dbHelper.deleteReceipt(receiptId);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Receipt deleted successfully'),
                    backgroundColor: AppConstants.successColor,
                  ),
                );
                _loadReceipts(); // Refresh the list
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error deleting receipt: $e'),
                    backgroundColor: AppConstants.errorColor,
                  ),
                );
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

// Receipt Form Screen for creating new receipts
class ReceiptFormScreen extends StatefulWidget {
  final Receipt? receipt;

  const ReceiptFormScreen({Key? key, this.receipt}) : super(key: key);

  @override
  State<ReceiptFormScreen> createState() => _ReceiptFormScreenState();
}

class _ReceiptFormScreenState extends State<ReceiptFormScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  List<Client> _clients = [];
  Client? _selectedClient;
  List<ReceiptItem> _items = [];
  List<Product> _products = [];
  
  bool _isLoading = true;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load clients and products
      final clients = await _dbHelper.getClients();
      final products = await _dbHelper.getProducts();
      
      setState(() {
        _clients = clients;
        _products = products;
        
        // Initialize with existing receipt data if editing
        if (widget.receipt != null) {
          if (widget.receipt!.clientId != null) {
            _selectedClient = _clients.firstWhere(
              (client) => client.id == widget.receipt!.clientId,
              orElse: () => Client(name: 'Unknown Client'),
            );
          }
          // We would also load receipt items here
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _updateTotal() {
    double total = 0;
    for (var item in _items) {
      total += item.total;
    }
    setState(() {
      _totalAmount = total;
    });
  }

  Future<void> _addProduct() async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return ProductSelectionSheet(products: _products);
      },
    );
    
    if (result != null) {
      final product = result['product'] as Product;
      final quantity = result['quantity'] as int;
      final priceAtSale = product.sellPrice ?? 0.0;
      
      setState(() {
        _items.add(ReceiptItem(
          receiptId: 0, // Will be updated when saving
          productId: product.id!,
          quantity: quantity,
          price: priceAtSale,
        ));
      });
      
      _updateTotal();
    }
  }

  void _removeItem(int index) {
    setState(() {
      _items.removeAt(index);
    });
    _updateTotal();
  }

  Future<void> _saveReceipt() async {
    if (_formKey.currentState!.validate() && _items.isNotEmpty) {
      try {
        // Create receipt
        final receipt = Receipt(
          date: DateTime.now(),
          clientId: _selectedClient?.id,
          type: 'sale', // Added required type field
          totalAmount: _totalAmount,
          status: 'pending',
        );
        
        // Save receipt to get ID
        final receiptId = await _dbHelper.insertReceipt(receipt);
        
        // Save receipt items
        for (final item in _items) {
          final receiptItem = ReceiptItem(
            receiptId: receiptId,
            productId: item.productId,
            quantity: item.quantity,
            price: item.price,
          );
          await _dbHelper.insertReceiptItem(receiptItem);
          
          // Update product inventory
          final product = _products.firstWhere((p) => p.id == item.productId);
          product.quantity -= item.quantity;
          await _dbHelper.updateProduct(product);
        }
        
        Navigator.pop(context);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt created successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving receipt: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } else if (_items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please add at least one product to the receipt'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.receipt == null ? 'Create Receipt' : 'Edit Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveReceipt,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: Column(
                children: [
                  // Client selection
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: DropdownButtonFormField<Client>(
                      decoration: const InputDecoration(
                        labelText: 'Client',
                        border: OutlineInputBorder(),
                      ),
                      value: _selectedClient,
                      items: [
                        const DropdownMenuItem<Client>(
                          value: null,
                          child: Text('Walk-in Customer'),
                        ),
                        ..._clients.map((client) {
                          return DropdownMenuItem<Client>(
                            value: client,
                            child: Text(client.name),
                          );
                        }).toList(),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedClient = value;
                        });
                      },
                    ),
                  ),
                  
                  // Receipt items
                  Expanded(
                    child: _items.isEmpty
                        ? const Center(
                            child: Text('No items added to receipt'),
                          )
                        : ListView.builder(
                            itemCount: _items.length,
                            itemBuilder: (context, index) {
                              final item = _items[index];
                              final product = _products.firstWhere(
                                (p) => p.id == item.productId,
                              );
                              
                              return ListTile(
                                title: Text(product.name),
                                subtitle: Text('${item.quantity} x \$${item.price.toStringAsFixed(2)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '\$${item.total.toStringAsFixed(2)}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete, color: Colors.red),
                                      onPressed: () => _removeItem(index),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  
                  // Total and actions
                  Container(
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.5),
                          spreadRadius: 1,
                          blurRadius: 3,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Total Amount:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              '\$${_totalAmount.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _addProduct,
                          icon: const Icon(Icons.add_shopping_cart),
                          label: const Text('Add Product'),
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// Widget for selecting products
class ProductSelectionSheet extends StatefulWidget {
  final List<Product> products;
  
  const ProductSelectionSheet({Key? key, required this.products}) : super(key: key);
  
  @override
  State<ProductSelectionSheet> createState() => _ProductSelectionSheetState();
}

class _ProductSelectionSheetState extends State<ProductSelectionSheet> {
  Product? _selectedProduct;
  int _quantity = 1;
  String _searchQuery = '';
  bool _isScannerVisible = false;
  final MobileScannerController _scannerController = MobileScannerController();
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _scanBarcode() {
    setState(() {
      _isScannerVisible = true;
    });
  }

  void _closeScanner() {
    setState(() {
      _isScannerVisible = false;
    });
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (capture.barcodes.isNotEmpty) {
      final barcode = capture.barcodes.first.rawValue ?? '';
      setState(() {
        _searchQuery = barcode;
        _isScannerVisible = false;
      });
      
      // Attempt to find and select the product with matching barcode
      final matchingProduct = widget.products.firstWhere(
        (product) => product.barcode == barcode,
        orElse: () => widget.products[0],
      );
      
      setState(() {
        _selectedProduct = matchingProduct;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredProducts = widget.products.where((product) {
      final searchLower = _searchQuery.toLowerCase();
      return product.name.toLowerCase().contains(searchLower) ||
          (product.barcode?.toLowerCase() ?? '').contains(searchLower);
    }).toList();
    
    // Show scanner if visible
    if (_isScannerVisible) {
      return Stack(
        children: [
          Positioned.fill(
            child: MobileScanner(
              controller: _scannerController,
              onDetect: _onBarcodeDetected,
            ),
          ),
          Positioned(
            top: 20,
            right: 20,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: _closeScanner,
            ),
          ),
        ],
      );
    }
    
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Text(
                'Select Product',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Products',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setState(() {
                          _searchQuery = value;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: _scanBarcode,
                    tooltip: 'Scan Barcode',
                    color: AppConstants.primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: filteredProducts.length,
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    final isSelected = _selectedProduct?.id == product.id;
                    
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: isSelected 
                            ? AppConstants.primaryColor 
                            : AppConstants.primaryColor.withOpacity(0.3),
                        child: Text(
                          product.name.substring(0, 1),
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ),
                      title: Text(product.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.barcode != null)
                            Text('Barcode: ${product.barcode}'),
                          Text('Stock: ${product.quantity}'),
                        ],
                      ),
                      trailing: Text(
                        '\$${product.sellPrice?.toStringAsFixed(2) ?? 'N/A'}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          _selectedProduct = product;
                        });
                      },
                    );
                  },
                ),
              ),
              if (_selectedProduct != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Quantity:'),
                    Expanded(
                      child: Slider(
                        value: _quantity.toDouble(),
                        min: 1,
                        max: _selectedProduct!.quantity.toDouble(),
                        divisions: _selectedProduct!.quantity,
                        label: _quantity.toString(),
                        onChanged: (value) {
                          setState(() {
                            _quantity = value.toInt();
                          });
                        },
                      ),
                    ),
                    SizedBox(
                      width: 50,
                      child: Text(_quantity.toString()),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context, {
                      'product': _selectedProduct,
                      'quantity': _quantity,
                    });
                  },
                  child: const Text('Add to Receipt'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// Receipt Detail Screen
class ReceiptDetailScreen extends StatefulWidget {
  final int receiptId;
  
  const ReceiptDetailScreen({Key? key, required this.receiptId}) : super(key: key);
  
  @override
  State<ReceiptDetailScreen> createState() => _ReceiptDetailScreenState();
}

class _ReceiptDetailScreenState extends State<ReceiptDetailScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = true;
  Map<String, dynamic>? _receiptData;
  
  @override
  void initState() {
    super.initState();
    _loadReceiptDetails();
  }
  
  Future<void> _loadReceiptDetails() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final data = await _dbHelper.getReceiptWithDetails(widget.receiptId);
      setState(() {
        _receiptData = data;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading receipt details: $e'),
          backgroundColor: AppConstants.errorColor,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt Details'),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    if (_receiptData == null || _receiptData!['receipt'] == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Receipt Details'),
        ),
        body: const Center(
          child: Text('Receipt not found'),
        ),
      );
    }
    
    final receipt = Receipt.fromMap(_receiptData!['receipt']);
    final items = _receiptData!['items'] as List<Map<String, dynamic>>;
    final client = _receiptData!['client'];
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Receipt #${receipt.id}'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'changeStatus') {
                _changeReceiptStatus(receipt);
              } else if (value == 'delete') {
                _deleteReceipt(receipt.id!);
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                const PopupMenuItem<String>(
                  value: 'changeStatus',
                  child: Text('Change Status'),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Text('Delete'),
                ),
              ];
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Receipt Information',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Chip(
                          label: Text(
                            receipt.status.toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getStatusColor(receipt.status),
                        ),
                      ],
                    ),
                    const Divider(),
                    _buildInfoRow('ID', '#${receipt.id}'),
                    _buildInfoRow(
                      'Date',
                      DateFormat('MMMM d, y - h:mm a').format(receipt.date),
                    ),
                    _buildInfoRow(
                      'Client',
                      client != null ? client['name'] : 'Walk-in Customer',
                    ),
                    if (client != null && client['phone'] != null)
                      _buildInfoRow('Phone', client['phone']),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Items',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: items.length,
                separatorBuilder: (context, index) => const Divider(),
                itemBuilder: (context, index) {
                  final item = items[index];
                  final quantity = item['quantity'];
                  final priceAtSale = item['price_at_sale'].toDouble();
                  final total = item['total'].toDouble();
                  final productName = item['product_name'] ?? 'Unknown Product';
                  
                  return ListTile(
                    title: Text(productName),
                    subtitle: Text('${quantity} x \$${priceAtSale.toStringAsFixed(2)}'),
                    trailing: Text(
                      '\$${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Amount',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '\$${receipt.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
  
  Future<void> _changeReceiptStatus(Receipt receipt) async {
    final result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Change Receipt Status'),
          children: <Widget>[
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'pending');
              },
              child: const Text('Pending'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'completed');
              },
              child: const Text('Completed'),
            ),
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, 'cancelled');
              },
              child: const Text('Cancelled'),
            ),
          ],
        );
      },
    );
    
    if (result != null && result != receipt.status) {
      try {
        receipt.status = result;
        await _dbHelper.updateReceipt(receipt);
        await _loadReceiptDetails();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt status updated to ${result.toUpperCase()}'),
            backgroundColor: AppConstants.successColor,
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating status: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }
  
  Future<void> _deleteReceipt(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Receipt'),
          content: const Text('Are you sure you want to delete this receipt? This action cannot be undone.'),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
    
    if (confirmed == true) {
      try {
        await _dbHelper.deleteReceipt(id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt deleted successfully'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        
        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting receipt: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }
}