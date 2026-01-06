import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:signsync/config/app_config.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/services/face_recognition_service.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/utils/constants.dart';

/// Settings screen for app configuration.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  // Detection thresholds (will sync with orchestrator)
  double _aslConfidenceThreshold = 0.85;
  double _objectConfidenceThreshold = 0.60;
  
  // Face Recognition state
  bool _personRecognitionEnabled = true;

  // Voice settings
  double _ttsVolume = 0.8;
  double _ttsSpeechRate = 0.9;

  @override
  void initState() {
    super.initState();
    // Initialize with current values from orchestrator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orchestrator = ref.read(mlOrchestratorServiceProvider);
      final ttsService = ref.read(ttsServiceProvider);

      setState(() {
        _personRecognitionEnabled = orchestrator.enableFace;
        _ttsVolume = ttsService.volume;
        _ttsSpeechRate = ttsService.speechRate;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final config = ref.watch(appConfigProvider);
    final isHighContrast = config.highContrastMode;
    final themeMode = config.themeMode;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingMd),
        children: [
          // Appearance Section
          _buildSectionHeader(l10n.appearance),
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

          // Language Section
          _buildSectionHeader(l10n.language),
          _buildLanguageSelector(config, l10n),
          const Divider(),

          // Face Recognition Section
          _buildSectionHeader(l10n.personRecognition),
          _buildSwitchTile(
            title: l10n.personRecognition,
            subtitle: 'Identify enrolled people',
            value: _personRecognitionEnabled,
            onChanged: (value) {
              setState(() => _personRecognitionEnabled = value);
              ref.read(mlOrchestratorServiceProvider).setFaceRecognitionEnabled(value);
            },
            icon: Icons.face,
          ),
          _buildActionTile(
            title: l10n.faceEnrollment,
            icon: Icons.person_add,
            onTap: () => _showEnrollmentDialog(context),
          ),
          _buildActionTile(
            title: l10n.privacyControls,
            icon: Icons.privacy_tip,
            onTap: () => _showPrivacyControls(context),
          ),
          const Divider(),

          // Performance Section
          _buildSectionHeader('Performance'),
          _buildSwitchTile(
            title: 'Adaptive Inference',
            subtitle: 'Adjust processing based on battery & heat',
            value: ref.watch(mlOrchestratorServiceProvider).adaptiveInferenceEnabled,
            onChanged: (value) {
              ref.read(mlOrchestratorServiceProvider).setAdaptiveInferenceEnabled(value);
            },
            icon: Icons.speed,
          ),
          _buildActionTile(
            title: 'Check for Model Updates',
            icon: Icons.system_update,
            onTap: () => _checkForModelUpdates(context, ref),
          ),
          const Divider(),

          // Detection Section
          _buildSectionHeader(l10n.objectDetection),
          _buildSliderTile(
            title: l10n.confidenceThreshold,
            subtitle: 'ASL: ${(_aslConfidenceThreshold * 100).toStringAsFixed(0)}%',
            value: _aslConfidenceThreshold,
            min: 0.5,
            max: 0.95,
            onChanged: (value) {
              setState(() => _aslConfidenceThreshold = value);
              ref.read(mlOrchestratorServiceProvider).setConfidenceThresholds(aslThreshold: value);
            },
            icon: Icons.tune,
          ),
          _buildSliderTile(
            title: 'Object Detection Threshold',
            subtitle: 'Objects: ${(_objectConfidenceThreshold * 100).toStringAsFixed(0)}%',
            value: _objectConfidenceThreshold,
            min: 0.3,
            max: 0.9,
            onChanged: (value) {
              setState(() => _objectConfidenceThreshold = value);
              ref.read(mlOrchestratorServiceProvider).setConfidenceThresholds(objectThreshold: value);
            },
            icon: Icons.sensors,
          ),
          const Divider(),

          // Alerts Section
          _buildSectionHeader('Alerts'),
          _buildSwitchTile(
            title: l10n.audioAlerts,
            subtitle: 'Play sounds for detected objects',
            value: ref.watch(mlOrchestratorServiceProvider).audioAlertsEnabled,
            onChanged: (value) {
              ref.read(mlOrchestratorServiceProvider).setAudioAlertsEnabled(value);
            },
            icon: Icons.volume_up,
          ),
          _buildSwitchTile(
            title: l10n.spatialAudio,
            subtitle: 'Indicate object direction',
            value: ref.watch(mlOrchestratorServiceProvider).spatialAudioEnabled,
            onChanged: (value) {
              ref.read(mlOrchestratorServiceProvider).setSpatialAudioEnabled(value);
            },
            icon: Icons.surround_sound,
          ),
          const Divider(),

          // Text-to-Speech Section
          _buildSectionHeader('Voice Settings'),
          _buildSliderTile(
            title: 'Voice Volume',
            subtitle: '${(_ttsVolume * 100).toStringAsFixed(0)}%',
            value: _ttsVolume,
            min: 0.0,
            max: 1.0,
            divisions: 10,
            onChanged: (value) {
              setState(() => _ttsVolume = value);
              final ttsService = ref.read(ttsServiceProvider);
              ttsService.setVolume(value);
            },
            icon: Icons.volume_up,
          ),
          _buildSliderTile(
            title: 'Speech Rate',
            subtitle: '${_ttsSpeechRate.toStringAsFixed(1)}x',
            value: _ttsSpeechRate,
            min: 0.5,
            max: 1.5,
            divisions: 10,
            onChanged: (value) {
              setState(() => _ttsSpeechRate = value);
              final ttsService = ref.read(ttsServiceProvider);
              ttsService.setSpeechRate(value);
            },
            icon: Icons.speed,
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
            subtitle: 'Required for sound alerts and voice input',
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
            onTap: () => _openExternalUrl(
              context,
              Uri.parse(AppConstants.privacyPolicyUrl),
            ),
          ),
          _buildActionTile(
            title: 'Terms of Service',
            icon: Icons.description,
            onTap: () => _openExternalUrl(
              context,
              Uri.parse(AppConstants.termsOfServiceUrl),
            ),
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
    int? divisions,
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
            divisions: divisions,
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

  Widget _buildLanguageSelector(AppConfig config, AppLocalizations l10n) {
    final languages = [
      {'code': 'en', 'name': 'English', 'locale': const Locale('en', 'US')},
      {'code': 'es', 'name': 'Español', 'locale': const Locale('es', 'ES')},
      {'code': 'fr', 'name': 'Français', 'locale': const Locale('fr', 'FR')},
    ];

    final currentLanguage = languages.firstWhere(
      (l) => (l['locale'] as Locale).languageCode == config.locale.languageCode,
      orElse: () => languages[0],
    );

    return ListTile(
      leading: const Icon(Icons.language),
      title: Text(l10n.language),
      subtitle: Text(currentLanguage['name'] as String),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showLanguageDialog(config, languages),
    );
  }

  Future<void> _showLanguageDialog(AppConfig config, List<Map<String, Object>> languages) async {
    final selected = await showDialog<Locale>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Language'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: languages.length,
            itemBuilder: (context, index) {
              final language = languages[index];
              final locale = language['locale'] as Locale;
              final isSelected = locale.languageCode == config.locale.languageCode;
              
              return ListTile(
                title: Text(language['name'] as String),
                trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, locale),
              );
            },
          ),
        ),
      ),
    );

    if (selected != null) {
      config.locale = selected;
      // Update TTS language
      ref.read(ttsServiceProvider).setLocale(selected);
    }
  }

  void _showEnrollmentDialog(BuildContext context) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Face Enrollment'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(mlOrchestratorServiceProvider).startFaceEnrollment(nameController.text);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Starting enrollment for ${nameController.text}')),
                );
              }
            },
            child: const Text('Start'),
          ),
        ],
      ),
    );
  }

  void _showPrivacyControls(BuildContext context) {
    final orchestrator = ref.read(mlOrchestratorServiceProvider);
    final profiles = orchestrator.getFaceProfiles();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Privacy & Data'),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('ENROLLED FACES', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  if (profiles.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No enrolled faces'),
                    )
                  else
                    ...profiles.map((profile) => ListTile(
                      title: Text(profile.name),
                      subtitle: Text(profile.label),
                      trailing: Switch(
                        value: !profile.isPrivate,
                        onChanged: (value) async {
                          await orchestrator.updateFaceProfile(profile.id, isPrivate: !value);
                          setDialogState(() {});
                        },
                      ),
                    )),
                  const Divider(),
                  const Text('DATA MANAGEMENT', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ListTile(
                    leading: const Icon(Icons.download),
                    title: const Text('Export My Data'),
                    onTap: () async {
                      final data = await orchestrator.exportUserData();
                      // In a real app, share the file
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Data exported successfully')),
                      );
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('Wipe All Local Data', style: TextStyle(color: Colors.red)),
                    onTap: () => _showWipeDataDialog(context, orchestrator),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  void _showWipeDataDialog(BuildContext context, MlOrchestratorService orchestrator) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe All Data?'),
        content: const Text('This will permanently delete all your enrolled faces, chat history, and cached detections. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await orchestrator.wipeAllLocalData();
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close privacy controls
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('All data wiped successfully')),
              );
            },
            child: const Text('Wipe Everything', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _checkForModelUpdates(BuildContext context, WidgetRef ref) async {
    final updateService = ref.read(modelUpdateServiceProvider);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Checking for updates...'),
          ],
        ),
      ),
    );

    try {
      await updateService.checkForUpdates();
      Navigator.pop(context); // Close checking dialog
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All models are up to date')),
      );
    } catch (e) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to check for updates: $e')),
      );
    }
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

  Future<void> _openExternalUrl(BuildContext context, Uri url) async {
    try {
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    } catch (e, stack) {
      LoggerService.warn('Failed to open external URL', error: e, stackTrace: stack, extra: {
        'url': url.toString(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open link: $url')),
        );
      }
    }
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
              onPressed: () async {
                Navigator.pop(context);
                final opened = await openAppSettings();
                if (!opened && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not open system settings')),
                  );
                }
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
