import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:owtest/sign_in_screen.dart';
import 'package:owtest/staff_portal.dart';
import 'package:owtest/student/complaint_detail_screen.dart'; // Corrected Import
import 'package:owtest/technician/dashboard.dart'; // Corrected Import

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // User is not signed in
        if (!snapshot.hasData) {
          return const SignInScreen();
        }

        // User is signed in, check their role
        return FutureBuilder<String>(
          future: _getUserRole(snapshot.data!.email!),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (roleSnapshot.hasError) {
              return Scaffold(
                body: Center(
                  child: Text('Error fetching user role: ${roleSnapshot.error}'),
                ),
              );
            }

            final role = roleSnapshot.data;

            switch (role) {
              case 'staff':
                return StaffPortalApp();
              case 'student':
                // Navigate to the new student screen
                return const ComplaintDetailScreen(); 
              case 'technician':
                // Navigate to the new technician screen
                return const TechnicianDashboard(); 
              default:
                return const Scaffold(
                  body: Center(
                    child: Text('Your role is not configured or you are not authorized.'),
                  ),
                );
            }
          },
        );
      },
    );
  }

  /// Searches for the user's email in the staff, student, and technician collections.
  Future<String> _getUserRole(String email) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Check staff
    var querySnapshot = await firestore.collection('staff').where('email', isEqualTo: email).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      return 'staff';
    }

    // 2. Check student
    querySnapshot = await firestore.collection('student').where('email', isEqualTo: email).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      return 'student';
    }

    // 3. Check technician
    querySnapshot = await firestore.collection('technician').where('email', isEqualTo: email).limit(1).get();
    if (querySnapshot.docs.isNotEmpty) {
      return 'technician';
    }

    return 'unknown';
  }
}
