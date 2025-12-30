import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/app_theme.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Settings screen for app configuration.
///
/// This screen provides access to app settings including theme,
/// accessibility options, and preferences.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final isHighContrast = config.highContrastMode;
    final themeMode = config.themeMode;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
        children: [
          // Appearance Section
          _buildSectionHeader('Appearance'),
          _buildThemeSelector(themeMode, (mode) {
            ref.read(appConfigProvider).themeMode = mode;
          }),
          _buildSwitchTile(
            title: 'High Contrast Mode',
            subtitle: 'Increase visibility with high contrast colors',
            value: isHighContrast,
            onChanged: (value) {
              ref.read(appConfigProvider).highContrastMode = value;
            },
            icon: Icons.contrast,
          ),
          _buildSliderTile(
            title: 'Text Size',
            subtitle: 'Adjust text scale: ${(config.textScaleFactor * 100).toStringAsFixed(0)}%',
            value: config.textScaleFactor,
            min: 0.8,
            max: 2.0,
            onChanged: (value) {
              ref.read(appConfigProvider).textScaleFactor = value;
            },
            icon: Icons.text_fields,
          ),
          const Divider(),

          // Accessibility Section
          _buildSectionHeader('Accessibility'),
          _buildSwitchTile(
            title: 'Reduce Motion',
            subtitle: 'Minimize animations and transitions',
            value: config.reduceMotion,
            onChanged: (value) {
              ref.read(appConfigProvider).reduceMotion = value;
            },
            icon: Icons.animation,
          ),
          _buildSwitchTile(
            title: 'Haptic Feedback',
            subtitle: 'Vibrate on actions',
            value: true,
            onChanged: (value) {},
            icon: Icons.vibration,
          ),
          const Divider(),

          // Permissions Section
          _buildSectionHeader('Permissions'),
          _buildPermissionTile(
            title: 'Camera',
            subtitle: 'Required for ASL translation and object detection',
            icon: Icons.camera_alt,
            onTap: () => _showPermissionDetails(context, 'camera'),
          ),
          _buildPermissionTile(
            title: 'Microphone',
            subtitle: 'Required for sound alerts',
            icon: Icons.mic,
            onTap: () => _showPermissionDetails(context, 'microphone'),
          ),
          const Divider(),

          // About Section
          _buildSectionHeader('About'),
          _buildInfoTile(
            title: 'App Version',
            subtitle: '${AppConstants.appVersion} (${AppConstants.appBuildNumber})',
            icon: Icons.info,
          ),
          _buildInfoTile(
            title: 'Flutter Version',
            subtitle: '3.x',
            icon: Icons.code,
          ),
          _buildActionTile(
            title: 'Privacy Policy',
            icon: Icons.privacy_tip,
            onTap: () {},
          ),
          _buildActionTile(
            title: 'Terms of Service',
            icon: Icons.description,
            onTap: () {},
          ),
          _buildActionTile(
            title: 'Reset Settings',
            icon: Icons.restart_alt,
            onTap: () => _showResetDialog(context, ref),
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppConstants.spacingMd,
        AppConstants.spacingSm,
        AppConstants.spacingMd,
        AppConstants.spacingXs,
      ),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 12,
          letterSpacing: 1.2,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildSliderTile({
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle),
          Slider(
            value: value,
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(
    ThemeMode themeMode,
    ValueChanged<ThemeMode> onChanged,
  ) {
    return ListTile(
      leading: const Icon(Icons.palette),
      title: const Text('Theme'),
      subtitle: Row(
        children: [
          _buildThemeOption(ThemeMode.light, 'Light', themeMode),
          const SizedBox(width: AppConstants.spacingSm),
          _buildThemeOption(ThemeMode.system, 'System', themeMode),
          const SizedBox(width: AppConstants.spacingSm),
          _buildThemeOption(ThemeMode.dark, 'Dark', themeMode),
        ],
      ),
    );
  }

  Widget _buildThemeOption(
    ThemeMode mode,
    String label,
    ThemeMode current,
  ) {
    final isSelected = mode == current;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(mode),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.transparent,
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.outlineLight,
            ),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: isSelected ? AppColors.onPrimary : null,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    return ListTile(
      leading: Icon(icon, color: isDestructive ? AppColors.error : null),
      title: Text(
        title,
        style: TextStyle(color: isDestructive ? AppColors.error : null),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  void _showPermissionDetails(BuildContext context, String permission) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$permission Permission'),
        content: Text(
          permission == 'camera'
              ? 'Camera access is required for ASL translation and object detection features. The camera feed is processed locally on your device and is not stored or transmitted.'
              : 'Microphone access is required for sound alert features. Audio is processed locally and only significant sounds will trigger notifications.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (permission == 'camera' || permission == 'microphone')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                // Open app settings
              },
              child: const Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  void _showResetDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Settings'),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              ref.read(appConfigProvider).resetToDefaults();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Settings reset to default')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}
