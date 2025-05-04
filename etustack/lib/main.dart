import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/home_screen.dart';
import 'services/cart_provider.dart';
import 'utils/app_constants.dart';
import 'services/database_helper_new.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize the database
  try {
    final dbHelper = DatabaseHelper();
    await dbHelper.database; // This will create the database if it doesn't exist
  } catch (e) {
    print('Database initialization error: $e');
    // In web, we might get errors with certain plugins
    // We'll handle this gracefully
  }
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => CartProvider()),
      ],
      child: MaterialApp(
        title: 'EtuStack Inventory',
        theme: AppConstants.appTheme,
        home: const HomeScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
