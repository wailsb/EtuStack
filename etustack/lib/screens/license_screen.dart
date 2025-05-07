import 'package:flutter/material.dart';
import '../services/license_service.dart';
import '../utils/app_constants.dart';
import 'home_screen.dart';

class LicenseScreen extends StatefulWidget {
  const LicenseScreen({Key? key}) : super(key: key);

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final _licenseKeyController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkExistingLicense();
  }

  @override
  void dispose() {
    _licenseKeyController.dispose();
    super.dispose();
  }

  Future<void> _checkExistingLicense() async {
    setState(() {
      _isLoading = true;
    });

    final isActive = await LicenseService.isLicenseActive();

    setState(() {
      _isLoading = false;
    });

    if (isActive) {
      _navigateToHome();
    }
  }

  Future<void> _activateLicense() async {
    final licenseKey = _licenseKeyController.text.trim();
    if (licenseKey.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a license key';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    final success = await LicenseService.activateLicense(licenseKey);

    setState(() {
      _isLoading = false;
    });

    if (success) {
      _navigateToHome();
    } else {
      setState(() {
        _errorMessage = 'Invalid license key. Please check and try again.';
      });
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Configure to resize when keyboard appears
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SafeArea(
              child: SingleChildScrollView(
                // Add this scroll view to handle overflow when keyboard appears
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: ConstrainedBox(
                    // Ensure the content takes at least the full screen height minus padding
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 48 - MediaQuery.of(context).padding.top,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 20), // Add some space at the top
                        const Icon(
                          Icons.inventory_2,
                          size: 64, // Slightly smaller than before
                          color: AppConstants.primaryColor,
                        ),
                        const SizedBox(height: 24),
                        const Text(
                          'EtuStock',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Text(
                          'Inventory Management System',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 36), // Slightly reduced spacing
                        const Text(
                          'Enter License Key',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _licenseKeyController,
                          decoration: InputDecoration(
                            hintText: 'Format: ES01-XXXXXXXX', // Updated format based on memory
                            border: const OutlineInputBorder(),
                            errorText: _errorMessage.isNotEmpty ? _errorMessage : null,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: _activateLicense,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          child: const Text(
                            'Activate License',
                            style: TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Divider(),
                        const SizedBox(height: 16),
                        const Text(
                          'Need a license key?',
                          style: TextStyle(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Contact the administrator to purchase a license for this software.',
                          style: TextStyle(color: Colors.grey),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 20), // Add some space at the bottom
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}