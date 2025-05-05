import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';

/// A service to handle application licensing based on MAC address
class LicensingService {
  static final LicensingService _instance = LicensingService._internal();
  factory LicensingService() => _instance;

  // Private constants
  static const String _licenseKeyPref = 'license_key';
  static const String _activationDatePref = 'activation_date';
  static const String _macAddressPref = 'mac_address';
  static const String _licenseFileName = 'etustack_license.key';

  // Boolean to store current activation status
  bool _isActivated = false;
  bool get isActivated => _isActivated;

  LicensingService._internal();

  /// Initialize the licensing service and check activation status
  Future<bool> initialize() async {
    // On web platform, we don't enforce licensing
    if (kIsWeb) {
      _isActivated = true;
      return true;
    }

    try {
      // Check if we've already validated the license in this session
      if (_isActivated) return true;

      // Read activation status from shared preferences
      final prefs = await SharedPreferences.getInstance();
      final savedKey = prefs.getString(_licenseKeyPref);
      final savedMac = prefs.getString(_macAddressPref);
      final activationDateStr = prefs.getString(_activationDatePref);

      // If no saved license data, need to activate
      if (savedKey == null || savedMac == null || activationDateStr == null) {
        return _activateFromFile();
      }

      // Get current MAC address
      final currentMac = await getMacAddress();
      
      // Compare with saved MAC address
      if (currentMac != savedMac) {
        debugPrint('License validation failed: MAC address mismatch');
        _isActivated = false;
        return false;
      }

      // Successfully activated
      _isActivated = true;
      return true;
    } catch (e) {
      debugPrint('Error checking license: $e');
      _isActivated = false;
      return false;
    }
  }

  /// Activate the application using a license file
  Future<bool> _activateFromFile() async {
    try {
      // Path where license file should be located:
      // Android: /data/data/[package_name]/files/
      // iOS: Documents directory
      // Windows/macOS/Linux: Application documents directory
      
      final directory = await _getLicenseFileDirectory();
      final licensePath = '${directory.path}/$_licenseFileName';
      final file = File(licensePath);
      
      // Check if license file exists
      if (!await file.exists()) {
        debugPrint('License file not found at: $licensePath');
        return false;
      }
      
      // Read and decode license file
      final licenseData = await file.readAsString();
      final licenseJson = jsonDecode(licenseData);
      
      // Extract MAC address from license
      final licensedMac = licenseJson['mac_address'];
      final licenseKey = licenseJson['license_key'];
      
      if (licensedMac == null || licenseKey == null) {
        debugPrint('Invalid license file format');
        return false;
      }
      
      // Get current MAC address
      final currentMac = await getMacAddress();
      
      // Validate MAC address
      if (currentMac != licensedMac) {
        debugPrint('License validation failed: MAC address mismatch');
        return false;
      }
      
      // Save activation data
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_licenseKeyPref, licenseKey);
      await prefs.setString(_macAddressPref, licensedMac);
      await prefs.setString(_activationDatePref, DateTime.now().toIso8601String());
      
      _isActivated = true;
      return true;
    } catch (e) {
      debugPrint('Error activating license: $e');
      return false;
    }
  }

  /// Get directory where license file should be located
  Future<Directory> _getLicenseFileDirectory() async {
    if (Platform.isAndroid || Platform.isIOS) {
      return await getApplicationDocumentsDirectory();
    } else if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return await getApplicationDocumentsDirectory();
    } else {
      throw UnsupportedError('Unsupported platform for licensing');
    }
  }
  
  /// Get the MAC address of the current device
  Future<String> getMacAddress() async {
    try {
      if (Platform.isAndroid) {
        // On Android, we use Method Channel to get MAC address
        const platform = MethodChannel('com.etustack/device_info');
        final macAddress = await platform.invokeMethod('getMacAddress');
        return macAddress;
      } else if (Platform.isWindows) {
        // On Windows, use ProcessRun to get MAC address
        final result = await Process.run('getmac', ['/fo', 'csv', '/nh']);
        final output = result.stdout.toString();
        final macAddressRegex = RegExp(r'(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}');
        final match = macAddressRegex.firstMatch(output);
        if (match != null) {
          return match.group(0)!.toUpperCase();
        }
        return 'unknown';
      } else if (Platform.isMacOS) {
        // On macOS, use system_profiler
        final result = await Process.run('system_profiler', ['SPNetworkDataType']);
        final output = result.stdout.toString();
        final macAddressRegex = RegExp(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}');
        final match = macAddressRegex.firstMatch(output);
        if (match != null) {
          return match.group(0)!.toUpperCase();
        }
        return 'unknown';
      } else if (Platform.isLinux) {
        // On Linux, use ip addr
        final result = await Process.run('ip', ['addr']);
        final output = result.stdout.toString();
        final macAddressRegex = RegExp(r'(?:[0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}');
        final match = macAddressRegex.firstMatch(output);
        if (match != null) {
          return match.group(0)!.toUpperCase();
        }
        return 'unknown';
      } else {
        // For web or other platforms
        return 'web_platform';
      }
    } catch (e) {
      debugPrint('Error getting MAC address: $e');
      return 'unknown';
    }
  }
  
  /// Generate a license file for a given MAC address (for admin use)
  Future<String> generateLicenseFile(String macAddress) async {
    final licenseKey = _generateLicenseKey(macAddress);
    final licenseData = {
      'mac_address': macAddress,
      'license_key': licenseKey,
      'issue_date': DateTime.now().toIso8601String(),
      'version': '1.0'
    };
    
    final licenseJson = jsonEncode(licenseData);
    final directory = await _getLicenseFileDirectory();
    final licensePath = '${directory.path}/$_licenseFileName';
    final file = File(licensePath);
    await file.writeAsString(licenseJson);
    
    return licensePath;
  }
  
  /// Generate a license key from MAC address (simplified for demo)
  String _generateLicenseKey(String macAddress) {
    // In a real application, you would use a more secure algorithm
    // This is just a simple example
    final bytes = utf8.encode(macAddress + "EtuStack_Secret_Salt");
    final digest = base64Encode(bytes);
    return digest.substring(0, 16);
  }
}
