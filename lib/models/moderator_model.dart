import 'dart:convert';

extension DateTimeCompatExtension on DateTime {
  DateTime toDate() => this;
}

DateTime? _parseNullableDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  if (value is String) {
    try {
      return DateTime.parse(value);
    } catch (_) {
      return null;
    }
  }
  try {
    return (value as dynamic).toDate();
  } catch (_) {
    return null;
  }
}

List<Map<String, dynamic>> _parseApprovedDevices(dynamic raw) {
  if (raw == null) return [];
  dynamic decoded = raw;
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return [];
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return [];
    }
  }

  if (decoded is List) {
    final List<Map<String, dynamic>> list = [];
    for (final item in decoded) {
      if (item is Map) {
        list.add(Map<String, dynamic>.from(item));
      } else if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty) {
          try {
            final parsed = jsonDecode(trimmed);
            if (parsed is Map) {
              list.add(Map<String, dynamic>.from(parsed));
            }
          } catch (_) {}
        }
      }
    }
    return list;
  } else if (decoded is Map) {
    return [Map<String, dynamic>.from(decoded)];
  }
  return [];
}

Map<String, dynamic>? _parsePendingDevice(dynamic raw) {
  if (raw == null) return null;
  dynamic decoded = raw;
  if (raw is String) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    try {
      decoded = jsonDecode(trimmed);
    } catch (_) {
      return null;
    }
  }
  if (decoded is Map) {
    return Map<String, dynamic>.from(decoded);
  }
  return null;
}

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
  final DateTime? lastLogin;
  final DateTime createdAt;

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

  String get fullName => '$firstName $lastName'.trim();

  bool get isActive => status == 'active';

  String? get currentDeviceModel => approvedDevices.isNotEmpty
      ? (approvedDevices.last['model']?.toString() ?? approvedDevices.last['name']?.toString() ?? 'Authorized Device')
      : null;

  factory Moderator.fromMap(Map<dynamic, dynamic> data, [String? id]) {
    final rawApproved = data['approvedDevices'] ?? data['approved_devices'];
    final approved = _parseApprovedDevices(rawApproved);

    final rawPending = data['pendingDevice'] ?? data['pending_device'];
    final pending = _parsePendingDevice(rawPending);

    final rawStatus = data['status']?.toString();
    final rawIsActive = data['is_active'] ?? data['isActive'];
    String resolvedStatus;
    if (rawStatus != null && rawStatus.isNotEmpty) {
      resolvedStatus = rawStatus;
    } else if (rawIsActive == true) {
      resolvedStatus = 'active';
    } else if (rawIsActive == false) {
      resolvedStatus = 'inactive';
    } else {
      resolvedStatus = 'inactive';
    }

    return Moderator(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      email: data['email']?.toString() ?? '',
      firstName: data['firstName']?.toString() ?? data['first_name']?.toString() ?? '',
      lastName: data['lastName']?.toString() ?? data['last_name']?.toString() ?? '',
      username: data['username']?.toString() ?? '',
      role: data['role']?.toString() ?? 'moderator',
      status: resolvedStatus,
      approvedDevices: approved,
      pendingDevice: pending,
      lastLogin: _parseNullableDateTime(data['lastLogin'] ?? data['last_login']),
      createdAt: _parseNullableDateTime(data['createdAt'] ?? data['created_at']) ?? DateTime.now(),
    );
  }

  factory Moderator.fromJson(dynamic json) {
    if (json is String) {
      try {
        final decoded = jsonDecode(json);
        if (decoded is Map) {
          return Moderator.fromMap(decoded);
        }
      } catch (_) {}
    } else if (json is Map) {
      return Moderator.fromMap(json);
    }
    return Moderator(
      id: '',
      email: '',
      firstName: '',
      lastName: '',
      username: '',
      role: 'moderator',
      status: 'inactive',
      approvedDevices: [],
      createdAt: DateTime.now(),
    );
  }

  factory Moderator.fromFirestore(dynamic doc) {
    if (doc == null) {
      return Moderator.fromJson(null);
    }
    if (doc is Map) {
      return Moderator.fromMap(doc);
    }
    try {
      final data = doc.data();
      if (data is Map) {
        return Moderator.fromMap(data, doc.id?.toString());
      }
    } catch (_) {}
    return Moderator.fromJson(null);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'firstName': firstName,
      'first_name': firstName,
      'lastName': lastName,
      'last_name': lastName,
      'username': username,
      'role': role,
      'status': status,
      'approvedDevices': approvedDevices,
      'approved_devices': approvedDevices,
      'pendingDevice': pendingDevice,
      'pending_device': pendingDevice,
      'lastLogin': lastLogin?.toIso8601String(),
      'last_login': lastLogin?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  Map<String, dynamic> toSupabase() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'username': username,
      'role': role,
      'status': status,
      'approved_devices': approvedDevices,
      'pending_device': pendingDevice,
      'last_login': lastLogin?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}