import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/license_activation_screen.dart';
import 'services/cart_provider.dart';
import 'services/licensing_service.dart';
import 'utils/app_constants.dart';
import 'services/database_helper_new.dart';
import 'services/database_helper_receipt.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the database
  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // This will create the database if it doesn't exist
    
    // Initialize receipt database helper
    final receiptDbHelper = DatabaseHelperReceipt();
    await receiptDbHelper.initialize();
  } catch (e) {
    print('Database initialization error: $e');
    // In web, we might get errors with certain plugins
    // We'll handle this gracefully
  }
  
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final LicensingService _licensingService = LicensingService();
  bool _isLicenseChecked = false;
  bool _isLicensed = false;
  
  @override
  void initState() {
    super.initState();
    _checkLicense();
  }
  
  Future<void> _checkLicense() async {
    // Skip license check during development - set to true for production
    const bool enforceLicensing = false;
    
    if (enforceLicensing) {
      final isLicensed = await _licensingService.initialize();
      setState(() {
        _isLicenseChecked = true;
        _isLicensed = isLicensed;
      });
    } else {
      // Development mode - skip licensing
      setState(() {
        _isLicenseChecked = true;
        _isLicensed = true;
      });
    }
  }
  
  void _onLicenseActivated() {
    setState(() {
      _isLicensed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'EtuStack Inventory',
        theme: AppConstants.appTheme,
        home: !_isLicenseChecked
            ? const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            : !_isLicensed
                ? LicenseActivationScreen(onActivated: _onLicenseActivated)
                : const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
