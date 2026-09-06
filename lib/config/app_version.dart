/// Compile-time identity of the binary that is actually running.
///
/// Keep this in lockstep with `pubspec.yaml` `version:`. `test/app_version_test.dart`
/// fails the build if they drift. Android PackageManager can stay stale after a
/// sideload or split-APK rebuild; this value is the source of truth for the
/// force-update lock.
class AppVersion {
  static const String name = '1.0.6';
  static const String buildNumber = '8';
  static const String full = '$name+$buildNumber';
}
