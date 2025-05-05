import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../services/database_helper.dart';
import '../models/product.dart';
import '../models/category.dart';
import '../models/supplier.dart';
import '../utils/app_constants.dart';
import 'product_scanner_screen.dart';

class ProductManagementScreen extends StatefulWidget {
  const ProductManagementScreen({Key? key}) : super(key: key);

  @override
  State<ProductManagementScreen> createState() =>
      _ProductManagementScreenState();
}

class _ProductManagementScreenState extends State<ProductManagementScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper();
  List<Product> _products = [];
  List<Category> _categories = [];
  List<Supplier> _suppliers = [];
  bool _isLoading = true;
  String _searchQuery = '';

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
      final products = await _dbHelper.getProducts();
      final categories = await _dbHelper.getCategories();
      final suppliers = await _dbHelper.getSuppliers();

      setState(() {
        _products = products;
        _categories = categories;
        _suppliers = suppliers;
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

  @override
  Widget build(BuildContext context) {
    final filteredProducts =
        _products.where((product) {
          final searchLower = _searchQuery.toLowerCase();
          return product.name.toLowerCase().contains(searchLower) ||
              (product.barcode?.toLowerCase() ?? '').contains(searchLower) ||
              (product.description?.toLowerCase() ?? '').contains(searchLower);
        }).toList();

    filteredProducts.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'scan',
            onPressed: _scanBarcode,
            backgroundColor: Colors.amber,
            child: const Icon(Icons.qr_code_scanner),
          ),
          const SizedBox(height: 16),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _addProduct,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
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
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : filteredProducts.isEmpty
                    ? const Center(child: Text('No products found'))
                    : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];

                          // Find category and supplier names
                          final categoryName =
                              product.categoryId != null
                                  ? _categories
                                      .firstWhere(
                                        (cat) => cat.id == product.categoryId,
                                        orElse: () => Category(name: 'Unknown'),
                                      )
                                      .name
                                  : 'None';

                          final supplierName =
                              product.supplierId != null
                                  ? _suppliers
                                      .firstWhere(
                                        (supp) => supp.id == product.supplierId,
                                        orElse: () => Supplier(name: 'Unknown'),
                                      )
                                      .name
                                  : 'None';

                          return Slidable(
                            endActionPane: ActionPane(
                              motion: const ScrollMotion(),
                              children: [
                                SlidableAction(
                                  onPressed: (context) {
                                    _editProduct(product);
                                  },
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                  icon: Icons.edit,
                                  label: 'Edit',
                                ),
                                SlidableAction(
                                  onPressed: (context) {
                                    _deleteProduct(product);
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
                                vertical: 4,
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppConstants.primaryColor,
                                  child: Text(
                                    product.name.substring(0, 1),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                                title: Text(product.name),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (product.barcode != null)
                                      Text('Barcode: ${product.barcode}'),
                                    Text('Category: $categoryName'),
                                    Text('Supplier: $supplierName'),
                                  ],
                                ),
                                trailing: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      '\$${product.sellPrice?.toStringAsFixed(2) ?? 'N/A'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                    Text(
                                      'Qty: ${product.quantity}',
                                      style: TextStyle(
                                        color:
                                            product.quantity > 0
                                                ? AppConstants.successColor
                                                : AppConstants.errorColor,
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  _viewProduct(product);
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }

  Future<void> _addProduct() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProductFormScreen(
              categories: _categories,
              suppliers: _suppliers,
              onProductSaved: _loadData,
            ),
      ),
    );

    if (result == true) {
      _loadData();
    }
  }

  Future<void> _scanBarcode() async {
    // Show scanner screen
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProductScannerScreen(
              onProductFound: (product) {
                // Product found but no specific action needed for navigation
              },
              onProductUpdated: (product) {
                // Update the product list with the updated product
                setState(() {
                  final index = _products.indexWhere((p) => p.id == product.id);
                  if (index != -1) {
                    _products[index] = product;
                  }
                });
              },
            ),
      ),
    );

    // Check if we need to create a new product with scanned barcode
    if (result != null && result['create'] == true) {
      // Get the barcode from the scan result
      final String barcode = result['barcode'] as String;
      debugPrint('Creating new product with barcode: $barcode');

      // Navigate to product form with pre-filled barcode
      final addResult = await Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (context) => ProductFormScreen(
                initialBarcode: barcode,
                categories: _categories,
                suppliers: _suppliers,
                onProductSaved: _loadData,
              ),
        ),
      );

      if (addResult == true) {
        _loadData();
      }
    }
  }

  void _editProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProductFormScreen(
              product: product,
              isEditing: true,
              categories: _categories,
              suppliers: _suppliers,
              onProductSaved: _loadData,
            ),
      ),
    );
  }

  void _viewProduct(Product product) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ProductDetailScreen(
              product: product,
              categoryName:
                  product.categoryId != null
                      ? _categories
                          .firstWhere(
                            (cat) => cat.id == product.categoryId,
                            orElse: () => Category(name: 'Unknown'),
                          )
                          .name
                      : 'None',
              supplierName:
                  product.supplierId != null
                      ? _suppliers
                          .firstWhere(
                            (supp) => supp.id == product.supplierId,
                            orElse: () => Supplier(name: 'Unknown'),
                          )
                          .name
                      : 'None',
            ),
      ),
    );
  }

  void _deleteProduct(Product product) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Product'),
            content: Text('Are you sure you want to delete ${product.name}?'),
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
                    await _dbHelper.deleteProduct(product.id!);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Product deleted successfully'),
                        backgroundColor: AppConstants.successColor,
                      ),
                    );
                    _loadData();
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error deleting product: $e'),
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

