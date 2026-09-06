import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:nanoid/nanoid.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/supabase_config.dart';

class SupabaseStorageService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// Uploads raw image bytes to Supabase storage bucket (`covers` by default)
  /// and returns its full public URL. Works seamlessly on Web, iOS, and Android.
  static Future<String?> uploadImageBytes(
    Uint8List bytes, {
    String extension = '.jpg',
    String bucket = 'covers',
    String? folder,
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final ext = extension.startsWith('.') ? extension : '.$extension';
      final fileName = '${nanoid(12)}$ext';
      final filePath = folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      // Upload binary to Supabase Storage
      await _client.storage.from(bucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: true,
            ),
          );

      // Retrieve public CDN URL
      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
      debugPrint('Uploaded image bytes to Supabase ($bucket): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading image bytes to Supabase Storage: $e');
      return null;
    }
  }

  /// Uploads raw audio bytes to Supabase storage bucket (`audio` by default)
  /// and returns its full public URL. Reports exact byte progress via [onProgress].
  static Future<String?> uploadAudioBytes(
    Uint8List bytes, {
    String extension = '.mp3',
    String bucket = 'audio',
    String? folder,
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final ext = extension.startsWith('.') ? extension : '.$extension';
      final fileName = '${nanoid(12)}$ext';
      final filePath =
          folder != null && folder.isNotEmpty ? '$folder/$fileName' : fileName;

      if (onProgress != null) {
        try {
          await _uploadBinaryWithProgress(
            bytes: bytes,
            bucket: bucket,
            path: filePath,
            contentType: _audioContentType(ext),
            onProgress: onProgress,
          );
        } catch (e) {
          debugPrint('Progress audio upload failed, falling back: $e');
          onProgress(0, bytes.length);
          await _client.storage.from(bucket).uploadBinary(
                filePath,
                bytes,
                fileOptions: const FileOptions(
                  cacheControl: '3600',
                  upsert: true,
                ),
              );
          onProgress(bytes.length, bytes.length);
        }
      } else {
        await _client.storage.from(bucket).uploadBinary(
              filePath,
              bytes,
              fileOptions: const FileOptions(
                cacheControl: '3600',
                upsert: true,
              ),
            );
      }

      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
      debugPrint('Uploaded audio bytes to Supabase ($bucket): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading audio bytes to Supabase Storage: $e');
      return null;
    }
  }

  static String _audioContentType(String extension) {
    switch (extension.toLowerCase()) {
      case '.mp3':
        return 'audio/mpeg';
      case '.wav':
        return 'audio/wav';
      case '.aac':
        return 'audio/aac';
      case '.m4a':
        return 'audio/mp4';
      case '.ogg':
        return 'audio/ogg';
      case '.flac':
        return 'audio/flac';
      default:
        return 'application/octet-stream';
    }
  }

  static Future<void> _uploadBinaryWithProgress({
    required Uint8List bytes,
    required String bucket,
    required String path,
    required String contentType,
    required void Function(int count, int total) onProgress,
  }) async {
    final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
    final uploadUrl =
        '${SupabaseConfig.url}/storage/v1/object/$bucket/$encodedPath';

    final session = _client.auth.currentSession;
    final accessToken = session?.accessToken ?? SupabaseConfig.publishableKey;

    onProgress(0, bytes.length);

    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        sendTimeout: const Duration(minutes: 15),
        receiveTimeout: const Duration(minutes: 2),
      ),
    );

    final headers = <String, dynamic>{
      'Authorization': 'Bearer $accessToken',
      'apikey': SupabaseConfig.publishableKey,
      'x-upsert': 'true',
      'cache-control': '3600',
      'content-length': bytes.length,
    };

    Future<Response<dynamic>> send(String method) {
      return dio.request(
        uploadUrl,
        data: bytes,
        options: Options(
          method: method,
          headers: headers,
          contentType: contentType,
          responseType: ResponseType.json,
          validateStatus: (status) => status != null && status < 400,
        ),
        onSendProgress: (sent, total) {
          final actualTotal = total > 0 ? total : bytes.length;
          onProgress(sent.clamp(0, actualTotal), actualTotal);
        },
      );
    }

    try {
      await send('POST');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 400 || status == 409 || status == 405) {
        await send('PUT');
      } else {
        rethrow;
      }
    }

    onProgress(bytes.length, bytes.length);
  }

  /// Uploads raw APK file bytes to Supabase storage bucket (`app-releases` by default)
  /// and returns its full public URL. Reports exact byte progress via [onProgress].
  static Future<String?> uploadApkBytes(
    Uint8List bytes, {
    required String fileName,
    String bucket = 'app-releases',
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_\-\.]'), '_');
      final path = 'apks/$sanitizedName';
      final encodedPath = path.split('/').map(Uri.encodeComponent).join('/');
      final uploadUrl = '${SupabaseConfig.url}/storage/v1/object/$bucket/$encodedPath';

      final session = _client.auth.currentSession;
      final accessToken = session?.accessToken ?? SupabaseConfig.publishableKey;

      onProgress?.call(0, bytes.length);

      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(minutes: 2),
          sendTimeout: const Duration(minutes: 15),
          receiveTimeout: const Duration(minutes: 2),
        ),
      );

      final headers = <String, dynamic>{
        'Authorization': 'Bearer $accessToken',
        'apikey': SupabaseConfig.publishableKey,
        'x-upsert': 'true',
        'cache-control': '3600',
        'content-length': bytes.length,
      };

      Future<Response<dynamic>> send(String method) {
        return dio.request(
          uploadUrl,
          data: bytes,
          options: Options(
            method: method,
            headers: headers,
            contentType: 'application/vnd.android.package-archive',
            responseType: ResponseType.json,
            validateStatus: (status) => status != null && status < 400,
          ),
          onSendProgress: (sent, total) {
            final actualTotal = total > 0 ? total : bytes.length;
            onProgress?.call(sent.clamp(0, actualTotal), actualTotal);
          },
        );
      }

      try {
        await send('POST');
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        // Existing object or method mismatch: retry as an upsert PUT.
        if (status == 400 || status == 409 || status == 405) {
          await send('PUT');
        } else {
          rethrow;
        }
      }

      onProgress?.call(bytes.length, bytes.length);

      final publicUrl = _client.storage.from(bucket).getPublicUrl(path);
      debugPrint('Uploaded APK to Supabase ($bucket): $publicUrl');
      return publicUrl;
    } catch (e) {
      debugPrint('Error uploading APK to Supabase Storage: $e');
      rethrow;
    }
  }

  /// Uploads an image file to the specified Supabase storage bucket (`covers` by default)
  /// and returns its full public URL.
  static Future<String?> uploadImage(
    File imageFile, {
    String bucket = 'covers',
    String? folder,
    void Function(int count, int total)? onProgress,
  }) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final ext = p.extension(imageFile.path).toLowerCase();
      return await uploadImageBytes(
        bytes,
        extension: ext.isNotEmpty ? ext : '.jpg',
        bucket: bucket,
        folder: folder,
        onProgress: onProgress,
      );
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
      final bytes = await audioFile.readAsBytes();
      final ext = p.extension(audioFile.path).toLowerCase();
      return await uploadAudioBytes(
        bytes,
        extension: ext.isNotEmpty ? ext : '.mp3',
        bucket: bucket,
        folder: folder,
        onProgress: onProgress,
      );
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
