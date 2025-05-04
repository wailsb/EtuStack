import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/material.dart';

class BarcodeScannerUtils {
  static MobileScannerController createDefaultController() {
    return MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
    );
  }

  static Widget buildOverlay() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: Colors.green,
          width: 2,
        ),
      ),
    );
  }
  
  // Simple function to format the barcode value
  static String formatBarcodeValue(String value) {
    if (value.length > 30) {
      return '${value.substring(0, 27)}...';
    }
    return value;
  }
}
