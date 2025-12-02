import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminPortalApp extends StatefulWidget {
  const AdminPortalApp({super.key});

  @override
  State<AdminPortalApp> createState() => _AdminPortalAppState();
}

class _AdminPortalAppState extends State<AdminPortalApp> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Portal - Staff List'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('staff').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No staff found.'));
          }

          final staffDocs = snapshot.data!.docs;

          return ListView.builder(
            itemCount: staffDocs.length,
            itemBuilder: (context, index) {
              final staff = staffDocs[index].data() as Map<String, dynamic>;
              final staffName = staff['staffName'] ?? 'N/A';
              final staffNo = staff['staffNo'] ?? 'N/A';
              final staffRank = staff['staffRank'] ?? 'N/A';
              final workCollege = staff['workCollege'] ?? 'N/A';

              return Card(
                margin: const EdgeInsets.all(8.0),
                child: ListTile(
                  title: Text(staffName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Staff No: $staffNo'),
                      Text('Rank: $staffRank'),
                      Text('College: $workCollege'),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}