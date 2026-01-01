import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/utils/constants.dart';

/// Dashboard screen that summarizes app status and provides quick mode access.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = ref.watch(appConfigProvider);
    final cameraFps = ref.watch(cameraFpsProvider);
    final perf = ref.watch(mlPerformanceProvider);
    final system = ref.watch(systemMetricsProvider);
    final soundMonitor = ref.watch(soundMonitorProvider);

    final avgProcessingMs = (perf['averageProcessingTime'] as num?)?.toDouble() ?? 0.0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
            tooltip: 'Settings',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        children: [
          _SectionTitle(title: 'Quick Modes'),
          const SizedBox(height: AppConstants.spacingSm),
          _ModeGrid(
            onSelectMode: (mode) => ref.read(appModeProvider.notifier).state = mode,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _SectionTitle(title: 'Real-time Health'),
          const SizedBox(height: AppConstants.spacingSm),
          _HealthRow(
            fps: cameraFps,
            avgProcessingMs: avgProcessingMs,
            batteryLevel: system.batteryLevel,
            batteryState: system.batteryState,
            memoryBytes: system.memoryBytes,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _SectionTitle(title: 'Alerts'),
          const SizedBox(height: AppConstants.spacingSm),
          _AlertsCard(
            ttsEnabled: config.ttsEnabled,
            objectAlertsEnabled: config.objectAudioAlertsEnabled,
            soundMonitoringEnabled: config.soundMonitoringEnabled,
            soundMonitoringActive: soundMonitor.isMonitoring,
          ),
          const SizedBox(height: AppConstants.spacingLg),
          _SectionTitle(title: 'Performance Details'),
          const SizedBox(height: AppConstants.spacingSm),
          _MetricsTable(
            cameraFps: cameraFps,
            avgProcessingMs: avgProcessingMs,
            perf: perf,
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _ModeGrid extends StatelessWidget {
  final ValueChanged<AppMode> onSelectMode;

  const _ModeGrid({required this.onSelectMode});

  @override
  Widget build(BuildContext context) {
    final items = <({AppMode mode, IconData icon})>[
      (mode: AppMode.translation, icon: Icons.translate),
      (mode: AppMode.detection, icon: Icons.visibility),
      (mode: AppMode.sound, icon: Icons.volume_up),
      (mode: AppMode.chat, icon: Icons.chat),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: AppConstants.spacingSm,
      crossAxisSpacing: AppConstants.spacingSm,
      childAspectRatio: 1.5,
      children: items
          .map(
            (item) => _ModeCard(
              title: item.mode.displayName,
              subtitle: item.mode.description,
              icon: item.icon,
              onTap: () => onSelectMode(item.mode),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _ModeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      child: Ink(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
        ),
        child: Row(
          children: [
            Icon(icon, size: AppConstants.iconSizeLg),
            const SizedBox(width: AppConstants.spacingMd),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthRow extends StatelessWidget {
  final double fps;
  final double avgProcessingMs;
  final int? batteryLevel;
  final BatteryState? batteryState;
  final int memoryBytes;

  const _HealthRow({
    required this.fps,
    required this.avgProcessingMs,
    required this.batteryLevel,
    required this.batteryState,
    required this.memoryBytes,
  });

  @override
  Widget build(BuildContext context) {
    final fpsColor = _healthColor(
      value: fps,
      good: 20,
      warn: 12,
      higherIsBetter: true,
    );

    final latencyColor = _healthColor(
      value: avgProcessingMs,
      good: 80,
      warn: 140,
      higherIsBetter: false,
    );

    final batteryColor = _healthColor(
      value: (batteryLevel ?? 0).toDouble(),
      good: 40,
      warn: 20,
      higherIsBetter: true,
    );

    final memoryMb = memoryBytes / (1024 * 1024);
    final memoryColor = _healthColor(
      value: memoryMb,
      good: 250,
      warn: 450,
      higherIsBetter: false,
    );

    return Row(
      children: [
        Expanded(
          child: _HealthTile(
            label: 'FPS',
            value: fps.isFinite ? fps.toStringAsFixed(1) : '--',
            color: fpsColor,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _HealthTile(
            label: 'Latency',
            value: '${avgProcessingMs.toStringAsFixed(0)} ms',
            color: latencyColor,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _HealthTile(
            label: 'Battery',
            value: batteryLevel == null
                ? '--'
                : '${batteryLevel!.toStringAsFixed(0)}%${batteryState == BatteryState.charging ? ' ⚡' : ''}',
            color: batteryColor,
          ),
        ),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: _HealthTile(
            label: 'Memory',
            value: '${memoryMb.toStringAsFixed(0)} MB',
            color: memoryColor,
          ),
        ),
      ],
    );
  }

  Color _healthColor({
    required double value,
    required double good,
    required double warn,
    required bool higherIsBetter,
  }) {
    if (!value.isFinite) return Colors.grey;

    if (higherIsBetter) {
      if (value >= good) return Colors.green;
      if (value >= warn) return Colors.orange;
      return Colors.red;
    }

    if (value <= good) return Colors.green;
    if (value <= warn) return Colors.orange;
    return Colors.red;
  }
}

class _HealthTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HealthTile({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Column(
        children: [
          Text(label, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _AlertsCard extends StatelessWidget {
  final bool ttsEnabled;
  final bool objectAlertsEnabled;
  final bool soundMonitoringEnabled;
  final bool soundMonitoringActive;

  const _AlertsCard({
    required this.ttsEnabled,
    required this.objectAlertsEnabled,
    required this.soundMonitoringEnabled,
    required this.soundMonitoringActive,
  });

  @override
  Widget build(BuildContext context) {
    final soundStatus = soundMonitoringActive
        ? 'Active'
        : soundMonitoringEnabled
            ? 'Enabled'
            : 'Off';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children: [
            _Row(label: 'Voice feedback', value: ttsEnabled ? 'On' : 'Off'),
            const SizedBox(height: AppConstants.spacingXs),
            _Row(label: 'Object alerts', value: objectAlertsEnabled ? 'On' : 'Off'),
            const SizedBox(height: AppConstants.spacingXs),
            _Row(label: 'Sound monitoring', value: soundStatus),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String label;
  final String value;

  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class _MetricsTable extends StatelessWidget {
  final double cameraFps;
  final double avgProcessingMs;
  final Map<String, dynamic> perf;

  const _MetricsTable({
    required this.cameraFps,
    required this.avgProcessingMs,
    required this.perf,
  });

  @override
  Widget build(BuildContext context) {
    final cnnStats = perf['cnnStats'] as Map<String, dynamic>?;
    final yoloStats = perf['yoloStats'] as Map<String, dynamic>?;

    final cnnAvgMs = (cnnStats?['averageInferenceTime'] as num?)?.toDouble();
    final yoloAvgMs = (yoloStats?['averageInferenceTime'] as num?)?.toDouble();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          children: [
            _metric(context, 'Camera FPS', cameraFps.isFinite ? cameraFps.toStringAsFixed(1) : '--'),
            _metric(context, 'Orchestrator avg', '${avgProcessingMs.toStringAsFixed(0)} ms'),
            _metric(context, 'CNN avg', cnnAvgMs == null ? '--' : '${cnnAvgMs.toStringAsFixed(0)} ms'),
            _metric(context, 'YOLO avg', yoloAvgMs == null ? '--' : '${yoloAvgMs.toStringAsFixed(0)} ms'),
          ],
        ),
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.labelLarge,
          ),
        ],
      ),
    );
  }
}
