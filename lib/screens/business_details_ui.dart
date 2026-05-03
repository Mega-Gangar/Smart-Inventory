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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.business_center, color: Colors.indigo),
            SizedBox(width: 10),
            Text(
              "Billing Profile",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp),
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
                  style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
                ),
                SizedBox(height: 2.5.h),
                _buildDialogField(
                  controller: nameController,
                  label: "Company Name",
                  hint: "e.g. My Awesome Store",
                  icon: Icons.store_mall_directory_outlined,
                  validate: AppValidators.validateCompanyName,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
                  controller: gstinController,
                  label: "GSTIN Number",
                  hint: "e.g. 22AAAAA0000A1Z5",
                  icon: Icons.receipt_long_outlined,
                  validate: AppValidators.validateGSTIN,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
                  controller: upiIdController,
                  label: "UPI ID",
                  hint: "e.g. username@bankname",
                  icon: Icons.payments,
                  validate: AppValidators.validateUpiData,
                ),
                SizedBox(height: 2.h),
                _buildDialogField(
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
        actionsPadding: EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("CANCEL", style: TextStyle(color: Colors.grey[700])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            ),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                await _saveBusinessDetails(
                  nameController.text,
                  gstinController.text.toUpperCase(),
                  upiIdController.text,
                  upiHolderNameController.text,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Billing details updated!"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            child: const Text(
              "SAVE DETAILS",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildDialogField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    String? Function(String?)? validate,
  }) {
    return TextFormField(
      controller: controller,
      style: TextStyle(fontSize: 15.sp),
      validator: validate,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      // Shows error while typing
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: Colors.indigo),
        filled: true,
        fillColor: Colors.grey[50],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.indigo, width: 2),
        ),
      ),
    );
  }
}
