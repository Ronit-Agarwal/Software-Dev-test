import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/core/navigation/route_guards.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/screens/home/home_screen.dart';
import 'package:signsync/screens/translation/translation_screen.dart';
import 'package:signsync/screens/translation/english_to_asl_screen.dart';
import 'package:signsync/screens/detection/detection_screen.dart';
import 'package:signsync/screens/chat/chat_screen.dart';
import 'package:signsync/screens/settings/settings_screen.dart';
import 'package:signsync/screens/sound/sound_screen.dart';
import 'package:signsync/services/permissions_service.dart';
import 'package:signsync/models/app_mode.dart';

/// App router configuration.
///
/// This class sets up the GoRouter instance with all routes,
/// route guards, and error handling.
class AppRouter {
  /// Creates the GoRouter instance.
  static GoRouter createRouter(AppConfig config) {
    return GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: kDebugMode,
      routes: _routes,
      errorPageBuilder: _errorPageBuilder,
      redirect: _redirect,
      onException: _onException,
    );
  }

  /// All application routes.
  static final List<GoRoute> _routes = [
    GoRoute(
      path: '/',
      name: 'home',
      pageBuilder: (context, state) => _buildPage(
        context,
        const HomeScreen(),
        state: state,
        screenName: 'Home',
      ),
    ),
    GoRoute(
      path: '/translation',
      name: 'translation',
      pageBuilder: (context, state) => _buildPage(
        context,
        const TranslationScreen(),
        state: state,
        screenName: 'ASL Translation',
      ),
    ),
    GoRoute(
      path: '/english-to-asl',
      name: 'englishToAsl',
      pageBuilder: (context, state) => _buildPage(
        context,
        const EnglishToAslScreen(),
        state: state,
        screenName: 'English to ASL',
      ),
    ),
    GoRoute(
      path: '/detection',
      name: 'detection',
      pageBuilder: (context, state) => _buildPage(
        context,
        const DetectionScreen(),
        state: state,
        screenName: 'Object Detection',
      ),
    ),
    GoRoute(
      path: '/sound',
      name: 'sound',
      pageBuilder: (context, state) => _buildPage(
        context,
        const SoundScreen(),
        state: state,
        screenName: 'Sound Alerts',
      ),
    ),
    GoRoute(
      path: '/chat',
      name: 'chat',
      pageBuilder: (context, state) => _buildPage(
        context,
        const ChatScreen(),
        state: state,
        screenName: 'AI Chat',
      ),
    ),
    GoRoute(
      path: '/settings',
      name: 'settings',
      pageBuilder: (context, state) => _buildPage(
        context,
        const SettingsScreen(),
        state: state,
        screenName: 'Settings',
      ),
    ),
  ];

  /// Redirect function for route guards.
  static String? _redirect(
    BuildContext context,
    GoRouterState state,
  ) {
    final location = state.uri.toString();

    // Redirect from root to translation
    if (location == '/') {
      return '/translation';
    }

    // Check permissions for camera-dependent routes
    final permissionRoutes = ['/translation', '/detection'];
    if (permissionRoutes.any((r) => location.startsWith(r))) {
      final permissionsService = PermissionsService();
      // In a real implementation, check permissions here
    }

    return null;
  }

  /// Exception handler for router errors.
  static void _onException(
    BuildContext context,
    GoRouterState state,
    Object error,
  ) {
    LoggerService.error(
      'Router exception',
      error: error,
      extra: {'location': state.uri.toString()},
    );

    // Navigate to error page
    context.go('/');
  }

  /// Builds a page with common configuration.
  static Page _buildPage(
    BuildContext context,
    Widget screen, {
    required GoRouterState state,
    required String screenName,
  }) {
    // Log screen view
    Future.microtask(() {
      LoggerService.debug('Navigating to: $screenName');
    });

    return _isCupertino(context: context)
        ? CupertinoPage<void>(
            key: state.pageKey,
            child: screen,
            title: screenName,
            fullscreenDialog: _isDialogRoute(state),
          )
        : MaterialPage<void>(
            key: state.pageKey,
            child: screen,
            fullscreenDialog: _isDialogRoute(state),
          );
  }

  /// Checks if the current platform should use Cupertino navigation.
  static bool _isCupertino({required BuildContext context}) {
    // Use cupertino on iOS and macOS
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Checks if the route is a dialog route.
  static bool _isDialogRoute(GoRouterState state) {
    return state.extra != null && state.extra is Dialog;
  }

  /// Builds the error page.
  static Page _errorPageBuilder(
    BuildContext context,
    GoRouterState state,
  ) {
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Page Not Found',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                state.error?.toString() ?? 'An unexpected error occurred',
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );


  /// Navigates to a route with optional parameters.
  static void navigate(
    BuildContext context, {
    required String location,
    Object? extra,
    bool replace = false,
  }) {
    if (replace) {
      context.replace(location, extra: extra);
    } else {
      context.go(location, extra: extra);
    }
  }

  /// Navigates to the specified app mode.
  static void navigateToMode(
    BuildContext context,
    AppMode mode, {
    bool replace = false,
  }) {
    navigate(context, location: mode.routePath, replace: replace);
  }

  /// Pops the current route.
  static void pop(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}

/// Route guards for permission checking.
mixin RouteGuards {
  /// Checks if the user has granted camera permission.
  static Future<bool> hasCameraPermission() async {
    // In a real implementation, check with permissions service
    return true;
  }

  /// Checks if the user has granted microphone permission.
  static Future<bool> hasMicrophonePermission() async {
    // In a real implementation, check with permissions service
    return true;
  }

  /// Redirects to settings if permissions are missing.
  static String? checkPermissions(
    BuildContext context,
    GoRouterState state,
  ) {
    // Implement permission checks
    return null;
  }
}
