import 'dart:async';

import 'package:flutter/material.dart';

import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../services/offline_service.dart';
import '../utils/app_logger.dart';

class OfflineProvider with ChangeNotifier {
  final OfflineService _offlineService = OfflineService.instance;

  List<OfflineMediaItem> _offlineMedia = [];
  List<OfflineMediaItem> _downloadQueue = [];
  bool _isLoading = false;
  bool _hasConnectivity = true;
  StreamSubscription? _progressSubscription;
  Map<String, double> _downloadProgress = {};

  List<OfflineMediaItem> get offlineMedia => _offlineMedia;
  List<OfflineMediaItem> get completedMedia =>
      _offlineMedia.where((item) => item.isCompleted).toList();
  List<OfflineMediaItem> get downloadingMedia =>
      _offlineMedia.where((item) => item.isDownloading).toList();
  List<OfflineMediaItem> get downloadQueue => _downloadQueue;
  bool get isLoading => _isLoading;
  bool get hasConnectivity => _hasConnectivity;
  bool get isOfflineMode => !_hasConnectivity;
  Map<String, double> get downloadProgress => _downloadProgress;

  Future<void> initialize() async {
    try {
      await _offlineService.initialize();
      await _checkConnectivity();
      await _loadOfflineMedia();
      _setupProgressListener();
      appLogger.d('OfflineProvider initialized');
    } catch (e) {
      appLogger.e('Failed to initialize OfflineProvider: $e');
    }
  }

  Future<void> _checkConnectivity() async {
    try {
      _hasConnectivity = await _offlineService.hasConnectivity();
      notifyListeners();
    } catch (e) {
      appLogger.w('Failed to check connectivity: $e');
      _hasConnectivity = false;
      notifyListeners();
    }
  }

  void _setupProgressListener() {
    _progressSubscription = _offlineService.progressStream.listen(
      (progress) {
        _downloadProgress[progress.itemId] = progress.progress;
        notifyListeners();
      },
      onError: (error) {
        appLogger.e('Progress stream error: $error');
      },
    );
  }

  Future<void> _loadOfflineMedia() async {
    if (_isLoading) return;

    _isLoading = true;
    notifyListeners();

    try {
      _offlineMedia = await _offlineService.getOfflineMedia();
      _downloadQueue = _offlineMedia
          .where(
            (item) =>
                item.status == OfflineMediaStatus.pending ||
                item.status == OfflineMediaStatus.downloading,
          )
          .toList();
    } catch (e) {
      appLogger.e('Failed to load offline media: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> downloadMedia(
    PlexMetadata metadata,
    String serverId,
    String serverName,
  ) async {
    try {
      // Check if already downloaded or downloading
      final existing = _offlineMedia.firstWhere(
        (item) =>
            item.ratingKey == metadata.ratingKey && item.serverId == serverId,
        orElse: () => OfflineMediaItem(
          id: '',
          ratingKey: '',
          serverId: '',
          serverName: '',
          title: '',
          type: OfflineMediaType.movie,
          status: OfflineMediaStatus.pending,
          localPath: '',
          fileSize: 0,
          downloadedSize: 0,
          createdAt: DateTime.now(),
        ),
      );

      if (existing.id.isNotEmpty) {
        appLogger.w('Media already exists in download queue or completed');
        return;
      }

      await _offlineService.queueDownloadFromMetadata(
        metadata,
        serverId,
        serverName,
      );

      await _loadOfflineMedia();
      appLogger.d('Queued download for: ${metadata.title}');
    } catch (e) {
      appLogger.e('Failed to queue download: $e');
      rethrow;
    }
  }

  Future<void> deleteDownload(String itemId) async {
    try {
      await _offlineService.deleteOfflineItem(itemId);
      _downloadProgress.remove(itemId);
      await _loadOfflineMedia();
      appLogger.d('Deleted offline item: $itemId');
    } catch (e) {
      appLogger.e('Failed to delete offline item: $e');
      rethrow;
    }
  }

  Future<bool> isMediaDownloaded(String ratingKey, String serverId) async {
    try {
      return await _offlineService.isMediaDownloaded(ratingKey, serverId);
    } catch (e) {
      appLogger.e('Failed to check if media is downloaded: $e');
      return false;
    }
  }

  Future<void> refreshConnectivity() async {
    await _checkConnectivity();
  }

  Future<void> refresh() async {
    await _checkConnectivity();
    await _loadOfflineMedia();
  }

  double getDownloadProgress(String itemId) {
    return _downloadProgress[itemId] ?? 0.0;
  }

  bool isDownloading(String ratingKey, String serverId) {
    final itemId = '${serverId}_${ratingKey}';
    return _downloadQueue.any((item) => item.id == itemId);
  }

  bool isCompleted(String ratingKey, String serverId) {
    final itemId = '${serverId}_${ratingKey}';
    return completedMedia.any((item) => item.id == itemId);
  }

  /// Get completed offline media item by metadata
  OfflineMediaItem? getOfflineMediaItem(String ratingKey, String serverId) {
    final itemId = '${serverId}_${ratingKey}';
    try {
      return completedMedia.firstWhere((item) => item.id == itemId);
    } catch (e) {
      return null;
    }
  }

  Future<void> clearAllDownloads() async {
    try {
      appLogger.d('Clearing all downloads and resetting database...');

      // Delete all offline media items
      for (final item in _offlineMedia) {
        await _offlineService.deleteOfflineItem(item.id);
      }

      // Clear local state
      _offlineMedia.clear();
      _downloadQueue.clear();
      _downloadProgress.clear();

      notifyListeners();
      appLogger.d('All downloads cleared successfully');
    } catch (e) {
      appLogger.e('Failed to clear all downloads: $e');
      rethrow;
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _offlineService.dispose();
    super.dispose();
  }
}
