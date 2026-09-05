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
  return DateTime.now();
}

List<String> _parseStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).where((item) => item.isNotEmpty).toList();
  }
  if (value is String && value.isNotEmpty) {
    return [value];
  }
  return const [];
}

enum BugReportType { bug, crash, feedback }

enum BugReportStatus { open, inProgress, resolved }

class BugReport {
  final String id;
  final BugReportType type;
  final String title;
  final String description;
  final List<String> screenshotUrls;
  final String? contactEmail;
  final String appVersion;
  final String buildNumber;
  final String platform;
  final String deviceModel;
  final String osVersion;
  final String locale;
  final String? stackTrace;
  final BugReportStatus status;
  final String adminNotes;
  final bool isSeen;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BugReport({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    this.screenshotUrls = const [],
    this.contactEmail,
    this.appVersion = '',
    this.buildNumber = '',
    this.platform = '',
    this.deviceModel = '',
    this.osVersion = '',
    this.locale = '',
    this.stackTrace,
    this.status = BugReportStatus.open,
    this.adminNotes = '',
    this.isSeen = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BugReport.fromMap(Map<String, dynamic> data, [String? id]) {
    final typeStr = (data['type']?.toString() ?? 'bug').toLowerCase();
    final statusStr = (data['status']?.toString() ?? 'open')
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    return BugReport(
      id: (id != null && id.isNotEmpty) ? id : (data['id']?.toString() ?? ''),
      type: BugReportType.values.firstWhere(
        (value) => value.name == typeStr,
        orElse: () => BugReportType.bug,
      ),
      title: data['title']?.toString() ?? '',
      description: data['description']?.toString() ?? '',
      screenshotUrls: _parseStringList(data['screenshot_urls'] ?? data['screenshotUrls']),
      contactEmail: data['contact_email']?.toString() ?? data['contactEmail']?.toString(),
      appVersion: data['app_version']?.toString() ?? data['appVersion']?.toString() ?? '',
      buildNumber: data['build_number']?.toString() ?? data['buildNumber']?.toString() ?? '',
      platform: data['platform']?.toString() ?? '',
      deviceModel: data['device_model']?.toString() ?? data['deviceModel']?.toString() ?? '',
      osVersion: data['os_version']?.toString() ?? data['osVersion']?.toString() ?? '',
      locale: data['locale']?.toString() ?? '',
      stackTrace: data['stack_trace']?.toString() ?? data['stackTrace']?.toString(),
      status: BugReportStatus.values.firstWhere(
        (value) => value.dbValue == statusStr || value.name == statusStr,
        orElse: () => BugReportStatus.open,
      ),
      adminNotes: data['admin_notes']?.toString() ?? data['adminNotes']?.toString() ?? '',
      isSeen: data['is_seen'] == true || data['isSeen'] == true,
      createdAt: _parseDateTime(data['created_at'] ?? data['createdAt']),
      updatedAt: _parseDateTime(data['updated_at'] ?? data['updatedAt']),
    );
  }

  Map<String, dynamic> toSupabase() {
    return {
      if (id.isNotEmpty) 'id': id,
      'type': type.name,
      'title': title,
      'description': description,
      'screenshot_urls': screenshotUrls,
      'contact_email': contactEmail,
      'app_version': appVersion,
      'build_number': buildNumber,
      'platform': platform,
      'device_model': deviceModel,
      'os_version': osVersion,
      'locale': locale,
      'stack_trace': stackTrace,
      'status': status.dbValue,
      'admin_notes': adminNotes,
      'is_seen': isSeen,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    };
  }

  String get versionLabel {
    if (appVersion.isEmpty) return '';
    if (buildNumber.isEmpty) return appVersion;
    return '$appVersion ($buildNumber)';
  }

  String get deviceLabel {
    final parts = [deviceModel, osVersion].where((part) => part.trim().isNotEmpty);
    return parts.join(' · ');
  }
}

extension BugReportStatusDb on BugReportStatus {
  String get dbValue {
    switch (this) {
      case BugReportStatus.inProgress:
        return 'in_progress';
      case BugReportStatus.open:
        return 'open';
      case BugReportStatus.resolved:
        return 'resolved';
    }
  }
}
