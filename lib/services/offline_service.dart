import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/download_queue_item.dart';
import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../providers/multi_server_provider.dart';
import '../services/plex_client.dart';
import '../utils/app_logger.dart';
import '../utils/plex_image_helper.dart';

class OfflineService {
  static OfflineService? _instance;
  static OfflineService get instance {
    _instance ??= OfflineService._();
    return _instance!;
  }

  OfflineService._();

  Database? _database;
  final StreamController<OfflineDownloadProgress> _progressController =
      StreamController<OfflineDownloadProgress>.broadcast();
  final Map<String, CancelToken> _downloadTokens = {};

  bool _isInitialized = false;
  MultiServerProvider? _multiServerProvider;

  Stream<OfflineDownloadProgress> get progressStream =>
      _progressController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initDatabase();
    _isInitialized = true;
    appLogger.d('OfflineService initialized');
  }

  /// Set the multi-server provider for accessing PlexClients
  void setMultiServerProvider(MultiServerProvider provider) {
    _multiServerProvider = provider;
  }

  Future<void> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'offline_media.db');

    _database = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE offline_media (
            id TEXT PRIMARY KEY,
            rating_key TEXT NOT NULL,
            server_id TEXT NOT NULL,
            title TEXT NOT NULL,
            type TEXT NOT NULL,
            status TEXT NOT NULL,
            local_path TEXT NOT NULL,
            file_size INTEGER NOT NULL,
            downloaded_size INTEGER DEFAULT 0,
            metadata TEXT,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            error TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE download_queue (
            id TEXT PRIMARY KEY,
            rating_key TEXT NOT NULL,
            server_id TEXT NOT NULL,
            metadata TEXT NOT NULL,
            priority INTEGER DEFAULT 0,
            queued_at INTEGER NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE progress_cache (
            item_id TEXT PRIMARY KEY,
            view_offset INTEGER NOT NULL,
            duration INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<bool> hasConnectivity() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      return connectivity.any((result) => result != ConnectivityResult.none);
    } catch (e) {
      return false;
    }
  }

  Future<void> queueDownload(DownloadQueueItem item) async {
    await _database!.insert('download_queue', {
      'id': item.id,
      'rating_key': item.ratingKey,
      'server_id': item.serverId,
      'metadata': jsonEncode(item.metadata.toJson()),
      'priority': item.priority.index,
      'queued_at': item.queuedAt.millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    _startDownload(item);
  }

  Future<void> queueDownloadFromMetadata(
    PlexMetadata metadata,
    String serverId,
    String serverName,
  ) async {
    final downloadItem = DownloadQueueItem(
      id: '${serverId}_${metadata.ratingKey}',
      ratingKey: metadata.ratingKey,
      serverId: serverId,
      serverName: serverName,
      metadata: metadata,
      priority: DownloadPriority.normal,
      queuedAt: DateTime.now(),
    );

    await queueDownload(downloadItem);
  }

  Future<void> _startDownload(DownloadQueueItem item) async {
    if (_downloadTokens.containsKey(item.id)) return;

    final cancelToken = CancelToken();
    _downloadTokens[item.id] = cancelToken;

    try {
      final localPath = await _generateLocalPath(item);

      final offlineItem = OfflineMediaItem(
        id: item.id,
        ratingKey: item.ratingKey,
        serverId: item.serverId,
        serverName: item.serverName,
        title: item.metadata.title ?? 'Unknown',
        type: _getOfflineMediaType(item.metadata.type),
        status: OfflineMediaStatus.downloading,
        localPath: localPath,
        fileSize: 0,
        downloadedSize: 0,
        createdAt: DateTime.now(),
        mediaInfo: item.metadata.toJson(),
      );

      await _saveOfflineItem(offlineItem);

      // Perform real video download with retry logic
      await _downloadVideoWithRetry(item, localPath, cancelToken);
    } catch (e) {
      appLogger.e('Download failed for ${item.metadata.title}: $e');
      await _updateItemStatus(
        item.id,
        OfflineMediaStatus.failed,
        error: e.toString(),
      );
    } finally {
      _downloadTokens.remove(item.id);
    }
  }

  /// Downloads the actual video file from Plex server
  Future<void> _downloadVideo(
    DownloadQueueItem item,
    String localPath,
    CancelToken cancelToken,
  ) async {
    try {
      // Get the Plex client for this server
      final plexClient = _getPlexClientForServer(item.serverId);
      if (plexClient == null) {
        throw Exception('No Plex client found for server: ${item.serverId}');
      }

      // Get the video URL for download
      final videoUrl = await plexClient.getVideoUrl(item.ratingKey);
      if (videoUrl == null) {
        throw Exception('Could not get video URL for: ${item.metadata.title}');
      }

      // Download poster image if available
      String? localPosterPath;
      try {
        localPosterPath = await _downloadPosterImage(item, plexClient);
      } catch (e) {
        appLogger.w('Failed to download poster image: $e');
        // Continue without poster - video download is more important
      }

      appLogger.i('Starting download for ${item.metadata.title}');
      appLogger.d('Video URL: $videoUrl');
      appLogger.d('Local path: $localPath');

      // Create the local file and ensure parent directory exists
      final file = File(localPath);
      await file.parent.create(recursive: true);

      // Create a dedicated Dio instance for downloads with proper timeout settings
      final dio = Dio();
      dio.options.connectTimeout = Duration(seconds: 30);
      dio.options.receiveTimeout = Duration(minutes: 10);
      dio.options.sendTimeout = Duration(seconds: 30);

      // Download the file with progress tracking
      final response = await dio.get(
        videoUrl,
        cancelToken: cancelToken,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
          receiveDataWhenStatusError: false,
          validateStatus: (status) {
            return status != null && status >= 200 && status < 300;
          },
        ),
        onReceiveProgress: (received, total) async {
          try {
            if (total > 0 && !cancelToken.isCancelled) {
              final progress = received / total;

              // Update progress in database
              await _database!.update(
                'offline_media',
                {'file_size': total, 'downloaded_size': received},
                where: 'id = ?',
                whereArgs: [item.id],
              );

              // Emit progress event
              _progressController.add(
                OfflineDownloadProgress(
                  itemId: item.id,
                  downloadedBytes: received,
                  totalBytes: total,
                  progress: progress,
                ),
              );
            }
          } catch (e) {
            appLogger.w('Error updating download progress: $e');
            // Don't fail the entire download for progress update errors
          }
        },
      );

      // Verify response data
      if (response.data == null) {
        throw Exception('No data received from server');
      }

      // Write the file to disk
      await file.writeAsBytes(response.data);

      // Verify file was written successfully
      if (!await file.exists() || await file.length() == 0) {
        throw Exception('Failed to write video file to disk');
      }

      if (!cancelToken.isCancelled) {
        final fileSize = await file.length();
        appLogger.i(
          'Download completed for ${item.metadata.title} (${_formatFileSize(fileSize)})',
        );

        // Final database update with actual file size
        await _database!.update(
          'offline_media',
          {'file_size': fileSize, 'downloaded_size': fileSize},
          where: 'id = ?',
          whereArgs: [item.id],
        );

        // Update metadata with local poster path if downloaded
        if (localPosterPath != null) {
          await _updateItemMetadataWithPoster(item.id, localPosterPath);
        }

        await _updateItemStatus(item.id, OfflineMediaStatus.completed);

        // Remove from download queue
        await _database!.delete(
          'download_queue',
          where: 'id = ?',
          whereArgs: [item.id],
        );
      } else {
        // Clean up partial file if cancelled
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      if (!cancelToken.isCancelled) {
        appLogger.e('Download error for ${item.metadata.title}: $e');

        // Clean up partial file on error
        final file = File(localPath);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (deleteError) {
            appLogger.w(
              'Failed to clean up partial download file: $deleteError',
            );
          }
        }

        rethrow;
      }
    }
  }

  /// Format file size in human readable format
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    if (bytes < 1024 * 1024 * 1024)
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)}MB';
    return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(1)}GB';
  }

  /// Download video with retry logic
  Future<void> _downloadVideoWithRetry(
    DownloadQueueItem item,
    String localPath,
    CancelToken cancelToken,
  ) async {
    const maxRetries = 3;
    const baseDelay = Duration(seconds: 2);

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        appLogger.d(
          'Download attempt $attempt/$maxRetries for ${item.metadata.title}',
        );
        await _downloadVideo(item, localPath, cancelToken);
        return; // Success, exit retry loop
      } catch (e) {
        if (cancelToken.isCancelled) {
          throw e; // Don't retry if cancelled
        }

        appLogger.w(
          'Download attempt $attempt failed for ${item.metadata.title}: $e',
        );

        if (attempt == maxRetries) {
          // Last attempt failed, give up
          appLogger.e(
            'Download failed after $maxRetries attempts for ${item.metadata.title}',
          );
          throw e;
        }

        // Wait before retry with exponential backoff
        final delay = Duration(
          milliseconds: baseDelay.inMilliseconds * attempt,
        );
        appLogger.d('Retrying download in ${delay.inSeconds} seconds...');
        await Future.delayed(delay);

        // Clean up partial file before retry
        final file = File(localPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
    }
  }

  /// Get Plex client for a specific server ID
  PlexClient? _getPlexClientForServer(String serverId) {
    if (_multiServerProvider == null) {
      appLogger.e('MultiServerProvider not set in OfflineService');
      return null;
    }

    return _multiServerProvider!.getClientForServer(serverId);
  }

  Future<void> _saveOfflineItem(OfflineMediaItem item) async {
    await _database!.insert('offline_media', {
      'id': item.id,
      'rating_key': item.ratingKey,
      'server_id': item.serverId,
      'title': item.title,
      'type': item.type.name,
      'status': item.status.name,
      'local_path': item.localPath,
      'file_size': item.fileSize,
      'downloaded_size': item.downloadedSize,
      'metadata': item.mediaInfo != null ? jsonEncode(item.mediaInfo) : null,
      'created_at': item.createdAt.millisecondsSinceEpoch,
      'completed_at': item.completedAt?.millisecondsSinceEpoch,
      'error': item.error,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _updateItemStatus(
    String id,
    OfflineMediaStatus status, {
    String? error,
  }) async {
    final updateData = <String, dynamic>{'status': status.name, 'error': error};

    if (status == OfflineMediaStatus.completed) {
      updateData['completed_at'] = DateTime.now().millisecondsSinceEpoch;
    }

    await _database!.update(
      'offline_media',
      updateData,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<OfflineMediaItem>> getOfflineMedia({
    OfflineMediaStatus? status,
  }) async {
    String? whereClause;
    List<Object?>? whereArgs;

    if (status != null) {
      whereClause = 'status = ?';
      whereArgs = [status.name];
    }

    final List<Map<String, dynamic>> maps = await _database!.query(
      'offline_media',
      where: whereClause,
      whereArgs: whereArgs,
      orderBy: 'created_at DESC',
    );

    return maps.map((map) => _offlineItemFromMap(map)).toList();
  }

  Future<List<OfflineMediaItem>> getCompletedOfflineMedia() async {
    return getOfflineMedia(status: OfflineMediaStatus.completed);
  }

  Future<bool> isMediaDownloaded(String ratingKey, String serverId) async {
    final itemId = '${serverId}_${ratingKey}';
    final result = await _database!.query(
      'offline_media',
      where: 'id = ? AND status = ?',
      whereArgs: [itemId, OfflineMediaStatus.completed.name],
    );
    return result.isNotEmpty;
  }

  /// Cancel an active download without deleting the offline item
  Future<void> cancelDownload(String id) async {
    final cancelToken = _downloadTokens[id];
    if (cancelToken != null) {
      cancelToken.cancel();
      _downloadTokens.remove(id);

      // Update status to failed
      await _updateItemStatus(
        id,
        OfflineMediaStatus.failed,
        error: 'Cancelled by user',
      );

      // Clean up partial file
      final items = await _database!.query(
        'offline_media',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (items.isNotEmpty) {
        final item = _offlineItemFromMap(items.first);
        final file = File(item.localPath);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            appLogger.w('Failed to delete partial file after cancellation: $e');
          }
        }
      }

      appLogger.i('Download cancelled for item: $id');
    }
  }

  Future<void> deleteOfflineItem(String id) async {
    // Get item info for cleanup
    final items = await _database!.query(
      'offline_media',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (items.isNotEmpty) {
      final item = _offlineItemFromMap(items.first);

      // Cancel download if in progress
      _downloadTokens[id]?.cancel();
      _downloadTokens.remove(id);

      // Delete local file
      try {
        final file = File(item.localPath);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        appLogger.w('Failed to delete local file: $e');
      }
    }

    // Remove from database
    await _database!.delete('offline_media', where: 'id = ?', whereArgs: [id]);
    await _database!.delete('download_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveProgress(String itemId, int viewOffset, int duration) async {
    await _database!.insert('progress_cache', {
      'item_id': itemId,
      'view_offset': viewOffset,
      'duration': duration,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int?> getProgress(String itemId) async {
    final result = await _database!.query(
      'progress_cache',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );

    return result.isNotEmpty ? result.first['view_offset'] as int? : null;
  }

  OfflineMediaItem _offlineItemFromMap(Map<String, dynamic> map) {
    return OfflineMediaItem(
      id: map['id'] as String,
      ratingKey: map['rating_key'] as String,
      serverId: map['server_id'] as String,
      serverName: '', // Could be retrieved from server registry
      title: map['title'] as String,
      type: _parseOfflineMediaType(map['type'] as String?),
      status: _parseOfflineMediaStatus(map['status'] as String?),
      localPath: map['local_path'] as String,
      fileSize: map['file_size'] as int,
      downloadedSize: map['downloaded_size'] as int? ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      completedAt: map['completed_at'] != null
          ? DateTime.fromMillisecondsSinceEpoch(map['completed_at'] as int)
          : null,
      error: map['error'] as String?,
      mediaInfo: map['metadata'] != null
          ? jsonDecode(map['metadata'] as String) as Map<String, dynamic>?
          : null,
    );
  }

  OfflineMediaType _getOfflineMediaType(String? type) {
    switch (type?.toLowerCase()) {
      case 'episode':
        return OfflineMediaType.episode;
      case 'season':
        return OfflineMediaType.season;
      case 'show':
        return OfflineMediaType.series;
      default:
        return OfflineMediaType.movie;
    }
  }

  Future<String> _generateLocalPath(DownloadQueueItem item) async {
    final appDir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(join(appDir.path, 'Downloads'));

    // Create downloads directory if it doesn't exist
    if (!await downloadsDir.exists()) {
      await downloadsDir.create(recursive: true);
    }

    final hash = md5.convert(utf8.encode('${item.serverId}_${item.ratingKey}'));

    // Generate a safe filename from the title
    final safeTitle = (item.metadata.title ?? 'unknown')
        .replaceAll(RegExp(r'[^\w\s\-\.]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '_');

    // Determine file extension based on media type
    String extension = '.mp4'; // Default
    if (item.metadata.type == 'movie' || item.metadata.type == 'episode') {
      extension = '.mp4'; // Most common video format
    }

    final filename =
        '${safeTitle}_${hash.toString().substring(0, 8)}$extension';
    return join(downloadsDir.path, filename);
  }

  /// Download poster image for offline media
  Future<String?> _downloadPosterImage(
    DownloadQueueItem item,
    PlexClient client,
  ) async {
    try {
      // Get poster URL from metadata
      String? posterPath;
      final metadata = item.metadata;

      if (metadata.thumb != null && metadata.thumb!.isNotEmpty) {
        posterPath = metadata.thumb;
      } else if (metadata.art != null && metadata.art!.isNotEmpty) {
        posterPath = metadata.art;
      }

      if (posterPath == null) {
        appLogger.d('No poster available for ${metadata.title}');
        return null;
      }

      // Generate local poster path
      final hash = md5.convert(
        utf8.encode('${item.serverId}_${item.ratingKey}'),
      );
      final posterHash = md5.convert(utf8.encode('${posterPath}'));
      final appDir = await getApplicationDocumentsDirectory();
      final postersDir = Directory(join(appDir.path, 'Downloads', 'posters'));
      await postersDir.create(recursive: true);

      final posterFileName =
          '${hash.toString().substring(0, 8)}_${posterHash.toString().substring(0, 8)}.jpg';
      final localPosterPath = join(postersDir.path, posterFileName);

      // Download poster image
      final posterUrl = PlexImageHelper.getOptimizedImageUrl(
        client: client,
        thumbPath: posterPath,
        maxWidth: 300,
        maxHeight: 450,
        devicePixelRatio: 1.0,
        enableTranscoding: true,
      );

      if (posterUrl.isEmpty) {
        appLogger.w('Could not generate poster URL for ${metadata.title}');
        return null;
      }

      final response = await Dio().get(
        posterUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final posterFile = File(localPosterPath);
      await posterFile.writeAsBytes(response.data);

      appLogger.d('Downloaded poster for ${metadata.title}: $localPosterPath');
      return localPosterPath;
    } catch (e) {
      appLogger.w('Error downloading poster image: $e');
      return null;
    }
  }

  /// Update offline item metadata with local poster path
  Future<void> _updateItemMetadataWithPoster(
    String itemId,
    String posterPath,
  ) async {
    try {
      final result = await _database!.query(
        'offline_media',
        where: 'id = ?',
        whereArgs: [itemId],
      );

      if (result.isNotEmpty) {
        final item = _offlineItemFromMap(result.first);
        final updatedMediaInfo = Map<String, dynamic>.from(
          item.mediaInfo ?? {},
        );

        // Store local poster path in metadata
        updatedMediaInfo['localPosterPath'] = posterPath;

        await _database!.update(
          'offline_media',
          {'metadata': jsonEncode(updatedMediaInfo)},
          where: 'id = ?',
          whereArgs: [itemId],
        );
      }
    } catch (e) {
      appLogger.w('Failed to update metadata with poster path: $e');
    }
  }

  OfflineMediaType _parseOfflineMediaType(String? typeString) {
    if (typeString == null) return OfflineMediaType.movie;

    try {
      return OfflineMediaType.values.firstWhere(
        (t) => t.name == typeString,
        orElse: () => OfflineMediaType.movie,
      );
    } catch (e) {
      appLogger.w('Invalid OfflineMediaType: $typeString, defaulting to movie');
      return OfflineMediaType.movie;
    }
  }

  OfflineMediaStatus _parseOfflineMediaStatus(String? statusString) {
    if (statusString == null) return OfflineMediaStatus.pending;

    try {
      return OfflineMediaStatus.values.firstWhere(
        (s) => s.name == statusString,
        orElse: () => OfflineMediaStatus.pending,
      );
    } catch (e) {
      appLogger.w(
        'Invalid OfflineMediaStatus: $statusString, defaulting to pending',
      );
      return OfflineMediaStatus.pending;
    }
  }

  void dispose() {
    _progressController.close();
    for (final token in _downloadTokens.values) {
      token.cancel();
    }
    _downloadTokens.clear();
  }
}

class OfflineDownloadProgress {
  final String itemId;
  final int downloadedBytes;
  final int totalBytes;
  final double progress;

  OfflineDownloadProgress({
    required this.itemId,
    required this.downloadedBytes,
    required this.totalBytes,
    required this.progress,
  });
}
