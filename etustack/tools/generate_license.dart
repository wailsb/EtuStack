import 'dart:io';
import 'dart:convert';

/// Sample script to generate a license file for EtuStack
/// 
/// In a real-world scenario, this would be a separate tool used by you
/// to generate license files for customers after they purchase your software.

void main() async {
  // Get the MAC address from command line or use a default for testing
  print('Enter MAC address (or press Enter for demo):');
  String? macAddress = stdin.readLineSync();
  
  if (macAddress == null || macAddress.isEmpty) {
    macAddress = '00:1A:2B:3C:4D:5E'; // Demo MAC address
    print('Using demo MAC address: $macAddress');
  }
  
  // Generate license data
  final licenseData = {
    'mac_address': macAddress,
    'license_key': generateLicenseKey(macAddress),
    'issue_date': DateTime.now().toIso8601String(),
    'version': '1.0'
  };
  
  // Convert to JSON
  final licenseJson = jsonEncode(licenseData);
  
  // Write to file - in a real app, you would need to put this file
  // in the application documents directory as described in the licensing service
  final outputDir = 'license_output';
  await Directory(outputDir).create(recursive: true);
  final licensePath = '$outputDir/etustack_license.key';
  final file = File(licensePath);
  await file.writeAsString(licenseJson);
  
  print('License file generated at: ${file.absolute.path}');
  print('''
===============================================================
LICENSE FILE INSTRUCTIONS
===============================================================

1. For Android: 
   Copy this file to /data/data/com.yourcompany.etustack/files/

2. For Windows:
   Copy this file to C:\\Users\\<username>\\Documents\\etustack_license.key

3. For macOS:
   Copy this file to ~/Documents/etustack_license.key

4. For Linux:
   Copy this file to ~/Documents/etustack_license.key

The application will read this file on the first run and activate
based on the MAC address of the device.
===============================================================
''');
}

String generateLicenseKey(String macAddress) {
  // In a real application, you would use a more secure algorithm
  // This is just a simple example
  final bytes = utf8.encode(macAddress + "EtuStack_Secret_Salt");
  final digest = base64Encode(bytes);
  return digest.substring(0, 16);
}
