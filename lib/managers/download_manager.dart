import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vocal_plan_model.dart';
import '../services/firebase_service.dart';

enum DownloadStatus { notDownloaded, downloading, downloaded, error }

class DownloadManager with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  final Dio _dio = Dio();

  List<VocalExerciseDay> _allExercises = [];
  Set<String> _downloadedFileNames = {};

  DownloadStatus _status = DownloadStatus.notDownloaded;
  DownloadStatus get status => kIsWeb ? DownloadStatus.downloaded : _status;

  double _totalProgress = 0.0;
  double get totalProgress => _totalProgress;

  bool _isInitialized = false;

  Future<void> initialize() async {
    if (_isInitialized) return;

    _allExercises = await _firebaseService.getAllVocalExercises();
    await _loadDownloadedFiles();
    _updateInitialStatus();
    _isInitialized = true;
    notifyListeners();
  }

  Future<void> _loadDownloadedFiles() async {
    final prefs = await SharedPreferences.getInstance();
    final fileList = prefs.getStringList('downloadedExerciseFiles') ?? [];
    _downloadedFileNames = fileList.toSet();
  }

  void _updateInitialStatus() {
    if (_allExercises.isEmpty) {
      _status = DownloadStatus.notDownloaded;
      return;
    }
    final downloadableUrls = _allExercises.where((e) => e.audioUrl != null && e.audioUrl!.isNotEmpty).map((e) => e.audioUrl!).toSet();
    if (downloadableUrls.isEmpty) {
      _status = DownloadStatus.downloaded;
      return;
    }

    bool allFilesDownloaded = true;
    for (var url in downloadableUrls) {
      final fileName = _getFileNameFromUrl(url);
      if (!_downloadedFileNames.contains(fileName)) {
        allFilesDownloaded = false;
        break;
      }
    }

    _status = allFilesDownloaded ? DownloadStatus.downloaded : DownloadStatus.notDownloaded;
  }

  Future<void> startDownloadAll() async {
    if (kIsWeb) return;
    if (_status == DownloadStatus.downloading) return;

    _status = DownloadStatus.downloading;
    _totalProgress = 0.0;
    notifyListeners();

    try {
      final downloads = _allExercises.where((e) => e.audioUrl != null && !_downloadedFileNames.contains(_getFileNameFromUrl(e.audioUrl!))).toList();
      if (downloads.isEmpty) {
        _status = DownloadStatus.downloaded;
        notifyListeners();
        return;
      }

      final directory = await getApplicationDocumentsDirectory();
      int completed = 0;
      final totalToDownload = downloads.length;

      for (final exercise in downloads) {
        final url = exercise.audioUrl!;
        final fileName = _getFileNameFromUrl(url);
        final savePath = '${directory.path}/$fileName';

        try {
          await _dio.download(url, savePath);
          _downloadedFileNames.add(fileName);
        } catch (e) {
          debugPrint('Failed to download $fileName: $e');
        }

        completed++;
        _totalProgress = completed / totalToDownload;
        notifyListeners();
      }

      await _saveFileListToPrefs();
      _status = DownloadStatus.downloaded;
    } catch (e) {
      _status = DownloadStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<void> deleteAllFiles() async {
    if (kIsWeb) return;
    _status = DownloadStatus.downloading;
    _totalProgress = 0.0;
    notifyListeners();

    try {
      final directory = await getApplicationDocumentsDirectory();
      for (final fileName in _downloadedFileNames) {
        final file = File('${directory.path}/$fileName');
        if (await file.exists()) {
          await file.delete();
        }
      }
      _downloadedFileNames.clear();
      await _saveFileListToPrefs();
      _status = DownloadStatus.notDownloaded;
    } catch (e) {
      _status = DownloadStatus.error;
    } finally {
      notifyListeners();
    }
  }

  Future<String?> getLocalPath(String audioUrl) async {
    if (kIsWeb) return null;
    final fileName = _getFileNameFromUrl(audioUrl);
    if (_downloadedFileNames.contains(fileName)) {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$fileName';
    }
    return null;
  }

  String _getFileNameFromUrl(String url) {
    return url.split('/').last;
  }

  Future<void> _saveFileListToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('downloadedExerciseFiles', _downloadedFileNames.toList());
  }
}