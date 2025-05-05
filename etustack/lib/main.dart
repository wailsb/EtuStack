import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'screens/license_screen.dart';
import 'services/cart_provider.dart';
import 'services/license_service.dart';
import 'utils/app_constants.dart';
import 'services/database_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize the database
  try {
    // Initialize the main database
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // This will create the database if it doesn't exist
    await dbHelper.initialize(); // Additional check for tables
    
    print('Database initialization completed successfully');
  } catch (e) {
    print('Database initialization error: $e');
    // In web, we might get errors with certain plugins
    // We'll handle this gracefully
  }

  // Check if license is already active
  final hasLicense = await LicenseService.isLicenseActive();

  runApp(MyApp(hasValidLicense: hasLicense));
}

class MyApp extends StatelessWidget {
  final bool hasValidLicense;
  
  const MyApp({super.key, required this.hasValidLicense});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => CartProvider())],
      child: MaterialApp(
        title: 'EtuStack Inventory',
        theme: AppConstants.appTheme,
        // Show LicenseScreen if no valid license, otherwise show HomeScreen
        home: hasValidLicense ? const HomeScreen() : const LicenseScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
