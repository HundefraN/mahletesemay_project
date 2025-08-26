import 'package:cloud_firestore/cloud_firestore.dart';

class Moderator {
  final String uid;
  final String email;
  final String role;
  final String status;
  final String firstName;
  final String lastName;

  Moderator({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
    required this.firstName,
    required this.lastName,
  });

  String get fullName => '$firstName $lastName'.trim();
  String get username => email.split('@').first;

  factory Moderator.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Moderator(
      uid: doc.id,
      email: data['email'] ?? '',
      role: data['role'] ?? 'moderator',
      status: data['status'] ?? 'blocked',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
    );
  }
}