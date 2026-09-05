import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/activity_log_model.dart';
import '../models/album_model.dart';
import '../models/app_config_model.dart';
import '../models/artist_model.dart';
import '../models/bug_report_model.dart';
import '../models/invitation_model.dart';
import '../models/moderator_model.dart';
import '../models/song_model.dart';
import '../models/suggestion_model.dart';
import '../models/vocal_plan_model.dart';
import '../utils/amharic_transliterator.dart';
import '../utils/constants.dart';
import 'push_dispatch_service.dart';
import 'push_payload.dart';

class SupabaseService {
  static final SupabaseService _instance = SupabaseService._internal();
  factory SupabaseService() => _instance;
  SupabaseService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  static final Map<String, DateTime> _lastStreamErrorLog = {};
  bool _singlesCatalogReady = false;

  static void _logStreamErrorThrottled(String key, dynamic error) {
    final now = DateTime.now();
    final lastLog = _lastStreamErrorLog[key];
    if (lastLog == null || now.difference(lastLog).inSeconds >= 15) {
      _lastStreamErrorLog[key] = now;
      debugPrint('SupabaseService: Realtime stream connection notice [$key]: $error');
    }
  }

  // ---------------------------------------------------------------------------
  // ARTISTS
  // ---------------------------------------------------------------------------

  Stream<List<Artist>> getArtistsStream() {
    return _client
        .from('artists')
        .stream(primaryKey: ['id'])
        .map((maps) => maps
            .where((item) => item['id']?.toString() != singlesArtistId)
            .map((item) => Artist.fromMap(item))
            .toList())
        .handleError((e) {
          _logStreamErrorThrottled('artists', e);
        });
  }

