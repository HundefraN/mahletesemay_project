/// Represents the remote application release and update configuration
/// stored in the Supabase `app_config` table.
class AppConfigModel {
  final String id;
  final String? latestVersion;
  final String? minRequiredVersion;
  final String? apkUrl;
  final String? releaseNotes;
  final bool forceUpdate;
  final DateTime? updatedAt;

  const AppConfigModel({
    required this.id,
    this.latestVersion,
    this.minRequiredVersion,
    this.apkUrl,
    this.releaseNotes,
    this.forceUpdate = false,
    this.updatedAt,
  });

  factory AppConfigModel.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    if (json['updated_at'] != null) {
      parsedDate = DateTime.tryParse(json['updated_at'].toString());
    }

    return AppConfigModel(
      id: json['id']?.toString() ?? 'default',
      latestVersion: json['latest_version']?.toString().trim(),
      minRequiredVersion: json['min_required_version']?.toString().trim(),
      apkUrl: json['apk_url']?.toString().trim(),
      releaseNotes: json['release_notes']?.toString(),
      forceUpdate: json['force_update'] == true,
      updatedAt: parsedDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'latest_version': latestVersion?.trim().isEmpty == true ? null : latestVersion?.trim(),
      'min_required_version': minRequiredVersion?.trim().isEmpty == true ? null : minRequiredVersion?.trim(),
      'apk_url': apkUrl?.trim().isEmpty == true ? null : apkUrl?.trim(),
      'release_notes': releaseNotes?.trim().isEmpty == true ? null : releaseNotes?.trim(),
      'force_update': forceUpdate,
      'updated_at': updatedAt?.toUtc().toIso8601String() ?? DateTime.now().toUtc().toIso8601String(),
    };
  }

  AppConfigModel copyWith({
    String? id,
    String? latestVersion,
    String? minRequiredVersion,
    String? apkUrl,
    String? releaseNotes,
    bool? forceUpdate,
    DateTime? updatedAt,
  }) {
    return AppConfigModel(
      id: id ?? this.id,
      latestVersion: latestVersion ?? this.latestVersion,
      minRequiredVersion: minRequiredVersion ?? this.minRequiredVersion,
      apkUrl: apkUrl ?? this.apkUrl,
      releaseNotes: releaseNotes ?? this.releaseNotes,
      forceUpdate: forceUpdate ?? this.forceUpdate,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'AppConfigModel(id: $id, latest: $latestVersion, min: $minRequiredVersion, force: $forceUpdate, url: $apkUrl)';
  }
}
