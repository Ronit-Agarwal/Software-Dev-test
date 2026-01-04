import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:signsync/core/error/global_error_handler.dart';
import 'package:signsync/core/logging/logger_service.dart';
import 'package:signsync/core/theme/app_theme.dart';
import 'package:signsync/config/providers.dart';
import 'package:signsync/config/app_config.dart';
import 'package:signsync/screens/chat/chat_screen.dart';
import 'package:signsync/screens/dashboard/dashboard_screen.dart';
import 'package:signsync/screens/detection/detection_screen.dart';
import 'package:signsync/screens/settings/settings_screen.dart';
import 'package:signsync/screens/sound/sound_screen.dart';
import 'package:signsync/screens/translation/translation_screen.dart';

/// Main entry point for the SignSync application.
///
/// This initializes Firebase, sets up error handling, logging,
/// theming, and routing for the entire application.
Future<void> main() async {
  // Ensure widget binding is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging system
  await LoggerService.initialize();

  // Initialize Firebase (no-op if not configured)
  await _initializeFirebase();

  // Set up global error handling
  GlobalErrorHandler.setupErrorHandlers();

  // Run the app with ProviderScope for Riverpod
  runApp(
    ProviderScope(
      overrides: [],
      child: const SignSyncApp(),
    ),
  );
}

/// Initializes Firebase for the application.
///
/// This is a no-op if Firebase is not configured, allowing
/// the app to run in a development/demo mode.
Future<void> _initializeFirebase() async {
  try {
    // Firebase initialization - uncomment when Firebase is configured
    // await Firebase.initializeApp(
    //   options: DefaultFirebaseOptions.currentPlatform,
    // );
    LoggerService.info('Firebase initialized (placeholder)');
  } catch (e, stack) {
    LoggerService.error('Firebase initialization failed', error: e, stack: stack);
    // Continue without Firebase - app will function in limited mode
  }
}

/// The root widget of the SignSync application.
///
/// This widget configures the app's theme, localization, and routing.
class SignSyncApp extends ConsumerWidget {
  const SignSyncApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Get the app configuration
    final config = ref.watch(appConfigProvider);

    return MaterialApp(
      // App configuration
      title: AppConfig.appName,
      debugShowCheckedModeBanner: AppConfig.isDebugMode,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: config.themeMode,

      // Localization
      locale: config.locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppConfig.supportedLocales,

      initialRoute: '/dashboard',
      routes: {
        '/': (_) => const DashboardScreen(),
        '/dashboard': (_) => const DashboardScreen(),
        '/translation': (_) => const TranslationScreen(),
        '/detection': (_) => const DetectionScreen(),
        '/sound': (_) => const SoundScreen(),
        '/chat': (_) => const ChatScreen(),
        '/settings': (_) => const SettingsScreen(),
      },

      // Accessibility
      builder: (context, child) {
        return _AppBuilder(
          child: child,
          config: config,
        );
      },
    );
  }
}

/// A builder widget that provides app-level context and configuration.
class _AppBuilder extends ConsumerWidget {
  final Widget? child;
  final AppConfig config;

  const _AppBuilder({
    required this.child,
    required this.config,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Set up text scaling based on user preference
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaleFactor: config.textScaleFactor.clamp(0.8, 2.0),
      ),
      child: child!,
    );
  }
}
