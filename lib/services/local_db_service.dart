import 'package:mahlete_semay_project/models/album_model.dart';
import 'package:mahlete_semay_project/models/artist_model.dart';
import 'package:mahlete_semay_project/models/song_model.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB();
    return _database!;
  }

  Future<Database> _initDB() async {
    String path = join(await getDatabasesPath(), 'mahlete_semay.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createTables,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE artists(
        id TEXT PRIMARY KEY,
        name TEXT,
        imageUrl TEXT,
        region TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE albums(
        id TEXT PRIMARY KEY,
        title TEXT,
        artistId TEXT,
        artistName TEXT,
        coverImageUrl TEXT,
        year INTEGER,
        volume INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE songs(
        id TEXT PRIMARY KEY,
        title TEXT,
        artistName TEXT,
        artistId TEXT,
        albumId TEXT,
        albumTitle TEXT,
        lyrics TEXT,
        scale TEXT,
        rhythm TEXT,
        viewCount INTEGER,
        createdAt INTEGER
      )
    ''');
  }

  Future<void> syncArtists(List<Artist> artists) async {
    final db = await database;
    Batch batch = db.batch();
    for (var artist in artists) {
      batch.insert('artists', {'id': artist.id, ...artist.toJson()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncAlbums(List<Album> albums) async {
    final db = await database;
    Batch batch = db.batch();
    for (var album in albums) {
      batch.insert('albums', {'id': album.id, ...album.toJson()},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<void> syncSongs(List<Song> songs) async {
    final db = await database;
    Batch batch = db.batch();
    for (var song in songs) {
      final songMap = song.toJson();
      songMap['createdAt'] = song.createdAt.millisecondsSinceEpoch;
      batch.insert('songs', {'id': song.id, ...songMap},
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  Future<List<Artist>> getArtists() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('artists');
    return List.generate(maps.length, (i) {
      return Artist(
        id: maps[i]['id'],
        name: maps[i]['name'],
        imageUrl: maps[i]['imageUrl'],
        region: maps[i]['region'],
      );
    });
  }

  Future<List<Album>> getAlbums() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('albums');
    return List.generate(maps.length, (i) {
      return Album(
        id: maps[i]['id'],
        title: maps[i]['title'],
        artistId: maps[i]['artistId'],
        artistName: maps[i]['artistName'],
        coverImageUrl: maps[i]['coverImageUrl'],
        year: maps[i]['year'],
        volume: maps[i]['volume'],
      );
    });
  }

  Future<List<Song>> getSongs() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query('songs');
    return List.generate(maps.length, (i) {
      return Song(
        id: maps[i]['id'],
        title: maps[i]['title'],
        artistName: maps[i]['artistName'],
        artistId: maps[i]['artistId'],
        albumId: maps[i]['albumId'],
        albumTitle: maps[i]['albumTitle'],
        lyrics: maps[i]['lyrics'],
        scale: maps[i]['scale'],
        rhythm: maps[i]['rhythm'],
        viewCount: maps[i]['viewCount'],
        createdAt:
        Timestamp.fromMillisecondsSinceEpoch(maps[i]['createdAt']),
      );
    });
  }
}