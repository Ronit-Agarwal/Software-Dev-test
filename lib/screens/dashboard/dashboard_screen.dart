import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/services/camera_service.dart';
import 'package:signsync/services/ml_orchestrator_service.dart';
import 'package:signsync/utils/constants.dart';
import 'package:signsync/widgets/common/bottom_nav_bar.dart';
import 'package:signsync/widgets/dashboard/health_indicator_widget.dart';
import 'package:signsync/widgets/dashboard/mode_toggle_widget.dart';
import 'package:signsync/widgets/dashboard/performance_stats_widget.dart';
import 'package:signsync/widgets/dashboard/quick_action_button.dart';

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
              _Header(l10n: l10n),
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
              _QuickActions(l10n: l10n),
              const SizedBox(height: AppConstants.spacingLg),
              _CurrentModeCard(mode: currentMode, orchestrator: orchestrator, l10n: l10n),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SignSyncBottomNavBar(
        currentIndex: currentMode.navigationIndex,
        onIndexChanged: (index) {
          HapticFeedback.selectionClick();
          ref.read(appModeProvider.notifier).state = AppMode.fromNavigationIndex(index);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AppLocalizations l10n;

  const _Header({required this.l10n});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Column(
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
      ),
    );
  }
}

class _QuickActions extends ConsumerWidget {
  final AppLocalizations l10n;

  const _QuickActions({required this.l10n});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                HapticFeedback.selectionClick();
                ref.read(appModeProvider.notifier).state = AppMode.translation;
              },
            ),
            QuickActionButton(
              icon: Icons.visibility,
              label: l10n.objectDetection,
              color: Colors.orange,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(appModeProvider.notifier).state = AppMode.detection;
              },
            ),
            QuickActionButton(
              icon: Icons.volume_up,
              label: l10n.soundDetection,
              color: Colors.blue,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(appModeProvider.notifier).state = AppMode.sound;
              },
            ),
            QuickActionButton(
              icon: Icons.chat,
              label: l10n.aiChat,
              color: Colors.purple,
              onTap: () {
                HapticFeedback.selectionClick();
                ref.read(appModeProvider.notifier).state = AppMode.chat;
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _CurrentModeCard extends StatelessWidget {
  final AppMode mode;
  final MlOrchestratorService orchestrator;
  final AppLocalizations l10n;

  const _CurrentModeCard({
    required this.mode,
    required this.orchestrator,
    required this.l10n,
  });

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
              children: [
                Icon(
                  _modeIcon(mode),
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppConstants.spacingSm),
                Expanded(
                  child: Text(
                    'Current Mode: ${_modeLabel(mode, l10n)}',
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

  static String _modeLabel(AppMode mode, AppLocalizations l10n) {
    switch (mode) {
      case AppMode.dashboard:
        return l10n.dashboard;
      case AppMode.translation:
        return l10n.aslTranslation;
      case AppMode.detection:
        return l10n.objectDetection;
      case AppMode.sound:
        return l10n.soundDetection;
      case AppMode.chat:
        return l10n.aiChat;
    }
  }

  static IconData _modeIcon(AppMode mode) {
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
    }
  }
}
