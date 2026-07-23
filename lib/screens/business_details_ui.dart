import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sizer/sizer.dart';
import '../validator.dart';

class BusinessDetailsUi {
  BusinessDetailsUi._(); // Prevent instantiation

  static void showBusinessDetailsDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogCtx) => const _BusinessDetailsDialog(),
    );
  }
}

class _BusinessDetailsDialog extends StatefulWidget {
  const _BusinessDetailsDialog();

  @override
  State<_BusinessDetailsDialog> createState() => _BusinessDetailsDialogState();
}

class _BusinessDetailsDialogState extends State<_BusinessDetailsDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _gstinController;
  late final TextEditingController _upiIdController;
  late final TextEditingController _upiHolderNameController;

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _gstinController = TextEditingController();
    _upiIdController = TextEditingController();
    _upiHolderNameController = TextEditingController();
    _loadBusinessDetails();
  }

  @override
  void dispose() {
    // 1. Properly dispose controllers to prevent memory leaks
    _nameController.dispose();
    _gstinController.dispose();
    _upiIdController.dispose();
    _upiHolderNameController.dispose();
    super.dispose();
  }

  /// Load details in the background while the dialog is already visible
  Future<void> _loadBusinessDetails() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    _nameController.text = prefs.getString('company_name') ?? '';
    _gstinController.text = prefs.getString('gstin_number') ?? '';
    _upiIdController.text = prefs.getString('upiId') ?? '';
    _upiHolderNameController.text = prefs.getString('upi_holderName') ?? '';

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _saveBusinessDetails() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('company_name', _nameController.text.trim());
    await prefs.setString('gstin_number', _gstinController.text.trim().toUpperCase());
    await prefs.setString('upiId', _upiIdController.text.trim());
    await prefs.setString('upi_holderName', _upiHolderNameController.text.trim());

    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Billing details updated!"),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
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
      content: _isLoading
          ? SizedBox(
        height: 20.h,
        child: const Center(child: CircularProgressIndicator()),
      )
          : Form(
        key: _formKey,
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
                context,
                controller: _nameController,
                label: "Company Name",
                hint: "e.g. My Awesome Store",
                icon: Icons.store_mall_directory_outlined,
                validate: AppValidators.validateCompanyName,
                textCapitalization: TextCapitalization.words,
              ),
              SizedBox(height: 2.h),
              _buildDialogField(
                context,
                controller: _gstinController,
                label: "GSTIN Number",
                hint: "e.g. 22AAAAA0000A1Z5",
                icon: Icons.receipt_long_outlined,
                validate: AppValidators.validateGSTIN,
                textCapitalization: TextCapitalization.characters,
              ),
              SizedBox(height: 2.h),
              _buildDialogField(
                context,
                controller: _upiIdController,
                label: "UPI ID",
                hint: "e.g. username@bankname",
                icon: Icons.payments_outlined,
                validate: AppValidators.validateUpiData,
                keyboardType: TextInputType.emailAddress,
              ),
              SizedBox(height: 2.h),
              _buildDialogField(
                context,
                controller: _upiHolderNameController,
                label: "UPI ID Holder Name",
                hint: "e.g. John Doe",
                icon: Icons.person_outline,
                validate: AppValidators.validateHolderName,
                textCapitalization: TextCapitalization.words,
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            "CANCEL",
            style: TextStyle(color: isDark ? Colors.white70 : Colors.grey[700]),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: isDark ?  colorScheme.surfaceBright : Colors.indigo,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 12),
            elevation: 0,
          ),
          onPressed: (_isLoading || _isSaving) ? null : _saveBusinessDetails,
          child: _isSaving
              ? SizedBox(
            width: 16.sp,
            height: 16.sp,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: colorScheme.onPrimary,
            ),
          )
              : const Text(
            "SAVE DETAILS",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildDialogField(
      BuildContext context, {
        required TextEditingController controller,
        required String label,
        required String hint,
        required IconData icon,
        String? Function(String?)? validate,
        TextCapitalization textCapitalization = TextCapitalization.none,
        TextInputType? keyboardType,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return TextFormField(
      controller: controller,
      textCapitalization: textCapitalization,
      keyboardType: keyboardType,
      style: TextStyle(
        fontSize: 15.sp,
        color: colorScheme.onSurface,
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