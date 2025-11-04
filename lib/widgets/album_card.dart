import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plex_metadata.dart';
import '../providers/plex_client_provider.dart';
import '../screens/album_detail_screen.dart';
import '../theme/theme_helper.dart';
import 'media_context_menu.dart';

class AlbumCard extends StatefulWidget {
  final PlexMetadata album;
  final double? width;
  final void Function(String ratingKey)? onRefresh;

  const AlbumCard({super.key, required this.album, this.width, this.onRefresh});

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  void _handleTap(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AlbumDetailScreen(album: widget.album),
      ),
    );
    widget.onRefresh?.call(widget.album.ratingKey);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width,
      child: MediaContextMenu(
        metadata: widget.album,
        onRefresh: widget.onRefresh,
        onTap: () => _handleTap(context),
        child: Semantics(
          label: "album-card-${widget.album.ratingKey}",
          identifier: "album-card-${widget.album.ratingKey}",
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _handleTap(context),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Square album artwork
                  Expanded(
                    child: AspectRatio(
                      aspectRatio: 1.0, // Force square aspect ratio
                      child: _buildAlbumArtwork(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Text content
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        widget.album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          height: 1.1,
                        ),
                      ),
                      if (widget.album.parentTitle != null)
                        Text(
                          widget.album.parentTitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens(context).textMuted,
                                fontSize: 11,
                                height: 1.1,
                              ),
                        )
                      else if (widget.album.year != null)
                        Text(
                          '${widget.album.year}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: tokens(context).textMuted,
                                fontSize: 11,
                                height: 1.1,
                              ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumArtwork(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        children: [
          _buildAlbumImage(context),
          // Subtle overlay with hover effect
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _handleTap(context),
                splashColor: Colors.white.withOpacity(0.1),
                highlightColor: Colors.white.withOpacity(0.05),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withOpacity(0.1),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumImage(BuildContext context) {
    final albumArt = widget.album.thumb;
    if (albumArt != null) {
      return Consumer<PlexClientProvider>(
        builder: (context, clientProvider, child) {
          final client = clientProvider.client;
          if (client == null) {
            return _buildPlaceholder(context);
          }

          return CachedNetworkImage(
            imageUrl: client.getThumbnailUrl(albumArt),
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            filterQuality: FilterQuality.medium,
            fadeInDuration: const Duration(milliseconds: 300),
            placeholder: (context, url) => _buildLoadingSkeleton(context),
            errorWidget: (context, url, error) => _buildPlaceholder(context),
          );
        },
      );
    } else {
      return _buildPlaceholder(context);
    }
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.album, size: 48, color: tokens(context).textMuted),
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}
