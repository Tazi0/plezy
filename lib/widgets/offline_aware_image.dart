import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../services/plex_client.dart';
import '../utils/plex_image_helper.dart';

/// Image widget that can load from local files (offline) or Plex server (online)
class OfflineAwareImage extends StatelessWidget {
  final PlexClient? client;
  final String? imagePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final FilterQuality filterQuality;
  final Widget Function(BuildContext, String)? placeholder;
  final Widget Function(BuildContext, String, dynamic)? errorWidget;
  final Duration fadeInDuration;
  final bool enableTranscoding;
  final Alignment alignment;
  final IconData? fallbackIcon;

  const OfflineAwareImage({
    super.key,
    this.client,
    required this.imagePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.filterQuality = FilterQuality.medium,
    this.placeholder,
    this.errorWidget,
    this.fadeInDuration = const Duration(milliseconds: 300),
    this.enableTranscoding = true,
    this.alignment = Alignment.center,
    this.fallbackIcon,
  });

  @override
  Widget build(BuildContext context) {
    // Return fallback if no image path
    if (imagePath == null || imagePath!.isEmpty) {
      return _buildFallback(context);
    }

    // Check if this is a local file path
    if (imagePath!.startsWith('file://')) {
      return _buildLocalImage(context);
    }

    // Use Plex server image if client is available
    if (client != null) {
      return _buildPlexImage(context);
    }

    // Fallback if no client available
    return _buildFallback(context);
  }

  Widget _buildLocalImage(BuildContext context) {
    final localPath = imagePath!.replaceFirst('file://', '');
    final file = File(localPath);

    return FutureBuilder<bool>(
      future: file.exists(),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data == true) {
          return Container(
            width: width,
            height: height,
            alignment: alignment,
            child: Image.file(
              file,
              width: width,
              height: height,
              fit: fit,
              filterQuality: filterQuality,
              errorBuilder: (context, error, stackTrace) {
                return _buildFallback(context);
              },
            ),
          );
        }
        return _buildFallback(context);
      },
    );
  }

  Widget _buildPlexImage(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        double resolvedDimension(
          double? explicit,
          double constraintMax,
          double fallback,
        ) {
          final candidate =
              explicit ??
              (constraintMax.isFinite && constraintMax > 0
                  ? constraintMax
                  : fallback);
          if (candidate.isNaN || candidate.isInfinite || candidate <= 0) {
            return fallback;
          }
          return candidate;
        }

        final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;

        final effectiveWidth = resolvedDimension(
          width,
          constraints.maxWidth,
          300.0,
        );
        final effectiveHeight = resolvedDimension(
          height,
          constraints.maxHeight,
          450.0,
        );

        // Get optimized image URL from Plex
        final imageUrl = PlexImageHelper.getOptimizedImageUrl(
          client: client!,
          thumbPath: imagePath,
          maxWidth: effectiveWidth,
          maxHeight: effectiveHeight,
          devicePixelRatio: devicePixelRatio,
          enableTranscoding:
              enableTranscoding && PlexImageHelper.shouldTranscode(imagePath),
        );

        if (imageUrl.isEmpty) {
          return _buildFallback(context);
        }

        return CachedNetworkImage(
          imageUrl: imageUrl,
          width: width,
          height: height,
          fit: fit,
          filterQuality: filterQuality,
          fadeInDuration: fadeInDuration,
          alignment: alignment,
          placeholder: placeholder,
          errorWidget:
              errorWidget ?? (context, url, error) => _buildFallback(context),
        );
      },
    );
  }

  Widget _buildFallback(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Icon(
          fallbackIcon ?? Icons.movie,
          size: 40,
          color: Theme.of(
            context,
          ).colorScheme.onSurfaceVariant.withOpacity(0.5),
        ),
      ),
    );
  }
}

/// Offline-aware poster image specifically for media cards
class OfflineAwarePosterImage extends OfflineAwareImage {
  const OfflineAwarePosterImage({
    super.key,
    super.client,
    required super.imagePath,
    super.width,
    super.height,
    super.fit = BoxFit.cover,
    super.filterQuality = FilterQuality.medium,
    super.placeholder,
    super.errorWidget,
    super.fadeInDuration = const Duration(milliseconds: 300),
    super.enableTranscoding = true,
    super.alignment = Alignment.center,
    super.fallbackIcon = Icons.movie,
  });
}
