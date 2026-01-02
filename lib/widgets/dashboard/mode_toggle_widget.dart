import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Widget for quick mode switching.
///
/// Provides visually appealing buttons to switch between
/// ASL Translation, Object Detection, Sound Alerts, and AI Chat.
class ModeToggleWidget extends ConsumerWidget {
  const ModeToggleWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentMode = ref.watch(appModeProvider);

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Mode',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: AppConstants.spacingMd),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: AppConstants.spacingSm,
              crossAxisSpacing: AppConstants.spacingSm,
              childAspectRatio: 1.3,
              children: AppMode.values
                  .where((mode) => mode != AppMode.dashboard)
                  .map((mode) {
                final isSelected = mode == currentMode;
                return _buildModeButton(
                  context,
                  mode,
                  isSelected,
                  () => ref.read(appModeProvider.notifier).state = mode,
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildModeButton(
    BuildContext context,
    AppMode mode,
    bool isSelected,
    VoidCallback onTap,
  ) {
    final icon = _getModeIcon(mode);
    final color = _getModeColor(mode);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.8)],
                )
              : null,
          color: isSelected ? null : Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(AppConstants.radiusLg),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingMd),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : color,
                size: 32,
              ),
              const SizedBox(height: AppConstants.spacingSm),
              Text(
                _getModeLabel(mode),
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: isSelected ? Colors.white : null,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _getModeIcon(AppMode mode) {
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

  Color _getModeColor(AppMode mode) {
    switch (mode) {
      case AppMode.dashboard:
        return AppColors.primary;
      case AppMode.translation:
        return AppColors.primary;
      case AppMode.detection:
        return Colors.orange;
      case AppMode.sound:
        return Colors.blue;
      case AppMode.chat:
        return Colors.purple;
    }
  }

  String _getModeLabel(AppMode mode) {
    switch (mode) {
      case AppMode.dashboard:
        return 'Dashboard';
      case AppMode.translation:
        return 'ASL\nTranslation';
      case AppMode.detection:
        return 'Object\nDetection';
      case AppMode.sound:
        return 'Sound\nAlerts';
      case AppMode.chat:
        return 'AI\nChat';
    }
  }
}
