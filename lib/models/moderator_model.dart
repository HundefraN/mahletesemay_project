// lib/models/moderator_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Moderator {
  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final String username;
  final String role; // 'admin' or 'moderator'
  final String status; // 'active', 'inactive', 'review', 'blocked'
  final List<Map<String, dynamic>> approvedDevices;
  final Map<String, dynamic>? pendingDevice;
  final Timestamp? lastLogin;
  final Timestamp createdAt;

  Moderator({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.role,
    required this.status,
    required this.approvedDevices,
    this.pendingDevice,
    this.lastLogin,
    required this.createdAt,
  });

  String get fullName => '$firstName $lastName';

  factory Moderator.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Moderator(
      id: doc.id,
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      username: data['username'] ?? '',
      role: data['role'] ?? 'moderator',
      status: data['status'] ?? 'inactive',
      approvedDevices: List<Map<String, dynamic>>.from(data['approvedDevices'] ?? []),
      pendingDevice: data['pendingDevice'],
      lastLogin: data['lastLogin'],
      createdAt: data['createdAt'] ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'username': username,
      'role': role,
      'status': status,
      'approvedDevices': approvedDevices,
      'pendingDevice': pendingDevice,
      'lastLogin': lastLogin,
      'createdAt': createdAt,
    };
  }
}