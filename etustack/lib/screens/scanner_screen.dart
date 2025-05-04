import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/database_helper.dart';
import '../services/cart_provider.dart';
import '../models/product.dart';
import '../utils/app_constants.dart';
import '../utils/barcode_scanner_utils.dart';
import '../widgets/product_quantity_dialog.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({Key? key}) : super(key: key);

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final MobileScannerController _controller = BarcodeScannerUtils.createDefaultController();
  bool _isProcessing = false;
  String _lastScannedCode = '';
  final DatabaseHelper _dbHelper = DatabaseHelper();
  
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
                  state == CameraFacing.front ? Icons.camera_front : Icons.camera_rear,
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
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                ),
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
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
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
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => ProductQuantityDialog(product: product),
    );
    
    if (result != null && result['add'] == true) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.addProduct(product, quantity: result['quantity']);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${product.name} added to cart'),
          backgroundColor: AppConstants.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _showProductNotFoundDialog(String barcode) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Product Not Found'),
        content: Text('No product found with barcode: $barcode'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Add logic to navigate to add product screen with pre-filled barcode
              // Navigator.push(context, MaterialPageRoute(builder: (context) => 
              //   AddProductScreen(initialBarcode: barcode),
              // ));
            },
            child: const Text('Add New Product'),
          ),
        ],
      ),
    );
  }
}
