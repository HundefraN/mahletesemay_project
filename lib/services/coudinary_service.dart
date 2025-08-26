import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';

class CloudinaryService {
  static final CloudinaryPublic _cloudinary = CloudinaryPublic(
    'dccwfpg8m',
    'artists_pic',
    cache: false,
  );

  static Future<String?> uploadImage(
      File imageFile, {
        void Function(int count, int total)? onProgress,
      }) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          resourceType: CloudinaryResourceType.Image,
        ),
        onProgress: onProgress,
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print('Cloudinary Error: ${e.message}');
      return null;
    } catch (e) {
      print('Unknown Error: $e');
      return null;
    }
  }

  static Future<String?> uploadAudio(
      File audioFile, {
        void Function(int count, int total)? onProgress,
      }) async {
    try {
      CloudinaryResponse response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          audioFile.path,
          resourceType: CloudinaryResourceType.Video,
        ),
        onProgress: onProgress,
      );
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      print('Cloudinary Error: ${e.message}');
      return null;
    } catch (e) {
      print('Unknown Error: $e');
      return null;
    }
  }
}