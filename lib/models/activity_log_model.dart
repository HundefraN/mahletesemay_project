import 'package:cloud_firestore/cloud_firestore.dart';

class ActivityLog {
  final String id;
  final String moderatorId;
  final String moderatorName;
  final String action;
  final String details;
  final Timestamp timestamp;
  final bool isSeen;

  ActivityLog({
    required this.id,
    required this.moderatorId,
    required this.moderatorName,
    required this.action,
    required this.details,
    required this.timestamp,
    this.isSeen = false,
  });

  factory ActivityLog.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return ActivityLog(
      id: doc.id,
      moderatorId: data['moderatorId'] ?? '',
      moderatorName: data['moderatorName'] ?? '',
      action: data['action'] ?? '',
      details: data['details'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isSeen: data['isSeen'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'moderatorId': moderatorId,
      'moderatorName': moderatorName,
      'action': action,
      'details': details,
      'timestamp': timestamp,
      'isSeen': isSeen,
    };
  }
}