import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/core/theme/colors.dart';

/// Widget displaying system health indicators.
///
/// Shows green/yellow/red status for camera, ML models,
/// and other system components.
class HealthIndicatorWidget extends ConsumerWidget {
  const HealthIndicatorWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameraService = ref.watch(cameraServiceProvider);
    final orchestrator = ref.watch(mlOrchestratorProvider);

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
                  'System Health',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Icon(
                  Icons.health_and_safety,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingMd),
            _buildIndicatorRow(
              context,
              label: 'Camera',
              status: cameraService.isInitialized
                  ? HealthStatus.good
                  : HealthStatus.error,
              icon: Icons.camera_alt,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildIndicatorRow(
              context,
              label: 'ML Models',
              status: orchestrator.isInitialized
                  ? HealthStatus.good
                  : HealthStatus.error,
              icon: Icons.psychology,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildIndicatorRow(
              context,
              label: 'Processing',
              status: orchestrator.isProcessing
                  ? HealthStatus.warning
                  : HealthStatus.good,
              icon: Icons.settings_suggest,
            ),
            const SizedBox(height: AppConstants.spacingSm),
            _buildIndicatorRow(
              context,
              label: 'Network',
              status: HealthStatus.good,
              icon: Icons.wifi,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIndicatorRow(
    BuildContext context, {
    required String label,
    required HealthStatus status,
    required IconData icon,
  }) {
    final statusColor = _getStatusColor(status);
    final statusText = _getStatusText(status);

    return Row(
      children: [
        Icon(icon, size: 20, color: statusColor),
        const SizedBox(width: AppConstants.spacingSm),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.spacingSm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                statusText,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(HealthStatus status) {
    switch (status) {
      case HealthStatus.good:
        return Colors.green;
      case HealthStatus.warning:
        return Colors.orange;
      case HealthStatus.error:
        return Colors.red;
    }
  }

  String _getStatusText(HealthStatus status) {
    switch (status) {
      case HealthStatus.good:
        return 'Good';
      case HealthStatus.warning:
        return 'Warning';
      case HealthStatus.error:
        return 'Error';
    }
  }
}

/// Health status enumeration.
enum HealthStatus {
  good,
  warning,
  error,
}
