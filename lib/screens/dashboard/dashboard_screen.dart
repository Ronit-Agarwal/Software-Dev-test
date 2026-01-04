import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/common/bottom_nav_bar.dart';
import 'package:signsync/widgets/dashboard/health_indicator_widget.dart';
import 'package:signsync/widgets/dashboard/mode_toggle_widget.dart';
import 'package:signsync/widgets/dashboard/performance_stats_widget.dart';
import 'package:signsync/widgets/dashboard/quick_action_button.dart';

/// Dashboard screen showing system status, performance, and quick actions.
///
/// The dashboard is designed to be stable even when platform plugins are
/// unavailable (e.g., during widget tests). It will render with placeholder
/// values and degrade gracefully.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);
    final orchestrator = ref.watch(mlOrchestratorServiceProvider);
    final cameraService = ref.watch(cameraServiceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Manage your SignSync experience',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppConstants.spacingLg),
              const ModeToggleWidget(),
              const SizedBox(height: AppConstants.spacingLg),
              PerformanceStatsWidget(
                fps: cameraService.currentFps,
                latency: orchestrator.lastInferenceLatency ?? 0,
                memoryUsage: orchestrator.memoryUsage ?? 0,
                batteryLevel: orchestrator.batteryLevel ?? 100,
              ),
              const SizedBox(height: AppConstants.spacingLg),
              const HealthIndicatorWidget(),
              const SizedBox(height: AppConstants.spacingLg),
              _QuickActions(onNavigate: (mode) => _navigateToMode(context, ref, mode)),
              const SizedBox(height: AppConstants.spacingLg),
              _CurrentModeCard(mode: currentMode),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SignSyncBottomNavBar(
        currentIndex: currentMode.navigationIndex,
        onIndexChanged: (index) {
          final mode = AppMode.fromNavigationIndex(index);
          _navigateToMode(context, ref, mode);
        },
      ),
    );
  }

  Future<void> _navigateToMode(BuildContext context, WidgetRef ref, AppMode mode) async {
    ref.read(appModeProvider.notifier).state = mode;

    final routeName = mode.routePath;
    final currentRouteName = ModalRoute.of(context)?.settings.name;
    if (currentRouteName == routeName) return;

    try {
      await Navigator.of(context).pushReplacementNamed(routeName);
    } catch (_) {
      // Widget tests commonly render screens without named routes.
    }
  }
}

class _QuickActions extends StatelessWidget {
  final ValueChanged<AppMode> onNavigate;

  const _QuickActions({required this.onNavigate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Quick Actions',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: AppConstants.spacingMd),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          mainAxisSpacing: AppConstants.spacingMd,
          crossAxisSpacing: AppConstants.spacingMd,
          children: [
            QuickActionButton(
              icon: Icons.translate,
              label: 'ASL Translation',
              color: AppColors.primary,
              onTap: () => onNavigate(AppMode.translation),
            ),
            QuickActionButton(
              icon: Icons.visibility,
              label: 'Object Detection',
              color: Colors.orange,
              onTap: () => onNavigate(AppMode.detection),
            ),
            QuickActionButton(
              icon: Icons.volume_up,
              label: 'Sound Alerts',
              color: Colors.blue,
              onTap: () => onNavigate(AppMode.sound),
            ),
            QuickActionButton(
              icon: Icons.chat,
              label: 'AI Chat',
              color: Colors.purple,
              onTap: () => onNavigate(AppMode.chat),
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentModeCard extends StatelessWidget {
  final AppMode mode;

  const _CurrentModeCard({required this.mode});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Row(
          children: [
            Icon(
              _iconForMode(mode),
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: AppConstants.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.displayName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mode.description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static IconData _iconForMode(AppMode mode) {
    switch (mode) {
      case AppMode.dashboard:
        return Icons.dashboard;
      case AppMode.translation:
        return Icons.translate;
      case AppMode.detection:
        return Icons.visibility;
      case AppMode.sound:
        return Icons.volume_up;
      case AppMode.chat:
        return Icons.chat;
      case AppMode.settings:
        return Icons.settings;
    }
  }
}
