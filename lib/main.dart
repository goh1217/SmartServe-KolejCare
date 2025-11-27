import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:owtest/auth_gate.dart';
import 'firebase_options.dart';

// This is the correct syntax for a main function that uses await.
Future<void> main() async {
  // Ensures that all Flutter bindings are initialized before we use them.
  WidgetsFlutterBinding.ensureInitialized();

  // Waits for Firebase to be initialized before running the app.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthGate(), // AuthGate will handle role-based navigation
    );
  }
}
