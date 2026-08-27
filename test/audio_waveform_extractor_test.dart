import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/services/audio_waveform_extractor_service.dart';
import 'package:mahlete_semay_project/utils/generated_tones.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioWaveformExtractorService extractorService;
  late Directory tempDir;

  setUpAll(() async {
    extractorService = AudioWaveformExtractorService();
    tempDir = await Directory.systemTemp.createTemp('waveform_test_');
  });

  tearDownAll(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('AudioWaveformExtractorService Tests', () {
    test('Extracts authentic waveform from real PCM WAV audio file', () async {
      // 1. Generate real synthesized PCM WAV audio file using GeneratedTones
      final wavBytes = GeneratedTones.getTone('A4');
      expect(wavBytes, isNotNull);
      expect(wavBytes!.length, greaterThan(1000));

      final testFile = File('${tempDir.path}/test_a4.wav');
      await testFile.writeAsBytes(wavBytes);

      // 2. Extract waveform
      const targetBars = 48;
      final waveform = await extractorService.extractWaveform(
        audioSource: testFile.path,
        targetSamples: targetBars,
      );

      // 3. Verify output
      expect(waveform.length, equals(targetBars));

      for (final val in waveform) {
        expect(val, greaterThanOrEqualTo(0.08));
        expect(val, lessThanOrEqualTo(1.0));
      }

      // Check that the waveform has physical dynamic variations (attack/decay curve)
      // Since A4 has attack and decay, amplitudes vary across the file
      final minVal = waveform.reduce((a, b) => a < b ? a : b);
      final maxVal = waveform.reduce((a, b) => a > b ? a : b);
      expect(maxVal, greaterThan(minVal));
      expect(maxVal, closeTo(1.0, 0.05)); // Normalization ensures peak reaches ~1.0
    });

    test('Extracts waveform with different target bar counts', () async {
      final wavBytes = GeneratedTones.getTone('C4');
      final testFile = File('${tempDir.path}/test_c4.wav');
      await testFile.writeAsBytes(wavBytes!);

      const counts = [24, 36, 64];
      for (final count in counts) {
        final waveform = await extractorService.extractWaveform(
          audioSource: testFile.path,
          targetSamples: count,
        );
        expect(waveform.length, equals(count));
      }
    });

    test('Handles fallback gracefully for empty or nonexistent sources without crashing', () async {
      final waveform = await extractorService.extractWaveform(
        audioSource: 'non_existent_file.mp3',
        targetSamples: 40,
      );

      expect(waveform.length, equals(40));
      for (final val in waveform) {
        expect(val, greaterThanOrEqualTo(0.08));
        expect(val, lessThanOrEqualTo(1.0));
      }
    });

    test('In-memory caching returns identical result instantly', () async {
      final wavBytes = GeneratedTones.getTone('E4');
      final testFile = File('${tempDir.path}/test_e4.wav');
      await testFile.writeAsBytes(wavBytes!);

      final first = await extractorService.extractWaveform(
        audioSource: testFile.path,
        targetSamples: 44,
      );

      final second = await extractorService.extractWaveform(
        audioSource: testFile.path,
        targetSamples: 44,
      );

      expect(identical(first, second), isTrue);
    });
  });
}
