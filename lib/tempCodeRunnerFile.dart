import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:owtest/auth_gate.dart';
import 'firebase_options.dart';
import 'package:flutter_stripe/flutter_stripe.dart'; 
import 'package:flutter/foundation.dart';
import 'dart:ui';

Future<void> main() async {
  // Ensures that all Flutter bindings are initialized before we use them.
  WidgetsFlutterBinding.ensureInitialized();

  // Surface uncaught Flutter errors to the console
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint(details.stack?.toString() ?? '');
  };

  // Surface platform errors (async zones) to the console
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Unhandled error: $error');
    debugPrint(stack.toString());
    return true;
  };

  // Load environment variables from .env
  try {
    await dotenv.load(fileName: ".env");
    debugPrint("✅ Environment variables loaded successfully");
    debugPrint("Publishable key present: ${dotenv.env['STRIPE_PUBLISHABLE_KEY']?.isNotEmpty ?? false}");
    debugPrint("Secret key present: ${dotenv.env['STRIPE_SECRET_KEY']?.isNotEmpty ?? false}");
  } catch (e) {
    debugPrint("❌ Error loading .env file: $e");
    debugPrint("Make sure .env file exists in the root directory");
  }

  // Initialize Stripe
  try {
    final publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY'];
    
    if (publishableKey == null || publishableKey.isEmpty) {
      debugPrint("❌ STRIPE_PUBLISHABLE_KEY not found in .env");
    } else {
      debugPrint("✅ Setting Stripe publishable key");
      Stripe.publishableKey = publishableKey;
      
      // Only call applySettings on mobile platforms
      if (!kIsWeb) {
        await Stripe.instance.applySettings();
        debugPrint("✅ Stripe settings applied (mobile)");
      } else {
        debugPrint("✅ Stripe initialized for web");
      }
    }
  } catch (e) {
    debugPrint("❌ Error initializing Stripe: $e");
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("✅ Firebase initialized");
  } catch (e) {
    debugPrint("❌ Error initializing Firebase: $e");
  }

  debugPrint("🚀 Launching app");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'All-In-One Portal',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        scaffoldBackgroundColor: Colors.grey[50],
        useMaterial3: true,
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // AuthGate will handle role-based navigation
    );
  }
}