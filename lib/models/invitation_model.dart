import 'package:cloud_firestore/cloud_firestore.dart';

class Invitation {
  final String id;
  final String code;
  final String email;
  final String firstName;
  final String lastName;
  final String status; // 'pending', 'claimed'
  final Timestamp createdAt;
  final String createdBy;

  Invitation({
    required this.id,
    required this.code,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.status,
    required this.createdAt,
    required this.createdBy,
  });

  factory Invitation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Invitation(
      id: doc.id,
      code: data['code'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] ?? Timestamp.now(),
      createdBy: data['createdBy'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'email': email,
      'firstName': firstName,
      'lastName': lastName,
      'status': status,
      'createdAt': createdAt,
      'createdBy': createdBy,
    };
  }
}