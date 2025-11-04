import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/plex_metadata.dart';
import '../providers/plex_client_provider.dart';
import '../theme/theme_helper.dart';
import '../utils/provider_extensions.dart';
import '../widgets/album_card.dart';
import '../widgets/app_bar_back_button.dart';
import '../widgets/desktop_app_bar.dart';

class ArtistDetailScreen extends StatefulWidget {
  final PlexMetadata artist;

  const ArtistDetailScreen({super.key, required this.artist});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  List<PlexMetadata> _albums = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadAlbums();
  }

  Future<void> _loadAlbums() async {
    final client = context.client;
    if (client == null) {
      setState(() {
        _errorMessage = 'No client available';
        _isLoading = false;
      });
      return;
    }

    try {
      final albums = await client.getChildren(widget.artist.ratingKey);
      setState(() {
        _albums = albums;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load albums: $e';
        _isLoading = false;
      });
    }
  }

  void _refreshAlbum(String ratingKey) {
    // Find and refresh specific album if needed
    final index = _albums.indexWhere((album) => album.ratingKey == ratingKey);
    if (index != -1) {
      // Could reload the specific album data here if needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          DesktopSliverAppBar(
            expandedHeight: 350,
            pinned: true,
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.8),
            flexibleSpace: FlexibleSpaceBar(background: _buildArtistHeader()),
            leading: const AppBarBackButton(style: BackButtonStyle.circular),
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
                        _loadAlbums();
                      },
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (_albums.isEmpty)
            const SliverFillRemaining(
              child: Center(child: Text('No albums found')),
            )
          else
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Albums section header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.album,
                          color: Theme.of(context).colorScheme.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Albums',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_albums.length}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Albums grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 180,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.85,
                          ),
                      itemCount: _albums.length,
                      itemBuilder: (context, index) {
                        final album = _albums[index];
                        return AlbumCard(
                          key: Key(album.ratingKey),
                          album: album,
                          onRefresh: _refreshAlbum,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildArtistHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.1),
            Theme.of(context).colorScheme.primary.withOpacity(0.6),
            Theme.of(context).colorScheme.primary,
          ],
        ),
      ),
      child: Stack(
        children: [
          // Background artist image with blur
          if (widget.artist.thumb != null)
            Positioned.fill(
              child: Consumer<PlexClientProvider>(
                builder: (context, clientProvider, child) {
                  final client = clientProvider.client;
                  if (client != null) {
                    return CachedNetworkImage(
                      imageUrl: client.getThumbnailUrl(widget.artist.thumb!),
                      fit: BoxFit.cover,
                      color: Colors.black.withOpacity(0.4),
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
                  colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                ),
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Artist info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Artist image
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.5),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: widget.artist.thumb != null
                              ? Consumer<PlexClientProvider>(
                                  builder: (context, clientProvider, child) {
                                    final client = clientProvider.client;
                                    if (client != null) {
                                      return CachedNetworkImage(
                                        imageUrl: client.getThumbnailUrl(
                                          widget.artist.thumb!,
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
                                                Icons.person,
                                                size: 50,
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
                                        Icons.person,
                                        size: 50,
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
                                    Icons.person,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Artist name
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'ARTIST',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              widget.artist.title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                height: 1.1,
                              ),
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
        ],
      ),
    );
  }
}
