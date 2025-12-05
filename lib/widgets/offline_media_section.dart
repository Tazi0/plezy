import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../providers/offline_provider.dart';
import '../screens/offline_downloads_screen.dart';
import '../utils/app_logger.dart';
import '../utils/video_player_navigation.dart';

class OfflineMediaSection extends StatelessWidget {
  const OfflineMediaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        if (!offlineProvider.isOfflineMode &&
            offlineProvider.completedMedia.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, offlineProvider),
            const SizedBox(height: 12),
            _buildMediaGrid(context, offlineProvider),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    OfflineProvider offlineProvider,
  ) {
    final theme = Theme.of(context);
    final isOffline = offlineProvider.isOfflineMode;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          if (isOffline)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.cloud_off,
                    size: 16,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    t.offline.mode,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isOffline
                  ? t.offline.downloaded_content
                  : t.offline.downloaded_media,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => _navigateToDownloads(context),
            child: Text(t.offline.manage_downloads),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaGrid(
    BuildContext context,
    OfflineProvider offlineProvider,
  ) {
    final completedMedia = offlineProvider.completedMedia;

    if (completedMedia.isEmpty) {
      return _buildEmptyState(context, offlineProvider.isOfflineMode);
    }

    return SizedBox(
      height: 200,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: completedMedia.length,
        itemBuilder: (context, index) {
          final item = completedMedia[index];
          return Padding(
            padding: EdgeInsets.only(
              right: index < completedMedia.length - 1 ? 12 : 0,
            ),
            child: _buildMediaItem(context, item, offlineProvider),
          );
        },
      ),
    );
  }

  Widget _buildMediaItem(
    BuildContext context,
    OfflineMediaItem item,
    OfflineProvider offlineProvider,
  ) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => _handleItemTap(context, item),
      child: SizedBox(
        width: 120,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: theme.colorScheme.surfaceVariant,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Stack(
                  children: [
                    _buildPoster(context, item),
                    _buildOfflineIndicator(context),
                    if (item.type == OfflineMediaType.episode)
                      _buildEpisodeOverlay(context, item),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              item.title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster(BuildContext context, OfflineMediaItem item) {
    // For now, show a placeholder since we don't have the image URL stored
    // In a complete implementation, we'd store image URLs in mediaInfo
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Icon(
        _getTypeIcon(item.type),
        size: 48,
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  Widget _buildOfflineIndicator(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green.shade600,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.download_done, size: 16, color: Colors.white),
      ),
    );
  }

  Widget _buildEpisodeOverlay(BuildContext context, OfflineMediaItem item) {
    return Positioned(
      bottom: 8,
      left: 8,
      right: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.7),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          _getEpisodeInfo(item),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isOfflineMode) {
    final theme = Theme.of(context);

    return Container(
      height: 120,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.3)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isOfflineMode ? Icons.cloud_off : Icons.download,
              size: 32,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              isOfflineMode
                  ? t.offline.no_downloaded_content
                  : t.offline.no_downloads_yet,
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

  String _getEpisodeInfo(OfflineMediaItem item) {
    // Extract episode info from mediaInfo if available
    if (item.mediaInfo != null) {
      final parentIndex = item.mediaInfo!['parentIndex'];
      final index = item.mediaInfo!['index'];
      if (parentIndex != null && index != null) {
        return 'S${parentIndex}E${index}';
      }
    }
    return item.type.name.toUpperCase();
  }

  void _handleItemTap(BuildContext context, OfflineMediaItem item) {
    appLogger.d('Tapped offline media item: ${item.title}');

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

  void _navigateToDownloads(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const OfflineDownloadsScreen()),
    );
  }
}
