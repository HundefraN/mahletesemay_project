import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import '../models/song_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Artist>> getArtistsStream() {
    return _db.collection('artists').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Artist.fromFirestore(doc)).toList());
  }

  Stream<List<Album>> getAlbumsStream() {
    return _db.collection('albums').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList());
  }

  Stream<List<Song>> getSongsStream() {
    return _db.collection('songs').snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList());
  }

  Future<List<Artist>> getArtists() async {
    QuerySnapshot snapshot = await _db.collection('artists').get();
    return snapshot.docs.map((doc) => Artist.fromFirestore(doc)).toList();
  }

  Future<List<Album>> getAlbums() async {
    QuerySnapshot snapshot = await _db.collection('albums').get();
    return snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList();
  }

  Future<List<Song>> getSongs() async {
    QuerySnapshot snapshot = await _db.collection('songs').get();
    return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
  }

  Future<void> addArtist(Artist artist) async {
    await _db.collection('artists').add(artist.toJson());
  }

  Future<void> addAlbum(Album album) async {
    await _db.collection('albums').add(album.toJson());
  }

  Future<void> addSong(Song song) async {
    await _db.collection('songs').add(song.toJson());
  }

  Future<void> updateArtist(String id, Map<String, dynamic> data) async {
    await _db.collection('artists').doc(id).update(data);
  }

  Future<void> updateAlbum(String id, Map<String, dynamic> data) async {
    await _db.collection('albums').doc(id).update(data);
  }

  Future<void> updateSong(String id, Map<String, dynamic> data) async {
    await _db.collection('songs').doc(id).update(data);
  }

  Future<void> incrementSongViewCount(String songId) async {
    final songRef = _db.collection('songs').doc(songId);
    await songRef.update({'viewCount': FieldValue.increment(1)});
  }
}