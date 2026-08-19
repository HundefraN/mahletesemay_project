extension DateTimeCompatExtension on DateTime {
  DateTime toDate() => this;
}

DateTime _parseDateTime(dynamic value) {
  if (value == null) return DateTime.now();
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return DateTime.now();
    }
  }
  try {
    return (value as dynamic).toDate();
  } catch (_) {
    return DateTime.now();
  }
}

class ActivityLog {
  final String id;
  final String moderatorId;
  final String moderatorName;
  final String action;
  final String details;
  final DateTime timestamp;
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

  factory ActivityLog.fromMap(Map<String, dynamic> data, [String? id]) {
    return ActivityLog(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      moderatorId: data['moderatorId'] ?? data['moderator_id'] ?? '',
      moderatorName: data['moderatorName'] ?? data['moderator_name'] ?? '',
      action: data['action'] ?? '',
      details: data['details'] ?? '',
      timestamp: _parseDateTime(data['timestamp'] ?? data['created_at']),
      isSeen: data['isSeen'] ?? data['is_seen'] ?? false,
    );
  }

  factory ActivityLog.fromJson(Map<String, dynamic> json) => ActivityLog.fromMap(json);

  factory ActivityLog.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return ActivityLog.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return ActivityLog.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'moderatorId': moderatorId,
      'moderator_id': moderatorId,
      'moderatorName': moderatorName,
      'moderator_name': moderatorName,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'isSeen': isSeen,
      'is_seen': isSeen,
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id.isNotEmpty) 'id': id,
      'moderator_id': moderatorId,
      'moderator_name': moderatorName,
      'action': action,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
      'is_seen': isSeen,
    };
  }
}