// lib/models/lead.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Lead {
  final String id;
  final String leadName;
  final String mobile;
  final String projectName;
  final String status;
  final Timestamp createdAt;

  Lead({
    required this.id,
    required this.leadName,
    required this.mobile,
    required this.projectName,
    required this.status,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
    'leadName': leadName,
    'mobile': mobile,
    'projectName': projectName,
    'status': status,
    'createdAt': createdAt,
  };

  factory Lead.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return Lead(
      id: doc.id,
      leadName: (data['leadName'] ?? '') as String,
      mobile: (data['mobile'] ?? '') as String,
      projectName: (data['projectName'] ?? '') as String,
      status: (data['status'] ?? 'New') as String,
      createdAt: (data['createdAt'] ?? Timestamp.now()) as Timestamp,
    );
  }
}
