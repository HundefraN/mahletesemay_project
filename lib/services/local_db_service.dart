import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/setlist_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:mahlete_semay_project/utils/amharic_transliterator.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static Database? _database;

  static const String _webSetlistsPrefKey = 'web_user_setlists_v1';
  static const String _webSetlistSongsPrefKey = 'web_user_setlist_songs_v1';

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = p.join(await getDatabasesPath(), 'mahlete_semay.db');
    return await openDatabase(
      path,
      version: 3,
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS setlists(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
      await db.execute('''
        CREATE TABLE IF NOT EXISTS setlist_songs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          setlistId INTEGER NOT NULL,
          songId TEXT NOT NULL,
          orderIndex INTEGER NOT NULL,
          customKey TEXT,
          notes TEXT,
          FOREIGN KEY (setlistId) REFERENCES setlists (id) ON DELETE CASCADE
        )
      ''');
    }

    if (oldVersion < 3) {
      Future<void> addColumnSafely(String table, String colDef) async {
        try {
          await db.execute('ALTER TABLE $table ADD COLUMN $colDef');
        } catch (_) {}
      }

      await addColumnSafely('artists', 'englishName TEXT');
      await addColumnSafely('artists', 'search_keywords TEXT');
      await addColumnSafely('albums', 'englishTitle TEXT');
      await addColumnSafely('albums', 'search_keywords TEXT');
      await addColumnSafely('songs', 'englishTitle TEXT');
      await addColumnSafely('songs', 'search_keywords TEXT');
    }
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE artists(
        id TEXT PRIMARY KEY,
        name TEXT,
        englishName TEXT,
        imageUrl TEXT,
        region TEXT,
        search_keywords TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE albums(
        id TEXT PRIMARY KEY,
        title TEXT,
        englishTitle TEXT,
        artistId TEXT,
        artistName TEXT,
        coverImageUrl TEXT,
        year INTEGER,
        volume INTEGER,
        search_keywords TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE songs(
        id TEXT PRIMARY KEY,
        title TEXT,
        englishTitle TEXT,
        artistName TEXT,
        artistId TEXT,
        albumId TEXT,
        albumTitle TEXT,
        lyrics TEXT,
        scale TEXT,
        rhythm TEXT,
        viewCount INTEGER,
        createdAt INTEGER,
        search_keywords TEXT
      )
    ''');
    await db.execute('''
        CREATE TABLE setlists(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          createdAt INTEGER NOT NULL
        )
      ''');
    await db.execute('''
        CREATE TABLE setlist_songs(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          setlistId INTEGER NOT NULL,
          songId TEXT NOT NULL,
          orderIndex INTEGER NOT NULL,
          customKey TEXT,
          notes TEXT,
          FOREIGN KEY (setlistId) REFERENCES setlists (id) ON DELETE CASCADE
        )
      ''');
  }

  Future<void> syncArtists(List<Artist> artists) async {
    if (kIsWeb) return;
    final db = await database;
    Batch batch = db.batch();
    batch.delete('artists');
    for (var artist in artists) {
      batch.insert('artists', artist.toLocalDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncAlbums(List<Album> albums) async {
    if (kIsWeb) return;
    final db = await database;
    Batch batch = db.batch();
    batch.delete('albums');
    for (var album in albums) {
      batch.insert('albums', album.toLocalDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncSongs(List<Song> songs) async {
    if (kIsWeb) return;
    final db = await database;
    Batch batch = db.batch();
    batch.delete('songs');
    for (var song in songs) {
      batch.insert('songs', song.toLocalDbMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Artist>> getArtists() async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('artists');
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final name = map['name']?.toString() ?? '';
      final engName = map['englishName']?.toString() ??
          (AmharicTransliterator.containsAmharic(name)
              ? AmharicTransliterator.toLatin(name)
              : '');

      final kwRaw = map['search_keywords']?.toString() ?? '';
      final keywords = kwRaw.isNotEmpty
          ? kwRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : AmharicTransliterator.generateSearchKeywords(
              title: name,
              englishTitle: engName,
              subtitleOrArtist: map['region']?.toString(),
            );

      return Artist(
        id: map['id']?.toString() ?? '',
        name: name,
        englishName: engName,
        imageUrl: map['imageUrl']?.toString() ?? '',
        region: map['region']?.toString() ?? '',
        searchKeywords: keywords,
      );
    });
  }

  Future<List<Album>> getAlbums() async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('albums');
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final title = map['title']?.toString() ?? '';
      final engTitle = map['englishTitle']?.toString() ??
          (AmharicTransliterator.containsAmharic(title)
              ? AmharicTransliterator.toLatin(title)
              : '');
      final yearVal = map['year'];
      final volumeVal = map['volume'];

      final kwRaw = map['search_keywords']?.toString() ?? '';
      final keywords = kwRaw.isNotEmpty
          ? kwRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : AmharicTransliterator.generateSearchKeywords(
              title: title,
              englishTitle: engTitle,
              subtitleOrArtist: map['artistName']?.toString(),
            );

      return Album(
        id: map['id']?.toString() ?? '',
        title: title,
        englishTitle: engTitle,
        artistId: map['artistId']?.toString() ?? '',
        artistName: map['artistName']?.toString() ?? '',
        coverImageUrl: map['coverImageUrl']?.toString() ?? '',
        year: yearVal is int ? yearVal : int.tryParse(yearVal?.toString() ?? ''),
        volume: volumeVal is int ? volumeVal : int.tryParse(volumeVal?.toString() ?? ''),
        searchKeywords: keywords,
      );
    });
  }

  Future<List<Song>> getSongs() async {
    if (kIsWeb) return [];
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');
    return List.generate(maps.length, (i) {
      final map = maps[i];
      final title = map['title']?.toString() ?? '';
      final engTitle = map['englishTitle']?.toString() ??
          (AmharicTransliterator.containsAmharic(title)
              ? AmharicTransliterator.toLatin(title)
              : '');

      final createdAtVal = map['createdAt'];
      DateTime dt;
      if (createdAtVal is int) {
        dt = DateTime.fromMillisecondsSinceEpoch(createdAtVal);
      } else if (createdAtVal is String) {
        dt = DateTime.tryParse(createdAtVal) ?? DateTime.now();
      } else {
        dt = DateTime.now();
      }

      final viewCountVal = map['viewCount'];
      final int viewCount = viewCountVal is int
          ? viewCountVal
          : int.tryParse(viewCountVal?.toString() ?? '') ?? 0;

      final kwRaw = map['search_keywords']?.toString() ?? '';
      final artistName = map['artistName']?.toString() ?? '';
      final lyrics = map['lyrics']?.toString() ?? '';

      final keywords = kwRaw.isNotEmpty
          ? kwRaw.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList()
          : AmharicTransliterator.generateSearchKeywords(
              title: title,
              englishTitle: engTitle,
              subtitleOrArtist: artistName,
              lyricsOrDescription: lyrics,
            );

      return Song(
        id: map['id']?.toString() ?? '',
        title: title,
        englishTitle: engTitle,
        artistName: artistName,
        artistId: map['artistId']?.toString() ?? '',
        albumId: map['albumId']?.toString() ?? '',
        albumTitle: map['albumTitle']?.toString() ?? '',
        lyrics: lyrics,
        scale: map['scale']?.toString(),
        rhythm: map['rhythm']?.toString(),
        viewCount: viewCount,
        createdAt: dt,
        searchKeywords: keywords,
      );
    });
  }

  // ── SETLIST MANAGEMENT (Native SQLite & Web SharedPreferences) ─────────────

  Future<int> createSetlist(Setlist setlist) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final setlists = await _getWebSetlists(prefs);
      final newId = DateTime.now().millisecondsSinceEpoch;
      final newSetlist = Setlist(
        id: newId,
        name: setlist.name,
        createdAt: setlist.createdAt,
      );
      setlists.insert(0, newSetlist);
      await _saveWebSetlists(prefs, setlists);
      return newId;
    }

    final db = await database;
    return await db.insert('setlists', setlist.toMap());
  }

  Future<void> deleteSetlist(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final setlists = await _getWebSetlists(prefs);
      setlists.removeWhere((s) => s.id == id);
      await _saveWebSetlists(prefs, setlists);

      final songs = await _getWebSetlistSongs(prefs);
      songs.removeWhere((s) => s.setlistId == id);
      await _saveWebSetlistSongs(prefs, songs);
      return;
    }

    final db = await database;
    await db.delete('setlists', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Setlist>> getSetlists() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return await _getWebSetlists(prefs);
    }

    final db = await database;
    final maps = await db.query('setlists', orderBy: 'createdAt DESC');
    return maps.map((map) => Setlist.fromMap(map)).toList();
  }

  Future<void> addSongToSetlist(SetlistSong song) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final songs = await _getWebSetlistSongs(prefs);
      final newSong = SetlistSong(
        id: DateTime.now().millisecondsSinceEpoch,
        setlistId: song.setlistId,
        songId: song.songId,
        orderIndex: song.orderIndex,
        customKey: song.customKey,
        notes: song.notes,
      );
      songs.add(newSong);
      await _saveWebSetlistSongs(prefs, songs);
      return;
    }

    final db = await database;
    await db.insert('setlist_songs', song.toMap());
  }

  Future<void> removeSongFromSetlist(int id) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final songs = await _getWebSetlistSongs(prefs);
      songs.removeWhere((s) => s.id == id);
      await _saveWebSetlistSongs(prefs, songs);
      return;
    }

    final db = await database;
    await db.delete('setlist_songs', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<SetlistSong>> getSongsForSetlist(int setlistId) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final songs = await _getWebSetlistSongs(prefs);
      return songs.where((s) => s.setlistId == setlistId).toList();
    }

    final db = await database;
    final maps = await db.query('setlist_songs',
        where: 'setlistId = ?', whereArgs: [setlistId]);
    return maps.map((map) => SetlistSong.fromMap(map)).toList();
  }

  Future<void> updateSongOrder(List<SetlistSong> songs) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final allSongs = await _getWebSetlistSongs(prefs);
      for (final updatedSong in songs) {
        final index = allSongs.indexWhere((s) => s.id == updatedSong.id);
        if (index != -1) {
          allSongs[index] = updatedSong;
        }
      }
      await _saveWebSetlistSongs(prefs, allSongs);
      return;
    }

    final db = await database;
    final batch = db.batch();
    for (int i = 0; i < songs.length; i++) {
      batch.update('setlist_songs', {'orderIndex': i},
          where: 'id = ?', whereArgs: [songs[i].id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> updateSetlistSong(SetlistSong song) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final allSongs = await _getWebSetlistSongs(prefs);
      final index = allSongs.indexWhere((s) => s.id == song.id);
      if (index != -1) {
        allSongs[index] = song;
        await _saveWebSetlistSongs(prefs, allSongs);
      }
      return;
    }

    final db = await database;
    await db.update('setlist_songs', song.toMap(),
        where: 'id = ?', whereArgs: [song.id]);
  }

  // ── Web Storage Helpers ───────────────────────────────────────────────────

  Future<List<Setlist>> _getWebSetlists(SharedPreferences prefs) async {
    final raw = prefs.getString(_webSetlistsPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Setlist.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveWebSetlists(
      SharedPreferences prefs, List<Setlist> list) async {
    final encoded = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_webSetlistsPrefKey, encoded);
  }

  Future<List<SetlistSong>> _getWebSetlistSongs(
      SharedPreferences prefs) async {
    final raw = prefs.getString(_webSetlistSongsPrefKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => SetlistSong.fromMap(Map<String, dynamic>.from(e))).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveWebSetlistSongs(
      SharedPreferences prefs, List<SetlistSong> list) async {
    final encoded = jsonEncode(list.map((e) => e.toMap()).toList());
    await prefs.setString(_webSetlistSongsPrefKey, encoded);
  }
}