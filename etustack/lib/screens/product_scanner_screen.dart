import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../models/product.dart';
import '../services/database_helper.dart';
import '../utils/app_constants.dart';
import '../utils/barcode_scanner_utils.dart';

class ProductScannerScreen extends StatefulWidget {
  final Function(Product) onProductFound;
  final Function(Product)? onProductUpdated;
  final bool allowQuantityUpdate;

  const ProductScannerScreen({
    Key? key,
    required this.onProductFound,
    this.onProductUpdated,
    this.allowQuantityUpdate = true,
  }) : super(key: key);

  @override
  State<ProductScannerScreen> createState() => _ProductScannerScreenState();
}

class _ProductScannerScreenState extends State<ProductScannerScreen> {
  final MobileScannerController _controller =
      BarcodeScannerUtils.createDefaultController();
  final DatabaseHelper _dbHelper = DatabaseHelper();
  bool _isProcessing = false;
  String _lastScannedCode = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Product'),
        actions: [
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.torchState,
              builder: (context, state, child) {
                return Icon(
                  state == TorchState.on ? Icons.flash_on : Icons.flash_off,
                );
              },
            ),
            onPressed: () => _controller.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _controller.cameraFacingState,
              builder: (context, state, child) {
                return Icon(
                  state == CameraFacing.front
                      ? Icons.camera_front
                      : Icons.camera_rear,
                );
              },
            ),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                MobileScanner(controller: _controller, onDetect: _onDetect),
                Positioned.fill(
                  child: Center(
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppConstants.primaryColor,
                          width: 3,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                if (_isProcessing)
                  const Positioned.fill(
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 2,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'Scan a product barcode',
                    style: AppConstants.subheadingStyle,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Position the barcode within the scanner frame',
                    style: AppConstants.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String code = barcodes.first.rawValue ?? '';

    // Avoid duplicate scans
    if (code == _lastScannedCode) return;
    _lastScannedCode = code;

    setState(() {
      _isProcessing = true;
    });

    try {
      // Find product in database
      final product = await _dbHelper.getProductByBarcode(code);

      if (product != null) {
        await _showProductFoundDialog(product);
      } else {
        await _showProductNotFoundDialog(code);
      }
    } finally {
      setState(() {
        _isProcessing = false;
      });

      // Reset last scanned code after a delay
      await Future.delayed(const Duration(seconds: 2));
      _lastScannedCode = '';
    }
  }

  Future<void> _showProductFoundDialog(Product product) async {
    if (widget.allowQuantityUpdate) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => _ProductQuantityUpdateDialog(product: product),
      );

      if (result != null) {
        if (result['update'] == true) {
          // Update product quantity
          final int quantityChange = (result['quantity'] as num).toInt();
          product.quantity = product.quantity + quantityChange;
          await _dbHelper.updateProduct(product);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${product.name} quantity updated (${quantityChange > 0 ? '+' : ''}$quantityChange)',
              ),
              backgroundColor: AppConstants.successColor,
              duration: const Duration(seconds: 2),
            ),
          );

          if (widget.onProductUpdated != null) {
            widget.onProductUpdated!(product);
          }
        }
        // Let the parent know we found a product
        widget.onProductFound(product);
        Navigator.pop(context);
      }
    } else {
      // Simply return the found product without updating quantity
      widget.onProductFound(product);
      Navigator.pop(context);
    }
  }

  Future<void> _showProductNotFoundDialog(String barcode) async {
    debugPrint('Product not found for barcode: $barcode');
    final result = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Product Not Found'),
            content: Text('No product found with barcode: $barcode'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(false);
                },
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                child: const Text('Add New Product'),
              ),
            ],
          ),
    );

    // If user wants to add a new product with this barcode
    if (result == true) {
      debugPrint('Creating new product with barcode: $barcode');
      Navigator.pop(context, {'create': true, 'barcode': barcode});
    }
  }
}

class _ProductQuantityUpdateDialog extends StatefulWidget {
  final Product product;

  const _ProductQuantityUpdateDialog({Key? key, required this.product})
    : super(key: key);

  @override
  State<_ProductQuantityUpdateDialog> createState() =>
      _ProductQuantityUpdateDialogState();
}

class _ProductQuantityUpdateDialogState
    extends State<_ProductQuantityUpdateDialog> {
  int _quantity = 1;
  bool _isIncrement = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Found: ${widget.product.name}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Current quantity: ${widget.product.quantity}'),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Operation:'),
              const SizedBox(width: 16),
              ToggleButtons(
                isSelected: [_isIncrement, !_isIncrement],
                onPressed: (index) {
                  setState(() {
                    _isIncrement = index == 0;
                  });
                },
                children: const [
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.add),
                        SizedBox(width: 4),
                        Text('Add'),
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Icon(Icons.remove),
                        SizedBox(width: 4),
                        Text('Remove'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Quantity:'),
              const SizedBox(width: 16),
              IconButton(
                icon: const Icon(Icons.remove),
                onPressed:
                    _quantity > 1
                        ? () {
                          setState(() {
                            _quantity--;
                          });
                        }
                        : null,
              ),
              Text(
                '$_quantity',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () {
                  setState(() {
                    _quantity++;
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'update': true,
              'quantity': _isIncrement ? _quantity : -_quantity,
            });
          },
          child: const Text('Update Inventory'),
        ),
      ],
    );
  }
}
