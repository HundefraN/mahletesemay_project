import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/config/app_version.dart';

void main() {
  test('AppVersion stays in lockstep with pubspec.yaml', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\s#+]+)(?:\+(\d+))?',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml must declare version:');
    expect(AppVersion.name, match!.group(1));
    expect(AppVersion.buildNumber, match.group(2) ?? '0');
    expect(AppVersion.full, '${AppVersion.name}+${AppVersion.buildNumber}');
  });
}
