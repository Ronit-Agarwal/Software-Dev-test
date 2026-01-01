import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/models/alert_item.dart';
import 'package:signsync/models/noise_event.dart';
import 'package:signsync/services/audio_service.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/utils/constants.dart';

class SoundScreen extends ConsumerStatefulWidget {
  const SoundScreen({super.key});

  @override
  ConsumerState<SoundScreen> createState() => _SoundScreenState();
}

class _SoundScreenState extends ConsumerState<SoundScreen> {
  bool _isListening = false;
  final List<NoiseEvent> _recentEvents = [];
  double _currentLevel = 0;
  double _currentDb = -120;

  List<double> _waveform = const [];
  List<double> _spectrum = const [];

  StreamSubscription<double>? _levelSub;
  StreamSubscription<double>? _dbSub;
  StreamSubscription<List<double>>? _waveSub;
  StreamSubscription<List<double>>? _specSub;

  @override
  void initState() {
    super.initState();
    LoggerService.info('Sound screen initialized');
  }

  @override
  void dispose() {
    unawaited(_levelSub?.cancel());
    unawaited(_dbSub?.cancel());
    unawaited(_waveSub?.cancel());
    unawaited(_specSub?.cancel());

    if (_isListening) {
      ref.read(audioServiceProvider).stopRecording();
    }

    super.dispose();
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
      if (!permissionsService.hasMicrophonePermission) {
        await permissionsService.requestMicrophonePermission();
      }

      final audioService = ref.read(audioServiceProvider);
      await audioService.initialize();
      await audioService.startRecording(onNoiseDetected: _onNoiseDetected);

      await _levelSub?.cancel();
      await _dbSub?.cancel();
      await _waveSub?.cancel();
      await _specSub?.cancel();

      _levelSub = audioService.audioLevelStream.listen((level) {
        if (!mounted) return;
        setState(() => _currentLevel = level);
      });
      _dbSub = audioService.dbLevelStream.listen((db) {
        if (!mounted) return;
        setState(() => _currentDb = db);
      });
      _waveSub = audioService.waveformStream.listen((wave) {
        if (!mounted) return;
        setState(() => _waveform = wave);
      });
      _specSub = audioService.spectrumStream.listen((spec) {
        if (!mounted) return;
        setState(() => _spectrum = spec);
      });

      setState(() => _isListening = true);
    } catch (e, stack) {
      LoggerService.error('Failed to start sound detection', error: e, stack: stack);
      _showError('Failed to access microphone: $e');
    }
  }

  void _stopListening() {
    LoggerService.info('Stopping sound detection');
    AnalyticsEvent.logSoundAlertsStopped(durationMs: DateTime.now().millisecondsSinceEpoch);

    ref.read(audioServiceProvider).stopRecording();
    setState(() => _isListening = false);
  }

  void _onNoiseDetected(NoiseEvent event) {
    setState(() {
      _recentEvents.insert(0, event);
      if (_recentEvents.length > 20) {
        _recentEvents.removeLast();
      }
    });

    if (event.shouldAlert) {
      _showAlertNotification(event);
      _speakAlert(event);
    }
  }

  Future<void> _speakAlert(NoiseEvent event) async {
    final alertQueue = ref.read(alertQueueServiceProvider);

    final priority = switch (event.severity) {
      AlertSeverity.critical => AlertPriority.critical,
      AlertSeverity.high => AlertPriority.high,
      AlertSeverity.medium => AlertPriority.normal,
      AlertSeverity.low => AlertPriority.low,
    };

    await alertQueue.enqueue(
      AlertItem(
        id: 'sound_${event.id}',
        text: '${event.type.displayName} detected',
        priority: priority,
        cacheKey: 'sound|${event.type.name}',
        dedupeWindow: const Duration(seconds: 4),
      ),
    );
  }

  void _showAlertNotification(NoiseEvent event) {
    if (!mounted) return;

    final severityColor = event.severity.color;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(event.type.icon, color: severityColor),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(event.type.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
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
          Expanded(
            flex: 2,
            child: _buildAudioVisualization(),
          ),
          Expanded(
            flex: 2,
            child: _buildEventsList(),
          ),
          _buildControlBar(),
        ],
      ),
    );
  }

  Widget _buildAudioVisualization() {
    return Container(
      margin: const EdgeInsets.all(AppConstants.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _isListening ? 'Listening…' : 'Tap Start to listen',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(
                  '${(_currentLevel * 100).toStringAsFixed(0)}%  ${_currentDb.toStringAsFixed(1)} dBFS',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Expanded(
              child: CustomPaint(
                painter: WaveformPainter(samples: _waveform, color: Theme.of(context).colorScheme.primary),
                child: const SizedBox.expand(),
              ),
            ),
            const SizedBox(height: AppConstants.spacingSm),
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: SpectrumPainter(bands: _spectrum, color: AppColors.warning),
                child: const SizedBox.expand(),
              ),
            ),
          ],
        ),
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
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingMd),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Recent Events', style: Theme.of(context).textTheme.titleMedium),
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
                        Text('No sounds detected yet', style: Theme.of(context).textTheme.bodyMedium),
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

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(AppConstants.spacingXs),
        decoration: BoxDecoration(
          color: event.severity.color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(AppConstants.radiusSm),
        ),
        child: Icon(event.type.icon, color: event.severity.color),
      ),
      title: Text(event.type.displayName),
      subtitle: Text('${(event.intensity * 100).toStringAsFixed(0)}% - $time'),
      trailing: Text(
        event.severity.displayName,
        style: TextStyle(color: event.severity.color, fontWeight: FontWeight.bold),
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
              Text('Detection History', style: Theme.of(context).textTheme.titleMedium),
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
                      trailing: Text('${(event.intensity * 100).toStringAsFixed(0)}%'),
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

class WaveformPainter extends CustomPainter {
  final List<double> samples;
  final Color color;

  WaveformPainter({required this.samples, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final midY = size.height / 2;

    final path = Path();
    if (samples.isEmpty) {
      path.moveTo(0, midY);
      path.lineTo(size.width, midY);
      canvas.drawPath(path, paint);
      return;
    }

    for (int i = 0; i < samples.length; i++) {
      final x = (i / (samples.length - 1)) * size.width;
      final y = midY - (samples[i] * (size.height / 2)) * 0.9;
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
    return oldDelegate.samples != samples || oldDelegate.color != color;
  }
}

class SpectrumPainter extends CustomPainter {
  final List<double> bands;
  final Color color;

  SpectrumPainter({required this.bands, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final barPaint = Paint()..color = color;
    final w = size.width / bands.length;

    for (int i = 0; i < bands.length; i++) {
      final mag = bands[i].clamp(0.0, 1.0);
      final h = mag * size.height;
      final rect = Rect.fromLTWH(i * w, size.height - h, w * 0.8, h);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        barPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant SpectrumPainter oldDelegate) {
    return oldDelegate.bands != bands || oldDelegate.color != color;
  }
}
