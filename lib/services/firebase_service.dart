import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:mahlete_semay_project/models/invitation_model.dart';
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
    try {
      final query = _db
          .collection('songs')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(date))
          .limit(1);

      final snapshot = await query.get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error in hasNewSongsSince: $e');
      return false;
    }
  }

  Future<List<Artist>> getArtists() async {
    try {
      final snapshot = await _db.collection('artists').get();
      debugPrint('Fetched ${snapshot.docs.length} artists from Firebase');
      return snapshot.docs.map((doc) => Artist.fromFirestore(doc)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting artists: $e\n$stackTrace');
      return [];
    }
  }

  Future<List<Album>> getAlbums() async {
    try {
      final snapshot = await _db.collection('albums').get();
      debugPrint('Fetched ${snapshot.docs.length} albums from Firebase');
      return snapshot.docs.map((doc) => Album.fromFirestore(doc)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting albums: $e\n$stackTrace');
      return [];
    }
  }

  Future<List<Song>> getSongs() async {
    try {
      final snapshot = await _db.collection('songs').get();
      debugPrint('Fetched ${snapshot.docs.length} songs from Firebase');
      return snapshot.docs.map((doc) => Song.fromFirestore(doc)).toList();
    } catch (e, stackTrace) {
      debugPrint('Error getting songs: $e\n$stackTrace');
      return [];
    }
  }

  Future<void> addArtist(Artist artist) async {
    try {
      await _db.collection('artists').add(artist.toJson());
    } catch (e) {
      debugPrint('Error adding artist: $e');
    }
  }

  Future<void> addAlbum(Album album) async {
    try {
      await _db.collection('albums').add(album.toJson());
    } catch (e) {
      debugPrint('Error adding album: $e');
    }
  }

  Future<void> addSong(Song song) async {
    try {
      await _db.collection('songs').add(song.toJson());
    } catch (e) {
      debugPrint('Error adding song: $e');
    }
  }

  Future<void> updateArtist(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection('artists').doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating artist: $e');
    }
  }

  Future<void> updateAlbum(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection('albums').doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating album: $e');
    }
  }

  Future<void> updateSong(String id, Map<String, dynamic> data) async {
    try {
      await _db.collection('songs').doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating song: $e');
    }
  }

  Future<void> deleteArtists(List<String> ids) async {
    try {
      WriteBatch batch = _db.batch();
      for (var id in ids) {
        batch.delete(_db.collection('artists').doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting artists: $e');
    }
  }

  Future<void> deleteAlbums(List<String> ids) async {
    try {
      WriteBatch batch = _db.batch();
      for (var id in ids) {
        batch.delete(_db.collection('albums').doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting albums: $e');
    }
  }

  Future<void> deleteSongs(List<String> ids) async {
    try {
      WriteBatch batch = _db.batch();
      for (var id in ids) {
        batch.delete(_db.collection('songs').doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting songs: $e');
    }
  }

  Future<void> incrementSongViewCount(String songId) async {
    try {
      await _db
          .collection('songs')
          .doc(songId)
          .update({'viewCount': FieldValue.increment(1)});
    } catch (e) {
      debugPrint('Error incrementing view count: $e');
    }
  }

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
      ) async {
    try {
      await _db
          .collection('vocal_plans')
          .doc(planId)
          .collection('days')
          .add(exerciseDay.toJson());
    } catch (e) {
      debugPrint('Error adding vocal exercise day: $e');
    }
  }

  Future<void> updateVocalExerciseDay(
      String planId,
      String dayId,
      Map<String, dynamic> data,
      ) async {
    try {
      await _db
          .collection('vocal_plans')
          .doc(planId)
          .collection('days')
          .doc(dayId)
          .update(data);
    } catch (e) {
      debugPrint('Error updating vocal exercise day: $e');
    }
  }

  Future<void> deleteVocalExerciseDay(String planId, String dayId) async {
    try {
      await _db
          .collection('vocal_plans')
          .doc(planId)
          .collection('days')
          .doc(dayId)
          .delete();
    } catch (e) {
      debugPrint('Error deleting vocal exercise day: $e');
    }
  }

  Stream<List<VocalExerciseDay>> getGeneralExercisesStream() => _db
      .collection('general_exercises')
      .orderBy('title')
      .snapshots()
      .map(
        (snapshot) => snapshot.docs
        .map((doc) => VocalExerciseDay.fromFirestore(doc))
        .toList(),
  );

  Future<void> addGeneralExercise(VocalExerciseDay exercise) async {
    try {
      await _db.collection('general_exercises').add(exercise.toJson());
    } catch (e) {
      debugPrint('Error adding general exercise: $e');
    }
  }

  Future<void> updateGeneralExercise(
      String id,
      Map<String, dynamic> data,
      ) async {
    try {
      await _db.collection('general_exercises').doc(id).update(data);
    } catch (e) {
      debugPrint('Error updating general exercise: $e');
    }
  }

  Future<void> deleteGeneralExercises(List<String> ids) async {
    try {
      WriteBatch batch = _db.batch();
      for (var id in ids) {
        batch.delete(_db.collection('general_exercises').doc(id));
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting general exercises: $e');
    }
  }

  Future<void> setModeratorData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('moderators').doc(uid).set(data, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error setting moderator data: $e');
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getModeratorDoc(String uid) {
    return _db.collection('moderators').doc(uid).get();
  }

  Stream<DocumentSnapshot> getModeratorStream(String uid) {
    return _db.collection('moderators').doc(uid).snapshots();
  }

  Future<void> addLyricSuggestion(Suggestion suggestion) async {
    try {
      await _db.collection('suggestions').add(suggestion.toJson());
    } catch (e) {
      debugPrint('Error adding lyric suggestion: $e');
    }
  }

  Stream<List<Suggestion>> getSuggestionsStream() {
    return _db.collection('suggestions').orderBy('submittedAt', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => Suggestion.fromFirestore(doc)).toList());
  }

  Future<void> updateSuggestionStatus(String id, SuggestionStatus status) async {
    try {
      await _db.collection('suggestions').doc(id).update({'status': status.name});
    } catch (e) {
      debugPrint('Error updating suggestion status: $e');
    }
  }

  Future<void> deleteSuggestion(String id) async {
    try {
      await _db.collection('suggestions').doc(id).delete();
    } catch (e) {
      debugPrint('Error deleting suggestion: $e');
    }
  }

  Stream<List<Moderator>> getModeratorsStream() => _db
      .collection('moderators')
      .snapshots()
      .map(
        (snapshot) =>
        snapshot.docs.map((doc) => Moderator.fromFirestore(doc)).toList(),
  );

  Future<void> updateModeratorStatus(String uid, String status) async {
    try {
      await _db.collection('moderators').doc(uid).update({'status': status});
    } catch (e) {
      debugPrint('Error updating moderator status: $e');
    }
  }

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
        timestamp: Timestamp.now(),
      );
      await _db.collection('activity_logs').add(log.toJson());
    } catch (e) {
      debugPrint('Error logging activity: $e');
    }
  }

  Stream<List<ActivityLog>> getActivityLogsStream() {
    return _db.collection('activity_logs').orderBy('timestamp', descending: true).snapshots().map((snapshot) =>
        snapshot.docs.map((doc) => ActivityLog.fromFirestore(doc)).toList());
  }

  Future<void> markAllActivitiesAsSeen() async {
    try {
      final querySnapshot = await _db.collection('activity_logs').where('isSeen', isEqualTo: false).get();
      WriteBatch batch = _db.batch();
      for (var doc in querySnapshot.docs) {
        batch.update(doc.reference, {'isSeen': true});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking activities as seen: $e');
    }
  }

  Future<void> approvePendingDevice(String moderatorId) async {
    try {
      final doc = await _db.collection('moderators').doc(moderatorId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (data.containsKey('pendingDevice')) {
          await _db.collection('moderators').doc(moderatorId).update({
            'approvedDevices': FieldValue.arrayUnion([data['pendingDevice']]),
            'pendingDevice': FieldValue.delete(),
            'status': 'active'
          });

          await logActivity(
            moderatorId: moderatorId,
            moderatorName: '${data['firstName']} ${data['lastName']}',
            action: 'DEVICE_APPROVED',
            details: 'New device approved by admin: ${data['pendingDevice']['model']}',
          );
        }
      }
    } catch (e) {
      debugPrint('Error approving pending device: $e');
    }
  }

  Future<void> rejectPendingDevice(String moderatorId) async {
    try {
      final doc = await _db.collection('moderators').doc(moderatorId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        await _db.collection('moderators').doc(moderatorId).update({
          'pendingDevice': FieldValue.delete(),
          'status': 'active'
        });

        await logActivity(
          moderatorId: moderatorId,
          moderatorName: '${data['firstName']} ${data['lastName']}',
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
      final doc = await _db.collection('moderators').doc(moderatorId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        final devices = List<Map<String, dynamic>>.from(data['approvedDevices'] ?? []);
        final deviceToRemove = devices.firstWhere((device) => device['id'] == deviceId, orElse: () => {});
        final updatedDevices = devices.where((device) => device['id'] != deviceId).toList();

        await _db.collection('moderators').doc(moderatorId).update({
          'approvedDevices': updatedDevices
        });

        await logActivity(
          moderatorId: moderatorId,
          moderatorName: '${data['firstName']} ${data['lastName']}',
          action: 'DEVICE_REMOVED',
          details: 'Device removed by admin: ${deviceToRemove['model'] ?? 'Unknown device'}',
        );
      }
    } catch (e) {
      debugPrint('Error removing device: $e');
    }
  }

  Future<String> createInvitation({
    required String email,
    required String firstName,
    required String lastName,
    required String adminId,
  }) async {
    try {
      const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final random = Random();
      String code;

      do {
        code = List.generate(8, (index) => chars[random.nextInt(chars.length)]).join();
      } while (await _invitationCodeExists(code));

      final newInvitation = Invitation(
        id: '',
        code: code,
        email: email,
        firstName: firstName,
        lastName: lastName,
        status: 'pending',
        createdAt: Timestamp.now(),
        createdBy: adminId,
      );

      await _db.collection('invitations').add(newInvitation.toJson());
      return code;
    } catch (e) {
      debugPrint('Error creating invitation: $e');
      rethrow;
    }
  }

  Future<bool> _invitationCodeExists(String code) async {
    try {
      final query = await _db.collection('invitations').where('code', isEqualTo: code).limit(1).get();
      return query.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking invitation code existence: $e');
      return true;
    }
  }

  Future<Invitation?> getInvitationByCode(String code) async {
    try {
      final query = await _db
          .collection('invitations')
          .where('code', isEqualTo: code)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get();

      if (query.docs.isEmpty) return null;
      return Invitation.fromFirestore(query.docs.first);
    } catch (e) {
      debugPrint('Error getting invitation by code: $e');
      return null;
    }
  }

  Future<List<VocalExerciseDay>> getAllVocalExercises() async {
    try {
      final List<VocalExerciseDay> allExercises = [];

      final generalExercisesSnapshot = await _db.collection('general_exercises').get();
      allExercises.addAll(generalExercisesSnapshot.docs.map((doc) => VocalExerciseDay.fromFirestore(doc)));

      const planIds = [
        'male_daily', 'female_daily', 'male_weekly', 'female_weekly',
        'male_monthly', 'female_monthly', 'male_quarterly', 'female_quarterly'
      ];

      for (final planId in planIds) {
        final planDaysSnapshot = await _db.collection('vocal_plans').doc(planId).collection('days').get();
        allExercises.addAll(planDaysSnapshot.docs.map((doc) => VocalExerciseDay.fromFirestore(doc)));
      }

      return allExercises;
    } catch (e) {
      debugPrint('Error getting all vocal exercises: $e');
      return [];
    }
  }

  Future<void> claimInvitation(String invitationId, String moderatorUid) async {
    try {
      await _db.collection('invitations').doc(invitationId).update({
        'status': 'claimed',
        'claimedBy': moderatorUid,
        'claimedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error claiming invitation: $e');
    }
  }
}