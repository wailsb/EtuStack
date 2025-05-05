import 'package:flutter/material.dart';
import '../services/licensing_service.dart';
import '../utils/app_constants.dart';

class LicenseActivationScreen extends StatefulWidget {
  final Function onActivated;

  const LicenseActivationScreen({
    Key? key,
    required this.onActivated,
  }) : super(key: key);

  @override
  State<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends State<LicenseActivationScreen> {
  final LicensingService _licensingService = LicensingService();
  bool _isChecking = true;
  bool _isActivated = false;
  String _macAddress = '';
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _checkLicense();
  }

  Future<void> _checkLicense() async {
    setState(() {
      _isChecking = true;
      _errorMessage = '';
    });

    try {
      // Check if app is activated
      final isActive = await _licensingService.initialize();
      
      // Get MAC address for display
      final macAddress = await _licensingService.getMacAddress();
      
      setState(() {
        _isActivated = isActive;
        _macAddress = macAddress;
        _isChecking = false;
      });
      
      if (isActive) {
        // Wait briefly to show activated state before proceeding
        await Future.delayed(const Duration(seconds: 1));
        widget.onActivated();
      }
    } catch (e) {
      setState(() {
        _isChecking = false;
        _errorMessage = 'Error checking license: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppConstants.primaryColor,
              AppConstants.primaryColor.withOpacity(0.7),
            ],
          ),
        ),
        child: Center(
          child: Card(
            margin: const EdgeInsets.all(32),
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: _isChecking
                  ? const _LoadingContent()
                  : _isActivated
                      ? _ActivatedContent(onContinue: widget.onActivated)
                      : _ActivationContent(
                          macAddress: _macAddress,
                          errorMessage: _errorMessage,
                          onRetry: _checkLicense,
                        ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.security,
            size: 64,
            color: AppConstants.primaryColor,
          ),
          const SizedBox(height: 24),
          const Text(
            'EtuStack Inventory',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Checking license...',
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 24),
          const CircularProgressIndicator(),
        ],
      ),
    );
  }
}

class _ActivatedContent extends StatelessWidget {
  final Function onContinue;

  const _ActivatedContent({
    Key? key,
    required this.onContinue,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 300,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 64,
            color: Colors.green,
          ),
          const SizedBox(height: 24),
          const Text(
            'EtuStack Inventory',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'License Activated',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => onContinue(),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Continue to App'),
          ),
        ],
      ),
    );
  }
}

class _ActivationContent extends StatelessWidget {
  final String macAddress;
  final String errorMessage;
  final VoidCallback onRetry;

  const _ActivationContent({
    Key? key,
    required this.macAddress,
    required this.errorMessage,
    required this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.security,
            size: 64,
            color: AppConstants.primaryColor,
          ),
          const SizedBox(height: 24),
          const Text(
            'EtuStack Inventory',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'License Activation Required',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'This software requires activation. Please create a license file in the application documents directory with the following MAC address:',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(
              macAddress,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'The license file must be named "etustack_license.key" and placed in the application documents directory.',
            textAlign: TextAlign.center,
          ),
          if (errorMessage.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              errorMessage,
              style: const TextStyle(
                color: Colors.red,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(double.infinity, 50),
            ),
            child: const Text('Check Again'),
          ),
        ],
      ),
    );
  }
}
