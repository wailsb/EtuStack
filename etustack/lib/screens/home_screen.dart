import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/cart_provider.dart';
import '../utils/app_constants.dart';
import './product_management_screen.dart';
import './category_management_screen.dart';
import './supplier_management_screen.dart';
import './client_management_screen.dart';
import './scanner_screen.dart';
import './admin_dashboard_screen.dart';
import './cart_screen.dart';
import './receipt_management_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  
  // Navigation method to be called from children
  void navigateTo(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
  
  final List<Widget> _pages = [
    const MainDashboard(),
    const ProductManagementScreen(),
    const CategoryManagementScreen(),
    const SupplierManagementScreen(),
    const ClientManagementScreen(),
    const ReceiptManagementScreen(),
    const AdminDashboardScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EtuStack Inventory'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.shopping_cart),
                if (context.watch<CartProvider>().itemCount > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        '${context.watch<CartProvider>().itemCount}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
              ],
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const CartScreen()),
              );
            },
          ),
        ],
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                color: AppConstants.primaryColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(
                    Icons.inventory_2,
                    color: Colors.white,
                    size: 64,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'EtuStack Inventory',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard),
              title: const Text('Main Dashboard'),
              selected: _selectedIndex == 0,
              onTap: () {
                setState(() {
                  _selectedIndex = 0;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.inventory),
              title: const Text('Product Management'),
              selected: _selectedIndex == 1,
              onTap: () {
                setState(() {
                  _selectedIndex = 1;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.category),
              title: const Text('Category Management'),
              selected: _selectedIndex == 2,
              onTap: () {
                setState(() {
                  _selectedIndex = 2;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Supplier Management'),
              selected: _selectedIndex == 3,
              onTap: () {
                setState(() {
                  _selectedIndex = 3;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.people),
              title: const Text('Client Management'),
              selected: _selectedIndex == 4,
              onTap: () {
                setState(() {
                  _selectedIndex = 4;
                });
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.receipt),
              title: const Text('Receipt Management'),
              selected: _selectedIndex == 5,
              onTap: () {
                setState(() {
                  _selectedIndex = 5;
                });
                Navigator.pop(context);
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.analytics),
              title: const Text('Admin Dashboard'),
              selected: _selectedIndex == 6,
              onTap: () {
                setState(() {
                  _selectedIndex = 6;
                });
                Navigator.pop(context);
              },
            ),
          ],
        ),
      ),
      // Set resizeToAvoidBottomInset to true to properly handle keyboard
      resizeToAvoidBottomInset: true,
      // Use SafeArea to respect system UI elements
      body: SafeArea(
        child: _pages[_selectedIndex],
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                );
              },
              tooltip: 'Scan Barcode',
              child: const Icon(Icons.qr_code_scanner),
            )
          : null,
    );
  }
}

class MainDashboard extends StatelessWidget {
  const MainDashboard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get reference to the home screen state
    final homeScreenState = context.findAncestorStateOfType<_HomeScreenState>();
    // Get the available screen height (accounting for keyboard)
    final availableHeight = MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom - 
                          kToolbarHeight;
    
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            physics: const AlwaysScrollableScrollPhysics(), // Ensure always scrollable even with small content
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: availableHeight - 32, // 32 for the padding
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Welcome to EtuStack Inventory',
                    style: AppConstants.headingStyle,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Your all-in-one inventory management solution',
                    style: AppConstants.subheadingStyle,
                  ),
                  const SizedBox(height: 24),
                  // Use LayoutBuilder to make responsive grid based on screen width
                  LayoutBuilder(
                    builder: (context, constraints) {
                      // Determine grid cross axis count based on width
                      final crossAxisCount = constraints.maxWidth > 600 ? 3 : 2;
                      return GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          // Adjust aspect ratio to better fit content
                          childAspectRatio: constraints.maxWidth > 600 ? 1.2 : 1.0,
                        ),
                        itemCount: 4, // Number of cards
                        itemBuilder: (context, index) {
                          // Define card data
                          final cardData = [
                            {
                              'icon': Icons.qr_code_scanner,
                              'title': 'Scan Products',
                              'subtitle': 'Scan barcodes to add products to cart',
                              'onTap': () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const ScannerScreen()),
                                );
                              },
                            },
                            {
                              'icon': Icons.shopping_cart,
                              'title': 'Current Cart',
                              'subtitle': 'View and manage your cart',
                              'onTap': () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const CartScreen()),
                                );
                              },
                            },
                            {
                              'icon': Icons.inventory,
                              'title': 'Products',
                              'subtitle': 'Manage your product inventory',
                              'onTap': () {
                                // Use callback to navigate to products screen
                                homeScreenState?.navigateTo(1);
                              },
                            },
                            {
                              'icon': Icons.analytics,
                              'title': 'Analytics',
                              'subtitle': 'View sales data and reports',
                              'onTap': () {
                                // Use callback to navigate to admin dashboard
                                homeScreenState?.navigateTo(5);
                              },
                            },
                          ];
                          
                          return _buildFeatureCard(
                            context,
                            cardData[index]['icon'] as IconData,
                            cardData[index]['title'] as String,
                            cardData[index]['subtitle'] as String,
                            cardData[index]['onTap'] as VoidCallback,
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min, // Important to prevent overflow
            children: [
              Icon(
                icon,
                size: 40, // Slightly smaller for better fit
                color: AppConstants.primaryColor,
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16, // Slightly smaller for better fit
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
                maxLines: 1, // Limit to 1 line
                overflow: TextOverflow.ellipsis, // Handle overflow text
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
                maxLines: 2, // Limit to 2 lines
                overflow: TextOverflow.ellipsis, // Handle overflow text
              ),
            ],
          ),
        ),
      ),
    );
  }
}