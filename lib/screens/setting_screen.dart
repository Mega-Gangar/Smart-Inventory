import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';
import '../services/update_services.dart';
import 'business_details_ui.dart';
import 'data_backup_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18.sp, color: Colors.white),
        ),
        backgroundColor: Colors.indigo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader("App Management"),

              // Check for Update Tile
              _buildSettingsTile(
                icon: Icons.system_update_rounded,
                title: "Check for Updates",
                subtitle: "Current Version: ${UpdateService.currentVersion}",
                onTap: () => UpdateService.checkForUpdates(context),
                trailing: Icon(Icons.arrow_forward_ios, size: 14.sp, color: Colors.grey),
              ),

              SizedBox(height: 2.h),
              _buildSectionHeader("Business Configuration"),

              _buildSettingsTile(
                icon: Icons.edit_document,
                title: "Edit Billing Format",
                subtitle: "Update shop name, address, and GST",
                onTap: () {
                  BusinessDetailsUi.showBusinessDetailsDialog(context);
                  },
              ),

              _buildSettingsTile(
                icon: Icons.settings_backup_restore,
                title: "Backup & Restore",
                subtitle: "Cloud and Local database management",
                onTap: () {
                  DataBackupUi.showBackupRestoreDialog(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(left: 2.w, bottom: 1.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
        leading: CircleAvatar(
          backgroundColor: Colors.indigo.withValues(alpha: 0.1),
          child: Icon(icon, color: Colors.indigo),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5.sp),
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(fontSize: 14.5.sp, color: Colors.grey[600]),
        ),
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }
}