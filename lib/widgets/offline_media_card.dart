import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/offline_media_item.dart';
import '../models/plex_metadata.dart';
import '../providers/offline_provider.dart';
import '../providers/settings_provider.dart';
import '../utils/video_player_navigation.dart';
import '../utils/content_rating_formatter.dart';
import '../utils/duration_formatter.dart';
import '../i18n/strings.g.dart';

/// MediaCard specifically designed for offline content with local image support
class OfflineMediaCard extends StatelessWidget {
  final OfflineMediaItem offlineItem;
  final PlexMetadata metadata;
  final double? width;
  final double? height;
  final VoidCallback? onRefresh;

  const OfflineMediaCard({
    super.key,
    required this.offlineItem,
    required this.metadata,
    this.width,
    this.height,
    this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: Container(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster with offline indicator
            Expanded(
              child: Stack(
                children: [
                  _buildPoster(context),
                  _buildOfflineIndicator(context),
                  _buildProgressOverlay(context),
                ],
              ),
            ),
            const SizedBox(height: 4),
            // Title and metadata
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    metadata.displayTitle,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_shouldShowMetadata())
                    Text(
                      _buildMetadataLine(),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(
                          context,
                        ).textTheme.bodySmall?.color?.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPoster(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        child: _buildOfflineImage(context),
      ),
    );
  }

  Widget _buildOfflineImage(BuildContext context) {
    // Check if we have a local poster path
    final localPosterPath =
        offlineItem.mediaInfo?['localPosterPath'] as String?;

    if (localPosterPath != null && localPosterPath.isNotEmpty) {
      final file = File(localPosterPath);
      return FutureBuilder<bool>(
        future: file.exists(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data == true) {
            return Image.file(
              file,
              width: double.infinity,
              height: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallbackPoster(context);
              },
            );
          }
          return _buildFallbackPoster(context);
        },
      );
    }

    // No local poster available
    return _buildFallbackPoster(context);
  }

  Widget _buildFallbackPoster(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Theme.of(context).colorScheme.surfaceVariant,
      child: Center(
        child: Icon(
          _getTypeIcon(),
          size: 48,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
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

  Widget _buildProgressOverlay(BuildContext context) {
    // Show progress bar if the item has been partially watched
    if (metadata.viewOffset != null &&
        metadata.duration != null &&
        metadata.viewOffset! > 0 &&
        metadata.duration! > 0) {
      final progress = metadata.viewOffset! / metadata.duration!;
      if (progress > 0.05 && progress < 0.95) {
        // Only show for meaningful progress
        return Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            height: 4,
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(8),
                bottomRight: Radius.circular(8),
              ),
              child: LinearProgressIndicator(
                value: progress,
                backgroundColor: Colors.black.withOpacity(0.3),
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
    }

    // Show watched indicator if fully watched
    if (metadata.isWatched) {
      return Positioned(
        top: 8,
        left: 8,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  IconData _getTypeIcon() {
    switch (offlineItem.type) {
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

  bool _shouldShowMetadata() {
    return metadata.type == 'episode' ||
        metadata.year != null ||
        metadata.duration != null;
  }

  String _buildMetadataLine() {
    final parts = <String>[];

    // For episodes, show season/episode info
    if (metadata.type == 'episode') {
      if (metadata.parentIndex != null && metadata.index != null) {
        parts.add('S${metadata.parentIndex}E${metadata.index}');
      }
    }

    // Add year for movies
    if (metadata.year != null && metadata.type == 'movie') {
      parts.add('${metadata.year}');
    }

    // Add content rating
    final rating = formatContentRating(metadata.contentRating);
    if (rating.isNotEmpty) {
      parts.add(rating);
    }

    // Add duration
    if (metadata.duration != null) {
      parts.add(formatDurationTextual(metadata.duration!));
    }

    return parts.join(' • ');
  }

  void _handleTap(BuildContext context) async {
    // Navigate to offline video player
    await navigateToOfflineVideoPlayer(
      context,
      metadata: metadata,
      offlineItem: offlineItem,
    );

    // Refresh if needed
    onRefresh?.call();
  }
}
