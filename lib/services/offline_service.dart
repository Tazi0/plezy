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
import '../utils/app_logger.dart';

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

  Stream<OfflineDownloadProgress> get progressStream =>
      _progressController.stream;

  Future<void> initialize() async {
    if (_isInitialized) return;

    await _initDatabase();
    _isInitialized = true;
    appLogger.d('OfflineService initialized');
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
      final offlineItem = OfflineMediaItem(
        id: item.id,
        ratingKey: item.ratingKey,
        serverId: item.serverId,
        serverName: item.serverName,
        title: item.metadata.title ?? 'Unknown',
        type: _getOfflineMediaType(item.metadata.type),
        status: OfflineMediaStatus.downloading,
        localPath: await _generateLocalPath(item),
        fileSize: 0,
        downloadedSize: 0,
        createdAt: DateTime.now(),
      );

      await _saveOfflineItem(offlineItem);

      // Download implementation would go here
      // For now, just simulate progress
      await _simulateDownload(item, cancelToken);
    } catch (e) {
      await _updateItemStatus(
        item.id,
        OfflineMediaStatus.failed,
        error: e.toString(),
      );
    } finally {
      _downloadTokens.remove(item.id);
    }
  }

  Future<void> _simulateDownload(
    DownloadQueueItem item,
    CancelToken cancelToken,
  ) async {
    const totalSize = 100 * 1024 * 1024; // 100MB simulation
    var downloaded = 0;

    // Update file size in the database
    await _database!.update(
      'offline_media',
      {'file_size': totalSize},
      where: 'id = ?',
      whereArgs: [item.id],
    );

    while (downloaded < totalSize && !cancelToken.isCancelled) {
      await Future.delayed(const Duration(milliseconds: 100));
      downloaded += 1024 * 1024; // 1MB per tick

      _progressController.add(
        OfflineDownloadProgress(
          itemId: item.id,
          downloadedBytes: downloaded,
          totalBytes: totalSize,
          progress: downloaded / totalSize,
        ),
      );

      await _database!.update(
        'offline_media',
        {'downloaded_size': downloaded},
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }

    if (!cancelToken.isCancelled) {
      await _updateItemStatus(item.id, OfflineMediaStatus.completed);
      // Remove from download queue
      await _database!.delete(
        'download_queue',
        where: 'id = ?',
        whereArgs: [item.id],
      );
    }
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
    final filename =
        '${(item.metadata.title ?? 'unknown').replaceAll(RegExp(r'[^\w\s-]'), '')}_${hash.toString().substring(0, 8)}.mp4';

    return join(downloadsDir.path, filename);
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
