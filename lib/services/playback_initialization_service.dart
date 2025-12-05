import '../i18n/strings.g.dart';
import '../models/offline_media_item.dart';
import '../models/plex_media_info.dart';
import '../models/plex_metadata.dart';
import '../mpv/mpv.dart';
import '../utils/app_logger.dart';
import 'offline_playback_service.dart';
import 'plex_client.dart';

/// Service responsible for fetching video playback data from the Plex server
class PlaybackInitializationService {
  final PlexClient client;
  final OfflineMediaItem? offlineItem;
  final bool isOfflineMode;
  final bool forceOfflinePlayback;

  PlaybackInitializationService({
    required this.client,
    this.offlineItem,
    this.isOfflineMode = false,
    this.forceOfflinePlayback = false,
  });

  /// Fetch playback data for the given metadata
  ///
  /// Returns a PlaybackInitializationResult with video URL and available versions
  /// Will use offline media if available and appropriate
  Future<PlaybackInitializationResult> getPlaybackData({
    required PlexMetadata metadata,
    required int selectedMediaIndex,
  }) async {
    try {
      // Check if we should use offline playback
      if (OfflinePlaybackService.shouldUseOfflinePlayback(
        offlineItem: offlineItem,
        isOfflineMode: isOfflineMode,
        forceOfflinePlayback: forceOfflinePlayback,
      )) {
        if (offlineItem == null || !offlineItem!.isCompleted) {
          throw PlaybackException(
            t.messages.errorLoading(error: 'No offline media available'),
          );
        }

        appLogger.d('Using offline playback for: ${metadata.title}');
        return OfflinePlaybackService.getOfflinePlaybackData(
          offlineItem: offlineItem!,
        );
      }

      // Use online playback
      appLogger.d('Using online playback for: ${metadata.title}');

      // Get consolidated playback data (URL, media info, and versions) in a single API call
      final playbackData = await client.getVideoPlaybackData(
        metadata.ratingKey,
        mediaIndex: selectedMediaIndex,
      );

      if (!playbackData.hasValidVideoUrl) {
        throw PlaybackException(t.messages.fileInfoNotAvailable);
      }

      // Build list of external subtitle tracks
      final externalSubtitles = _buildExternalSubtitles(playbackData.mediaInfo);

      // Return result with available versions and video URL
      return PlaybackInitializationResult(
        availableVersions: playbackData.availableVersions,
        videoUrl: playbackData.videoUrl,
        mediaInfo: playbackData.mediaInfo,
        externalSubtitles: externalSubtitles,
      );
    } catch (e) {
      if (e is PlaybackException) {
        rethrow;
      }
      throw PlaybackException(t.messages.errorLoading(error: e.toString()));
    }
  }

  /// Build list of external subtitle tracks from media info
  List<SubtitleTrack> _buildExternalSubtitles(PlexMediaInfo? mediaInfo) {
    final externalSubtitles = <SubtitleTrack>[];

    if (mediaInfo == null) {
      return externalSubtitles;
    }

    final externalTracks = mediaInfo.subtitleTracks
        .where((PlexSubtitleTrack track) => track.isExternal)
        .toList();

    if (externalTracks.isNotEmpty) {
      appLogger.d('Found ${externalTracks.length} external subtitle track(s)');
    }

    for (final plexTrack in externalTracks) {
      try {
        // Skip if no auth token is available
        final token = client.config.token;
        if (token == null) {
          appLogger.w('No auth token available for external subtitles');
          continue;
        }

        final url = plexTrack.getSubtitleUrl(client.config.baseUrl, token);

        // Skip if URL couldn't be constructed
        if (url == null) continue;

        externalSubtitles.add(
          SubtitleTrack.uri(
            url,
            title:
                plexTrack.displayTitle ??
                plexTrack.language ??
                'Track ${plexTrack.id}',
            language: plexTrack.languageCode,
          ),
        );
      } catch (e) {
        // Silent fallback - log error but continue with other subtitles
        appLogger.w(
          'Failed to add external subtitle track ${plexTrack.id}',
          error: e,
        );
      }
    }

    return externalSubtitles;
  }
}

/// Result of playback initialization
class PlaybackInitializationResult {
  final List<dynamic> availableVersions;
  final String? videoUrl;
  final PlexMediaInfo? mediaInfo;
  final List<SubtitleTrack> externalSubtitles;

  PlaybackInitializationResult({
    required this.availableVersions,
    this.videoUrl,
    this.mediaInfo,
    this.externalSubtitles = const [],
  });
}

/// Exception thrown when playback initialization fails
class PlaybackException implements Exception {
  final String message;

  PlaybackException(this.message);

  @override
  String toString() => message;
}
