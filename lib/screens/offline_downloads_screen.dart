import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../providers/offline_provider.dart';
import '../utils/app_logger.dart';
import '../utils/video_player_navigation.dart';

class OfflineDownloadsScreen extends StatefulWidget {
  const OfflineDownloadsScreen({super.key});

  @override
  State<OfflineDownloadsScreen> createState() => _OfflineDownloadsScreenState();
}

class _OfflineDownloadsScreenState extends State<OfflineDownloadsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    // Refresh data when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OfflineProvider>().refresh();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t.offline.manage_downloads),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
        scrolledUnderElevation: 0,
        actions: [
          Consumer<OfflineProvider>(
            builder: (context, offlineProvider, child) {
              return IconButton(
                icon: Icon(
                  offlineProvider.hasConnectivity
                      ? Icons.cloud
                      : Icons.cloud_off,
                  color: offlineProvider.hasConnectivity
                      ? Colors.green
                      : Colors.orange,
                ),
                onPressed: () => offlineProvider.refreshConnectivity(),
                tooltip: offlineProvider.hasConnectivity
                    ? t.common.online
                    : t.common.offline,
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.download_done), text: 'Downloaded'),
            Tab(icon: Icon(Icons.downloading), text: 'Downloading'),
            Tab(icon: Icon(Icons.settings), text: 'Settings'),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildDownloadedTab(),
                  _buildDownloadingTab(),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDownloadedTab() {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        final completedMedia = offlineProvider.completedMedia;

        if (offlineProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: completedMedia.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.download_done,
                      title: t.offline.no_downloads_yet,
                      subtitle: 'Start downloading content to watch offline',
                    )
                  : RefreshIndicator(
                      onRefresh: () => offlineProvider.refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: completedMedia.length,
                        itemBuilder: (context, index) {
                          final item = completedMedia[index];
                          return _buildDownloadedItem(item);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadingTab() {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        final allMedia = offlineProvider.offlineMedia;
        final activeDownloads = allMedia
            .where(
              (item) =>
                  item.status == OfflineMediaStatus.pending ||
                  item.status == OfflineMediaStatus.downloading,
            )
            .toList();

        if (offlineProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        return Column(
          children: [
            Expanded(
              child: activeDownloads.isEmpty
                  ? _buildEmptyState(
                      icon: Icons.downloading,
                      title: 'No active downloads',
                      subtitle: 'Downloads will appear here when they start',
                    )
                  : RefreshIndicator(
                      onRefresh: () => offlineProvider.refresh(),
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: activeDownloads.length,
                        itemBuilder: (context, index) {
                          final item = activeDownloads[index];
                          return _buildDownloadingItem(item, offlineProvider);
                        },
                      ),
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSettingsTab() {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Debug information card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Download Settings',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      leading: const Icon(Icons.high_quality),
                      title: Text(t.offline.download_quality),
                      subtitle: const Text('High (720p)'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        // TODO: Implement quality selection
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.wifi),
                      title: Text(t.offline.wifi_only),
                      subtitle: const Text(
                        'Only download when connected to WiFi',
                      ),
                      value: true, // TODO: Connect to actual setting
                      onChanged: (value) {
                        // TODO: Implement WiFi only setting
                      },
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.auto_awesome),
                      title: Text(t.offline.auto_download),
                      subtitle: const Text(
                        'Automatically download new episodes',
                      ),
                      value: false, // TODO: Connect to actual setting
                      onChanged: (value) {
                        // TODO: Implement auto download setting
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDownloadedItem(OfflineMediaItem item) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  _getTypeIcon(item.type),
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned(
                top: 4,
                right: 4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.green.shade600,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.download_done,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_formatFileSize(item.fileSize)} • ${_formatType(item.type)}',
              style: theme.textTheme.bodySmall,
            ),
            if (item.completedAt != null)
              Text(
                'Downloaded ${_formatDate(item.completedAt!)}',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleDownloadedItemAction(value, item),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow),
                  SizedBox(width: 8),
                  Text('Play'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Delete', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _handlePlayOfflineItem(item),
      ),
    );
  }

  Widget _buildDownloadingItem(
    OfflineMediaItem item,
    OfflineProvider offlineProvider,
  ) {
    final theme = Theme.of(context);
    final progress = offlineProvider.getDownloadProgress(item.id);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 56,
          height: 80,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Stack(
            children: [
              Center(
                child: Icon(
                  _getTypeIcon(item.type),
                  size: 32,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Positioned(
                bottom: 4,
                left: 4,
                right: 4,
                child: LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        title: Text(
          item.title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${(progress * 100).toInt()}% • ${_formatFileSize(item.downloadedSize)} / ${_formatFileSize(item.fileSize)}',
              style: theme.textTheme.bodySmall,
            ),
            Text(
              _formatType(item.type),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.cancel, color: Colors.red),
          onPressed: () => _cancelDownload(item, offlineProvider),
          tooltip: 'Cancel Download',
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  IconData _getTypeIcon(OfflineMediaType type) {
    switch (type) {
      case OfflineMediaType.movie:
        return Icons.movie;
      case OfflineMediaType.episode:
        return Icons.tv;
      case OfflineMediaType.season:
        return Icons.playlist_play;
      case OfflineMediaType.series:
        return Icons.tv;
    }
  }

  String _formatType(OfflineMediaType type) {
    switch (type) {
      case OfflineMediaType.movie:
        return 'Movie';
      case OfflineMediaType.episode:
        return 'Episode';
      case OfflineMediaType.season:
        return 'Season';
      case OfflineMediaType.series:
        return 'Series';
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes == 0) return '0 B';

    const units = ['B', 'KB', 'MB', 'GB', 'TB'];
    int unitIndex = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date).inDays;

    if (difference == 0) {
      return 'today';
    } else if (difference == 1) {
      return 'yesterday';
    } else if (difference < 7) {
      return '$difference days ago';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  void _handleDownloadedItemAction(String action, OfflineMediaItem item) {
    switch (action) {
      case 'play':
        _handlePlayOfflineItem(item);
        break;
      case 'delete':
        _deleteDownload(item);
        break;
    }
  }

  void _handlePlayOfflineItem(OfflineMediaItem item) {
    appLogger.d('Playing offline item: ${item.title}');

    // Convert offline item to PlexMetadata for video player navigation
    final metadata = _createMetadataFromOfflineItem(item);

    // Navigate to video player for offline playback
    navigateToOfflineVideoPlayer(
      context,
      metadata: metadata,
      offlineItem: item,
    );
  }

  /// Create PlexMetadata from OfflineMediaItem for video player compatibility
  PlexMetadata _createMetadataFromOfflineItem(OfflineMediaItem item) {
    // Extract metadata from stored mediaInfo if available
    final mediaInfo = item.mediaInfo;

    return PlexMetadata(
      ratingKey: item.ratingKey,
      key: '/library/metadata/${item.ratingKey}',
      guid: mediaInfo?['guid'] as String?,
      studio: mediaInfo?['studio'] as String?,
      type: _convertOfflineTypeToPlexType(item.type),
      title: item.title,
      contentRating: mediaInfo?['contentRating'] as String?,
      summary: mediaInfo?['summary'] as String?,
      rating: mediaInfo?['rating'] != null
          ? (mediaInfo!['rating'] as num).toDouble()
          : null,
      audienceRating: mediaInfo?['audienceRating'] != null
          ? (mediaInfo!['audienceRating'] as num).toDouble()
          : null,
      year: mediaInfo?['year'] as int?,
      thumb: mediaInfo?['thumb'] as String?,
      art: mediaInfo?['art'] as String?,
      duration: mediaInfo?['duration'] as int?,
      addedAt: mediaInfo?['addedAt'] as int?,
      updatedAt: mediaInfo?['updatedAt'] as int?,
      // Episode-specific fields
      grandparentRatingKey: mediaInfo?['grandparentRatingKey'] as String?,
      parentRatingKey: mediaInfo?['parentRatingKey'] as String?,
      grandparentTitle: mediaInfo?['grandparentTitle'] as String?,
      parentTitle: mediaInfo?['parentTitle'] as String?,
      grandparentThumb: mediaInfo?['grandparentThumb'] as String?,
      parentThumb: mediaInfo?['parentThumb'] as String?,
      grandparentArt: mediaInfo?['grandparentArt'] as String?,
      grandparentTheme: mediaInfo?['grandparentTheme'] as String?,
      index: mediaInfo?['index'] as int?,
      parentIndex: mediaInfo?['parentIndex'] as int?,
      // Use server ID from offline item
      serverId: item.serverId,
      // Resume position can be added later from progress cache
      viewOffset: null,
    );
  }

  /// Convert OfflineMediaType to Plex type string
  String _convertOfflineTypeToPlexType(OfflineMediaType type) {
    switch (type) {
      case OfflineMediaType.movie:
        return 'movie';
      case OfflineMediaType.episode:
        return 'episode';
      case OfflineMediaType.season:
        return 'season';
      case OfflineMediaType.series:
        return 'show';
    }
  }

  Future<void> _deleteDownload(OfflineMediaItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Download'),
        content: Text('Are you sure you want to delete "${item.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.common.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              t.common.delete,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        final offlineProvider = context.read<OfflineProvider>();
        await offlineProvider.deleteDownload(item.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Deleted "${item.title}"'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        appLogger.e('Failed to delete download: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete "${item.title}"'),
              backgroundColor: Colors.red.shade600,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _cancelDownload(
    OfflineMediaItem item,
    OfflineProvider offlineProvider,
  ) async {
    try {
      await offlineProvider.deleteDownload(item.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Cancelled download of "${item.title}"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      appLogger.e('Failed to cancel download: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to cancel download'),
            backgroundColor: Colors.red.shade600,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
