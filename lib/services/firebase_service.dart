// Backward-compatibility service facade delegating to SupabaseService
import '../models/activity_log_model.dart';
import '../models/album_model.dart';
import '../models/artist_model.dart';
import '../models/invitation_model.dart';
import '../models/moderator_model.dart';
import '../models/song_model.dart';
import '../models/suggestion_model.dart';
import '../models/vocal_plan_model.dart';
import 'supabase_service.dart';

class FirebaseService {
  final SupabaseService _supabase = SupabaseService();

  Stream<List<Artist>> getArtistsStream() => _supabase.getArtistsStream();
  Stream<List<Album>> getAlbumsStream() => _supabase.getAlbumsStream();
  Stream<List<Song>> getSongsStream() => _supabase.getSongsStream();

  Future<bool> hasNewSongsSince(DateTime date) => _supabase.hasNewSongsSince(date);

  Future<List<Artist>> getArtists() => _supabase.getArtists();
  Future<List<Album>> getAlbums() => _supabase.getAlbums();
  Future<List<Song>> getSongs() => _supabase.getSongs();

  Future<void> addArtist(Artist artist) => _supabase.addArtist(artist);
  Future<void> addAlbum(Album album) => _supabase.addAlbum(album);
  Future<void> addSong(Song song) => _supabase.addSong(song);

  Future<void> updateArtist(String id, Map<String, dynamic> data) => _supabase.updateArtist(id, data);
  Future<void> updateAlbum(String id, Map<String, dynamic> data) => _supabase.updateAlbum(id, data);
  Future<void> updateSong(String id, Map<String, dynamic> data) => _supabase.updateSong(id, data);

  Future<void> deleteArtists(List<String> ids) => _supabase.deleteArtists(ids);
  Future<void> deleteAlbums(List<String> ids) => _supabase.deleteAlbums(ids);
  Future<void> deleteSongs(List<String> ids) => _supabase.deleteSongs(ids);

  Future<void> incrementSongViewCount(String songId) => _supabase.incrementSongViewCount(songId);

  Stream<List<VocalExerciseDay>> getVocalPlanDaysStream(String planId) => _supabase.getVocalPlanDaysStream(planId);
  Future<List<VocalExerciseDay>> getVocalPlanDays(String planId) => _supabase.getVocalPlanDays(planId);
  Future<void> addVocalExerciseDay(String planId, VocalExerciseDay exerciseDay) => _supabase.addVocalExerciseDay(planId, exerciseDay);
  Future<void> updateVocalExerciseDay(String planId, String dayId, Map<String, dynamic> data) => _supabase.updateVocalExerciseDay(planId, dayId, data);
  Future<void> deleteVocalExerciseDay(String planId, String dayId) => _supabase.deleteVocalExerciseDay(planId, dayId);

  Stream<List<VocalExerciseDay>> getGeneralExercisesStream() => _supabase.getGeneralExercisesStream();
  Future<List<VocalExerciseDay>> getGeneralExercises() => _supabase.getGeneralExercises();
  Future<void> addGeneralExercise(VocalExerciseDay exercise) => _supabase.addGeneralExercise(exercise);
  Future<void> updateGeneralExercise(String id, Map<String, dynamic> data) => _supabase.updateGeneralExercise(id, data);
  Future<void> deleteGeneralExercises(List<String> ids) => _supabase.deleteGeneralExercises(ids);

  Future<void> setModeratorData(String uid, Map<String, dynamic> data) => _supabase.setModeratorData(uid, data);
  Future<dynamic> getModeratorDoc(String uid) => _supabase.getModeratorDoc(uid);
  Stream<dynamic> getModeratorStream(String uid) => _supabase.getModeratorStream(uid);

  Future<void> addLyricSuggestion(Suggestion suggestion) => _supabase.addLyricSuggestion(suggestion);
  Stream<List<Suggestion>> getSuggestionsStream() => _supabase.getSuggestionsStream();
  Future<void> updateSuggestionStatus(String id, SuggestionStatus status) => _supabase.updateSuggestionStatus(id, status);
  Future<void> deleteSuggestion(String id) => _supabase.deleteSuggestion(id);

  Stream<List<Moderator>> getModeratorsStream() => _supabase.getModeratorsStream();
  Future<void> updateModeratorStatus(String uid, String status) => _supabase.updateModeratorStatus(uid, status);
  Future<void> updateModeratorRole(String uid, String role) => _supabase.updateModeratorRole(uid, role);
  Future<void> deleteModerator(String uid) => _supabase.deleteModerator(uid);

  Future<void> logActivity({
    required String moderatorId,
    required String moderatorName,
    required String action,
    required String details,
  }) => _supabase.logActivity(
    moderatorId: moderatorId,
    moderatorName: moderatorName,
    action: action,
    details: details,
  );

  Stream<List<ActivityLog>> getActivityLogsStream() => _supabase.getActivityLogsStream();
  Future<void> markAllActivitiesAsSeen() => _supabase.markAllActivitiesAsSeen();

  Future<void> approvePendingDevice(String moderatorId) => _supabase.approvePendingDevice(moderatorId);
  Future<void> rejectPendingDevice(String moderatorId) => _supabase.rejectPendingDevice(moderatorId);
  Future<void> removeDevice(String moderatorId, String deviceId) => _supabase.removeDevice(moderatorId, deviceId);

  Future<String> createInvitation({
    required String email,
    required String firstName,
    required String lastName,
    required String adminId,
    String role = 'moderator',
  }) => _supabase.createInvitation(
    email: email,
    firstName: firstName,
    lastName: lastName,
    adminId: adminId,
    role: role,
  );

  Future<Invitation?> getInvitationByCode(String code) => _supabase.getInvitationByCode(code);
  Stream<List<Invitation>> getInvitationsStream() => _supabase.getInvitationsStream();
  Future<void> deleteInvitation(String invitationId) => _supabase.deleteInvitation(invitationId);
  Future<void> revokeInvitation(String invitationId) => _supabase.revokeInvitation(invitationId);
  Future<List<VocalExerciseDay>> getAllVocalExercises() => _supabase.getAllVocalExercises();
  Future<void> claimInvitation(String invitationId, String moderatorUid) => _supabase.claimInvitation(invitationId, moderatorUid);
  Future<void> confirmUserEmail(String userId) => _supabase.confirmUserEmail(userId);

  // Duplicate detection queries
  Future<List<Song>> findSongDuplicates({required String title, String? artistId, String? albumId}) =>
      _supabase.findSongDuplicates(title: title, artistId: artistId, albumId: albumId);
  Future<List<Album>> findAlbumDuplicates({required String title, String? artistId}) =>
      _supabase.findAlbumDuplicates(title: title, artistId: artistId);
  Future<List<Artist>> findArtistDuplicates({required String name, String? region}) =>
      _supabase.findArtistDuplicates(name: name, region: region);
}