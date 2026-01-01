import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/noise_event.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Sound alerts screen for noise detection.
///
/// This screen handles microphone input, real-time visualization, and
/// alerting the user for important sounds.
class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key});

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> {
  StreamSubscription<double>? _levelSub;
  StreamSubscription<List<double>>? _waveformSub;
  StreamSubscription<List<double>>? _spectrumSub;

  double _currentLevel = 0;
  List<double> _waveform = const <double>[];
  List<double> _spectrum = const <double>[];

  @override
  void initState() {
    super.initState();
    LoggerService.info('Sound screen initialized');
  }

  @override
  void dispose() {
    final levelSub = _levelSub;
    final waveformSub = _waveformSub;
    final spectrumSub = _spectrumSub;

    if (levelSub != null) {
      unawaited(levelSub.cancel());
    }
    if (waveformSub != null) {
      unawaited(waveformSub.cancel());
    }
    if (spectrumSub != null) {
      unawaited(spectrumSub.cancel());
    }

    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final permissionsService = ref.read(permissionsServiceProvider);
    await permissionsService.requestMicrophonePermission();
  }

  Future<void> _toggleListening() async {
    final monitor = ref.read(soundMonitorProvider);

    if (monitor.isMonitoring) {
      await _stopListening();
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

      final monitor = ref.read(soundMonitorProvider);
      await monitor.start();

      final levelSub = _levelSub;
      final waveformSub = _waveformSub;
      final spectrumSub = _spectrumSub;

      if (levelSub != null) {
        await levelSub.cancel();
      }
      if (waveformSub != null) {
        await waveformSub.cancel();
      }
      if (spectrumSub != null) {
        await spectrumSub.cancel();
      }

      _levelSub = monitor.audioLevelStream.listen((level) {
        if (!mounted) return;
        setState(() => _currentLevel = level);
      });

      _waveformSub = monitor.waveformStream.listen((waveform) {
        if (!mounted) return;
        setState(() => _waveform = waveform);
      });

      _spectrumSub = monitor.spectrumStream.listen((spectrum) {
        if (!mounted) return;
        setState(() => _spectrum = spectrum);
      });

      LoggerService.info('Sound detection started');
    } catch (e, stack) {
      LoggerService.error('Failed to start sound detection', error: e, stack: stack);
      _showError('Failed to access microphone: $e');
    }
  }

  Future<void> _stopListening() async {
    LoggerService.info('Stopping sound detection');

    final monitor = ref.read(soundMonitorProvider);
    await monitor.stop();

    final levelSub = _levelSub;
    final waveformSub = _waveformSub;
    final spectrumSub = _spectrumSub;

    if (levelSub != null) {
      await levelSub.cancel();
    }
    if (waveformSub != null) {
      await waveformSub.cancel();
    }
    if (spectrumSub != null) {
      await spectrumSub.cancel();
    }

    _levelSub = null;
    _waveformSub = null;
    _spectrumSub = null;

    setState(() {
      _currentLevel = 0;
    });
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
    final monitor = ref.watch(soundMonitorProvider);
    final config = ref.watch(appConfigProvider);
    final events = monitor.events.reversed.toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sound Alerts'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Sound Settings',
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 2,
            child: _buildAudioVisualization(
              isListening: monitor.isMonitoring,
              alertThreshold: config.soundAlertThreshold,
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildEventsList(events),
          ),
          _buildControlBar(isListening: monitor.isMonitoring),
        ],
      ),
    );
  }

  Widget _buildAudioVisualization({
    required bool isListening,
    required double alertThreshold,
  }) {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingMd),
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isListening ? 'Listening…' : 'Tap Start to monitor sounds',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              Text(
                '${(_currentLevel * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: _currentLevel >= alertThreshold ? AppColors.warning : null,
                    ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingSm),
          LinearProgressIndicator(
            value: _currentLevel.clamp(0.0, 1.0),
            minHeight: 6,
            backgroundColor: Colors.black12,
            valueColor: AlwaysStoppedAnimation<Color>(
              _currentLevel >= alertThreshold ? AppColors.warning : Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppConstants.spacingMd),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: _SignalCard(
                    title: 'Waveform',
                    child: CustomPaint(
                      painter: WaveformPainter(
                        waveform: _waveform,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingMd),
                Expanded(
                  child: _SignalCard(
                    title: 'Spectrum',
                    child: CustomPaint(
                      painter: SpectrumPainter(
                        spectrum: _spectrum,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList(List<NoiseEvent> events) {
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
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Events',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                if (events.isNotEmpty)
                  TextButton(
                    onPressed: () => ref.read(soundMonitorProvider).clearHistory(),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          Expanded(
            child: events.isEmpty
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
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
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

    return ListTile(
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
        '${(event.intensity * 100).toStringAsFixed(0)}% • $time',
      ),
      trailing: Text(
        event.severity.displayName,
        style: TextStyle(
          color: event.severity.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildControlBar({required bool isListening}) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingMd),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          FilledButton.icon(
            onPressed: _toggleListening,
            icon: Icon(isListening ? Icons.stop : Icons.mic),
            label: Text(isListening ? 'Stop' : 'Start'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(120, 48),
              backgroundColor: isListening ? AppColors.error : null,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.mic_none),
            onPressed: _checkPermissions,
            tooltip: 'Request Microphone Permission',
            iconSize: AppConstants.iconSizeLg,
          ),
        ],
      ),
    );
  }
}

class _SignalCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _SignalCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium,
          ),
          const SizedBox(height: AppConstants.spacingSm),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// Paints a waveform from normalized samples in [-1, 1].
class WaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color color;

  WaveformPainter({
    required this.waveform,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.length < 2) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final path = Path();
    final midY = size.height / 2;

    for (int i = 0; i < waveform.length; i++) {
      final x = (i / (waveform.length - 1)) * size.width;
      final y = midY - waveform[i] * midY;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
    return oldDelegate.waveform != waveform || oldDelegate.color != color;
  }
}

/// Paints a normalized spectrum as bars.
class SpectrumPainter extends CustomPainter {
  final List<double> spectrum;
  final Color color;

  SpectrumPainter({
    required this.spectrum,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum.isEmpty) return;

    final paint = Paint()..color = color.withOpacity(0.85);
    final barWidth = size.width / spectrum.length;

    for (int i = 0; i < spectrum.length; i++) {
      final mag = spectrum[i].clamp(0.0, 1.0);
      final h = mag * size.height;
      final rect = Rect.fromLTWH(
        i * barWidth,
        size.height - h,
        barWidth * 0.9,
        h,
      );
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) {
    return oldDelegate.spectrum != spectrum || oldDelegate.color != color;
  }
}
