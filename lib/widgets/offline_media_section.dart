import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../providers/offline_provider.dart';
import '../screens/offline_downloads_screen.dart';
import 'offline_media_card.dart';

class OfflineMediaSection extends StatelessWidget {
  const OfflineMediaSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        // Only show the section when user is offline
        if (!offlineProvider.isOfflineMode) {
          return const SizedBox.shrink();
        }

        // If offline but no completed media, show empty state
        if (offlineProvider.completedMedia.isEmpty) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(context, offlineProvider),
              const SizedBox(height: 12),
              _buildEmptyState(context, offlineProvider.isOfflineMode),
            ],
          );
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Responsive card width based on screen size (same as HubSection)
        final screenWidth = constraints.maxWidth;
        final cardWidth = screenWidth > 1600
            ? 220.0
            : screenWidth > 1200
            ? 200.0
            : screenWidth > 800
            ? 190.0
            : 160.0;

        // MediaCard has 8px padding on all sides (16px total horizontally)
        // So actual poster width is cardWidth - 16
        final posterWidth = cardWidth - 16;
        // 2:3 poster aspect ratio (height is 1.5x width)
        final posterHeight = posterWidth * 1.5;
        // Container height = poster + padding + spacing + text + focus indicator headroom
        // 8px top padding + posterHeight + 4px spacing + ~26px text + 8px bottom padding
        // + 10px extra for focus indicator border (3px) and scale effect (1.02x)
        final containerHeight = posterHeight + 46 + 10;

        return SizedBox(
          height: containerHeight,
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: completedMedia.length,
            itemBuilder: (context, index) {
              final item = completedMedia[index];
              final metadata = _createMetadataFromOfflineItem(item);

              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: OfflineMediaCard(
                  key: Key(item.id),
                  offlineItem: item,
                  metadata: metadata,
                  width: cardWidth,
                  height: containerHeight,
                  onRefresh: () => _handleItemRefresh(item, context),
                ),
              );
            },
          ),
        );
      },
    );
  }

  void _handleItemRefresh(OfflineMediaItem _, BuildContext context) {
    // Refresh functionality if needed for offline items
    // For now, we can trigger a general refresh of the offline provider
    final offlineProvider = Provider.of<OfflineProvider>(
      context,
      listen: false,
    );
    offlineProvider.refresh();
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

  /// Create PlexMetadata from OfflineMediaItem for video player compatibility
  PlexMetadata _createMetadataFromOfflineItem(OfflineMediaItem item) {
    // Extract metadata from stored mediaInfo if available
    final mediaInfo = item.mediaInfo;

    // Use local poster path if available, otherwise fallback to original
    String? thumbPath;
    String? artPath;

    if (mediaInfo != null && mediaInfo['localPosterPath'] != null) {
      // Use local poster for both thumb and art
      final localPoster = 'file://${mediaInfo['localPosterPath']}';
      thumbPath = localPoster;
      artPath = localPoster;
    } else {
      // Fallback to original paths (will fail when offline, but preserved for metadata)
      thumbPath = mediaInfo?['thumb'] as String?;
      artPath = mediaInfo?['art'] as String?;
    }

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
      thumb: thumbPath,
      art: artPath,
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
