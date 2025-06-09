import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logging/logging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'dart:developer' as dev;

import 'firebase_options.dart';
import 'home_page.dart';
import 'core/theme/app_theme.dart';

// Global flag to prevent multiple main() calls
bool _isAppInitialized = false;

void main() async {
  // Prevent multiple initialization
  if (_isAppInitialized) {
    dev.log('App already initialized, skipping duplicate main() call',
        name: 'NativeFlow');
    return;
  }
  _isAppInitialized = true;

  // Ensure Flutter is properly initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Configure error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    dev.log(
      'Flutter error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
      name: 'FlutterError',
    );
  };

  // Configure logging
  _configureLogging();

  // Configure system UI
  await _configureSystemUI();

  // Initialize core services
  await _initializeServices();

  runApp(const NativeFlowApp());
}

void _configureLogging() {
  Logger.root.level = kDebugMode ? Level.FINE : Level.INFO;
  Logger.root.onRecord.listen((record) {
    dev.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      zone: record.zone,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
  dev.log('Logging configured', name: 'NativeFlow');
}

Future<void> _configureSystemUI() async {
  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Configure system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  dev.log('System UI configured', name: 'NativeFlow');
}

Future<void> _initializeServices() async {
  try {
    // Initialize Hive for local storage
    await Hive.initFlutter();
    dev.log('Hive initialized successfully', name: 'NativeFlow');

    // Initialize Firebase (graceful failure)
    await _initializeFirebase();

    // Initialize SoLoud for audio (graceful failure)
    await _initializeSoLoud();
  } catch (e, stackTrace) {
    dev.log(
      'Service initialization error: $e',
      error: e,
      stackTrace: stackTrace,
      name: 'NativeFlow',
    );
  }
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dev.log('Firebase initialized successfully', name: 'NativeFlow');
  } catch (e) {
    dev.log(
      'Firebase initialization skipped: $e',
      name: 'NativeFlow',
    );
    // Continue without Firebase - the app can work without it
  }
}

Future<void> _initializeSoLoud() async {
  try {
    // Only initialize on native platforms during startup
    // Web initialization will happen on user interaction
    if (!kIsWeb) {
      await SoLoud.instance.init();
      dev.log('SoLoud initialized successfully', name: 'NativeFlow');
    } else {
      dev.log('SoLoud initialization deferred for web platform',
          name: 'NativeFlow');
    }
  } catch (e) {
    dev.log(
      'SoLoud initialization error: $e',
      name: 'NativeFlow',
    );
    // Continue without audio - the app can work in text-only mode
  }
}

class NativeFlowApp extends StatelessWidget {
  const NativeFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeFlow',
      debugShowCheckedModeBanner: false,

      // Use our professional theme
      theme: AppTheme.lightTheme,

      // Performance optimizations
      builder: (context, child) {
        return MediaQuery(
          // Prevent font scaling for consistent UI
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.noScaling,
          ),
          child: child!,
        );
      },

      // App configuration
      home: const HomePage(),

      // Error handling
      onGenerateRoute: (settings) {
        // Handle unknown routes gracefully
        return MaterialPageRoute(
          builder: (context) => const HomePage(),
        );
      },

      // Localization support (for future)
      supportedLocales: const [
        Locale('en', 'US'),
        Locale('es', 'ES'),
        Locale('fr', 'FR'),
        Locale('de', 'DE'),
        Locale('ja', 'JP'),
        Locale('ko', 'KR'),
        Locale('zh', 'CN'),
      ],
    );
  }
}
