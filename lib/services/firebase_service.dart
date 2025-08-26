import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mahlete_semay_project/models/vocal_plan_model.dart';
import '../models/activity_log_model.dart';
import '../models/artist_model.dart';
import '../models/album_model.dart';
import '../models/moderator_model.dart';
import '../models/song_model.dart';
import '../models/suggestion_model.dart';

class FirebaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<Artist>> getArtistsStream() => _db
      .collection('artists')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Artist.fromFirestore(doc)).toList(),
      );
  Stream<List<Album>> getAlbumsStream() => _db
      .collection('albums')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList(),
      );
  Stream<List<Song>> getSongsStream() => _db
      .collection('songs')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList(),
      );
  Future<bool> hasNewSongsSince(DateTime date) async {
    final query = _db
        .collection('songs')
        .where('createdAt', isGreaterThan: Timestamp.fromDate(date))
        .limit(1);

    final snapshot = await query.get();
    return snapshot.docs.isNotEmpty;
  }
  Future<List<Artist>> getArtists() async =>
      (await _db.collection('artists').get()).docs
          .map((doc) => Artist.fromFirestore(doc))
          .toList();
  Future<List<Album>> getAlbums() async =>
      (await _db.collection('albums').get()).docs
          .map((doc) => Album.fromFirestore(doc))
          .toList();
  Future<List<Song>> getSongs() async => (await _db.collection('songs').get())
      .docs
      .map((doc) => Song.fromFirestore(doc))
      .toList();

  Future<void> addArtist(Artist artist) async =>
      await _db.collection('artists').add(artist.toJson());
  Future<void> addAlbum(Album album) async =>
      await _db.collection('albums').add(album.toJson());
  Future<void> addSong(Song song) async =>
      await _db.collection('songs').add(song.toJson());

  Future<void> updateArtist(String id, Map<String, dynamic> data) async =>
      await _db.collection('artists').doc(id).update(data);
  Future<void> updateAlbum(String id, Map<String, dynamic> data) async =>
      await _db.collection('albums').doc(id).update(data);
  Future<void> updateSong(String id, Map<String, dynamic> data) async =>
      await _db.collection('songs').doc(id).update(data);

  Future<void> deleteArtists(List<String> ids) async {
    WriteBatch batch = _db.batch();
    for (var id in ids) {
      batch.delete(_db.collection('artists').doc(id));
    }
    await batch.commit();
  }

  Future<void> deleteAlbums(List<String> ids) async {
    WriteBatch batch = _db.batch();
    for (var id in ids) {
      batch.delete(_db.collection('albums').doc(id));
    }
    await batch.commit();
  }

  Future<void> deleteSongs(List<String> ids) async {
    WriteBatch batch = _db.batch();
    for (var id in ids) {
      batch.delete(_db.collection('songs').doc(id));
    }
    await batch.commit();
  }

  Future<void> incrementSongViewCount(String songId) async => await _db
      .collection('songs')
      .doc(songId)
      .update({'viewCount': FieldValue.increment(1)});

  Stream<List<VocalExerciseDay>> getVocalPlanDaysStream(String planId) => _db
      .collection('vocal_plans')
      .doc(planId)
      .collection('days')
      .orderBy('dayNumber')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => VocalExerciseDay.fromFirestore(doc))
            .toList(),
      );
  Future<void> addVocalExerciseDay(
    String planId,
    VocalExerciseDay exerciseDay,
  ) async => await _db
      .collection('vocal_plans')
      .doc(planId)
      .collection('days')
      .add(exerciseDay.toJson());
  Future<void> updateVocalExerciseDay(
    String planId,
    String dayId,
    Map<String, dynamic> data,
  ) async => await _db
      .collection('vocal_plans')
      .doc(planId)
      .collection('days')
      .doc(dayId)
      .update(data);
  Future<void> deleteVocalExerciseDay(String planId, String dayId) async =>
      await _db
          .collection('vocal_plans')
          .doc(planId)
          .collection('days')
          .doc(dayId)
          .delete();

  Stream<List<VocalExerciseDay>> getGeneralExercisesStream() => _db
      .collection('general_exercises')
      .orderBy('title')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
            .map((doc) => VocalExerciseDay.fromFirestore(doc))
            .toList(),
      );
  Future<void> addGeneralExercise(VocalExerciseDay exercise) async =>
      await _db.collection('general_exercises').add(exercise.toJson());
  Future<void> updateGeneralExercise(
    String id,
    Map<String, dynamic> data,
  ) async => await _db.collection('general_exercises').doc(id).update(data);
  Future<void> deleteGeneralExercises(List<String> ids) async {
    WriteBatch batch = _db.batch();
    for (var id in ids) {
      batch.delete(_db.collection('general_exercises').doc(id));
    }
    await batch.commit();
  }
  Future<void> setModeratorData(String uid, Map<String, dynamic> data) async {
    await _db.collection('moderators').doc(uid).set(data);
  }
  Future<DocumentSnapshot?> getModeratorDoc(String uid) async {
    final doc = await _db.collection('moderators').doc(uid).get();
    return doc.exists ? doc : null;
  }
  Future<void> addLyricSuggestion(Suggestion suggestion) async {
    await _db.collection('suggestions').add(suggestion.toJson());
  }

  Stream<List<Suggestion>> getSuggestionsStream() {
    return _db.collection('suggestions').orderBy('submittedAt', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Suggestion.fromFirestore(doc)).toList());
  }

  Future<void> updateSuggestionStatus(String id, SuggestionStatus status) async {
    await _db.collection('suggestions').doc(id).update({'status': status.name});
  }

  Future<void> deleteSuggestion(String id) async {
    await _db.collection('suggestions').doc(id).delete();
  }
  Stream<List<Moderator>> getModeratorsStream() => _db
      .collection('moderators')
      .snapshots()
      .map(
        (snapshot) =>
            snapshot.docs.map((doc) => Moderator.fromFirestore(doc)).toList(),
      );
  Future<void> updateModeratorStatus(String uid, String status) async =>
      await _db.collection('moderators').doc(uid).update({'status': status});
  Future<void> logActivity({
    required String moderatorId,
    required String moderatorName,
    required String action,
    required String details,
  }) async {
    final log = ActivityLog(
      id: '',
      moderatorId: moderatorId,
      moderatorName: moderatorName,
      action: action,
      details: details,
      timestamp: Timestamp.now(),
    );
    await _db.collection('activity_logs').add(log.toJson());
  }

  Stream<List<ActivityLog>> getActivityLogsStream() {
    return _db.collection('activity_logs').orderBy('timestamp', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ActivityLog.fromFirestore(doc)).toList());
  }

  Future<void> markAllActivitiesAsSeen() async {
    final querySnapshot = await _db.collection('activity_logs').where('isSeen', isEqualTo: false).get();
    WriteBatch batch = _db.batch();
    for (var doc in querySnapshot.docs) {
      batch.update(doc.reference, {'isSeen': true});
    }
    await batch.commit();
  }
}
