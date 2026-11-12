import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../database/database_backup.dart';

class DataBackupUi {
  static void showBackupRestoreDialog(BuildContext context) {
    // Theme references
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.indigo, // Adapts to your brand Indigo
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_sync, color: Colors.white),
              SizedBox(width: 3.w),
              Text(
                "Data Management",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 1.5.h),
              child: Text(
                "Protect your business data by creating a backup or restore from a previous file.",
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontSize: 15.sp,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 1.h),
            _buildActionTile(
              context,
              title: "Export Backup",
              subtitle: "Create a copy of your current database",
              icon: Icons.drive_folder_upload_rounded,
              color: Colors.indigo,
              onTap: () async {
                Navigator.pop(dialogCtx);
                await DatabaseBackupHelper.exportDatabase(context);
              },
            ),
            SizedBox(height: 1.5.h),
            _buildActionTile(
              context,
              title: "Import Backup",
              subtitle: "Restore data from a .db file",
              icon: Icons.settings_backup_restore_rounded,
              color: Colors.orange[800]!,
              onTap: () {
                Navigator.pop(dialogCtx);
                _confirmImport(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(
              "CLOSE",
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _confirmImport(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        title: Container(
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: Colors.red, // Semantic error color for warnings
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.white, size: 24.sp),
              SizedBox(width: 3.w),
              Text(
                "Critical Warning",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: 1.h),
            Text(
              "Are you sure you want to proceed?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.5.h),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.grey[700],
                  fontSize: 14.5.sp,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: "This action will "),
                  TextSpan(
                    text: "permanently delete ",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(text: "all sales, products, and inventory data."),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.fromLTRB(4.w, 0, 4.w, 2.h),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: colorScheme.primary),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "CANCEL",
                    style: TextStyle(color: colorScheme.primary),
                  ),
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: colorScheme.onError,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    Navigator.pop(dialogCtx);
                    bool success = await DatabaseBackupHelper.importDatabase(context);
                    if (success) {
                      _showRestartDialog(context);
                    } else {
                      messenger.showSnackBar(
                        SnackBar(
                          content: const Text("Import failed. Use .db file"),
                          backgroundColor: colorScheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: const Text(
                    "RESTORE",
                    style: TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static void _showRestartDialog(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(20, 30, 20, 20),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: Colors.green[700], size: 50.sp),
            SizedBox(height: 2.h),
            Text(
              "Restore Successful",
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              "The app must restart to load records.",
              textAlign: TextAlign.center,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 3.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                ),
                onPressed: () => exit(0),
                child: const Text("RESTART NOW"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildActionTile(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required Color color,
        required VoidCallback onTap,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: EdgeInsets.all(3.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(2.w),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 22.sp),
            ),
            SizedBox(width: 4.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 14.sp, color: color),
          ],
        ),
      ),
    );
  }
}