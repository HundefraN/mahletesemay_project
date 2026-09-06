import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/services/force_update_service.dart';

void main() {
  group('ForceUpdateService.isUpdateRequired', () {
    test('never locks when the installed version cannot be parsed', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '',
          minRequiredVersion: '1.0.4',
          latestVersion: '1.0.4',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('locks when installed is below min required', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.3+5',
          installedBuild: '5',
          minRequiredVersion: '1.0.4+6',
          latestVersion: '1.0.4+6',
          forceUpdate: false,
        ),
        isTrue,
      );
    });

    test('does not lock when installed meets min and force is off', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.4+6',
          installedBuild: '6',
          minRequiredVersion: '1.0.4',
          latestVersion: '1.0.5',
          forceUpdate: false,
        ),
        isFalse,
      );
    });

    test('force update locks devices behind latest', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.3+5',
          installedBuild: '5',
          minRequiredVersion: '1.0.0',
          latestVersion: '1.0.4+6',
          forceUpdate: true,
        ),
        isTrue,
      );
    });

    test('does not lock after installing the published latest', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.4+6',
          installedBuild: '6',
          minRequiredVersion: '1.0.4+6',
          latestVersion: '1.0.4+6',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when latest omits +build but marketing version matches', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.4+6',
          installedBuild: '6',
          minRequiredVersion: '1.0.3',
          latestVersion: '1.0.4',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when device omits +build but marketing version matches latest', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.4',
          minRequiredVersion: '1.0.3',
          latestVersion: '1.0.4+6',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when already on latest even if min required has a higher build', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.5+7',
          installedBuild: '7',
          minRequiredVersion: '1.0.5+8',
          latestVersion: '1.0.5',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when min required includes +build but installed is that release', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.5',
          installedBuild: '7',
          minRequiredVersion: '1.0.5+7',
          latestVersion: '1.0.5+7',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when PackageInfo omits build after installing latest', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.5',
          minRequiredVersion: '1.0.5+7',
          latestVersion: '1.0.5+7',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('does not lock when version and buildNumber are passed separately', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.5',
          installedBuild: '7',
          minRequiredVersion: '1.0.5+7',
          latestVersion: '1.0.5+7',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('still locks a lower build when both sides have an explicit build', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: '1.0.4+5',
          installedBuild: '5',
          minRequiredVersion: '1.0.0',
          latestVersion: '1.0.4+6',
          forceUpdate: true,
        ),
        isTrue,
      );
    });

    test('does not lock a 1.0.6 binary whose PackageManager still says 1.0.3+5', () {
      final running = ForceUpdateService.resolveRunningVersion(
        compileTimeVersion: '1.0.6',
        compileTimeBuild: '8',
        platformVersion: '1.0.3',
        platformBuild: '5',
      );
      expect(running, '1.0.6+8');
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: running,
          minRequiredVersion: '1.0.6',
          latestVersion: '1.0.6',
          forceUpdate: true,
        ),
        isFalse,
      );
    });

    test('treats v-prefixed versions as equal after update', () {
      expect(
        ForceUpdateService.isUpdateRequired(
          installedVersion: 'v1.0.4+6',
          installedBuild: '6',
          minRequiredVersion: 'v1.0.4',
          latestVersion: 'V1.0.4+6',
          forceUpdate: true,
        ),
        isFalse,
      );
    });
  });

  group('ForceUpdateService.isInstalledAtLeast', () {
    test('is true when installed matches the downloaded APK version', () {
      expect(
        ForceUpdateService.isInstalledAtLeast(
          installedVersion: '1.0.4+6',
          installedBuild: '6',
          targetVersion: '1.0.4+6',
        ),
        isTrue,
      );
    });

    test('is false when installed is still behind the downloaded APK', () {
      expect(
        ForceUpdateService.isInstalledAtLeast(
          installedVersion: '1.0.3+5',
          installedBuild: '5',
          targetVersion: '1.0.4+6',
        ),
        isFalse,
      );
    });

    test('treats split-per-abi versionCode 1005 as pubspec build 5', () {
      expect(ForceUpdateService.parseBuildNumber('1.0.3+1005'), 5);
      expect(ForceUpdateService.parseBuildNumber('1.0.6', fallback: '2008'), 8);
      expect(
        ForceUpdateService.isInstalledAtLeast(
          installedVersion: '1.0.6+2008',
          installedBuild: '2008',
          targetVersion: '1.0.6+8',
        ),
        isTrue,
      );
    });

    test('resolveRunningVersion prefers the newer of compile-time and platform', () {
      expect(
        ForceUpdateService.resolveRunningVersion(
          compileTimeVersion: '1.0.6',
          compileTimeBuild: '8',
          platformVersion: '1.0.3',
          platformBuild: '5',
        ),
        '1.0.6+8',
      );
      expect(
        ForceUpdateService.resolveRunningVersion(
          compileTimeVersion: '1.0.6',
          compileTimeBuild: '8',
          platformVersion: '1.0.6',
          platformBuild: '2008',
        ),
        '1.0.6+8',
      );
    });

    test('formatDisplay never stacks a second v prefix', () {
      expect(ForceUpdateService.formatDisplay('1.0.6+8'), 'v1.0.6+8');
      expect(ForceUpdateService.formatDisplay('v1.0.6'), 'v1.0.6');
    });

    test('is true when marketing versions match and one side omits +build', () {
      expect(
        ForceUpdateService.isInstalledAtLeast(
          installedVersion: '1.0.5+7',
          installedBuild: '7',
          targetVersion: '1.0.5',
        ),
        isTrue,
      );
      expect(
        ForceUpdateService.isInstalledAtLeast(
          installedVersion: '1.0.5',
          targetVersion: '1.0.5+7',
        ),
        isTrue,
      );
    });
  });
}
