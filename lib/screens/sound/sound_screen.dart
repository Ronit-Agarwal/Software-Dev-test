import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/noise_event.dart';
import 'package:signsync/services/audio_service.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/sound/spectrum_visualizer.dart';

/// Sound alerts screen for noise detection.
///
/// This screen handles microphone input, noise detection, and
/// alerting the user for important sounds.
class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key});

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> {
  bool _isListening = false;
  final List<NoiseEvent> _recentEvents = [];
  double _currentLevel = 0;
  List<double> _currentSpectrum = List.filled(20, 0.0);

  @override
  void initState() {
    super.initState();
    LoggerService.info('Sound screen initialized');
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final permissionsService = ref.read(permissionsServiceProvider);
    await permissionsService.requestMicrophonePermission();
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      _stopListening();
    } else {
      await _startListening();
    }
  }

  Future<void> _startListening() async {
    LoggerService.info('Starting sound detection');
    AnalyticsEvent.logSoundAlertsStarted();

    try {
      final permissionsService = ref.read(permissionsServiceProvider);
      if (!await permissionsService.hasMicrophonePermission) {
        await permissionsService.requestMicrophonePermission();
      }

      final audioService = ref.read(audioServiceProvider);
      await audioService.initialize();
      await audioService.startRecording(onNoiseDetected: _onNoiseDetected);

      // Subscribe to audio levels
      audioService.audioLevelStream.listen((level) {
        if (mounted) {
          setState(() => _currentLevel = level);
        }
      });

      // Subscribe to spectrum
      audioService.spectrumStream.listen((spectrum) {
        if (mounted) {
          setState(() => _currentSpectrum = spectrum);
        }
      });

      setState(() => _isListening = true);
      LoggerService.info('Sound detection started');
    } catch (e, stack) {
      LoggerService.error('Failed to start sound detection', error: e, stack: stack);
      _showError('Failed to access microphone: $e');
    }
  }

  void _stopListening() {
    LoggerService.info('Stopping sound detection');
    AnalyticsEvent.logSoundAlertsStopped();

    final audioService = ref.read(audioServiceProvider);
    audioService.stopRecording();

    setState(() => _isListening = false);
  }

  void _onNoiseDetected(NoiseEvent event) {
    setState(() {
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 20) {
        _recentEvents.removeLast();
      }
    });

    // Show notification for significant events
    if (event.shouldAlert) {
      _showAlertNotification(event);
    }

    LoggerService.debug('Noise detected: ${event.type.displayName}');
  }

  void _showAlertNotification(NoiseEvent event) {
    if (!mounted) return;

    final severityColor = event.severity.color;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              event.type.icon,
              color: severityColor,
            ),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    event.type.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Intensity: ${(event.intensity * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        backgroundColor: severityColor.withOpacity(0.9),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.pushNamed(context, '/settings'),
            tooltip: 'Sound Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          // Audio Visualization Area
          Expanded(
            flex: 2,
            _buildAudioVisualization(),
          ),

          // Recent Events List
          Expanded(
            flex: 2,
            _buildEventsList(),
          ),

          // Control Buttons
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildAudioVisualization() {
    final audioService = ref.watch(audioServiceProvider);

    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Frequency Spectrum Visualizer
          SpectrumVisualizer(
            spectrum: _currentSpectrum,
            isListening: _isListening,
          ),
          
          const SizedBox(height: AppConstants.spacingMd),
          
          // Noise Threshold Slider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppConstants.spacingLg),
            child: Row(
              children: [
                const Icon(Icons.volume_down, size: 16),
                Expanded(
                  child: Slider(
                    value: audioService.noiseThreshold,
                    onChanged: (value) => audioService.setNoiseThreshold(value),
                    activeColor: AppColors.primary,
                  ),
                ),
                const Icon(Icons.volume_up, size: 16),
              ],
            ),
          ),
          
          Text(
            'Threshold: ${(audioService.noiseThreshold * 100).toStringAsFixed(0)}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),

          const SizedBox(height: AppConstants.spacingMd),
          
          // Status and Haptic Control
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                _isListening ? 'Listening...' : 'Tap Start',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(width: AppConstants.spacingLg),
              FilterChip(
                label: const Text('Haptic'),
                selected: audioService.hapticEnabled,
                onSelected: (value) => audioService.setHapticEnabled(value),
                avatar: Icon(
                  audioService.hapticEnabled ? Icons.vibration : Icons.phonelink_erase,
                  size: 16,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(AppConstants.radiusXl),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (_recentEvents.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      ref.read(audioServiceProvider).clearEvents();
                      setState(() => _recentEvents.clear());
                    },
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          // Events
          Expanded(
            child: _recentEvents.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.notifications_off,
                          size: AppConstants.iconSizeXl,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: AppConstants.spacingMd),
                        Text(
                          'No sounds detected yet',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: _recentEvents.length,
                    itemBuilder: (context, index) {
                      final event = _recentEvents[index];
                      return _buildEventTile(event);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventTile(NoiseEvent event) {
    final time = event.timestamp.toIso8601String().split('T').last.substring(0, 8);

    return Dismissible(
      key: Key(event.id),
      background: Container(
        color: AppColors.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppConstants.spacingMd),
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      onDismissed: (direction) {
        setState(() => _recentEvents.remove(event));
      },
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(AppConstants.spacingXs),
          decoration: BoxDecoration(
            color: event.severity.color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppConstants.radiusSm),
          ),
          child: Icon(
            event.type.icon,
            color: event.severity.color,
          ),
        ),
        title: Text(event.type.displayName),
        subtitle: Text(
          '${event.intensity.toStringAsFixed(2)} intensity - $time',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              event.severity.displayName,
              style: TextStyle(
                color: event.severity.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilledButton.icon(
            onPressed: _toggleListening,
            icon: Icon(_isListening ? Icons.stop : Icons.mic),
            label: Text(_isListening ? 'Stop' : 'Start'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: _isListening ? AppColors.error : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: _showHistory,
            tooltip: 'History',
            iconSize: AppConstants.iconSizeLg,
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    showModalBottomSheet(
      context: context,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.8,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppConstants.radiusXl),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppConstants.spacingMd),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Text(
                'Detection History',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: AppConstants.spacingMd),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: _recentEvents.length,
                  itemBuilder: (context, index) {
                    final event = _recentEvents[index];
                    return ListTile(
                      leading: Icon(event.type.icon),
                      title: Text(event.type.displayName),
                      subtitle: Text(event.timestamp.relativeTime),
                      trailing: Text(
                        '${(event.intensity * 100).toStringAsFixed(0)}%',
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
