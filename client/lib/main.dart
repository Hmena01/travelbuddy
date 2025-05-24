import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'dart:developer' as dev;
import 'package:logging/logging.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'home_page.dart';

void main() async {
  // Make main async
  // Optional: Configure logging for flutter_soloud
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

  // Ensure Flutter bindings are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase (optional - will continue if Firebase is not configured)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    dev.log('Firebase initialized successfully');
  } catch (e) {
    dev.log('Firebase initialization skipped: $e');
    // Continue without Firebase - the app can work without it
  }

  // Initialize SoLoud instance
  try {
    await SoLoud.instance.init();
    dev.log('SoLoud initialized successfully');
  } catch (e) {
    dev.log('Error initializing SoLoud: $e');
    // Handle initialization error if needed
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NativeFlow Translation',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      home: const HomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
