import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:signsync/models/app_mode.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/core/theme/colors.dart';
import 'package:signsync/utils/constants.dart';

/// Custom bottom navigation bar for mode switching.
///
/// This widget provides a consistent navigation experience with
/// proper accessibility support.
class SignSyncBottomNavBar extends ConsumerWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const SignSyncBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onIndexChanged,
      type: BottomNavigationBarType.fixed,
      items: _buildItems(),
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showSelectedLabels: true,
      showUnselectedLabels: true,
    );
  }

  List<BottomNavigationBarItem> _buildItems() {
    return const [
      BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Dashboard',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.translate),
        label: 'Translation',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.visibility),
        label: 'Detection',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.volume_up),
        label: 'Sound',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'AI Chat',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.settings),
        label: 'Settings',
      ),
    ];
  }
}

/// A compact bottom navigation bar for smaller screens.
class CompactBottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const CompactBottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      onTap: onIndexChanged,
      type: BottomNavigationBarType.fixed,
      items: _buildItems(),
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedItemColor: Theme.of(context).colorScheme.primary,
      unselectedItemColor: Theme.of(context).colorScheme.onSurfaceVariant,
      showSelectedLabels: true,
      showUnselectedLabels: true,
      elevation: 8,
    );
  }

  List<BottomNavigationBarItem> _buildItems() {
    return [
      const BottomNavigationBarItem(
        icon: Icon(Icons.dashboard),
        label: 'Home',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.translate),
        label: 'ASL',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.visibility),
        label: 'Detect',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.volume_up),
        label: 'Sound',
      ),
      const BottomNavigationBarItem(
        icon: Icon(Icons.chat),
        label: 'Chat',
      ),
    ];
  }
}

/// A navigation rail for tablet/desktop layouts.
class SignSyncNavRail extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  const SignSyncNavRail({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NavigationRail(
      selectedIndex: selectedIndex,
      onDestinationSelected: onDestinationSelected,
      destinations: _buildDestinations(),
      labelType: NavigationRailLabelType.all,
      backgroundColor: Theme.of(context).colorScheme.surface,
      indicatorColor: Theme.of(context).colorScheme.primaryContainer,
      elevation: 8,
    );
  }

  List<NavigationRailDestination> _buildDestinations() {
    return const [
      NavigationRailDestination(
        icon: Icon(Icons.dashboard),
        selectedIcon: Icon(Icons.dashboard),
        label: Text('Dashboard'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.translate),
        selectedIcon: Icon(Icons.translate),
        label: Text('ASL Translation'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.visibility),
        selectedIcon: Icon(Icons.visibility),
        label: Text('Object Detection'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.volume_up),
        selectedIcon: Icon(Icons.volume_up),
        label: Text('Sound Alerts'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.chat),
        selectedIcon: Icon(Icons.chat),
        label: Text('AI Chat'),
      ),
    ];
  }
}

/// A tab bar for switching between modes.
class ModeTabBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const ModeTabBar({
    super.key,
    required this.selectedIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = ['ASL', 'Detect', 'Sound', 'Chat'];

    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingXs),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(AppConstants.radiusLg),
      ),
      child: Row(
        children: tabs.asMap().entries.map((entry) {
          final index = entry.key;
          final tab = entry.value;
          final isSelected = index == selectedIndex;

          return Expanded(
            child: GestureDetector(
              onTap: () => onTap(index),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: AppConstants.spacingSm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusMd),
                ),
                child: Text(
                  tab,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected
                        ? Theme.of(context).colorScheme.onPrimary
                        : Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
