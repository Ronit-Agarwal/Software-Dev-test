import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:signsync/config/providers.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/common/bottom_nav_bar.dart';
import 'package:signsync/widgets/dashboard/health_indicator_widget.dart';
import 'package:signsync/widgets/dashboard/mode_toggle_widget.dart';
import 'package:signsync/widgets/dashboard/performance_stats_widget.dart';
import 'package:signsync/widgets/dashboard/quick_action_button.dart';

/// Dashboard screen with mode switching and real-time stats.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);
    final orchestrator = ref.watch(mlOrchestratorServiceProvider);
    final cameraService = ref.watch(cameraServiceProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context, l10n),
              const SizedBox(height: AppConstants.spacingLg),

              // Mode Toggle Section
              const ModeToggleWidget(),
              const SizedBox(height: AppConstants.spacingLg),

              // Performance Stats
              PerformanceStatsWidget(
                fps: cameraService.currentFps,
                latency: orchestrator.lastInferenceLatency ?? 0,
                memoryUsage: orchestrator.memoryUsage ?? 0,
                batteryLevel: orchestrator.batteryLevel ?? 100,
              ),
              const SizedBox(height: AppConstants.spacingLg),

              // Health Indicators
              const HealthIndicatorWidget(),
              const SizedBox(height: AppConstants.spacingLg),

              // Quick Actions
              _buildQuickActions(context, ref, l10n),
              const SizedBox(height: AppConstants.spacingLg),

              // Current Mode Info
              _buildCurrentModeCard(context, currentMode, orchestrator, l10n),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SignSyncBottomNavBar(
        currentIndex: currentMode.navigationIndex,
        onIndexChanged: (index) {
          final newMode = AppMode.fromNavigationIndex(index);
          ref.read(appModeProvider.notifier).state = newMode;
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.dashboard,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: AppConstants.spacingXs),
        Text(
          'Manage your SignSync experience',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
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
              icon: Icons.camera_alt,
              label: l10n.aslTranslation,
              color: AppColors.primary,
              onTap: () {
                ref.read(appModeProvider.notifier).state = AppMode.translation;
              },
            ),
            QuickActionButton(
              icon: Icons.visibility,
              label: l10n.objectDetection,
              color: Colors.orange,
              onTap: () {
                ref.read(appModeProvider.notifier).state = AppMode.detection;
              },
            ),
            QuickActionButton(
              icon: Icons.volume_up,
              label: l10n.soundDetection,
              color: Colors.blue,
              onTap: () {
                ref.read(appModeProvider.notifier).state = AppMode.sound;
              },
            ),
            QuickActionButton(
              icon: Icons.chat,
              label: l10n.aiChat,
              color: Colors.purple,
              onTap: () {
                ref.read(appModeProvider.notifier).state = AppMode.chat;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCurrentModeCard(
    BuildContext context,
    AppMode mode,
    dynamic orchestrator,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getModeIcon(mode),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    'Current Mode: ${_getLocalizedModeName(mode, l10n)}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.spacingSm,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(AppConstants.radiusCircular),
                  ),
                  child: const Text(
                    'Active',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.spacingSm),
            Text(
              mode.description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (orchestrator.isProcessing) ...[
              const SizedBox(height: AppConstants.spacingMd),
              Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingSm),
                  const Text(
                    'Processing...',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLocalizedModeName(AppMode mode, AppLocalizations l10n) {
    switch (mode) {
      case AppMode.translation: return l10n.aslTranslation;
      case AppMode.detection: return l10n.objectDetection;
      case AppMode.sound: return l10n.soundDetection;
      case AppMode.chat: return l10n.aiChat;
      default: return 'Dashboard';
    }
  }

  IconData _getModeIcon(AppMode mode) {
    switch (mode) {
      case AppMode.translation:
        return Icons.translate;
      case AppMode.detection:
        return Icons.visibility;
      case AppMode.sound:
        return Icons.volume_up;
      case AppMode.chat:
        return Icons.chat;
    }
  }
}
