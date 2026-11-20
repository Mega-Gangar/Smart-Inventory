import 'dart:io';
import 'package:path/path.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart' as sqflite;

class DatabaseSyncService {
  // Python backend URL
  static const String backendUrl = String.fromEnvironment('BACKEND_URL');

  /// Retrieves the absolute file path of SQLite database
  static Future<String> getDatabasePath() async {
    String databasesPath = await sqflite.getDatabasesPath();
    String path = join(databasesPath, 'business.db');
    return path;
  }

  /// Uploads the local SQLite database file to Python backend for stock predictions
  static Future<String?> uploadDatabaseToPython() async {
    try {
      // 1. Get the dynamic path on the device
      String dbPath = await getDatabasePath();

      // 2. Verify the file actually exists before uploading
      File dbFile = File(dbPath);
      if (!await dbFile.exists()) {
        return null;
      }

      var request = http.MultipartRequest(
        'POST',
        Uri.parse(backendUrl),
      );

      // 3. Attach the local SQLite file using the verified path
      request.files.add(await http.MultipartFile.fromPath('file', dbPath));

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return response.body; // Returns the JSON prediction response body
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }
}