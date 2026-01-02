import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:signsync/services/face_recognition_service.dart';

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

  @override
  void initState() {
    super.initState();
    // Initialize with current values from orchestrator
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orchestrator = ref.read(mlOrchestratorServiceProvider);
      setState(() {
        _personRecognitionEnabled = orchestrator.enableFace;
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

          // Language Section
          _buildSectionHeader('Language'),
          _buildLanguageSelector(),
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
          title: const Text('Privacy Controls'),
          content: SizedBox(
            width: double.maxFinite,
            child: profiles.isEmpty 
              ? const Text('No enrolled faces')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: profiles.length,
                  itemBuilder: (context, index) {
                    final profile = profiles[index];
                    return ListTile(
                      title: Text(profile.name),
                      subtitle: Text(profile.label),
                      trailing: Switch(
                        value: !profile.isPrivate,
                        onChanged: (value) async {
                          await orchestrator.updateFaceProfile(profile.id, isPrivate: !value);
                          setDialogState(() {});
                        },
                      ),
                    );
                  },
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
