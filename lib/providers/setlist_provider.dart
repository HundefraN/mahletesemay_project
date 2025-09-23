import 'package:flutter/material.dart';
import '../models/setlist_model.dart';
import '../services/local_db_service.dart';

class SetlistProvider with ChangeNotifier {
  final LocalDbService _localDbService = LocalDbService();
  List<Setlist> _setlists = [];
  Map<int, List<SetlistSong>> _setlistSongs = {};
  bool _isLoading = true;

  List<Setlist> get setlists => _setlists;
  List<SetlistSong> getSongsForSetlist(int setlistId) => _setlistSongs[setlistId] ?? [];
  bool get isLoading => _isLoading;

  SetlistProvider() {
    loadSetlists();
  }

  Future<void> loadSetlists() async {
    _isLoading = true;
    notifyListeners();

    _setlists = await _localDbService.getSetlists();
    for (final setlist in _setlists) {
      await loadSongsForSetlist(setlist.id!);
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadSongsForSetlist(int setlistId) async {
    _setlistSongs[setlistId] = await _localDbService.getSongsForSetlist(setlistId);
    _setlistSongs[setlistId]?.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    notifyListeners();
  }

  Future<int> createSetlist(String name) async {
    final newSetlist = Setlist(name: name, createdAt: DateTime.now());
    final id = await _localDbService.createSetlist(newSetlist);
    await loadSetlists();
    return id;
  }

  Future<void> deleteSetlist(int id) async {
    await _localDbService.deleteSetlist(id);
    _setlists.removeWhere((s) => s.id == id);
    _setlistSongs.remove(id);
    notifyListeners();
  }

  Future<void> addSongToSetlist(int setlistId, String songId) async {
    final currentSongs = getSongsForSetlist(setlistId);
    final newSong = SetlistSong(
      setlistId: setlistId,
      songId: songId,
      orderIndex: currentSongs.length,
    );
    await _localDbService.addSongToSetlist(newSong);
    await loadSongsForSetlist(setlistId);
  }

  Future<void> removeSongFromSetlist(int setlistId, int setlistSongId) async {
    await _localDbService.removeSongFromSetlist(setlistSongId);
    await loadSongsForSetlist(setlistId);
  }

  Future<void> updateSongOrder(int setlistId, int oldIndex, int newIndex) async {
    List<SetlistSong> songs = getSongsForSetlist(setlistId);
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final SetlistSong item = songs.removeAt(oldIndex);
    songs.insert(newIndex, item);

    await _localDbService.updateSongOrder(songs);
    await loadSongsForSetlist(setlistId);
  }

  Future<void> updateSongDetails(SetlistSong song) async {
    await _localDbService.updateSetlistSong(song);
    await loadSongsForSetlist(song.setlistId);
  }
}