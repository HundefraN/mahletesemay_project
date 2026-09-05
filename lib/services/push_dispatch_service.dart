import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'push_payload.dart';

/// Outcome of invoking the `send-push` Edge Function.
class PushSendResult {
  const PushSendResult({
    required this.ok,
    this.sent = 0,
    this.deduped = false,
    this.error,
  });

  final bool ok;
  final int sent;
  final bool deduped;
  final String? error;

  String get adminSummary {
    if (deduped) {
      return 'Update reminder was already sent a moment ago.';
    }
    if (ok) {
      return sent == 1
          ? 'Update reminder sent to 1 device.'
          : 'Update reminder sent to $sent devices.';
    }
    return 'Update reminder failed${error == null ? '.' : ': $error'}';
  }
}

/// Invokes the `send-push` Edge Function after a catalog mutation.
/// Failures are swallowed so admin saves never block on push delivery.
class PushDispatchService {
  PushDispatchService._();

  static Future<void> notifyContentChange({
    required String entity,
    String? entityId,
    required bool silent,
    String? title,
    String? body,
    String? reference,
  }) async {
    if (kIsWeb) {
      // Web admins still trigger the function so mobile devices wake up.
    }

    final type = silent
        ? (entity == PushEntity.all ? PushType.syncContent : PushType.contentUpdated)
        : PushType.newContent;

    try {
      await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'type': type,
          'silent': silent,
          'entity': entity,
          if (entityId != null) 'entityId': entityId,
          if (title != null) 'title': title,
          if (body != null) 'body': body,
          if (reference != null) 'reference': reference,
        },
      );
      debugPrint(
        'PushDispatch: sent $type silent=$silent entity=$entity id=$entityId',
      );
    } catch (e) {
      debugPrint('PushDispatch: send-push invoke failed ($e)');
    }
  }

  /// Visible reminder to every registered device after an admin publishes.
  static Future<PushSendResult> notifyForceUpdate({
    required bool forceUpdate,
    String? latestVersion,
    String? minRequiredVersion,
    String? apkUrl,
    String? releaseNotes,
  }) async {
    final versionLabel =
        (latestVersion != null && latestVersion.trim().isNotEmpty)
            ? latestVersion.trim()
            : null;
    final notesSnippet = _firstReleaseNoteLine(releaseNotes);
    final title = forceUpdate ? 'Update Required' : 'New Version Available';
    final body = forceUpdate
        ? 'Mahlete Semay${versionLabel == null ? '' : ' $versionLabel'} is required. Open the app to install it now.'
        : 'Mahlete Semay${versionLabel == null ? '' : ' $versionLabel'} is ready. Open the app to update.'
            '${notesSnippet == null ? '' : ' $notesSnippet'}';

    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-push',
        body: {
          'type': PushType.forceUpdate,
          'silent': false,
          'entity': 'app',
          'entityId': '${versionLabel ?? 'default'}:$forceUpdate',
          'title': title,
          'body': body,
          'reference': versionLabel,
          'latestVersion': latestVersion,
          'minRequiredVersion': minRequiredVersion,
          'forceUpdate': forceUpdate,
          'apkUrl': apkUrl,
        },
      );
      final result = _parseInvokeResult(response.data);
      debugPrint(
        'PushDispatch: sent force_update force=$forceUpdate '
        'latest=$latestVersion sent=${result.sent} ok=${result.ok}',
      );
      return result;
    } catch (e) {
      debugPrint('PushDispatch: force-update send-push invoke failed ($e)');
      return PushSendResult(ok: false, error: e.toString());
    }
  }

  static String? _firstReleaseNoteLine(String? notes) {
    if (notes == null) return null;
    for (final raw in notes.split(RegExp(r'[\r\n]+'))) {
      final line = raw.replaceFirst(RegExp(r'^[\s•\-]+'), '').trim();
      if (line.isNotEmpty) {
        return line.length > 80 ? '${line.substring(0, 77)}...' : line;
      }
    }
    return null;
  }

  static PushSendResult _parseInvokeResult(dynamic data) {
    if (data is! Map) {
      return const PushSendResult(ok: true);
    }
    final map = Map<String, dynamic>.from(data);
    return PushSendResult(
      ok: map['ok'] != false,
      sent: (map['sent'] as num?)?.toInt() ?? 0,
      deduped: map['deduped'] == true,
      error: map['error']?.toString(),
    );
  }
}
