import 'dart:io';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'database_helper.dart';

class DatabaseBackupHelper {
  static void _showSnackBar(BuildContext context, String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static Future<bool> importDatabase(BuildContext context) async {
    try {
      // 1. Open the file picker for the user to select the backup file
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Select Database Backup',
        type: FileType.any, // Android/iOS can be strict about .db extensions, so 'any' is safest
      );

      if (result != null && result.files.single.path != null) {
        File backupFile = File(result.files.single.path!);

        // Optional: Basic validation to ensure they picked a .db file
        if (!backupFile.path.endsWith('.db')) {
          return false;
        }

        // 2. Get the path where the app expects the active database to be
        String databasesPath = await getDatabasesPath();
        String targetPath = join(databasesPath, "business.db");

        // 3. CRITICAL: Close the active database connection
        await DBProvider.closeDatabase();

        // 4. Overwrite the existing database with the backup file
        await backupFile.copy(targetPath);

        return true;
      }
      return false; // User canceled the picker
    } catch (e) {
      return false;
    }
  }

  static Future<void> exportDatabase(BuildContext context) async {
    try {
      // 1. Get the path to the internal database
      String databasesPath = await getDatabasesPath();
      String dbPath = join(databasesPath, "business.db");
      File dbFile = File(dbPath);

      // 2. Check if the file actually exists before trying to share it
      if (await dbFile.exists()) {
        final params=ShareParams(
          files:[XFile(dbPath)],
          text: 'Smart Inventory Database Backup',
          subject: 'Database Backup');
        // 3. Share the file. This creates a secure copy for the user to export.
        await SharePlus.instance.share(
          params,
        );
      } else {
        _showSnackBar(context, "Database file not found!", isError: true);
      }
    } catch (e) {
      _showSnackBar(context, "Failed to export: $e", isError: true);
    }
  }
}
