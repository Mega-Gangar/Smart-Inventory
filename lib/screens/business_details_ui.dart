import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../validator.dart';

class BusinessDetailsUi {
  static Future<void> _saveBusinessDetails(
      String name,
      String gstin,
      String upiId,
      String holderName,
      ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', name);
    await prefs.setString('gstin_number', gstin);
    await prefs.setString('upiId', upiId);
    await prefs.setString('upi_holderName', holderName);
  }

  static void showBusinessDetailsDialog(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final prefs = await SharedPreferences.getInstance();

    // Theme references defined once
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    TextEditingController nameController = TextEditingController(
      text: prefs.getString('company_name') ?? "",
    );
    TextEditingController gstinController = TextEditingController(
      text: prefs.getString('gstin_number') ?? "",
    );
    TextEditingController upiIdController = TextEditingController(
      text: prefs.getString('upiId') ?? "",
    );
    TextEditingController upiHolderNameController = TextEditingController(
      text: prefs.getString('upi_holderName') ?? "",
    );

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.business_center, color: isDark ? Colors.white : Colors.indigo),
            const SizedBox(width: 10),
            Text(
              "Billing Profile",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
                color: colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Information provided here will appear on your generated PDF receipts.",
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: isDark ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                SizedBox(height: 2.5.h),
                _buildDialogField(
                  context, // Pass context for theme access
                  controller: nameController,
                  label: "Company Name",
                  hint: "e.g. My Awesome Store",
                  icon: Icons.store_mall_directory_outlined,
                  validate: AppValidators.validateCompanyName,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
                  context,
                  controller: gstinController,
                  label: "GSTIN Number",
                  hint: "e.g. 22AAAAA0000A1Z5",
                  icon: Icons.receipt_long_outlined,
                  validate: AppValidators.validateGSTIN,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
                  context,
                  controller: upiIdController,
                  label: "UPI ID",
                  hint: "e.g. username@bankname",
                  icon: Icons.payments,
                  validate: AppValidators.validateUpiData,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
                  context,
                  controller: upiHolderNameController,
                  hint: '',
                  label: "UPI ID Holder Name",
                  icon: Icons.payments,
                  validate: AppValidators.validateHolderName,
                ),
              ],
            ),
          ),
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "CANCEL",
              style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: colorScheme.primary,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
              elevation: 0,
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _saveBusinessDetails(
                  nameController.text,
                  gstinController.text.toUpperCase(),
                  upiIdController.text,
                  upiHolderNameController.text,
                );
                if (!dialogCtx.mounted) return;
                Navigator.pop(dialogCtx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Billing details updated!"),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text(
              "SAVE DETAILS",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        required String hint,
        required IconData icon,
        String? Function(String?)? validate,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      style: TextStyle(
        fontSize: 15.sp,
        color: colorScheme.onSurface, // Ensures entered text is visible
      ),
      validator: validate,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
        hintText: hint,
        hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.grey[400]),
        prefixIcon: Icon(icon, color: isDark ? Colors.white : Colors.indigo),
        filled: true,
        fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}