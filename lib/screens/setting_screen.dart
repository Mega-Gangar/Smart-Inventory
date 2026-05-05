import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sizer/sizer.dart';
import '../services/theme_provider.dart';
import '../services/update_services.dart';
import 'business_details_ui.dart';
import 'data_backup_ui.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final appBarTheme = Theme.of(context).appBarTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Settings",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18.sp,
            color: Colors.white,
          ),
        ),
        backgroundColor: appBarTheme.backgroundColor,
        iconTheme: appBarTheme.iconTheme,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, "App Management"),
              _buildSettingsTile(
                context,
                icon: Icons.system_update_rounded,
                title: "Check for Updates",
                subtitle: "Current Version: ${UpdateService.currentVersion}",
                onTap: () => UpdateService.checkForUpdates(context),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 2.h),
              _buildSectionHeader(context, "Business Configuration"),
              _buildSettingsTile(
                context,
                icon: Icons.edit_document,
                title: "Edit Billing Format",
                subtitle: "Update shop name, address, and GST",
                onTap: () => BusinessDetailsUi.showBusinessDetailsDialog(context),
              ),
              _buildSettingsTile(
                context,
                icon: Icons.settings_backup_restore,
                title: "Backup & Restore",
                subtitle: "Cloud and Local database management",
                onTap: () => DataBackupUi.showBackupRestoreDialog(context),
              ),
              SizedBox(height: 2.h),
              _buildSectionHeader(context, "Interface"),
              _buildSettingsTile(
                context,
                icon: themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode,
                title: "Dark Mode",
                subtitle: "Reduce glare and save battery",
                onTap: () {},
                trailing: Switch(
                  value: themeProvider.isDarkMode,
                  activeThumbColor: colorScheme.primary,
                  onChanged: (value) {
                    themeProvider.toggleTheme(value);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(left: 2.w, bottom: 1.h),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.sp,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required VoidCallback onTap,
        Widget? trailing,
      }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      margin: EdgeInsets.only(bottom: 1.5.h),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      // Theme wrapper to remove Splash and Ripple effects
      child: Theme(
        data: Theme.of(context).copyWith(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
        ),
        child: ListTile(
          contentPadding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 0.5.h),
          leading: CircleAvatar(
            backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
            child: Icon(icon, color: isDark ? colorScheme.primary : Colors.indigo),
          ),
          title: Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15.5.sp,
              color: colorScheme.onSurface,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              fontSize: 14.5.sp,
              color: isDark ? Colors.white70 : Colors.grey[600],
            ),
          ),
          trailing: trailing,
          onTap: onTap,
        ),
      ),
    );
  }
}