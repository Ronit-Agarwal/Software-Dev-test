/// Route guards for navigation permission checking.
///
/// This file contains guard functions that can be used to protect
/// routes based on permissions or other conditions.
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:signsync/services/permissions_service.dart';

/// A guard function that checks for camera permission.
Future<String?> cameraPermissionGuard(
  BuildContext context,
  GoRouterState state,
) async {
  final permissionsService = PermissionsService();
  
  if (!await permissionsService.hasCameraPermission) {
    return '/permission?reason=camera&redirect=${Uri.encodeComponent(state.location)}';
  }
  
  return null;
}

/// A guard function that checks for microphone permission.
Future<String?> microphonePermissionGuard(
  BuildContext context,
  GoRouterState state,
) async {
  final permissionsService = PermissionsService();
  
  if (!await permissionsService.hasMicrophonePermission) {
    return '/permission?reason=microphone&redirect=${Uri.encodeComponent(state.location)}';
  }
  
  return null;
}

/// A guard function that requires both camera and microphone permissions.
Future<String?> requiredPermissionsGuard(
  BuildContext context,
  GoRouterState state,
) async {
  final permissionsService = PermissionsService();
  
  if (!permissionsService.allPermissionsGranted) {
    return '/permission?reason=all&redirect=${Uri.encodeComponent(state.location)}';
  }
  
  return null;
}

/// A guard that checks if the app is initialized.
String? appInitializedGuard(
  BuildContext context,
  GoRouterState state,
) {
  // Check if app initialization is complete
  // This could check a provider or service
  return null;
}

/// A guard for authenticated routes.
String? authGuard(
  BuildContext context,
  GoRouterState state,
) {
  // Implement authentication check
  return null;
}

/// A guard for onboarding completion.
String? onboardingGuard(
  BuildContext context,
  GoRouterState state,
) {
  // Check if onboarding has been completed
  return null;
}

/// A guard that redirects to a specific route if a condition is met.
String? redirectIf(
  bool condition,
  String redirectTo,
) {
  return condition ? redirectTo : null;
}

/// A guard that requires a minimum app version.
String? minVersionGuard(
  String currentVersion,
  String minVersion,
) {
  // Implement version comparison
  return null;
}

/// Helper class for creating composite guards.
class GuardChain {
  final List<Future<String?> Function(BuildContext, GoRouterState)> _guards;

  GuardChain(this._guards);

  /// Creates a composite guard from multiple guards.
  Future<String?> call(
    BuildContext context,
    GoRouterState state,
  ) async {
    for (final guard in _guards) {
      final result = await guard(context, state);
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  /// Creates a guard chain from a list of guards.
  static GuardChain from(List<Future<String?> Function(BuildContext, GoRouterState)> guards) {
    return GuardChain(guards);
  }
}

/// Extension to add guards to a GoRoute.
extension GoRouteGuards on GoRoute {
  /// Adds a guard to the route.
  GoRoute withGuard(
    Future<String?> Function(BuildContext, GoRouterState) guard,
  ) {
    return GoRoute(
      path: path,
      name: name,
      pageBuilder: pageBuilder,
      routes: routes.map((r) => r.withGuard(guard)).toList(),
      redirect: (context, state) async {
        final routeRedirect = redirect?.call(context, state);
        if (routeRedirect != null) return routeRedirect;
        return await guard(context, state);
      },
    );
  }

  /// Adds multiple guards to the route.
  GoRoute withGuards(
    List<Future<String?> Function(BuildContext, GoRouterState)> guards,
  ) {
    return GoRoute(
      path: path,
      name: name,
      pageBuilder: pageBuilder,
      routes: routes.map((r) => r.withGuards(guards)).toList(),
      redirect: (context, state) async {
        final routeRedirect = redirect?.call(context, state);
        if (routeRedirect != null) return routeRedirect;
        
        for (final guard in guards) {
          final result = await guard(context, state);
          if (result != null) return result;
        }
        return null;
      },
    );
  }
}
