import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service for saving and restoring admin form drafts using SharedPreferences.
///
/// Each entity type (song, album, artist) has its own storage key.
/// Drafts are stored as JSON-encoded maps of form field values.
class DraftService {
  static const String _songDraftKey = 'admin_draft_song';
  static const String _albumDraftKey = 'admin_draft_album';
  static const String _artistDraftKey = 'admin_draft_artist';

  // ---------------------------------------------------------------------------
  // SONG DRAFTS
  // ---------------------------------------------------------------------------

  static Future<void> saveSongDraft({
    required String title,
    required String lyrics,
    String? artistId,
    String? artistName,
    String? artistImageUrl,
    String? artistRegion,
    String? albumId,
    String? albumTitle,
    String? albumCoverUrl,
    String? scale,
    String? rhythm,
    String? otherScale,
    String? otherRhythm,
    bool isSingle = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'title': title,
      'lyrics': lyrics,
      'artistId': artistId,
      'artistName': artistName,
      'artistImageUrl': artistImageUrl ?? '',
      'artistRegion': artistRegion ?? '',
      'albumId': albumId,
      'albumTitle': albumTitle,
      'albumCoverUrl': albumCoverUrl ?? '',
      'scale': scale,
      'rhythm': rhythm,
      'otherScale': otherScale,
      'otherRhythm': otherRhythm,
      'isSingle': isSingle,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_songDraftKey, json.encode(draft));
    debugPrint('Song draft saved');
  }

  static Future<Map<String, dynamic>?> loadSongDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString(_songDraftKey);
    if (draftJson == null) return null;
    try {
      return json.decode(draftJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading song draft: $e');
      return null;
    }
  }

  static Future<void> clearSongDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_songDraftKey);
    debugPrint('Song draft cleared');
  }

  static Future<bool> hasSongDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_songDraftKey);
  }

  // ---------------------------------------------------------------------------
  // ALBUM DRAFTS
  // ---------------------------------------------------------------------------

  static Future<void> saveAlbumDraft({
    required String title,
    String? year,
    String? volume,
    String? artistId,
    String? artistName,
    String? artistImageUrl,
    String? artistRegion,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'title': title,
      'year': year,
      'volume': volume,
      'artistId': artistId,
      'artistName': artistName,
      'artistImageUrl': artistImageUrl ?? '',
      'artistRegion': artistRegion ?? '',
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_albumDraftKey, json.encode(draft));
    debugPrint('Album draft saved');
  }

  static Future<Map<String, dynamic>?> loadAlbumDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString(_albumDraftKey);
    if (draftJson == null) return null;
    try {
      return json.decode(draftJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading album draft: $e');
      return null;
    }
  }

  static Future<void> clearAlbumDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_albumDraftKey);
    debugPrint('Album draft cleared');
  }

  static Future<bool> hasAlbumDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_albumDraftKey);
  }

  // ---------------------------------------------------------------------------
  // ARTIST DRAFTS
  // ---------------------------------------------------------------------------

  static Future<void> saveArtistDraft({
    required String name,
    required String region,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final draft = {
      'name': name,
      'region': region,
      'savedAt': DateTime.now().toIso8601String(),
    };
    await prefs.setString(_artistDraftKey, json.encode(draft));
    debugPrint('Artist draft saved');
  }

  static Future<Map<String, dynamic>?> loadArtistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final draftJson = prefs.getString(_artistDraftKey);
    if (draftJson == null) return null;
    try {
      return json.decode(draftJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error loading artist draft: $e');
      return null;
    }
  }

  static Future<void> clearArtistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_artistDraftKey);
    debugPrint('Artist draft cleared');
  }

  static Future<bool> hasArtistDraft() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_artistDraftKey);
  }
}
