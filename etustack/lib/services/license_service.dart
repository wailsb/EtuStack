import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class LicenseService {
  // Change this secret salt value to something unique for your app
  static const String _secretSalt = 'EtuStock_Secret_Key_19283746';
  static const String _storedLicenseKey = 'license_key';

  // List of valid license keys - hardcoded for simplicity
  static final List<String> _validKeys = [
    // Add your pre-generated keys here
    'ES01-4a9ef3b2',
    'ES02-8b7e6c5d',
    'ES03-1f2e3d4c',
  ];

  // Verify a license key
  static bool verifyLicense(String licenseKey) {
    try {
      // Simple approach: check if the key is in the list of valid keys
      final isValidFormat = RegExp(
        r'^[A-Z0-9]+-[a-f0-9]{8}$',
      ).hasMatch(licenseKey);
      if (!isValidFormat) return false;

      // For demonstration, we'll also accept dynamically generated keys
      // In production, you'd likely only use the _validKeys list
      if (_isValidGeneratedKey(licenseKey) || _validKeys.contains(licenseKey)) {
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('License verification error: $e');
      return false;
    }
  }

  // Check if the key was dynamically generated with our algorithm
  static bool _isValidGeneratedKey(String key) {
    // Split the key to get the prefix and hash
    final parts = key.split('-');
    if (parts.length != 2) return false;

    final prefix = parts[0];
    final providedHash = parts[1];

    // Calculate the expected hash based on the prefix
    final expectedHash = _generateHash(prefix);

    // Compare the hashes
    return expectedHash == providedHash;
  }

  // Activate a license
  static Future<bool> activateLicense(String licenseKey) async {
    // First verify that the license is valid
    if (!verifyLicense(licenseKey)) {
      return false;
    }

    // Store the license key in local storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storedLicenseKey, licenseKey);
    return true;
  }

  // Check if a license is active
  static Future<bool> isLicenseActive() async {
    final prefs = await SharedPreferences.getInstance();
    final storedKey = prefs.getString(_storedLicenseKey);

    if (storedKey == null) return false;
    return verifyLicense(storedKey);
  }

  // Get license details
  static Future<Map<String, dynamic>> getLicenseDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final licenseKey = prefs.getString(_storedLicenseKey);

    if (licenseKey == null) {
      return {'isActive': false};
    }

    final isValid = verifyLicense(licenseKey);

    if (!isValid) {
      return {'isActive': false};
    }

    return {'isActive': true, 'licenseKey': licenseKey};
  }

  // Generate a hash for a prefix
  static String _generateHash(String prefix) {
    // Combine the prefix with the secret salt
    final data = '$prefix$_secretSalt';
    // Create a SHA-256 hash
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    // Return first 8 characters of the hash
    return digest.toString().substring(0, 8);
  }
}
