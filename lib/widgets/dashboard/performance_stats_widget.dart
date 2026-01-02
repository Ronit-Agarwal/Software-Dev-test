import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/core/theme/colors.dart';

/// Widget displaying real-time performance statistics.
///
/// Shows FPS, inference latency, memory usage, and battery level
/// with visual indicators and color-coded status.
class PerformanceStatsWidget extends ConsumerStatefulWidget {
  final double fps;
  final int latency;
  final double memoryUsage;
  final int batteryLevel;

  const PerformanceStatsWidget({
    super.key,
    required this.fps,
    required this.latency,
    required this.memoryUsage,
    required this.batteryLevel,
  });

  @override
  ConsumerState<PerformanceStatsWidget> createState() => _PerformanceStatsWidgetState();
}

class _PerformanceStatsWidgetState extends ConsumerState<PerformanceStatsWidget> {
  Timer? _updateTimer;

  @override
  void initState() {
    super.initState();
    _updateTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _updateTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Performance',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.speed,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.fiber_manual_record,
                    label: 'FPS',
                    value: widget.fps.toStringAsFixed(1),
                    color: _getFpsColor(widget.fps),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.timer,
                    label: 'Latency',
                    value: '${widget.latency}ms',
                    color: _getLatencyColor(widget.latency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.memory,
                    label: 'Memory',
                    value: '${widget.memoryUsage.toStringAsFixed(0)}MB',
                    color: _getMemoryColor(widget.memoryUsage),
                  ),
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: _buildStatCard(
                    context,
                    icon: Icons.battery_full,
                    label: 'Battery',
                    value: '${widget.batteryLevel}%',
                    color: _getBatteryColor(widget.batteryLevel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingSm),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppConstants.radiusMd),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Color _getFpsColor(double fps) {
    if (fps >= 24) return Colors.green;
    if (fps >= 15) return Colors.orange;
    return Colors.red;
  }

  Color _getLatencyColor(int latency) {
    if (latency < 100) return Colors.green;
    if (latency < 200) return Colors.orange;
    return Colors.red;
  }

  Color _getMemoryColor(double memory) {
    if (memory < 200) return Colors.green;
    if (memory < 400) return Colors.orange;
    return Colors.red;
  }

  Color _getBatteryColor(int battery) {
    if (battery > 50) return Colors.green;
    if (battery > 20) return Colors.orange;
    return Colors.red;
  }
}
