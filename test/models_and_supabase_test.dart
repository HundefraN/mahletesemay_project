import 'package:flutter_test/flutter_test.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:mahlete_semay_project/models/moderator_model.dart';
import 'package:mahlete_semay_project/models/suggestion_model.dart';
import 'package:mahlete_semay_project/models/activity_log_model.dart';
import 'package:mahlete_semay_project/models/invitation_model.dart';

void main() {
  group('Supabase Model Serialization Tests', () {
    test('Artist model parses snake_case and camelCase', () {
      final map = {
        'id': 'artist_1',
        'name': 'Ephrem Tamiru',
        'image_url': 'https://example.com/img.jpg',
        'region': 'Shoa',
      };
      final artist = Artist.fromMap(map);
      expect(artist.id, 'artist_1');
      expect(artist.name, 'Ephrem Tamiru');
      expect(artist.imageUrl, 'https://example.com/img.jpg');
      expect(artist.region, 'Shoa');

      final supa = artist.toSupabase();
      expect(supa['image_url'], 'https://example.com/img.jpg');
    });

    test('Song model parses date and view count correctly', () {
      final now = DateTime.now();
      final map = {
        'id': 'song_1',
        'title': 'Test Song',
        'artist_name': 'Test Artist',
        'artist_id': 'art_1',
        'album_id': 'alb_1',
        'album_title': 'Test Album',
        'lyrics': 'Sample lyrics',
        'scale': '1st (Major Scale)',
        'rhythm': 'Waltz',
        'view_count': 42,
        'created_at': now.toIso8601String(),
      };
      final song = Song.fromMap(map);
      expect(song.id, 'song_1');
      expect(song.viewCount, 42);
      expect(song.scale, '1st (Major Scale)');
      expect(song.createdAt.year, now.year);
    });

    test('Moderator model parses approved devices and pending device', () {
      final map = {
        'id': 'user_123',
        'email': 'admin@test.com',
        'first_name': 'John',
        'last_name': 'Doe',
        'username': 'john.doe',
        'role': 'admin',
        'status': 'active',
        'approved_devices': [
          {'id': 'dev_1', 'model': 'Pixel 8'}
        ],
        'pending_device': {'id': 'dev_2', 'model': 'iPhone 15'},
        'last_login': '2026-08-18T10:00:00.000Z',
        'created_at': '2026-01-01T00:00:00.000Z',
      };
      final moderator = Moderator.fromMap(map);
      expect(moderator.id, 'user_123');
      expect(moderator.fullName, 'John Doe');
      expect(moderator.approvedDevices.length, 1);
      expect(moderator.pendingDevice?['model'], 'iPhone 15');
      expect(moderator.role, 'admin');
    });

    test('Invitation model parses role and claimed properties', () {
      final map = {
        'id': 'inv_1',
        'code': 'MS-7K9P-2X4W',
        'email': 'mod@test.com',
        'first_name': 'Sarah',
        'last_name': 'Connor',
        'role': 'admin',
        'status': 'pending',
        'created_by': 'admin_id',
        'created_at': '2026-08-18T12:00:00.000Z',
      };
      final inv = Invitation.fromMap(map);
      expect(inv.id, 'inv_1');
      expect(inv.code, 'MS-7K9P-2X4W');
      expect(inv.role, 'admin');
      expect(inv.fullName, 'Sarah Connor');
      expect(inv.status, 'pending');

      final supa = inv.toSupabase();
      expect(supa['role'], 'admin');
      expect(supa['code'], 'MS-7K9P-2X4W');
    });

    test('Suggestion and ActivityLog parse statuses and timestamps', () {
      final sugMap = {
        'id': 'sug_1',
        'song_title': 'New Melody',
        'artist_name': 'Singer',
        'lyrics': 'Lyrics here',
        'submitted_by': 'user_1',
        'submitted_at': '2026-08-18T12:00:00.000Z',
        'status': 'pending',
      };
      final suggestion = Suggestion.fromMap(sugMap);
      expect(suggestion.status, SuggestionStatus.pending);
      expect(suggestion.songTitle, 'New Melody');

      final logMap = {
        'id': 'log_1',
        'moderator_id': 'm_1',
        'moderator_name': 'Mod Name',
        'action': 'CREATE_SONG',
        'details': 'Added song',
        'is_seen': false,
        'created_at': '2026-08-18T12:00:00.000Z',
      };
      final log = ActivityLog.fromMap(logMap);
      expect(log.action, 'CREATE_SONG');
      expect(log.isSeen, false);
    });

    test('toLocalDbMap formats maps matching SQLite schema exactly', () {
      final artist = Artist(
          id: 'a1',
          name: 'Singer',
          imageUrl: 'http://img.jpg',
          region: 'Ethiopian');
      final artistMap = artist.toLocalDbMap();
      expect(artistMap.keys.toSet(), {
        'id',
        'name',
        'englishName',
        'imageUrl',
        'region',
        'search_keywords',
      });

      final album = Album(
          id: 'al1',
          title: 'Album 1',
          artistId: 'a1',
          artistName: 'Singer',
          coverImageUrl: 'http://cov.jpg',
          year: 2024,
          volume: 1);
      final albumMap = album.toLocalDbMap();
      expect(albumMap.keys.toSet(), {
        'id',
        'title',
        'englishTitle',
        'artistId',
        'artistName',
        'coverImageUrl',
        'year',
        'volume',
        'search_keywords',
      });

      final song = Song(
          id: 's1',
          title: 'Song 1',
          artistName: 'Singer',
          artistId: 'a1',
          albumId: 'al1',
          albumTitle: 'Album 1',
          lyrics: 'Test',
          viewCount: 10,
          createdAt: DateTime.now(),
          scale: 'Major',
          rhythm: 'Slow');
      final songMap = song.toLocalDbMap();
      expect(songMap.keys.toSet(), {
        'id',
        'title',
        'englishTitle',
        'artistName',
        'artistId',
        'albumId',
        'albumTitle',
        'lyrics',
        'scale',
        'rhythm',
        'viewCount',
        'createdAt',
        'search_keywords',
      });
      expect(songMap['createdAt'], isA<int>());
    });
  });
}
