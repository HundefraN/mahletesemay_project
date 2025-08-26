import 'dart:math';
import 'dart:typed_data';

/// A utility class that holds pre-generated WAV audio data for pure sine wave tones.
/// This avoids the need for any external asset files for the pitch trainer.
class GeneratedTones {
  // Private constructor to prevent instantiation.
  GeneratedTones._();

  static final Map<String, Uint8List> _noteData = {
    'C4': _generateWavData(261.63),
    'D4': _generateWavData(293.66),
    'E4': _generateWavData(329.63),
    'F4': _generateWavData(349.23),
    'G4': _generateWavData(392.00),
    'A4': _generateWavData(440.00),
    'B4': _generateWavData(493.88),
  };

  /// Retrieves the WAV byte data for a given note.
  static Uint8List? getTone(String note) {
    return _noteData[note];
  }

  /// Generates a 1-second sine wave for a given frequency and returns it
  /// as a valid WAV file in a byte array.
  static Uint8List _generateWavData(double frequency) {
    const int sampleRate = 44100;
    const int durationSeconds = 1;
    const int numSamples = sampleRate * durationSeconds;
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
    header.setUint16(20, 1, Endian.little); // AudioFormat (PCM)
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

    // Generate PCM data
    for (int i = 0; i < numSamples; i++) {
      final angle = (2 * pi * frequency * i) / sampleRate;
      final sample = (sin(angle) * 32767).toInt();
      pcmData.setInt16(i * 2, sample, Endian.little);
    }

    final allBytes = BytesBuilder();
    allBytes.add(header.buffer.asUint8List());
    allBytes.add(pcmData.buffer.asUint8List());

    return allBytes.toBytes();
  }
}