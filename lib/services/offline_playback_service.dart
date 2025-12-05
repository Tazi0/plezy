import '../i18n/strings.g.dart';
import '../models/offline_media_item.dart';
import '../models/plex_media_info.dart';
import '../utils/app_logger.dart';
import 'playback_initialization_service.dart';

/// Service responsible for handling offline media playback initialization
class OfflinePlaybackService {
  /// Get playback data for offline media
  ///
  /// Returns a PlaybackInitializationResult with local file path and cached media info
  static PlaybackInitializationResult getOfflinePlaybackData({
    required OfflineMediaItem offlineItem,
  }) {
    try {
      // Validate that the offline item is completed and has a local path
      if (!offlineItem.isCompleted) {
        throw PlaybackException(
          t.messages.errorLoading(error: 'Media not fully downloaded'),
        );
      }

      if (offlineItem.localPath.isEmpty) {
        throw PlaybackException(
          t.messages.errorLoading(error: 'Local file path not available'),
        );
      }

      // For offline playback, we don't need to parse the complex media info
      // The local file path is sufficient for basic playback
      // TODO: In the future, we could parse and reconstruct PlexMediaInfo
      // to support advanced features like multiple audio tracks and subtitles
      PlexMediaInfo? mediaInfo;

      // For offline playback, we don't have multiple versions available
      // The downloaded version is the only one we can use
      final availableVersions = <dynamic>[];

      appLogger.d('Preparing offline playback for: ${offlineItem.title}');
      appLogger.d('Local path: ${offlineItem.localPath}');

      return PlaybackInitializationResult(
        availableVersions: availableVersions,
        videoUrl: offlineItem.localPath,
        mediaInfo: mediaInfo,
        externalSubtitles:
            const [], // External subtitles not supported for offline playback yet
      );
    } catch (e) {
      if (e is PlaybackException) {
        rethrow;
      }
      throw PlaybackException(t.messages.errorLoading(error: e.toString()));
    }
  }

  /// Check if metadata should use offline playback
  ///
  /// Returns true if the media is available offline and should be played locally
  static bool shouldUseOfflinePlayback({
    required OfflineMediaItem? offlineItem,
    required bool isOfflineMode,
    bool forceOfflinePlayback = false,
  }) {
    // TEMPORARY: Disable all automatic offline detection to fix playback issues
    // Only use offline playback when explicitly forced (user tapped on offline content)
    if (forceOfflinePlayback && offlineItem?.isCompleted == true) {
      appLogger.d('Using forced offline playback for: ${offlineItem?.title}');
      return true;
    }

    // For all other cases, use online playback
    return false;
  }
}
