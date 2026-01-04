import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/screens/chat/chat_screen.dart';
import 'package:signsync/screens/dashboard/dashboard_screen.dart';
import 'package:signsync/screens/detection/detection_screen.dart';
import 'package:signsync/screens/home/home_screen.dart';
import 'package:signsync/screens/settings/settings_screen.dart';
import 'package:signsync/screens/sound/sound_screen.dart';
import 'package:signsync/screens/translation/translation_screen.dart';

/// Central route configuration for SignSync.
///
/// The production app currently uses simple Navigator routes (see [SignSyncApp])
/// for maximum testability. This router remains available for deep-linking and
/// future migration to GoRouter-based navigation.
class AppRouter {
  static GoRouter createRouter(AppConfig config) {
    return GoRouter(
      initialLocation: '/dashboard',
      debugLogDiagnostics: kDebugMode,
      routes: <GoRoute>[
        GoRoute(
          path: '/',
          name: 'root',
          redirect: (_, __) => '/dashboard',
        ),
        GoRoute(
          path: '/home',
          name: 'home',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const HomeScreen(),
            screenName: 'Home',
          ),
        ),
        GoRoute(
          path: '/dashboard',
          name: 'dashboard',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const DashboardScreen(),
            screenName: 'Dashboard',
          ),
        ),
        GoRoute(
          path: '/translation',
          name: 'translation',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const TranslationScreen(),
            screenName: 'ASL Translation',
          ),
        ),
        GoRoute(
          path: '/detection',
          name: 'detection',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const DetectionScreen(),
            screenName: 'Object Detection',
          ),
        ),
        GoRoute(
          path: '/sound',
          name: 'sound',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const SoundScreen(),
            screenName: 'Sound Alerts',
          ),
        ),
        GoRoute(
          path: '/chat',
          name: 'chat',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const ChatScreen(),
            screenName: 'AI Chat',
          ),
        ),
        GoRoute(
          path: '/settings',
          name: 'settings',
          pageBuilder: (context, state) => _buildPage(
            context,
            state,
            const SettingsScreen(),
            screenName: 'Settings',
          ),
        ),
      ],
      errorPageBuilder: (context, state) => _errorPageBuilder(context, state),
      redirect: (context, state) {
        if (state.uri.path == '/') return '/dashboard';
        return null;
      },
    );
  }

  static Page<void> _buildPage(
    BuildContext context,
    GoRouterState state,
    Widget screen, {
    required String screenName,
  }) {
    Future.microtask(() {
      LoggerService.debug('Navigating to: $screenName');
    });

    final useCupertino = defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;

    if (useCupertino) {
      return CupertinoPage<void>(
        key: state.pageKey,
        title: screenName,
        child: screen,
      );
    }

    return MaterialPage<void>(
      key: state.pageKey,
      child: screen,
    );
  }

  static Page<void> _errorPageBuilder(BuildContext context, GoRouterState state) {
    final error = state.error;
    LoggerService.error(
      'Route error',
      error: error,
      stackTrace: error is Error ? error.stackTrace : null,
    );

    return MaterialPage<void>(
      key: state.pageKey,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(
                  'Navigation Error',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  error?.toString() ?? 'An unexpected routing error occurred.',
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/dashboard'),
                  child: const Text('Go to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
