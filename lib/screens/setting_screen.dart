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
                onTap: () =>
                    BusinessDetailsUi.showBusinessDetailsDialog(context),
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
                title: "Theme Mode",
                subtitle: _getThemeSubtitle(themeProvider.themeMode),
                onTap: () => _showThemeSelectionDialog(context, themeProvider),
                trailing: Icon(
                  Icons.arrow_drop_down_circle_outlined,
                  size: 18.sp,
                  color: colorScheme.primary,
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
        child: Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(15),
          child: ListTile(
            contentPadding: EdgeInsets.symmetric(
              horizontal: 4.w,
              vertical: 0.5.h,
            ),
            leading: CircleAvatar(
              backgroundColor: colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                icon,
                color: isDark ? colorScheme.primary : Colors.indigo,
              ),
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
      ),
    );
  }
  String _getThemeSubtitle(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return "Following phone's system settings";
      case ThemeMode.dark:
        return "Dark mode always active";
      case ThemeMode.light:
        return "Light mode always active";
    }
  }

  void _showThemeSelectionDialog(BuildContext context, ThemeProvider provider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: Theme.of(context).cardColor,
        insetPadding: EdgeInsets.symmetric(horizontal: 6.w),
        titlePadding: EdgeInsets.zero,
        contentPadding: EdgeInsets.only(left: 4.w, right: 4.w, top: 2.h, bottom: 2.5.h),
        clipBehavior: Clip.antiAlias,
        title: Container(
          padding: EdgeInsets.all(5.w),
          decoration: BoxDecoration(
            color: isDark ? colorScheme.surface : Colors.indigo,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            children: [
              const Icon(Icons.palette_outlined, color: Colors.white),
              SizedBox(width: 3.w),
              Text(
                "Choose Theme",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: RadioGroup<ThemeMode>(
          groupValue: provider.themeMode,
          onChanged: (ThemeMode? mode) {
            if (mode != null) provider.setThemeMode(mode);
            Navigator.pop(dialogCtx);
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildThemeOption(
                context,
                title: "Follow System",
                subtitle: "Matches your phone's display options",
                icon: Icons.brightness_auto_rounded,
                value: ThemeMode.system,
                isSelected: provider.themeMode == ThemeMode.system,
                onTap: () {
                  provider.setThemeMode(ThemeMode.system);
                  Navigator.pop(dialogCtx);
                },
              ),
              _buildThemeOption(
                context,
                title: "Light Mode",
                subtitle: "Classic, high-contrast bright visual base",
                icon: Icons.light_mode_rounded,
                value: ThemeMode.light,
                isSelected: provider.themeMode == ThemeMode.light,
                onTap: () {
                  provider.setThemeMode(ThemeMode.light);
                  Navigator.pop(dialogCtx);
                },
              ),
              _buildThemeOption(
                context,
                title: "Dark Mode",
                subtitle: "Reduces screen glare and saves battery life",
                icon: Icons.dark_mode_rounded,
                value: ThemeMode.dark,
                isSelected: provider.themeMode == ThemeMode.dark,
                onTap: () {
                  provider.setThemeMode(ThemeMode.dark);
                  Navigator.pop(dialogCtx);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThemeOption(
      BuildContext context, {
        required String title,
        required String subtitle,
        required IconData icon,
        required ThemeMode value,
        required bool isSelected,
        required VoidCallback onTap,
      }) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: EdgeInsets.symmetric(vertical: 0.6.h),
      decoration: BoxDecoration(
        color: isSelected
            ? colorScheme.primary.withValues(alpha: isDark ? 0.15 : 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected
              ? colorScheme.primary.withValues(alpha: 0.4)
              : Colors.transparent,
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.5.h),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? colorScheme.primary
                      : (isDark ? Colors.white60 : Colors.grey[600]),
                  size: 18.sp,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          fontSize: 16.sp,
                          color: colorScheme.onSurface,
                        ),
                      ),
                      SizedBox(height: 0.3.h),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isDark ? Colors.white54 : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),

                Radio<ThemeMode>(
                  value: value,
                  activeColor: colorScheme.primary,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}