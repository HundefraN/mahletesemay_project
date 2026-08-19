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

class Invitation {
  final String id;
  final String code;
  final String email;
  final String firstName;
  final String lastName;
  final String role; // 'moderator' or 'admin'
  final String status; // 'pending', 'claimed', 'revoked'
  final DateTime createdAt;
  final String createdBy;
  final String? claimedBy;
  final DateTime? claimedAt;

  Invitation({
    required this.id,
    required this.code,
    required this.email,
    required this.firstName,
    required this.lastName,
    this.role = 'moderator',
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.claimedBy,
    this.claimedAt,
  });

  String get fullName => '$firstName $lastName'.trim();
  bool get isClaimed => status.toLowerCase() == 'claimed';

  factory Invitation.fromMap(Map<String, dynamic> data, [String? id]) {
    return Invitation(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      code: data['code'] ?? '',
      email: data['email'] ?? '',
      firstName: data['firstName'] ?? data['first_name'] ?? '',
      lastName: data['lastName'] ?? data['last_name'] ?? '',
      role: data['role'] ?? 'moderator',
      status: data['status'] ?? 'pending',
      createdAt: _parseDateTime(data['createdAt'] ?? data['created_at']),
      createdBy: data['createdBy'] ?? data['created_by'] ?? '',
      claimedBy: data['claimedBy'] ?? data['claimed_by'],
      claimedAt: data['claimedAt'] != null || data['claimed_at'] != null
          ? _parseDateTime(data['claimedAt'] ?? data['claimed_at'])
          : null,
    );
  }

  factory Invitation.fromJson(Map<String, dynamic> json) => Invitation.fromMap(json);

  factory Invitation.fromFirestore(dynamic doc) {
    if (doc is Map<String, dynamic>) {
      return Invitation.fromMap(doc);
    }
    final data = doc.data() as Map<String, dynamic>;
    return Invitation.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
      if (id.isNotEmpty) 'id': id,
      'code': code,
      'email': email,
      'firstName': firstName,
      'first_name': firstName,
      'lastName': lastName,
      'last_name': lastName,
      'role': role,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'created_by': createdBy,
      if (claimedBy != null) 'claimed_by': claimedBy,
      if (claimedAt != null) 'claimed_at': claimedAt!.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id.isNotEmpty) 'id': id,
      'code': code,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'created_by': createdBy,
      if (claimedBy != null) 'claimed_by': claimedBy,
      if (claimedAt != null) 'claimed_at': claimedAt!.toIso8601String(),
    };
  }
}