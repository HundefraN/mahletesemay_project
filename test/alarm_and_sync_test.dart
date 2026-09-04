import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/services/alarm_service.dart';
import 'package:mahlete_semay_project/services/notification_service.dart';
import 'package:mahlete_semay_project/utils/permission_helper.dart';

void main() {
  group('Alarm & Background Sync Tests', () {
    test('ServiceAlarmMetadata serializes and deserializes correctly', () {
      final now = DateTime.now();
      final meta = ServiceAlarmMetadata(
        id: 12345,
        reminderId: 'rem_abc123',
        title: 'Sunday Morning Worship',
        body: 'Service starts at 9:00 AM',
        serviceDateTime: now,
        notes: 'Lead chorus rehearsal 30 minutes before.',
      );

      final jsonStr = meta.toJson();
      expect(jsonStr, isNotEmpty);

      final decoded = ServiceAlarmMetadata.fromJson(jsonStr);
      expect(decoded.id, equals(12345));
      expect(decoded.reminderId, equals('rem_abc123'));
      expect(decoded.title, equals('Sunday Morning Worship'));
      expect(decoded.body, equals('Service starts at 9:00 AM'));
      expect(decoded.notes, equals('Lead chorus rehearsal 30 minutes before.'));
      expect(
        decoded.serviceDateTime.millisecondsSinceEpoch ~/ 1000,
        equals(now.millisecondsSinceEpoch ~/ 1000),
      );
    });

    test('NotificationPayload encodes and decodes serviceAlarmOverlay kind', () {
      const payload = NotificationPayload(
        NotificationKind.serviceAlarmOverlay,
        reference: 'reminder_999',
      );

      final encoded = payload.encode();
      expect(encoded, contains('service_alarm_overlay'));
      expect(encoded, contains('reminder_999'));

      final decoded = NotificationPayload.decode(encoded);
      expect(decoded, isNotNull);
      expect(decoded!.kind, equals(NotificationKind.serviceAlarmOverlay));
      expect(decoded.reference, equals('reminder_999'));
    });

    test('AlarmPermissionStatus reports isReliable based on exact alarm and battery killer exclusion', () {
      const reliable = AlarmPermissionStatus(
        notificationsGranted: true,
        exactAlarmGranted: true,
        batteryOptimizationsIgnored: true,
        systemAlertWindowGranted: true,
      );
      expect(reliable.isReliable, isTrue);

      const batteryRestricted = AlarmPermissionStatus(
        notificationsGranted: true,
        exactAlarmGranted: true,
        batteryOptimizationsIgnored: false,
        systemAlertWindowGranted: true,
      );
      expect(batteryRestricted.isReliable, isFalse);

      const exactDenied = AlarmPermissionStatus(
        notificationsGranted: true,
        exactAlarmGranted: false,
        batteryOptimizationsIgnored: true,
        systemAlertWindowGranted: true,
      );
      expect(exactDenied.isReliable, isFalse);
    });
  });
}
