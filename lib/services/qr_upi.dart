import '../main.dart';
import 'package:sizer/sizer.dart';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class QrUpi {
  static Future<bool?> showUPIDialog(BuildContext context, double amount) async {
    final prefs = await SharedPreferences.getInstance();
    final String upiId = prefs.getString('upiId') ?? "";
    final String upiHolderName = prefs.getString('upi_holderName') ?? "Not Set";
    final String upiUrl =
        "upi://pay?pa=$upiId&pn=$upiHolderName&am=${amount.toStringAsFixed(2)}&cu=INR";

    return showDialog<bool>(
      context: context,
        builder: (context) => PopScope(
          // This handles the Android/System back gesture
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            // When back is pressed, return with 'false'
            Navigator.pop(context, false);
          },
          child:AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(15),
              decoration: const BoxDecoration(
                color: Colors.indigo,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    "Scan to Pay",
                    style: TextStyle(color: Colors.white, fontSize: 16.sp),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 10,
              top: 13,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
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
              Text(
                "Total Payable",
                style: TextStyle(fontSize: 13.sp, color: Colors.grey[600]),
              ),
              Text(
                formatter.format(amount),
                style: TextStyle(
                  fontSize: 22.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.indigo.withValues(alpha: 0.2),
                  ),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: QrImageView(
                  data: upiUrl,
                  version: QrVersions.auto,
                  size: 180.0,
                  eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: Colors.indigo,
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Merchant: $upiHolderName",
                style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.w500),
              ),
              Text(
                upiId,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 15,
          vertical: 10,
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text(
                "PAID SUCCESSFULLY",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    ));
  }
}