  Future<List<Artist>> getArtists() async {
    try {
      final response = await _client.from('artists').select();
      debugPrint('Fetched ${response.length} artists from Supabase');
      return (response as List)
          .map((item) => Artist.fromMap(item as Map<String, dynamic>))
          .where((artist) => artist.id != singlesArtistId)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting artists: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addArtist(Artist artist) async {
    try {
      await _client.from('artists').insert(artist.toSupabase());
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.artist,
        entityId: artist.id,
        silent: true,
      ));
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
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.artist,
        entityId: id,
        silent: true,
      ));
    } catch (e) {
      debugPrint('Error updating artist: $e');
      rethrow;
    }
  }

  Future<void> deleteArtists(List<String> ids) async {
    try {
      final deletableIds = ids.where((id) => id != singlesArtistId).toList();
      if (deletableIds.isEmpty) return;
      await _client.from('artists').delete().inFilter('id', deletableIds);
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.artist,
        silent: true,
      ));
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
        .map((maps) => maps
            .where((item) => item['id']?.toString() != singlesAlbumId)
            .map((item) => Album.fromMap(item))
            .toList())
        .handleError((e) {
          _logStreamErrorThrottled('albums', e);
        });
  }

  Future<List<Album>> getAlbums() async {
    try {
      final response = await _client.from('albums').select();
      debugPrint('Fetched ${response.length} albums from Supabase');
      return (response as List)
          .map((item) => Album.fromMap(item as Map<String, dynamic>))
          .where((album) => album.id != singlesAlbumId)
          .toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting albums: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addAlbum(Album album) async {
    try {
      await _client.from('albums').insert(album.toSupabase());
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.album,
        entityId: album.id,
        silent: true,
      ));
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
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.album,
        entityId: id,
        silent: true,
      ));
    } catch (e) {
      debugPrint('Error updating album: $e');
      rethrow;
    }
  }

  Future<void> deleteAlbums(List<String> ids) async {
    try {
      final deletableIds = ids.where((id) => id != singlesAlbumId).toList();
      if (deletableIds.isEmpty) return;
      await _client.from('albums').delete().inFilter('id', deletableIds);
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.album,
        silent: true,
      ));
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
        .map((maps) => maps.map((item) => Song.fromMap(item)).toList())
        .handleError((e) {
          _logStreamErrorThrottled('songs', e);
        });
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

  /// Creates the placeholder "Singles" artist/album used by standalone releases.
  /// Songs reference these IDs, so they must exist before insert/update.
  Future<void> ensureSinglesCatalog() async {
    if (_singlesCatalogReady) return;
    try {
      await _client.from('artists').upsert(
        {
          'id': singlesArtistId,
          'name': 'Various Artists',
          'english_name': 'Various Artists',
          'image_url': '',
          'region': '',
          'search_keywords': ['singles', 'various artists'],
        },
        onConflict: 'id',
        ignoreDuplicates: true,
      );
      await _client.from('albums').upsert(
        {
          'id': singlesAlbumId,
          'title': 'Singles',
          'english_title': 'Singles',
          'artist_id': singlesArtistId,
          'artist_name': 'Various Artists',
          'cover_image_url': '',
          'search_keywords': ['singles'],
        },
        onConflict: 'id',
        ignoreDuplicates: true,
      );
      _singlesCatalogReady = true;
    } catch (e) {
      debugPrint('Error ensuring singles catalog: $e');
      rethrow;
    }
  }

  Future<void> _prepareSongPayload(Map<String, dynamic> payload) async {
    if (payload['album_id'] is String && (payload['album_id'] as String).isEmpty) {
      payload['album_id'] = null;
    }
    if (payload['artist_id'] is String && (payload['artist_id'] as String).isEmpty) {
      payload['artist_id'] = null;
    }

    final albumId = payload['album_id']?.toString();
    final artistId = payload['artist_id']?.toString();
    if (albumId == singlesAlbumId || artistId == singlesArtistId) {
      await ensureSinglesCatalog();
    }
  }

  Future<void> addSong(Song song) async {
    try {
      final payload = song.toSupabase();
      await _prepareSongPayload(payload);
      await _client.from('songs').insert(payload);
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.song,
        entityId: song.id,
        silent: false,
        title: 'New Song Available',
        body: '"${song.title}" by ${song.artistName} is now in your library.',
        reference: song.id,
      ));
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

      await _prepareSongPayload(payload);
      await _client.from('songs').update(payload).eq('id', id);
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.song,
        entityId: id,
        silent: true,
      ));
    } catch (e) {
      debugPrint('Error updating song: $e');
      rethrow;
    }
  }

  Future<void> deleteSongs(List<String> ids) async {
    try {
      if (ids.isEmpty) return;
      await _client.from('songs').delete().inFilter('id', ids);
      unawaited(PushDispatchService.notifyContentChange(
        entity: PushEntity.song,
        silent: true,
      ));
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
  // BUG & CRASH REPORTS
  // ---------------------------------------------------------------------------

  Future<void> submitBugReport(BugReport report) async {
    try {
      await _client.from('bug_reports').insert(report.toSupabase());
    } catch (e) {
      debugPrint('Error submitting bug report: $e');
      rethrow;
    }
  }

  Stream<List<BugReport>> getBugReportsStream() {
    return _client
        .from('bug_reports')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: false)
        .map((maps) => maps.map((item) => BugReport.fromMap(item)).toList());
  }

  Future<void> updateBugReport({
    required String id,
    BugReportStatus? status,
    String? adminNotes,
    bool? isSeen,
  }) async {
    try {
      final data = <String, dynamic>{
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (status != null) data['status'] = status.dbValue;
      if (adminNotes != null) data['admin_notes'] = adminNotes;
      if (isSeen != null) data['is_seen'] = isSeen;
      await _client.from('bug_reports').update(data).eq('id', id);
    } catch (e) {
      debugPrint('Error updating bug report: $e');
      rethrow;
    }
  }

  Future<void> markAllBugReportsAsSeen() async {
    try {
      await _client.from('bug_reports').update({'is_seen': true}).eq('is_seen', false);
    } catch (e) {
      debugPrint('Error marking bug reports as seen: $e');
    }
  }

  Future<void> deleteBugReport(String id) async {
    try {
      await _client.from('bug_reports').delete().eq('id', id);
    } catch (e) {
      debugPrint('Error deleting bug report: $e');
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

  Future<Invitation?> getInvitationByCode(String inputCode, {String? email}) async {
    try {
      final normalizedInput = inputCode.replaceAll('-', '').replaceAll(' ', '').trim().toUpperCase();
      if (normalizedInput.isEmpty) return null;

      // SECURITY DEFINER RPC works for anonymous claimers; table SELECT is admin-only.
      try {
        final rpcRes = await _client.rpc('lookup_invitation_for_claim', params: {
          'p_code': inputCode.trim(),
          'p_email': email?.trim().toLowerCase() ?? '',
        });
        if (rpcRes is Map) {
          final map = Map<String, dynamic>.from(rpcRes);
          if (map['success'] == true) {
            return Invitation.fromMap(map);
          }
        }
      } catch (e) {
        debugPrint('lookup_invitation_for_claim RPC info: $e');
      }

      // Fallback for databases that still allow invitation SELECT
      final exactRes = await _client
          .from('invitations')
          .select()
          .ilike('code', inputCode.trim())
          .maybeSingle();

      if (exactRes != null) {
        return Invitation.fromMap(exactRes);
      }

      final listRes = await _client.from('invitations').select();
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

  Future<bool> repairAuthUsersSchema() async {
    try {
      await _client.rpc('repair_auth_users_schema');
      return true;
    } catch (e) {
      debugPrint('repair_auth_users_schema RPC info: $e');
      return false;
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
        .handleError((e) {
          debugPrint('Error in getRepairModeStream: $e');
          return _lastKnownRepairMode;
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

  // ---------------------------------------------------------------------------
  // FORCE UPDATE — minimum app version
  // ---------------------------------------------------------------------------
  // APP CONFIG & FORCE UPDATE RELEASES
  // ---------------------------------------------------------------------------

  /// Fetches the latest [AppConfigModel] from Supabase `app_config` table.
  /// Falls back to `app_settings` for `min_required_version` if `app_config` is empty or unreachable.
  Future<AppConfigModel?> getAppConfig({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    try {
      final res = await _client
          .from('app_config')
          .select()
          .order('updated_at', ascending: false)
          .limit(1)
          .timeout(timeout);

      if (res.isNotEmpty) {
        return AppConfigModel.fromJson(res.first);
      }

      // Fallback to legacy app_settings if app_config not yet populated
      final legacyMinVersion = await getMinRequiredVersion();
      if (legacyMinVersion != null) {
        return AppConfigModel(
          id: 'default',
          latestVersion: legacyMinVersion,
          minRequiredVersion: legacyMinVersion,
          forceUpdate: false,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching app_config: $e');
      return null;
    }
  }

  /// Realtime stream of the latest [AppConfigModel] from `app_config` table.
  Stream<AppConfigModel?> getAppConfigStream() {
    return _client
        .from('app_config')
        .stream(primaryKey: ['id'])
        .order('updated_at', ascending: false)
        .limit(1)
        .map((rows) {
          if (rows.isNotEmpty) {
            return AppConfigModel.fromJson(rows.first);
          }
          return null;
        })
        .handleError((error) {
          _logStreamErrorThrottled('app_config', error);
        });
  }

  /// Saves or updates the release configuration in `app_config` table.
  /// Also mirrors `min_required_version` to `app_settings` for legacy consistency.
  ///
  /// When [notifyUsers] is true, every registered device receives a visible
  /// "please update" push. Push failure does not roll back the saved config.
  Future<PushSendResult?> saveAppConfig(
    AppConfigModel config,
    String adminId,
    String adminName, {
    bool notifyUsers = true,
  }) async {
    try {
      final data = {
        'id': config.id.isEmpty ? 'default' : config.id,
        'latest_version': config.latestVersion?.trim().isEmpty == true ? null : config.latestVersion?.trim(),
        'min_required_version': config.minRequiredVersion?.trim().isEmpty == true ? null : config.minRequiredVersion?.trim(),
        'apk_url': config.apkUrl?.trim().isEmpty == true ? null : config.apkUrl?.trim(),
        'release_notes': config.releaseNotes?.trim().isEmpty == true ? null : config.releaseNotes?.trim(),
        'force_update': config.forceUpdate,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _client.from('app_config').upsert(data);

      // Mirror to legacy app_settings table as well
      try {
        final res = await _client.from('app_settings').select('id');
        if (res.isNotEmpty) {
          for (final row in res) {
            await _client.from('app_settings').update({
              'min_required_version': config.minRequiredVersion,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            }).eq('id', row['id']);
          }
        } else {
          await _client.from('app_settings').insert({
            'min_required_version': config.minRequiredVersion,
            'is_repair_mode': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          });
        }
      } catch (e) {
        debugPrint('Notice: could not mirror to app_settings: $e');
      }

      await logActivity(
        moderatorId: adminId,
        moderatorName: adminName,
        action: 'APP_RELEASE_UPDATED',
        details: 'Release updated: latest=${config.latestVersion}, min_required=${config.minRequiredVersion}, force=${config.forceUpdate}',
      );

      if (!notifyUsers) return null;

      return PushDispatchService.notifyForceUpdate(
        forceUpdate: config.forceUpdate,
        latestVersion: config.latestVersion,
        minRequiredVersion: config.minRequiredVersion,
        apkUrl: config.apkUrl,
        releaseNotes: config.releaseNotes,
      ).timeout(
        const Duration(seconds: 45),
        onTimeout: () => const PushSendResult(
          ok: false,
          error: 'Push timed out. The release was saved.',
        ),
      );
    } catch (e) {
      debugPrint('Error saving app_config: $e');
      rethrow;
    }
  }

  /// Fetches the `min_required_version` value from the `app_config` table (falling back to `app_settings`).
  Future<String?> getMinRequiredVersion() async {
    try {
      final res = await _client
          .from('app_config')
          .select('min_required_version, updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .timeout(const Duration(milliseconds: 2000));
      if (res.isNotEmpty && res.first['min_required_version'] != null) {
        final version = res.first['min_required_version'].toString().trim();
        if (version.isNotEmpty) return version;
      }
    } catch (_) {
      // Fall through to app_settings
    }

    try {
      final res = await _client
          .from('app_settings')
          .select('min_required_version, updated_at')
          .order('updated_at', ascending: false)
          .limit(1)
          .timeout(const Duration(milliseconds: 2000));
      if (res.isNotEmpty && res.first['min_required_version'] != null) {
        final version = res.first['min_required_version'].toString().trim();
        return version.isEmpty ? null : version;
      }
      return null;
    } catch (e) {
      debugPrint('Error fetching min_required_version: $e');
      return null;
    }
  }

  /// Sets or clears the `min_required_version` in the `app_settings` and `app_config` tables.
  /// Pass `null` or empty string to disable the force-update requirement.
  Future<void> setMinRequiredVersion(String? version, String adminId, String adminName) async {
    try {
      final sanitized = (version == null || version.trim().isEmpty) ? null : version.trim();
      
      // Update app_config
      try {
        final current = await getAppConfig();
        final updated = (current ?? const AppConfigModel(id: 'default')).copyWith(
          minRequiredVersion: sanitized,
        );
        await saveAppConfig(
          updated,
          adminId,
          adminName,
          notifyUsers: false,
        );
      } catch (e) {
        debugPrint('Notice updating app_config in setMinRequiredVersion: $e');
      }

      final res = await _client.from('app_settings').select('id');
      if (res.isNotEmpty) {
        for (final row in res) {
          await _client.from('app_settings').update({
            'min_required_version': sanitized,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          }).eq('id', row['id']);
        }
      } else {
        await _client.from('app_settings').insert({
          'min_required_version': sanitized,
          'is_repair_mode': false,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }

      await logActivity(
        moderatorId: adminId,
        moderatorName: adminName,
        action: 'MIN_VERSION_UPDATED',
        details: 'Minimum required version set to ${sanitized ?? "NONE (Disabled)"}',
      );
    } catch (e) {
      debugPrint('Error setting min_required_version: $e');
      rethrow;
    }
  }

  // ---------------------------------------------------------------------------
  // DUPLICATE DETECTION QUERIES
  // ---------------------------------------------------------------------------

  /// Find songs matching the given title (case-insensitive).
  /// Optionally filter by artistId and/or albumId for tighter matches.
  Future<List<Song>> findSongDuplicates({
    required String title,
    String? artistId,
    String? albumId,
  }) async {
    try {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return [];

      // Fetch songs with matching title (case-insensitive via ilike)
      var query = _client.from('songs').select().ilike('title', trimmed);

      // If artistId provided, add that filter for exact-match results
      if (artistId != null && artistId.isNotEmpty) {
        query = query.eq('artist_id', artistId);
      }
      if (albumId != null && albumId.isNotEmpty) {
        query = query.eq('album_id', albumId);
      }

      final response = await query;
      return (response as List)
          .map((item) => Song.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error finding song duplicates: $e');
      return [];
    }
  }

  /// Find albums matching the given title (case-insensitive).
  /// Optionally filter by artistId for tighter matches.
  Future<List<Album>> findAlbumDuplicates({
    required String title,
    String? artistId,
  }) async {
    try {
      final trimmed = title.trim();
      if (trimmed.isEmpty) return [];

      var query = _client.from('albums').select().ilike('title', trimmed);

      if (artistId != null && artistId.isNotEmpty) {
        query = query.eq('artist_id', artistId);
      }

      final response = await query;
      return (response as List)
          .map((item) => Album.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error finding album duplicates: $e');
      return [];
    }
  }

  /// Find artists matching the given name (case-insensitive).
  /// Optionally filter by region for tighter matches.
  Future<List<Artist>> findArtistDuplicates({
    required String name,
    String? region,
  }) async {
    try {
      final trimmed = name.trim();
      if (trimmed.isEmpty) return [];

      var query = _client.from('artists').select().ilike('name', trimmed);

      if (region != null && region.isNotEmpty) {
        query = query.eq('region', region);
      }

      final response = await query;
      return (response as List)
          .map((item) => Artist.fromMap(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error finding artist duplicates: $e');
      return [];
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
