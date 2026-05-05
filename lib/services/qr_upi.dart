import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import 'package:smart_inventory/main.dart';
import 'package:smart_inventory/screens/setting_screen.dart';
// Ensure 'formatter' and 'SettingsPage' are accessible

class QrUpi {
  static Future<bool?> showUPIDialog(
    BuildContext context,
    double amount,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String upiId = prefs.getString('upiId') ?? "";
    final String upiHolderName = prefs.getString('upi_holderName') ?? "Not Set";

    // Check if UPI ID is configured
    bool isConfigured = upiId.isNotEmpty;

    // Generate UPI URL for QR Code
    final String upiUrl = isConfigured
        ? "upi://pay?pa=$upiId&pn=$upiHolderName&am=${amount.toStringAsFixed(2)}&cu=INR"
        : "";

    return showDialog<bool>(
      context: context,
      builder: (context) {
        // Access current theme colors
        final colorScheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            Navigator.pop(context, false);
          },
          child: AlertDialog(
            backgroundColor: colorScheme.surface,
            surfaceTintColor: Colors.transparent, // Prevents Material 3 tinting
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            titlePadding: EdgeInsets.zero,
            title: Stack(
              children: [
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: isDark ? colorScheme.surfaceBright : Colors.indigo,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        isConfigured ? "Scan to Pay" : "Configuration Required",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 10,
                  top: 13,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.close, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 80.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 10),
                  if (!isConfigured) ...[
                    // Configuration Warning UI
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange,
                      size: 50.sp,
                    ),
                    const SizedBox(height: 15),
                    Text(
                      "Update UPI ID",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: Colors.red, // Adaptive error color
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      "Please set your Merchant UPI ID in settings to accept payments.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: colorScheme.onSurface),
                    ),
                  ] else ...[
                    // Standard Payment UI
                    Text(
                      "Total Payable",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      formatter.format(amount),
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.indigoAccent[100]
                            : Colors.indigo,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // LOCKED LIGHT MODE CONTAINER FOR QR CODE
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white, // Hardcoded white for scanners
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: Colors.indigo.withValues(alpha: 0.3),
                          width: 2,
                        ),
                      ),
                      child: QrImageView(
                        data: upiUrl,
                        version: QrVersions.auto,
                        size: 180.0,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black, // Dark eyes for contrast
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black, // Black dots for 100% scan rate
                        ),
                      ),
                    ),

                    const SizedBox(height: 15),
                    Text(
                      "Merchant: $upiHolderName",
                      style: TextStyle(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    Text(
                      upiId,
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(15, 0, 15, 15),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? colorScheme.surfaceBright : Colors.indigo,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    if (isConfigured) {
                      Navigator.pop(context, true); // Sale Successful
                    } else {
                      Navigator.pop(context, false);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsPage(),
                        ),
                      );
                    }
                  },
                  child: Text(
                    isConfigured ? "PAID SUCCESSFULLY" : "GO TO SETTINGS",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
