import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plex_metadata.dart';
import '../providers/plex_client_provider.dart';
import '../screens/artist_detail_screen.dart';
import '../theme/theme_helper.dart';
import '../utils/provider_extensions.dart';
import '../utils/video_player_navigation.dart';
import '../widgets/app_bar_back_button.dart';
import '../widgets/desktop_app_bar.dart';

class AlbumDetailScreen extends StatefulWidget {
  final PlexMetadata album;

  const AlbumDetailScreen({super.key, required this.album});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  List<PlexMetadata> _tracks = [];
  bool _isLoading = true;
  String? _errorMessage;
  final ScrollController _scrollController = ScrollController();
  bool _showStickyPlayButton = false;

  @override
  void initState() {
    super.initState();
    _loadTracks();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final shouldShow = _scrollController.offset > 300;
    if (shouldShow != _showStickyPlayButton) {
      setState(() {
        _showStickyPlayButton = shouldShow;
      });
    }
  }

  Future<void> _loadTracks() async {
    final client = context.client;
    if (client == null) {
      setState(() {
        _errorMessage = 'No client available';
        _isLoading = false;
      });
      return;
    }

    try {
      final tracks = await client.getChildren(widget.album.ratingKey);
      setState(() {
        _tracks = tracks;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load tracks: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _playTrack(PlexMetadata track) async {
    await navigateToVideoPlayer(context, metadata: track);
  }

  Future<void> _playAlbum() async {
    if (_tracks.isNotEmpty) {
      await navigateToVideoPlayer(context, metadata: _tracks.first);
    }
  }

  Future<void> _navigateToArtist() async {
    if (widget.album.parentRatingKey == null) return;

    final client = context.client;
    if (client == null) return;

    try {
      final artistMetadata = await client.getMetadata(
        widget.album.parentRatingKey!,
      );
      if (artistMetadata != null && mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistDetailScreen(artist: artistMetadata),
          ),
        );
      }
    } catch (e) {
      // Handle error silently or show a snackbar
    }
  }

  String _formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatTotalDuration() {
    if (_tracks.isEmpty) return '';
    final totalMs = _tracks
        .where((track) => track.duration != null)
        .fold<int>(0, (sum, track) => sum + track.duration!);

    final totalDuration = Duration(milliseconds: totalMs);
    final hours = totalDuration.inHours;
    final minutes = totalDuration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          DesktopSliverAppBar(
            expandedHeight: 400,
            pinned: true,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.8),
            flexibleSpace: FlexibleSpaceBar(background: _buildAlbumHeader()),
            leading: const AppBarBackButton(style: BackButtonStyle.circular),
            actions: [
              if (_showStickyPlayButton && !_isLoading && _tracks.isNotEmpty)
                Container(
                  margin: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.play_arrow, color: Colors.white),
                    onPressed: _playAlbum,
                    tooltip: 'Play Album',
                  ),
                ),
            ],
          ),
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_errorMessage != null)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: tokens(context).textMuted,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: tokens(context).textMuted),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _isLoading = true;
                          _errorMessage = null;
                        });
                        _loadTracks();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_tracks.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No tracks found')),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Album info section
                  Container(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        const SizedBox(height: 24),
                        // Album stats
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatItem('${_tracks.length}', 'tracks'),
                            Container(
                              width: 1,
                              height: 24,
                              color: tokens(context).outline,
                            ),
                            _buildStatItem(_formatTotalDuration(), 'duration'),
                            if (widget.album.year != null) ...[
                              Container(
                                width: 1,
                                height: 24,
                                color: tokens(context).outline,
                              ),
                              _buildStatItem('${widget.album.year}', 'year'),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Track list
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _tracks.length,
                    itemBuilder: (context, index) {
                      final track = _tracks[index];
                      return _buildTrackTile(track, index);
                    },
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAlbumHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.8),
            Theme.of(context).colorScheme.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background album art with blur
          if (widget.album.thumb != null)
            Positioned.fill(
              child: Consumer<PlexClientProvider>(
                builder: (context, clientProvider, child) {
                  final client = clientProvider.client;
                  if (client != null) {
                    return CachedNetworkImage(
                      imageUrl: client.getThumbnailUrl(widget.album.thumb!),
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.3),
                      colorBlendMode: BlendMode.darken,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          // Content
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.7)],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Album artwork
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Album cover
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: widget.album.thumb != null
                              ? Consumer<PlexClientProvider>(
                                  builder: (context, clientProvider, child) {
                                    final client = clientProvider.client;
                                    if (client != null) {
                                      return CachedNetworkImage(
                                        imageUrl: client.getThumbnailUrl(
                                          widget.album.thumb!,
                                        ),
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) =>
                                            Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                              child: const Center(
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Colors.white,
                                                    ),
                                              ),
                                            ),
                                        errorWidget: (context, url, error) =>
                                            Container(
                                              color: Theme.of(context)
                                                  .colorScheme
                                                  .primary
                                                  .withOpacity(0.3),
                                              child: const Icon(
                                                Icons.album,
                                                size: 60,
                                                color: Colors.white,
                                              ),
                                            ),
                                      );
                                    }
                                    return Container(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.primary.withOpacity(0.3),
                                      child: const Icon(
                                        Icons.album,
                                        size: 60,
                                        color: Colors.white,
                                      ),
                                    );
                                  },
                                )
                              : Container(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.primary.withOpacity(0.3),
                                  child: const Icon(
                                    Icons.album,
                                    size: 60,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Album info and play button
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ALBUM',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.album.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
                            ),
                            if (widget.album.parentTitle != null) ...[
                              const SizedBox(height: 8),
                              MouseRegion(
                                cursor: SystemMouseCursors.click,
                                child: GestureDetector(
                                  onTap: _navigateToArtist,
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'by ${widget.album.parentTitle}',
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.9),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        decoration: TextDecoration.underline,
                                        decorationColor: Colors.white
                                            .withOpacity(0.6),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                            if (!_isLoading && _tracks.isNotEmpty) ...[
                              const SizedBox(height: 16),
                              // Play button in header
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(30),
                                    onTap: _playAlbum,
                                    child: const Icon(
                                      Icons.play_arrow,
                                      color: Colors.white,
                                      size: 30,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: tokens(context).textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTrackTile(PlexMetadata track, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
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
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
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
                          _formatDuration(track.duration!),
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
    );
  }
}
