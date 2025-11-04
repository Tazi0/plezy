import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../client/plex_client.dart';
import '../mixins/item_updatable.dart';
import '../models/plex_metadata.dart';
import '../providers/plex_client_provider.dart';
import '../screens/artist_detail_screen.dart';
import '../theme/theme_helper.dart';
import '../utils/provider_extensions.dart';
import '../utils/video_player_navigation.dart';
import '../widgets/app_bar_back_button.dart';
import '../widgets/desktop_app_bar.dart';
import '../widgets/media_context_menu.dart';

class AlbumDetailScreen extends StatefulWidget {
  final PlexMetadata album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen>
    with ItemUpdatable {
  @override
  PlexClient get client => context.clientSafe;

  List<PlexMetadata> _tracks = [];
  bool _isLoadingTracks = false;
  bool _watchStateChanged = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadTracks();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTracks() async {
    setState(() {
      _isLoadingTracks = true;
    });

    try {
      final clientProvider = context.plexClient;
      final client = clientProvider.client;
      if (client == null) {
        throw Exception('No client available');
      }

      final tracks = await client.getChildren(widget.album.ratingKey);
      setState(() {
        _tracks = tracks;
        _isLoadingTracks = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingTracks = false;
      });
    }
  }

  @override
  Future<void> updateItem(String ratingKey) async {
    _watchStateChanged = true;
    await super.updateItem(ratingKey);
  }

  @override
  void updateItemInLists(String ratingKey, PlexMetadata updatedMetadata) {
    final index = _tracks.indexWhere((item) => item.ratingKey == ratingKey);
    if (index != -1) {
      _tracks[index] = updatedMetadata;
    }
  }

  Future<void> _playTrack(PlexMetadata track) async {
    await navigateToVideoPlayer(context, metadata: track);
    _loadTracks();
  }

  Future<void> _playAlbum() async {
    if (_tracks.isNotEmpty) {
      await _playTrack(_tracks.first);
    }
  }

  void _navigateToArtist() {
    if (widget.album.parentRatingKey != null) {
      final artistMetadata = PlexMetadata(
        ratingKey: widget.album.parentRatingKey!,
        key: widget.album.parentRatingKey!,
        title: widget.album.parentTitle ?? 'Unknown Artist',
        type: 'artist',
        thumb: widget.album.parentThumb,
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ArtistDetailScreen(artist: artistMetadata),
        ),
      );
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatTotalDuration() {
    if (_tracks.isEmpty) return '';
    final totalMs = _tracks
        .where((track) => track.duration != null)
        .fold<int>(0, (sum, track) => sum + track.duration!);

    return _formatDuration(totalMs);
  }

  @override
  Widget build(BuildContext context) {
    // Determine header height based on screen size
    final size = MediaQuery.of(context).size;
    final isDesktop = size.width > 600;
    final headerHeight = isDesktop ? size.height * 0.6 : size.height * 0.4;

    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Hero header with background art
          DesktopSliverAppBar(
            expandedHeight: headerHeight,
            pinned: true,
            leading: AppBarBackButton(
              style: BackButtonStyle.circular,
              onPressed: () => Navigator.pop(context, _watchStateChanged),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Background Art
                  if (widget.album.thumb != null)
                    Consumer<PlexClientProvider>(
                      builder: (context, clientProvider, child) {
                        final client = clientProvider.client;
                        if (client == null) {
                          return Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          );
                        }
                        return CachedNetworkImage(
                          imageUrl: client.getThumbnailUrl(widget.album.thumb),
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                          ),
                        );
                      },
                    )
                  else
                    Container(
                      color: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                    ),

                  // Gradient overlay
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.7),
                          Colors.black.withValues(alpha: 0.95),
                        ],
                        stops: const [0.3, 0.7, 1.0],
                      ),
                    ),
                  ),

                  // Content at bottom
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Album artwork, title and metadata
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                // Album cover
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.5),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: widget.album.thumb != null
                                        ? Consumer<PlexClientProvider>(
                                            builder:
                                                (
                                                  context,
                                                  clientProvider,
                                                  child,
                                                ) {
                                                  final client =
                                                      clientProvider.client;
                                                  if (client != null) {
                                                    return CachedNetworkImage(
                                                      imageUrl: client
                                                          .getThumbnailUrl(
                                                            widget.album.thumb!,
                                                          ),
                                                      fit: BoxFit.cover,
                                                      placeholder:
                                                          (
                                                            context,
                                                            url,
                                                          ) => Container(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            child: const Center(
                                                              child:
                                                                  CircularProgressIndicator(
                                                                    color: Colors
                                                                        .white,
                                                                  ),
                                                            ),
                                                          ),
                                                      errorWidget:
                                                          (
                                                            context,
                                                            url,
                                                            error,
                                                          ) => Container(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.3,
                                                                ),
                                                            child: const Icon(
                                                              Icons.album,
                                                              size: 40,
                                                              color:
                                                                  Colors.white,
                                                            ),
                                                          ),
                                                    );
                                                  }
                                                  return Container(
                                                    color: Colors.black
                                                        .withOpacity(0.3),
                                                    child: const Icon(
                                                      Icons.album,
                                                      size: 40,
                                                      color: Colors.white,
                                                    ),
                                                  );
                                                },
                                          )
                                        : Container(
                                            color: Colors.black.withOpacity(
                                              0.3,
                                            ),
                                            child: const Icon(
                                              Icons.album,
                                              size: 40,
                                              color: Colors.white,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Album title and metadata
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Album title
                                      Text(
                                        widget.album.title,
                                        style: Theme.of(context)
                                            .textTheme
                                            .displaySmall
                                            ?.copyWith(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.5),
                                                  blurRadius: 8,
                                                ),
                                              ],
                                            ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (widget.album.parentTitle != null) ...[
                                        const SizedBox(height: 8),
                                        GestureDetector(
                                          onTap: _navigateToArtist,
                                          child: Text(
                                            widget.album.parentTitle ?? "",
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
                                              decorationColor: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  color: Colors.black,
                                                  blurRadius: 4,
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                      const SizedBox(height: 12),
                                      // Metadata chips
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          // Album type chip
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.4,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'ALBUM',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          if (widget.album.year != null)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${widget.album.year}',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          if (_tracks.isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '${_tracks.length} tracks',
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          if (_tracks.isNotEmpty &&
                                              _formatTotalDuration().isNotEmpty)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(
                                                  alpha: 0.4,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                _formatTotalDuration(),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 48,
                          child: FilledButton.icon(
                            onPressed: _tracks.isEmpty ? null : _playAlbum,
                            icon: const Icon(Icons.play_arrow, size: 20),
                            label: const Text(
                              'Play Album',
                              style: TextStyle(fontSize: 16),
                            ),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Tracks
                  Text(
                    'Tracks',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingTracks)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_tracks.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          'No tracks found',
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(color: Colors.grey),
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.zero,
                      itemCount: _tracks.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final track = _tracks[index];
                        return _buildTrackCard(track, index);
                      },
                    ),
                  const SizedBox(height: 24),

                  // Summary
                  if (widget.album.summary != null &&
                      widget.album.summary!.isNotEmpty) ...[
                    Text(
                      'About',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.album.summary!,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    ),
                    const SizedBox(height: 24),
                  ],

                  // Additional info
                  if (widget.album.parentTitle != null) ...[
                    _buildInfoRow('Artist', widget.album.parentTitle!),
                    const SizedBox(height: 12),
                  ],
                  if (widget.album.studio != null) ...[
                    _buildInfoRow('Label', widget.album.studio!),
                    const SizedBox(height: 12),
                  ],
                  if (widget.album.year != null) ...[
                    _buildInfoRow('Year', '${widget.album.year}'),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrackCard(PlexMetadata track, int index) {
    return MediaContextMenu(
      metadata: track,
      onRefresh: updateItem,
      onTap: () async {
        await _playTrack(track);
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: Theme.of(context).colorScheme.surface,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => _playTrack(track),
            hoverColor: Theme.of(context).colorScheme.primary.withOpacity(0.1),
            splashColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Track number
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: Text(
                        '${track.index ?? index + 1}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Track info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                        if (track.duration != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            _formatTrackDuration(track.duration!),
                            style: TextStyle(
                              color: tokens(context).textMuted,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Play button
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.play_arrow,
                        color: Theme.of(context).colorScheme.primary,
                        size: 20,
                      ),
                      onPressed: () => _playTrack(track),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: widget.album.parentTitle != null && label == 'Artist'
              ? GestureDetector(
                  onTap: _navigateToArtist,
                  child: Text(
                    value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                )
              : Text(value, style: Theme.of(context).textTheme.bodyLarge),
        ),
      ],
    );
  }

  String _formatTrackDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }
}
