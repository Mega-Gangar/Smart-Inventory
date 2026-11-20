import 'dart:convert';
import 'package:material_ui/material_ui.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateService {
  static const String currentVersion = "1.1.7";
  static const String githubUser = "Mega-Gangar";
  static const String repoName = "Smart-Inventory";

  static Future<void> checkForUpdates(BuildContext context) async {
    final colorScheme = Theme.of(context).colorScheme;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Checking for updates..."),
        duration: Duration(seconds: 1),
      ),
    );

    final url = Uri.parse(
      const String.fromEnvironment('UPDATE_URL'),
    );

    try {
      final response = await http.get(url);
      if (!context.mounted) return;
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        String latestVersion = data['tag_name'].toString().replaceAll('v', '');
        String downloadUrl = data['html_url'];

        if (latestVersion != currentVersion) {
          if (!context.mounted) return;
          _showUpdateDialog(context, latestVersion, downloadUrl);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("You are on the latest Update!"),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[600], // Success semantic
            ),
          );
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("Error while checking for update..."),
          duration: const Duration(seconds: 2),
          backgroundColor: colorScheme.error, // Error semantic
        ),
      );
    }
  }

  static void _showUpdateDialog(
      BuildContext context,
      String version,
      String url,
      ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).dialogTheme.backgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        title: Container(
          padding: EdgeInsets.all(4.w),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.indigo, // Brand Primary
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.system_update_rounded, color: Colors.white),
              SizedBox(width: 3.w),
              Text(
                "New Update",
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
            SizedBox(height: 2.h),
            Icon(
              Icons.rocket_launch_rounded,
              color: isDark ? Colors.white : Colors.indigo,
              size: 40.sp,
            ),
            SizedBox(height: 2.h),
            Text(
              "Version $version is here!",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 17.sp,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 1.h),
            Text(
              "We've added new features and fixed bugs to improve your experience.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.grey[600],
                fontSize: 15.sp,
              ),
            ),
          ],
        ),
        actionsPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
        actions: [
          Row(
            children: [
              Expanded(
                child: TextButton( // Switched to TextButton for secondary action
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 1.3.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () => Navigator.pop(dialogCtx),
                  child: Text(
                    "LATER",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white60 : Colors.grey[700],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 4.w),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? colorScheme.surface : Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 1.5.h),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () async {
                    final uri = Uri.parse(url);
                    try {
                      await launchUrl(
                        uri,
                        mode: LaunchMode.externalApplication,
                      );
                    } catch (e) {
                      debugPrint("Could not launch updater link: $e");
                    }
                  },
                  child: Text(
                    "UPDATE NOW",
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}