import 'dart:math';
import 'dart:typed_data';

/// Utility class that synthesizes clean PCM WAV audio data for reference pitch tones.
class GeneratedTones {
  GeneratedTones._();

  static final Map<String, Uint8List> _cache = {};

  static const Map<String, int> _noteOffsets = {
    'C': 0, 'C#': 1, 'Db': 1,
    'D': 2, 'D#': 3, 'Eb': 3,
    'E': 4,
    'F': 5, 'F#': 6, 'Gb': 6,
    'G': 7, 'G#': 8, 'Ab': 8,
    'A': 9, 'A#': 10, 'Bb': 10,
    'B': 11,
  };

  /// Calculates frequency for standard musical notes (A4 = 440 Hz).
  static double getFrequencyFromNote(String note) {
    if (note.isEmpty) return 440.0;
    try {
      final octaveStr = note.substring(note.length - 1);
      final key = note.substring(0, note.length - 1);
      if (!_noteOffsets.containsKey(key)) return 440.0;
      final octave = int.parse(octaveStr);
      final midiNote = (octave + 1) * 12 + _noteOffsets[key]!;
      return 440.0 * pow(2.0, (midiNote - 69) / 12.0);
    } catch (_) {
      return 440.0;
    }
  }

  /// Retrieves or generates 1.25s WAV byte data for any note.
  static Uint8List? getTone(String note) {
    if (_cache.containsKey(note)) {
      return _cache[note];
    }

    final freq = getFrequencyFromNote(note);
    final bytes = _generateWavData(freq);
    _cache[note] = bytes;
    return bytes;
  }

  /// Generates a 1.25-second PCM WAV tone with smooth attack and release decay.
  static Uint8List _generateWavData(double frequency) {
    const int sampleRate = 44100;
    const double durationSeconds = 1.25;
    final int numSamples = (sampleRate * durationSeconds).toInt();
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = dataSize + 36;

    final header = ByteData(44);
    final pcmData = ByteData(dataSize);

    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); // 'W'
    header.setUint8(9, 0x41); // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'

    // fmt subchunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Subchunk1Size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);

    // data subchunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);

    const attackSamples = 441; // ~10ms attack
    final releaseSamples = (sampleRate * 0.15).toInt(); // ~150ms decay
    final mainEndIndex = numSamples - releaseSamples;

    // Generate PCM data with sine wave + subtle 2nd harmonic for rich vocal tone warmth
    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fundamental = sin(2 * pi * frequency * t);
      final harmonic2 = 0.25 * sin(4 * pi * frequency * t);
      double amplitude = (fundamental + harmonic2) / 1.25;

      // Envelope modulation
      if (i < attackSamples) {
        amplitude *= (i / attackSamples);
      } else if (i > mainEndIndex) {
        final decayProgress = (numSamples - i) / releaseSamples;
        amplitude *= decayProgress.clamp(0.0, 1.0);
      }

