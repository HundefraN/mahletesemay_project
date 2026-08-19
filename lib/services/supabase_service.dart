import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/invitation_model.dart';
import '../models/moderator_model.dart';
import '../models/song_model.dart';
import '../models/suggestion_model.dart';
import '../models/vocal_plan_model.dart';
import '../utils/amharic_transliterator.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // ---------------------------------------------------------------------------
  // ARTISTS
  // ---------------------------------------------------------------------------

  Stream<List<Artist>> getArtistsStream() {
    return _client
        .from('artists')
        .stream(primaryKey: ['id'])
        .map((maps) => maps.map((item) => Artist.fromMap(item)).toList());
  }

  Future<List<Artist>> getArtists() async {
    try {
      final response = await _client.from('artists').select();
      debugPrint('Fetched ${response.length} artists from Supabase');
      return (response as List).map((item) => Artist.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting artists: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addArtist(Artist artist) async {
    try {
      await _client.from('artists').insert(artist.toSupabase());
    } catch (e) {
      debugPrint('Error adding artist: $e');
      rethrow;
    }
  }

  Future<void> updateArtist(String id, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      if (payload.containsKey('imageUrl')) {
        payload['image_url'] = payload.remove('imageUrl');
      }
      if (payload.containsKey('englishName')) {
        payload['english_name'] = payload.remove('englishName');
      }
      if (payload.containsKey('searchKeywords')) {
        payload['search_keywords'] = payload.remove('searchKeywords');
      }

      if (payload.containsKey('name') && !payload.containsKey('search_keywords')) {
        final name = payload['name']?.toString() ?? '';
        final engName = payload['english_name']?.toString() ??
            (AmharicTransliterator.containsAmharic(name)
                ? AmharicTransliterator.toLatin(name)
                : '');
        payload['english_name'] = engName;
        payload['search_keywords'] = AmharicTransliterator.generateSearchKeywords(
          title: name,
          englishTitle: engName,
          subtitleOrArtist: payload['region']?.toString(),
        );
      }

      await _client.from('artists').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('Error updating artist: $e');
      rethrow;
    }
  }

  Future<void> deleteArtists(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      await _client.from('artists').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('Error deleting artists: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ALBUMS
  // ---------------------------------------------------------------------------

  Stream<List<Album>> getAlbumsStream() {
    return _client
        .from('albums')
        .stream(primaryKey: ['id'])
        .map((maps) => maps.map((item) => Album.fromMap(item)).toList());
  }

  Future<List<Album>> getAlbums() async {
    try {
      final response = await _client.from('albums').select();
      debugPrint('Fetched ${response.length} albums from Supabase');
      return (response as List).map((item) => Album.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting albums: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addAlbum(Album album) async {
    try {
      await _client.from('albums').insert(album.toSupabase());
    } catch (e) {
      debugPrint('Error adding album: $e');
      rethrow;
    }
  }

  Future<void> updateAlbum(String id, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      if (payload.containsKey('artistId')) payload['artist_id'] = payload.remove('artistId');
      if (payload.containsKey('artistName')) payload['artist_name'] = payload.remove('artistName');
      if (payload.containsKey('coverImageUrl')) payload['cover_image_url'] = payload.remove('coverImageUrl');
      if (payload.containsKey('englishTitle')) payload['english_title'] = payload.remove('englishTitle');
      if (payload.containsKey('searchKeywords')) payload['search_keywords'] = payload.remove('searchKeywords');

      if (payload.containsKey('title') && !payload.containsKey('search_keywords')) {
        final title = payload['title']?.toString() ?? '';
        final engTitle = payload['english_title']?.toString() ??
            (AmharicTransliterator.containsAmharic(title)
                ? AmharicTransliterator.toLatin(title)
                : '');
        payload['english_title'] = engTitle;
        payload['search_keywords'] = AmharicTransliterator.generateSearchKeywords(
          title: title,
          englishTitle: engTitle,
          subtitleOrArtist: payload['artist_name']?.toString(),
        );
      }

      await _client.from('albums').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('Error updating album: $e');
      rethrow;
    }
  }

  Future<void> deleteAlbums(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      await _client.from('albums').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('Error deleting albums: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // SONGS
  // ---------------------------------------------------------------------------

  Stream<List<Song>> getSongsStream() {
    return _client
        .from('songs')
        .stream(primaryKey: ['id'])
        .map((maps) => maps.map((item) => Song.fromMap(item)).toList());
  }

  Future<bool> hasNewSongsSince(DateTime date) async {
    try {
      final response = await _client
          .from('songs')
          .select('id')
          .gt('created_at', date.toUtc().toIso8601String())
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('Error in hasNewSongsSince: $e');
      return false;
    }
  }

  Future<List<Song>> getSongs() async {
    try {
      final response = await _client.from('songs').select();
      debugPrint('Fetched ${response.length} songs from Supabase');
      return (response as List).map((item) => Song.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting songs: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addSong(Song song) async {
    try {
      await _client.from('songs').insert(song.toSupabase());
    } catch (e) {
      debugPrint('Error adding song: $e');
      rethrow;
    }
  }

  Future<void> updateSong(String id, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      if (payload.containsKey('artistId')) payload['artist_id'] = payload.remove('artistId');
      if (payload.containsKey('artistName')) payload['artist_name'] = payload.remove('artistName');
      if (payload.containsKey('albumId')) payload['album_id'] = payload.remove('albumId');
      if (payload.containsKey('albumTitle')) payload['album_title'] = payload.remove('albumTitle');
      if (payload.containsKey('viewCount')) payload['view_count'] = payload.remove('viewCount');
      if (payload.containsKey('englishTitle')) payload['english_title'] = payload.remove('englishTitle');
      if (payload.containsKey('searchKeywords')) payload['search_keywords'] = payload.remove('searchKeywords');
      if (payload.containsKey('createdAt')) {
        final val = payload.remove('createdAt');
        payload['created_at'] = val is DateTime ? val.toIso8601String() : val.toString();
      }

      if ((payload.containsKey('title') || payload.containsKey('lyrics')) && !payload.containsKey('search_keywords')) {
        final title = payload['title']?.toString() ?? '';
        final engTitle = payload['english_title']?.toString() ??
            (AmharicTransliterator.containsAmharic(title)
                ? AmharicTransliterator.toLatin(title)
                : '');
        payload['english_title'] = engTitle;
        payload['search_keywords'] = AmharicTransliterator.generateSearchKeywords(
          title: title,
          englishTitle: engTitle,
          subtitleOrArtist: payload['artist_name']?.toString(),
          lyricsOrDescription: payload['lyrics']?.toString(),
        );
      }

      await _client.from('songs').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('Error updating song: $e');
      rethrow;
    }
  }

  Future<void> deleteSongs(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      await _client.from('songs').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('Error deleting songs: $e');
      rethrow;
    }
  }

  Future<void> incrementSongViewCount(String songId) async {
    try {
      await _client.rpc('increment_song_view_count', params: {'p_song_id': songId});
    } catch (e) {
      debugPrint('Error calling increment_song_view_count RPC, falling back to direct update: $e');
      try {
        final current = await _client.from('songs').select('view_count').eq('id', songId).maybeSingle();
        final int currentCount = (current?['view_count'] as int?) ?? 0;
        await _client.from('songs').update({'view_count': currentCount + 1}).eq('id', songId);
      } catch (err) {
        debugPrint('Error incrementing song view count: $err');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // VOCAL PLANS & PLAN DAYS
  // ---------------------------------------------------------------------------

  Future<List<VocalExerciseDay>> getVocalPlanDays(String planId) async {
    try {
      final response = await _client
          .from('vocal_plan_days')
          .select()
          .eq('plan_id', planId)
          .order('day_number', ascending: true);
      return (response as List).map((item) => VocalExerciseDay.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting vocal plan days: $e');
      return [];
    }
  }

  Stream<List<VocalExerciseDay>> getVocalPlanDaysStream(String planId) async* {
    try {
      final initial = await getVocalPlanDays(planId);
      yield initial;
    } catch (e) {
      debugPrint('Error in initial getVocalPlanDays: $e');
    }

    try {
      yield* _client
          .from('vocal_plan_days')
          .stream(primaryKey: ['id'])
          .eq('plan_id', planId)
          .order('day_number', ascending: true)
          .map((maps) => maps.map((item) => VocalExerciseDay.fromMap(item)).toList())
          .handleError((e) {
            debugPrint('Realtime stream error for vocal_plan_days: $e');
          });
    } catch (e) {
      debugPrint('Error subscribing to vocal_plan_days stream: $e');
    }
  }

  Future<void> addVocalExerciseDay(String planId, VocalExerciseDay exerciseDay) async {
    try {
      await _client.from('vocal_plan_days').insert(exerciseDay.toSupabase(planId));
    } catch (e) {
      debugPrint('Error adding vocal exercise day: $e');
      rethrow;
    }
  }

  Future<void> updateVocalExerciseDay(String planId, String dayId, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      if (payload.containsKey('dayNumber')) payload['day_number'] = payload.remove('dayNumber');
      if (payload.containsKey('audioUrl')) payload['audio_url'] = payload.remove('audioUrl');
      if (payload.containsKey('isRestDay')) payload['is_rest_day'] = payload.remove('isRestDay');
      await _client.from('vocal_plan_days').update(payload).eq('id', dayId);
    } catch (e) {
      debugPrint('Error updating vocal exercise day: $e');
      rethrow;
    }
  }

  Future<void> deleteVocalExerciseDay(String planId, String dayId) async {
    try {
      await _client.from('vocal_plan_days').delete().eq('id', dayId);
    } catch (e) {
      debugPrint('Error deleting vocal exercise day: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // GENERAL EXERCISES
  // ---------------------------------------------------------------------------

  Future<List<VocalExerciseDay>> getGeneralExercises() async {
    try {
      final response = await _client
          .from('general_exercises')
          .select()
          .order('title', ascending: true);
      return (response as List).map((item) => VocalExerciseDay.fromMap(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error getting general exercises: $e');
      return [];
    }
  }

  Stream<List<VocalExerciseDay>> getGeneralExercisesStream() async* {
    try {
      final initial = await getGeneralExercises();
      yield initial;
    } catch (e) {
      debugPrint('Error in initial getGeneralExercises: $e');
    }

    try {
      yield* _client
          .from('general_exercises')
          .stream(primaryKey: ['id'])
          .order('title', ascending: true)
          .map((maps) => maps.map((item) => VocalExerciseDay.fromMap(item)).toList())
          .handleError((e) {
            debugPrint('Realtime stream error for general_exercises: $e');
          });
    } catch (e) {
      debugPrint('Error subscribing to general_exercises stream: $e');
    }
  }

  Future<void> addGeneralExercise(VocalExerciseDay exercise) async {
    try {
      await _client.from('general_exercises').insert(exercise.toSupabase());
    } catch (e) {
      debugPrint('Error adding general exercise: $e');
      rethrow;
    }
  }

  Future<void> updateGeneralExercise(String id, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload.remove('id');
      if (payload.containsKey('dayNumber')) payload['day_number'] = payload.remove('dayNumber');
      if (payload.containsKey('audioUrl')) payload['audio_url'] = payload.remove('audioUrl');
      if (payload.containsKey('isRestDay')) payload['is_rest_day'] = payload.remove('isRestDay');
      if (payload.containsKey('englishTitle')) payload['english_title'] = payload.remove('englishTitle');
      if (payload.containsKey('searchKeywords')) payload['search_keywords'] = payload.remove('searchKeywords');

      if ((payload.containsKey('title') || payload.containsKey('description')) && !payload.containsKey('search_keywords')) {
        final title = payload['title']?.toString() ?? '';
        final engTitle = payload['english_title']?.toString() ??
            (AmharicTransliterator.containsAmharic(title)
                ? AmharicTransliterator.toLatin(title)
                : '');
        payload['english_title'] = engTitle;
        payload['search_keywords'] = AmharicTransliterator.generateSearchKeywords(
          title: title,
          englishTitle: engTitle,
          lyricsOrDescription: payload['description']?.toString(),
        );
      }

      await _client.from('general_exercises').update(payload).eq('id', id);
    } catch (e) {
      debugPrint('Error updating general exercise: $e');
      rethrow;
    }
  }

  Future<void> deleteGeneralExercises(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      await _client.from('general_exercises').delete().inFilter('id', ids);
    } catch (e) {
      debugPrint('Error deleting general exercises: $e');
      rethrow;
    }
  }

  Future<List<VocalExerciseDay>> getAllVocalExercises() async {
    try {
      final List<VocalExerciseDay> allExercises = [];

      final generalResp = await _client.from('general_exercises').select();
      allExercises.addAll((generalResp as List).map((doc) => VocalExerciseDay.fromMap(doc as Map<String, dynamic>)));

      final planDaysResp = await _client.from('vocal_plan_days').select();
      allExercises.addAll((planDaysResp as List).map((doc) => VocalExerciseDay.fromMap(doc as Map<String, dynamic>)));

      return allExercises;
    } catch (e) {
      debugPrint('Error getting all vocal exercises: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // MODERATORS & AUTH PROFILE
  // ---------------------------------------------------------------------------

  Future<void> setModeratorData(String uid, Map<String, dynamic> data) async {
    try {
      final payload = Map<String, dynamic>.from(data);
      payload['id'] = uid;
      if (payload.containsKey('firstName')) payload['first_name'] = payload.remove('firstName');
      if (payload.containsKey('lastName')) payload['last_name'] = payload.remove('lastName');
      if (payload.containsKey('approvedDevices')) payload['approved_devices'] = payload.remove('approvedDevices');
      if (payload.containsKey('pendingDevice')) payload['pending_device'] = payload.remove('pendingDevice');
      if (payload.containsKey('lastLogin')) {
        final val = payload.remove('lastLogin');
        payload['last_login'] = val is DateTime ? val.toIso8601String() : val?.toString();
      }
      if (payload.containsKey('createdAt')) {
        final val = payload.remove('createdAt');
        payload['created_at'] = val is DateTime ? val.toIso8601String() : val?.toString();
      }
      final status = payload['status']?.toString() ?? 'active';
      payload['status'] = status;
      payload['is_active'] = status == 'active';
      await _client.from('moderators').upsert(payload);
    } catch (e) {
      debugPrint('Error setting moderator data: $e');
    }
  }

  Future<Moderator?> getModerator(String uid) async {
    try {
      final res = await _client.from('moderators').select().eq('id', uid).maybeSingle();
      if (res == null) return null;
      return Moderator.fromMap(res);
    } catch (e) {
      debugPrint('Error getting moderator: $e');
      return null;
    }
  }

  // Compatibility helper returning Map-like wrapper with .exists and .data()
  Future<dynamic> getModeratorDoc(String uid) async {
    try {
      final res = await _client.from('moderators').select().eq('id', uid).maybeSingle();
      return _SupabaseDocSnapshot(id: uid, dataMap: res);
    } catch (e) {
      debugPrint('Error getting moderator doc: $e');
      return _SupabaseDocSnapshot(id: uid, dataMap: null);
    }
  }

  Stream<dynamic> getModeratorStream(String uid) {
    return _client
        .from('moderators')
        .stream(primaryKey: ['id'])
        .eq('id', uid)
        .map((list) => _SupabaseDocSnapshot(id: uid, dataMap: list.isNotEmpty ? list.first : null));
  }

  Stream<List<Moderator>> getModeratorsStream() {
    return _client
        .from('moderators')
        .stream(primaryKey: ['id'])
        .map((maps) => maps.map((item) => Moderator.fromMap(item)).toList());
  }

  Future<void> updateModeratorStatus(String uid, String status) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', uid).maybeSingle();
      final name = doc != null ? '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim() : uid;

      try {
        await _client.from('moderators').update({
          'status': status,
          'is_active': status == 'active',
        }).eq('id', uid);
      } catch (_) {
        await _client.from('moderators').update({'status': status}).eq('id', uid);
      }

      await logActivity(
        moderatorId: uid,
        moderatorName: name.isNotEmpty ? name : 'Moderator',
        action: 'STATUS_UPDATED',
        details: 'Account status updated to $status',
      );
    } catch (e) {
      debugPrint('Error updating moderator status: $e');
      rethrow;
    }
  }

  Future<void> updateModeratorRole(String uid, String role) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', uid).maybeSingle();
      final name = doc != null ? '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim() : uid;

      await _client.from('moderators').update({'role': role}).eq('id', uid);

      await logActivity(
        moderatorId: uid,
        moderatorName: name.isNotEmpty ? name : 'Moderator',
        action: 'ROLE_UPDATED',
        details: 'User role changed to ${role.toUpperCase()}',
      );
    } catch (e) {
      debugPrint('Error updating moderator role: $e');
      rethrow;
    }
  }

  Future<void> deleteModerator(String uid) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', uid).maybeSingle();
      final name = doc != null ? '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim() : uid;

      await _client.from('moderators').delete().eq('id', uid);

      await logActivity(
        moderatorId: uid,
        moderatorName: name.isNotEmpty ? name : 'Moderator',
        action: 'MODERATOR_DELETED',
        details: 'Moderator profile deleted from system',
      );
    } catch (e) {
      debugPrint('Error deleting moderator: $e');
      rethrow;
    }
  }

  Future<void> approvePendingDevice(String moderatorId) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', moderatorId).maybeSingle();
      if (doc != null) {
        final pendingDevice = Moderator.fromMap(doc).pendingDevice;
        if (pendingDevice != null) {
          final approved = List<Map<String, dynamic>>.from(Moderator.fromMap(doc).approvedDevices);
          approved.add(pendingDevice);

          await _client.from('moderators').update({
            'approved_devices': approved,
            'pending_device': null,
            'status': 'active',
          }).eq('id', moderatorId);

          await logActivity(
            moderatorId: moderatorId,
            moderatorName: '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim(),
            action: 'DEVICE_APPROVED',
            details: 'New device approved by admin: ${pendingDevice['model'] ?? 'Device'}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error approving pending device: $e');
    }
  }

  Future<void> rejectPendingDevice(String moderatorId) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', moderatorId).maybeSingle();
      if (doc != null) {
        await _client.from('moderators').update({
          'pending_device': null,
          'status': 'active',
        }).eq('id', moderatorId);

        await logActivity(
          moderatorId: moderatorId,
          moderatorName: '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim(),
          action: 'DEVICE_REJECTED',
          details: 'Device access request rejected by admin',
        );
      }
    } catch (e) {
      debugPrint('Error rejecting pending device: $e');
    }
  }

  Future<void> removeDevice(String moderatorId, String deviceId) async {
    try {
      final doc = await _client.from('moderators').select().eq('id', moderatorId).maybeSingle();
      if (doc != null) {
        final devices = List<Map<String, dynamic>>.from(Moderator.fromMap(doc).approvedDevices);
        final deviceToRemove = devices.firstWhere((device) => device['id'] == deviceId, orElse: () => {});
        final updatedDevices = devices.where((device) => device['id'] != deviceId).toList();

        await _client.from('moderators').update({
          'approved_devices': updatedDevices,
        }).eq('id', moderatorId);

        await logActivity(
          moderatorId: moderatorId,
          moderatorName: '${doc['first_name'] ?? doc['firstName'] ?? ''} ${doc['last_name'] ?? doc['lastName'] ?? ''}'.trim(),
          action: 'DEVICE_REMOVED',
          details: 'Device removed by admin: ${deviceToRemove['model'] ?? 'Unknown device'}',
        );
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // SUGGESTIONS
  // ---------------------------------------------------------------------------

  Future<void> addLyricSuggestion(Suggestion suggestion) async {
    try {
      await _client.from('suggestions').insert(suggestion.toSupabase());
    } catch (e) {
      debugPrint('Error adding lyric suggestion: $e');
      rethrow;
    }
  }

  Stream<List<Suggestion>> getSuggestionsStream() {
    return _client
        .from('suggestions')
        .stream(primaryKey: ['id'])
        .order('submitted_at', ascending: false)
        .map((maps) => maps.map((item) => Suggestion.fromMap(item)).toList());
  }

  Future<void> updateSuggestionStatus(String id, SuggestionStatus status) async {
    try {
      await _client.from('suggestions').update({'status': status.name}).eq('id', id);
    } catch (e) {
      debugPrint('Error updating suggestion status: $e');
      rethrow;
    }
  }

  Future<void> deleteSuggestion(String id) async {
    try {
      await _client.from('suggestions').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting suggestion: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // ACTIVITY LOGS
  // ---------------------------------------------------------------------------

  Future<void> logActivity({
    required String moderatorId,
    required String moderatorName,
    required String action,
    required String details,
  }) async {
    try {
      final log = ActivityLog(
        id: '',
        moderatorId: moderatorId,
        moderatorName: moderatorName,
        action: action,
        details: details,
        timestamp: DateTime.now(),
      );
      await _client.from('activity_logs').insert(log.toSupabase());
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Stream<List<ActivityLog>> getActivityLogsStream() {
    return _client
        .from('activity_logs')
        .stream(primaryKey: ['id'])
        .order('timestamp', ascending: false)
        .map((maps) => maps.map((item) => ActivityLog.fromMap(item)).toList());
  }

  Future<void> markAllActivitiesAsSeen() async {
    try {
      await _client.from('activity_logs').update({'is_seen': true}).eq('is_seen', false);
    } catch (e) {
      debugPrint('Error marking activities as seen: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // INVITATIONS & INVITE CODES
  // ---------------------------------------------------------------------------

  Future<String> createInvitation({
    required String email,
    required String firstName,
    required String lastName,
    required String adminId,
    String role = 'moderator',
  }) async {
    try {
      // High entropy unambiguous alphanumeric characters (excludes 0, O, 1, I)
      const chars = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
      final random = Random.secure();
      String code;

      do {
        final part1 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
        final part2 = List.generate(4, (_) => chars[random.nextInt(chars.length)]).join();
        code = 'MS-$part1-$part2';
      } while (await _invitationCodeExists(code));

      final newInvitation = Invitation(
        id: '',
        code: code,
        email: email.trim().toLowerCase(),
        firstName: firstName.trim(),
        lastName: lastName.trim(),
        role: role,
        status: 'pending',
        createdAt: DateTime.now(),
        createdBy: adminId,
      );

      await _client.from('invitations').insert(newInvitation.toSupabase());

      await logActivity(
        moderatorId: adminId,
        moderatorName: 'Admin',
        action: 'INVITATION_CREATED',
        details: 'Generated ${role.toUpperCase()} invite code for ${newInvitation.email} ($code)',
      );

      return code;
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      rethrow;
    }
  }

  Future<bool> _invitationCodeExists(String code) async {
    try {
      final normalized = code.replaceAll('-', '').trim().toUpperCase();
      final res = await _client.from('invitations').select('id, code').limit(100);
      for (final row in (res as List)) {
        final existing = (row['code'] ?? '').toString().replaceAll('-', '').trim().toUpperCase();
        if (existing == normalized) return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error checking invitation code existence: $e');
      return true;
    }
  }

  Future<Invitation?> getInvitationByCode(String inputCode) async {
    try {
      final normalizedInput = inputCode.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
      if (normalizedInput.isEmpty) return null;

      // 1. Try exact match on code
      final exactRes = await _client
          .from('invitations')
          .select()
          .ilike('code', inputCode.trim())
          .maybeSingle();

      if (exactRes != null) {
        return Invitation.fromMap(exactRes);
      }

      // 2. Query all invitations and match normalized input
      final listRes = await _client
          .from('invitations')
          .select();

      for (final item in (listRes as List)) {
        final dbCode = (item['code'] ?? '').toString().replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
        if (dbCode == normalizedInput) {
          return Invitation.fromMap(item);
        }
      }

      return null;
    } catch (e) {
      debugPrint('Error getting invitation by code: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>?> claimModeratorAccountRpc({
    required String email,
    required String password,
    required String code,
    Map<String, dynamic>? deviceInfo,
    String? userId,
  }) async {
    try {
      final res = await _client.rpc('claim_moderator_account', params: {
        'p_email': email.trim().toLowerCase(),
        'p_password': password.trim(),
        'p_code': code.trim().toUpperCase(),
        'p_device_info': deviceInfo,
        if (userId != null) 'p_user_id': userId,
      });
      if (res is Map) {
        return Map<String, dynamic>.from(res);
      }
      return null;
    } on PostgrestException catch (e) {
      debugPrint('claim_moderator_account PostgrestException: ${e.message} (code: ${e.code}, details: ${e.details})');
      return {'success': false, 'error': e.message, 'code': e.code};
    } catch (e) {
      debugPrint('claim_moderator_account RPC error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> claimInvitation(String invitationId, String moderatorUid) async {
    try {
      await _client.from('invitations').update({
        'status': 'claimed',
        'claimed_by': moderatorUid,
        'claimed_at': DateTime.now().toIso8601String(),
      }).eq('id', invitationId);
    } catch (e) {
      debugPrint('Error claiming invitation: $e');
    }
  }

  Future<void> confirmUserEmail(String userId) async {
    try {
      await _client.rpc('confirm_user_email', params: {'user_id': userId});
    } catch (e) {
      debugPrint('confirm_user_email RPC info: $e');
    }
  }

  Stream<List<Invitation>> getInvitationsStream() {
    return _client
        .from('invitations')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((list) => list.map((item) => Invitation.fromMap(item)).toList());
  }

  Future<void> deleteInvitation(String invitationId) async {
    try {
      await _client.from('invitations').delete().eq('id', invitationId);
    } catch (e) {
      debugPrint('Error deleting invitation: $e');
      rethrow;
    }
  }

  Future<void> revokeInvitation(String invitationId) async {
    try {
      await _client.from('invitations').update({'status': 'revoked'}).eq('id', invitationId);
    } catch (e) {
      debugPrint('Error revoking invitation: $e');
      rethrow;
    }
  }

  // Legacy Invite Codes stream
  Stream<List<Map<String, dynamic>>> getInviteCodesStream() {
    return _client
        .from('invite_codes')
        .stream(primaryKey: ['code'])
        .order('created_at', ascending: false);
  }

  Future<void> createInviteCode(String code) async {
    await _client.from('invite_codes').insert({
      'code': code,
      'used': false,
      'used_by': null,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // ---------------------------------------------------------------------------
  // FCM DEVICE TOKENS (Stored in Supabase table `user_fcm_tokens`)
  // ---------------------------------------------------------------------------

  Future<void> saveUserFcmToken({
    required String token,
    String? userId,
    Map<String, dynamic>? deviceInfo,
  }) async {
    try {
      await _client.from('user_fcm_tokens').upsert({
        'token': token,
        'user_id': userId,
        'device_info': deviceInfo,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'token');
      debugPrint('FCM token synchronized with Supabase user_fcm_tokens');
    } catch (e) {
      debugPrint('Error saving FCM token to Supabase: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // APP SETTINGS / REPAIR MODE
  // ---------------------------------------------------------------------------

  Stream<bool>? _repairModeStream;
  bool _lastKnownRepairMode = false;

  bool get lastKnownRepairMode => _lastKnownRepairMode;

  Future<bool> getRepairMode() async {
    try {
      final res = await _client.from('app_settings').select('is_repair_mode');
      if (res.isNotEmpty) {
        _lastKnownRepairMode = res.any((m) => m['is_repair_mode'] == true);
      } else {
        _lastKnownRepairMode = false;
      }
      return _lastKnownRepairMode;
    } catch (e) {
      debugPrint('Error getting repair mode: $e');
      return _lastKnownRepairMode;
    }
  }

  Stream<bool> getRepairModeStream() {
    _repairModeStream ??= _client
        .from('app_settings')
        .stream(primaryKey: ['id'])
        .map((maps) {
          final isRepair = maps.isNotEmpty ? (maps.any((m) => m['is_repair_mode'] == true)) : false;
          _lastKnownRepairMode = isRepair;
          return isRepair;
        })
        .asBroadcastStream();
    return _repairModeStream!;
  }

  Future<void> setRepairMode(bool isRepairMode, String adminId, String adminName) async {
    try {
      _lastKnownRepairMode = isRepairMode;
      final res = await _client.from('app_settings').select();
      if (res.isNotEmpty) {
        // Update all rows in app_settings to ensure consistency across any duplicate rows
        for (final row in res) {
          await _client.from('app_settings').update({
            'is_repair_mode': isRepairMode,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', row['id']);
        }
      } else {
        await _client.from('app_settings').insert({
          'is_repair_mode': isRepairMode,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await logActivity(
        moderatorId: adminId,
        moderatorName: adminName,
        action: 'REPAIR_MODE_TOGGLED',
        details: 'Repair mode turned ${isRepairMode ? "ON" : "OFF"}',
      );
    } catch (e) {
      debugPrint('Error setting repair mode: $e');
      rethrow;
    }
  }
}

/// Helper snapshot object to mimic Firestore DocumentSnapshot for existing listeners
class _SupabaseDocSnapshot {
  final String id;
  final Map<String, dynamic>? dataMap;

  _SupabaseDocSnapshot({required this.id, required this.dataMap});

  bool get exists => dataMap != null;
  Map<String, dynamic> data() => dataMap ?? {};
}
