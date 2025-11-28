import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_ui_auth/firebase_ui_auth.dart';
import 'package:flutter/material.dart';
import 'package:owtest/insert_record.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => InsertRecord()),
              );
            },
            icon: const Icon(Icons.add),
          ),
          SignOutButton(),
        ],
      ),
      body: Center(
        child: Text(
          user?.displayName != null
              ? 'Welcome, ${user!.displayName}!'
              : 'Welcome!',
        ),
      ),
    );
  }
}