      final sample = (amplitude * 28000).round().clamp(-32768, 32767);
      pcmData.setInt16(i * 2, sample, Endian.little);
    }

    final allBytes = BytesBuilder();
    allBytes.add(header.buffer.asUint8List());
    allBytes.add(pcmData.buffer.asUint8List());

    return allBytes.toBytes();
  }

  static Uint8List? _successBeepCache;
  static Uint8List? _lockNoteBeepCache;

  /// Synthesizes a crisp, professional 0.35-second ascending success chime WAV sound.
  static Uint8List getSuccessBeepTone() {
    if (_successBeepCache != null) return _successBeepCache!;

    const int sampleRate = 44100;
    const double duration = 0.38;
    final int numSamples = (sampleRate * duration).toInt();
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = dataSize + 36;

    final header = ByteData(44);
    final pcmData = ByteData(dataSize);

    _buildWavHeader(header, fileSize, sampleRate, numChannels, bitsPerSample, dataSize);

    // 3 arpeggiated notes: E5 (659Hz), G#5 (830Hz), B5 (987Hz), E6 (1318Hz)
    final frequencies = [659.25, 830.61, 987.77, 1318.51];
    final stepLength = numSamples ~/ frequencies.length;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final stepIdx = (i ~/ stepLength).clamp(0, frequencies.length - 1);
      final freq = frequencies[stepIdx];

      final sampleT = (i % stepLength) / sampleRate;
      double env = 1.0 - ((i % stepLength) / stepLength);
      // Overall fade out
      env *= (1.0 - (i / numSamples));

      final wave = sin(2 * pi * freq * sampleT) + 0.3 * sin(4 * pi * freq * sampleT);
      final sample = (wave * env * 24000).round().clamp(-32768, 32767);
      pcmData.setInt16(i * 2, sample, Endian.little);
    }

    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(header.buffer.asUint8List());
    bytesBuilder.add(pcmData.buffer.asUint8List());
    _successBeepCache = bytesBuilder.toBytes();
    return _successBeepCache!;
  }

  /// Synthesizes a fast 0.15-second double-ping note lock confirmation WAV sound.
  static Uint8List getLockNoteBeepTone() {
    if (_lockNoteBeepCache != null) return _lockNoteBeepCache!;

    const int sampleRate = 44100;
    const double duration = 0.18;
    final int numSamples = (sampleRate * duration).toInt();
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = dataSize + 36;

    final header = ByteData(44);
    final pcmData = ByteData(dataSize);

    _buildWavHeader(header, fileSize, sampleRate, numChannels, bitsPerSample, dataSize);

    const freq1 = 880.0; // A5
    const freq2 = 1760.0; // A6
    final halfSamples = numSamples ~/ 2;

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final freq = i < halfSamples ? freq1 : freq2;
      final localIdx = i < halfSamples ? i : (i - halfSamples);
      final localDecay = 1.0 - (localIdx / halfSamples);

      final wave = sin(2 * pi * freq * t);
      final sample = (wave * localDecay * 26000).round().clamp(-32768, 32767);
      pcmData.setInt16(i * 2, sample, Endian.little);
    }

    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(header.buffer.asUint8List());
    bytesBuilder.add(pcmData.buffer.asUint8List());
    _lockNoteBeepCache = bytesBuilder.toBytes();
    return _lockNoteBeepCache!;
  }

  static final Map<String, Uint8List> _pitchBeepCache = {};

  /// Synthesizes a clean, high-precision PCM WAV beep at the exact tuned frequency.
  static Uint8List getPitchBeepTone(double frequency, {double duration = 0.30}) {
    final key = '${frequency.toStringAsFixed(2)}_${duration.toStringAsFixed(2)}';
    if (_pitchBeepCache.containsKey(key)) {
      return _pitchBeepCache[key]!;
    }

    const int sampleRate = 44100;
    final int numSamples = (sampleRate * duration).toInt();
    const int bitsPerSample = 16;
    const int numChannels = 1;
    final int dataSize = numSamples * numChannels * bitsPerSample ~/ 8;
    final int fileSize = dataSize + 36;

    final header = ByteData(44);
    final pcmData = ByteData(dataSize);

    _buildWavHeader(header, fileSize, sampleRate, numChannels, bitsPerSample, dataSize);

    const attackSamples = 220; // ~5ms attack
    final releaseSamples = (sampleRate * 0.08).toInt(); // ~80ms decay
    final mainEndIndex = numSamples - releaseSamples;

    // For low bass frequencies (<220Hz), shift pitch up 1 or 2 octaves for beep audibility on small phone speakers while maintaining exact pitch harmonic alignment
    double renderFreq = frequency;
    while (renderFreq < 220.0 && renderFreq > 0) {
      renderFreq *= 2.0; // Harmonic octave shift for speaker playback
    }

    for (int i = 0; i < numSamples; i++) {
      final t = i / sampleRate;
      final fundamental = sin(2 * pi * renderFreq * t);
      final harmonic2 = 0.35 * sin(4 * pi * renderFreq * t);
      final harmonic3 = 0.15 * sin(6 * pi * renderFreq * t);
      
      double amplitude = (fundamental + harmonic2 + harmonic3) / 1.5;

      // Envelope modulation
      if (i < attackSamples) {
        amplitude *= (i / attackSamples);
      } else if (i > mainEndIndex) {
        final decayProgress = (numSamples - i) / releaseSamples;
        amplitude *= decayProgress.clamp(0.0, 1.0);
      } else {
        // Subtle sustain decay
        final sustainProgress = 1.0 - (0.2 * (i - attackSamples) / (mainEndIndex - attackSamples));
        amplitude *= sustainProgress;
      }

      final sample = (amplitude * 26000).round().clamp(-32768, 32767);
      pcmData.setInt16(i * 2, sample, Endian.little);
    }

    final bytesBuilder = BytesBuilder();
    bytesBuilder.add(header.buffer.asUint8List());
    bytesBuilder.add(pcmData.buffer.asUint8List());

    final bytes = bytesBuilder.toBytes();
    _pitchBeepCache[key] = bytes;
    return bytes;
  }

  /// Synthesizes a tuned pitch beep for a musical note string (e.g. "E2", "A2", "C4").
  static Uint8List getNoteBeepTone(String note, {double duration = 0.30}) {
    final freq = getFrequencyFromNote(note);
    return getPitchBeepTone(freq, duration: duration);
  }

  static void _buildWavHeader(
    ByteData header,
    int fileSize,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
    int dataSize,
  ) {
    final int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    final int blockAlign = numChannels * bitsPerSample ~/ 8;

    header.setUint8(0, 0x52); header.setUint8(1, 0x49); header.setUint8(2, 0x46); header.setUint8(3, 0x46);
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57); header.setUint8(9, 0x41); header.setUint8(10, 0x56); header.setUint8(11, 0x45);
    header.setUint8(12, 0x66); header.setUint8(13, 0x6D); header.setUint8(14, 0x74); header.setUint8(15, 0x20);
    header.setUint32(16, 16, Endian.little);
    header.setUint16(20, 1, Endian.little);
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    header.setUint8(36, 0x64); header.setUint8(37, 0x61); header.setUint8(38, 0x74); header.setUint8(39, 0x61);
    header.setUint32(40, dataSize, Endian.little);
  }
}