// Product Form Screen for adding and editing products
class ProductFormScreen extends StatefulWidget {
  final Product? product;
  final bool isEditing;
  final String? initialBarcode;
  final List<Category> categories;
  final List<Supplier> suppliers;
  final Function onProductSaved;

  const ProductFormScreen({
    Key? key,
    this.product,
    this.isEditing = false,
    this.initialBarcode,
    required this.categories,
    required this.suppliers,
    required this.onProductSaved,
  }) : super(key: key);

  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _quantityController = TextEditingController();
  final _buyPriceController = TextEditingController();
  final _sellPriceController = TextEditingController();
  int? _selectedCategoryId;
  int? _selectedSupplierId;
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();

    if (widget.isEditing && widget.product != null) {
      // Editing existing product
      _nameController.text = widget.product!.name;
      _barcodeController.text = widget.product!.barcode ?? '';
      _descriptionController.text = widget.product!.description ?? '';
      _quantityController.text = widget.product!.quantity.toString();
      _buyPriceController.text = widget.product!.buyPrice?.toString() ?? '';
      _sellPriceController.text = widget.product!.sellPrice?.toString() ?? '';
      _selectedCategoryId = widget.product!.categoryId;
      _selectedSupplierId = widget.product!.supplierId;
    } else {
      // Creating new product
      _quantityController.text = '0';

      // Pre-fill barcode if provided
      if (widget.initialBarcode != null && widget.initialBarcode!.isNotEmpty) {
        debugPrint('Setting barcode: ${widget.initialBarcode}');
        _barcodeController.text = widget.initialBarcode!;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _barcodeController.dispose();
    _descriptionController.dispose();
    _quantityController.dispose();
    _buyPriceController.dispose();
    _sellPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'Add Product'),
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: const InputDecoration(
                          labelText: 'Product Name',
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a product name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _barcodeController,
                        decoration: const InputDecoration(
                          labelText: 'Barcode',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _quantityController,
                        decoration: const InputDecoration(
                          labelText: 'Quantity',
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a quantity';
                          }
                          if (int.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _buyPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Buy Price',
                                border: OutlineInputBorder(),
                                prefixText: '\$',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid price';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: TextFormField(
                              controller: _sellPriceController,
                              decoration: const InputDecoration(
                                labelText: 'Sell Price',
                                border: OutlineInputBorder(),
                                prefixText: '\$',
                              ),
                              keyboardType: TextInputType.number,
                              validator: (value) {
                                if (value != null && value.isNotEmpty) {
                                  if (double.tryParse(value) == null) {
                                    return 'Please enter a valid price';
                                  }
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedCategoryId,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...widget.categories.map((category) {
                            return DropdownMenuItem<int>(
                              value: category.id,
                              child: Text(category.name),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedCategoryId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<int>(
                        value: _selectedSupplierId,
                        decoration: const InputDecoration(
                          labelText: 'Supplier',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int>(
                            value: null,
                            child: Text('None'),
                          ),
                          ...widget.suppliers.map((supplier) {
                            return DropdownMenuItem<int>(
                              value: supplier.id,
                              child: Text(supplier.name),
                            );
                          }).toList(),
                        ],
                        onChanged: (value) {
                          setState(() {
                            _selectedSupplierId = value;
                          });
                        },
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _saveProduct,
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                        child: Text(
                          widget.isEditing ? 'Update Product' : 'Add Product',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
    );
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final product = Product(
          id: widget.product?.id,
          name: _nameController.text.trim(),
          barcode:
              _barcodeController.text.trim().isNotEmpty
                  ? _barcodeController.text.trim()
                  : null,
          description:
              _descriptionController.text.trim().isNotEmpty
                  ? _descriptionController.text.trim()
                  : null,
          quantity: int.parse(_quantityController.text.trim()),
          buyPrice:
              _buyPriceController.text.trim().isNotEmpty
                  ? double.parse(_buyPriceController.text.trim())
                  : null,
          sellPrice:
              _sellPriceController.text.trim().isNotEmpty
                  ? double.parse(_sellPriceController.text.trim())
                  : null,
          categoryId: _selectedCategoryId,
          supplierId: _selectedSupplierId,
        );

        if (widget.product == null) {
          await _dbHelper.insertProduct(product);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product added successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        } else {
          await _dbHelper.updateProduct(product);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Product updated successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }

        widget.onProductSaved();
        Navigator.of(context).pop(true);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving product: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}

// Product Detail Screen
class ProductDetailScreen extends StatelessWidget {
  final Product product;
  final String categoryName;
  final String supplierName;

  const ProductDetailScreen({
    Key? key,
    required this.product,
    required this.categoryName,
    required this.supplierName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(product.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Product Information',
                      style: AppConstants.subheadingStyle,
                    ),
                    const Divider(),
                    _buildInfoRow('Name', product.name),
                    if (product.barcode != null)
                      _buildInfoRow('Barcode', product.barcode!),
                    if (product.description != null)
                      _buildInfoRow('Description', product.description!),
                    _buildInfoRow('Category', categoryName),
                    _buildInfoRow('Supplier', supplierName),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Inventory & Pricing',
                      style: AppConstants.subheadingStyle,
                    ),
                    const Divider(),
                    _buildInfoRow(
                      'Quantity',
                      product.quantity.toString(),
                      valueColor:
                          product.quantity > 0
                              ? AppConstants.successColor
                              : AppConstants.errorColor,
                    ),
                    if (product.buyPrice != null)
                      _buildInfoRow(
                        'Buy Price',
                        '\$${product.buyPrice!.toStringAsFixed(2)}',
                      ),
                    if (product.sellPrice != null)
                      _buildInfoRow(
                        'Sell Price',
                        '\$${product.sellPrice!.toStringAsFixed(2)}',
                      ),
                    if (product.profit != null)
                      _buildInfoRow(
                        'Profit Margin',
                        '${product.profitMargin!.toStringAsFixed(2)}%',
                        valueColor: AppConstants.successColor,
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

  Widget _buildInfoRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor,
                fontWeight: valueColor != null ? FontWeight.bold : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
