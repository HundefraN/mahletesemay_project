import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/services/pitch_service.dart';

Uint8List generateTestPcm(double frequency, {int sampleRate = 44100, int numSamples = 2048, double harmonic2Strength = 0.3}) {
  final byteData = ByteData(numSamples * 2);
  for (int i = 0; i < numSamples; i++) {
    final t = i / sampleRate;
    final wave = sin(2 * pi * frequency * t) + harmonic2Strength * sin(4 * pi * frequency * t);
    final sample = (wave / (1.0 + harmonic2Strength) * 26000).round().clamp(-32768, 32767);
    byteData.setInt16(i * 2, sample, Endian.little);
  }
  return byteData.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PitchService & YIN+ Detection Engine Tests', () {
    final pitchService = PitchService();

    test('Detects Guitar Low E2 (82.41 Hz) with harmonic overtones', () {
      final pcm = generateTestPcm(82.41, harmonic2Strength: 0.5);
      final result = PitchService.detectPitchFromPcm16(pcm, sampleRate: 44100);
      expect(result.pitch, greaterThan(80.0));
      expect(result.pitch, lessThan(85.0));
      expect(result.clarity, greaterThan(0.50));
      expect(pitchService.getNoteFromPitch(result.pitch), equals('E2'));
    });

    test('Detects Guitar A2 (110.0 Hz)', () {
      final pcm = generateTestPcm(110.0, harmonic2Strength: 0.4);
      final result = PitchService.detectPitchFromPcm16(pcm, sampleRate: 44100);
      expect(result.pitch, greaterThan(107.0));
      expect(result.pitch, lessThan(113.0));
      expect(pitchService.getNoteFromPitch(result.pitch), equals('A2'));
    });

    test('Detects Vocal Middle C4 (261.63 Hz)', () {
      final pcm = generateTestPcm(261.63, harmonic2Strength: 0.2);
      final result = PitchService.detectPitchFromPcm16(pcm, sampleRate: 44100);
      expect(result.pitch, greaterThan(258.0));
      expect(result.pitch, lessThan(265.0));
      expect(pitchService.getNoteFromPitch(result.pitch), equals('C4'));
    });

    test('Detects Concert Pitch A4 (440.0 Hz)', () {
      final pcm = generateTestPcm(440.0, harmonic2Strength: 0.1);
      final result = PitchService.detectPitchFromPcm16(pcm, sampleRate: 44100);
      expect(result.pitch, greaterThan(435.0));
      expect(result.pitch, lessThan(445.0));
      expect(pitchService.getNoteFromPitch(result.pitch), equals('A4'));
    });

    test('Detects High Soprano C6 (1046.5 Hz)', () {
      final pcm = generateTestPcm(1046.5, harmonic2Strength: 0.1);
      final result = PitchService.detectPitchFromPcm16(pcm, sampleRate: 44100);
      expect(result.pitch, greaterThan(1030.0));
      expect(result.pitch, lessThan(1060.0));
      expect(pitchService.getNoteFromPitch(result.pitch), equals('C6'));
    });

    test('Octave-wrapped cents difference handles auto-transposition', () {
      final targetPitchC4 = 261.63;
      final userPitchC3 = 130.81; // 1 octave lower
      final userPitchC5 = 523.25; // 1 octave higher

      final centsC3 = pitchService.getOctaveWrappedCentsDifference(targetPitchC4, userPitchC3);
      final centsC5 = pitchService.getOctaveWrappedCentsDifference(targetPitchC4, userPitchC5);

      expect(centsC3.abs(), lessThan(5.0));
      expect(centsC5.abs(), lessThan(5.0));
    });

    test('Voice type range calculation & span analysis', () {
      final voiceType = pitchService.getVoiceType('E2', 'E4');
      expect(voiceType, equals('Bass'));

      final tenorType = pitchService.getVoiceType('C3', 'C5');
      expect(tenorType, equals('Tenor'));

      final sopranoType = pitchService.getVoiceType('C4', 'C6');
      expect(sopranoType, equals('Soprano'));

      final span = pitchService.getVocalRangeSpan('C3', 'C5');
      expect(span, contains('2 Octaves'));
    });
  });
}
