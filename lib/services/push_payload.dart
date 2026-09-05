import 'package:firebase_messaging/firebase_messaging.dart';

import 'notification_service.dart';

/// Wire names used in FCM `data` payloads. Values must stay strings — FCM
/// rejects non-string data map entries.
class PushType {
  PushType._();

  /// Data-only wake-up: fetch remote catalog and write SQLite. No tray alert.
  static const String syncContent = 'sync_content';

  /// User-visible library alert (new song, broadcast, etc.).
  static const String newContent = 'new_content';

  /// Catalog mutation (artist/album/song edit). Usually silent.
  static const String contentUpdated = 'content_updated';

  /// Admin published a mandatory / min-version app release.
  static const String forceUpdate = 'force_update';
}

class PushEntity {
  PushEntity._();

  static const String artist = 'artist';
  static const String album = 'album';
  static const String song = 'song';
  static const String all = 'all';
}

/// Parsed FCM data payload. Backend and client must stay in lockstep.
///
/// Silent sync (artist name change, lyric edit):
/// ```json
/// {
///   "type": "sync_content",
///   "silent": "true",
///   "entity": "artist",
///   "entity_id": "<id>"
/// }
/// ```
///
/// Visible alert (new song) — also include a `notification` block so the OS
/// can display the tray item when the Dart isolate does not start:
/// ```json
/// {
///   "type": "new_content",
///   "silent": "false",
///   "entity": "song",
///   "entity_id": "<id>",
///   "title": "New Song Available",
///   "body": "\"Title\" by Artist",
///   "k": "new_content",
///   "r": "<songId>"
/// }
/// ```
class PushPayload {
  const PushPayload({
    required this.type,
    required this.silent,
    this.entity = PushEntity.all,
    this.entityId,
    this.title,
    this.body,
    this.kindWireName,
    this.reference,
    this.latestVersion,
    this.minRequiredVersion,
    this.forceUpdate,
    this.apkUrl,
  });

  final String type;
  final bool silent;
  final String entity;
  final String? entityId;
  final String? title;
  final String? body;
  final String? kindWireName;
  final String? reference;
  final String? latestVersion;
  final String? minRequiredVersion;
  final bool? forceUpdate;
  final String? apkUrl;

  bool get isForceUpdate => type == PushType.forceUpdate;

  bool get isSilentSync =>
      !isForceUpdate &&
      (silent || type == PushType.syncContent || type == PushType.contentUpdated);

  NotificationPayload toNotificationPayload() {
    final kind = NotificationKind.fromWireName(kindWireName) ??
        (isForceUpdate
            ? NotificationKind.forceUpdate
            : NotificationKind.newContent);
    return NotificationPayload(
      kind,
      reference: reference ?? entityId,
    );
  }

  static PushPayload fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    final silentRaw = (data['silent'] ?? '').toString().toLowerCase();
    final type = (data['type'] ?? '').toString();
    final hasVisibleNotification = message.notification != null;

    final inferredSilent = type != PushType.forceUpdate &&
        (silentRaw == 'true' ||
            (silentRaw.isEmpty &&
                !hasVisibleNotification &&
                type != PushType.newContent));

    return PushPayload(
      type: type.isEmpty
          ? (inferredSilent ? PushType.syncContent : PushType.newContent)
          : type,
      silent: inferredSilent,
      entity: (data['entity'] ?? PushEntity.all).toString(),
      entityId: _nonEmpty(data['entity_id']),
      title: _nonEmpty(data['title']) ?? message.notification?.title,
      body: _nonEmpty(data['body']) ?? message.notification?.body,
      kindWireName: _nonEmpty(data['k']),
      reference: _nonEmpty(data['r']) ?? _nonEmpty(data['entity_id']),
      latestVersion: _nonEmpty(data['latest_version']),
      minRequiredVersion: _nonEmpty(data['min_required_version']),
      forceUpdate: _asBool(data['force_update']),
      apkUrl: _nonEmpty(data['apk_url']),
    );
  }

  static String? _nonEmpty(dynamic value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  /// String-only map for FCM HTTP v1 `data` and for local tests.
  Map<String, String> toDataMap() {
    return {
      'type': type,
      'silent': silent.toString(),
      'entity': entity,
      if (entityId != null) 'entity_id': entityId!,
      if (title != null) 'title': title!,
      if (body != null) 'body': body!,
      'k': kindWireName ??
          (isForceUpdate
              ? NotificationKind.forceUpdate.wireName
              : NotificationKind.newContent.wireName),
      if (reference != null) 'r': reference!,
      if (latestVersion != null) 'latest_version': latestVersion!,
      if (minRequiredVersion != null)
        'min_required_version': minRequiredVersion!,
      if (forceUpdate != null) 'force_update': forceUpdate.toString(),
      if (apkUrl != null) 'apk_url': apkUrl!,
    };
  }

  static bool? _asBool(dynamic value) {
    if (value == null) return null;
    if (value == true || value == 1) return true;
    if (value == false || value == 0) return false;
    final normalized = value.toString().toLowerCase().trim();
    if (normalized == 'true' || normalized == 't' || normalized == '1') {
      return true;
    }
    if (normalized == 'false' || normalized == 'f' || normalized == '0') {
      return false;
    }
    return null;
  }
}
