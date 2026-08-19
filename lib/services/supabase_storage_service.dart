import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Uploads an image file to the specified Supabase storage bucket (`covers` by default)
  /// and returns its full public URL.
  static Future<String?> uploadImage(
    File imageFile, {
    String bucket = 'covers',
    String? folder,
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final ext = p.extension(imageFile.path).toLowerCase();
      final extension = ext.isNotEmpty ? ext : '.jpg';
      final fileName = '${nanoid(12)}$extension';
      final filePath = folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      // Upload binary to Supabase Storage
      await _client.storage.from(bucket).upload(
            filePath,
            imageFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Retrieve public CDN URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
      debugPrint('Uploaded image to Supabase ($bucket): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image to Supabase Storage: $e');
      return null;
    }
  }

  /// Uploads an audio file to the `audio` storage bucket
  /// and returns its full public URL.
  static Future<String?> uploadAudio(
    File audioFile, {
    String bucket = 'audio',
    String? folder,
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final ext = p.extension(audioFile.path).toLowerCase();
      final extension = ext.isNotEmpty ? ext : '.mp3';
      final fileName = '${nanoid(12)}$extension';
      final filePath = folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      // Upload binary to Supabase Storage
      await _client.storage.from(bucket).upload(
            filePath,
            audioFile,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Retrieve public CDN URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
      debugPrint('Uploaded audio to Supabase ($bucket): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading audio to Supabase Storage: $e');
      return null;
    }
  }

  /// Deletes a file from Supabase Storage by its public URL or path.
  static Future<bool> deleteFile(String publicUrl, {String? defaultBucket}) async {
    try {
      final uri = Uri.tryParse(publicUrl);
      if (uri == null) return false;

      // URL pattern: .../storage/v1/object/public/<bucket>/<path...>
      final segments = uri.pathSegments;
      final publicIndex = segments.indexOf('public');

      String bucket;
      String path;

      if (publicIndex != -1 && segments.length > publicIndex + 2) {
        bucket = segments[publicIndex + 1];
        path = segments.sublist(publicIndex + 2).join('/');
      } else if (defaultBucket != null) {
        bucket = defaultBucket;
        path = segments.last;
      } else {
        return false;
      }

      await _client.storage.from(bucket).remove([path]);
      debugPrint('Deleted file from Supabase ($bucket): $path');
      return true;
    } catch (e) {
      debugPrint('Error deleting file from Supabase Storage: $e');
      return false;
    }
  }
}
