# Offline Playback Implementation

This document describes how offline media playback has been implemented in Plezy.

## Overview

The offline playback functionality allows users to play downloaded media files using the existing video player infrastructure. When a user taps on a completed download, the app will use the local file path instead of streaming from the Plex server.

## Architecture

### Core Components

1. **OfflinePlaybackService** (`lib/services/offline_playback_service.dart`)
   - Handles initialization of offline media playback
   - Validates offline media items and prepares them for playback
   - Determines when offline playback should be used

2. **PlaybackInitializationService** (modified)
   - Extended to support both online and offline playback
   - Checks for offline media availability before falling back to online streaming
   - Automatically selects offline playback when in offline mode or when offline media is available

3. **OfflineProvider** (extended)
   - Added `getOfflineMediaItem()` method to retrieve completed downloads by ratingKey and serverId

### UI Integration

1. **OfflineMediaSection** (`lib/widgets/offline_media_section.dart`)
   - Displays completed downloads on the Discover screen
   - Allows users to tap on completed downloads to play them offline
   - Converts OfflineMediaItem to PlexMetadata for video player compatibility

2. **OfflineDownloadsScreen** (`lib/screens/offline_downloads_screen.dart`)
   - Shows both a "Play" button and tap-to-play functionality for completed downloads
   - Uses the same offline playback infrastructure as the OfflineMediaSection

## How It Works

### Offline Playback Detection

The system automatically determines when to use offline playback based on:

1. **Offline Mode**: When the device has no connectivity, completed downloads are played locally
2. **Available Downloads**: Even when online, users can play downloaded content to save bandwidth

### Playback Flow

1. User taps on a completed download (either from Discover screen or Downloads screen)
2. The OfflineMediaItem is converted to a PlexMetadata object for compatibility
3. The video player screen is launched with the metadata
4. The PlaybackInitializationService detects that offline media is available
5. Instead of fetching the stream URL from Plex, it uses the local file path
6. The video player opens the local file using the MPV player

### Data Conversion

When converting from OfflineMediaItem to PlexMetadata:
- Core metadata fields (title, type, ratingKey, etc.) are preserved
- Episode-specific fields (season/episode numbers, show titles) are extracted from stored mediaInfo
- Server information is maintained for proper identification
- Complex metadata (genres, cast, etc.) is simplified since it's not needed for playback

## Technical Details

### File Path Handling

- Offline media files are stored using the path from `OfflineMediaItem.localPath`
- The video player treats local file paths the same as remote URLs
- No special handling is needed in the video player itself

### Metadata Compatibility

- The existing PlexMetadata model is reused for offline playback
- This ensures compatibility with the existing video player infrastructure
- Resume positions and other playback features work normally

### Error Handling

- Validates that offline media is completed before attempting playback
- Falls back gracefully if local files are missing or corrupted
- Provides clear error messages for offline playback issues

## Limitations

Current implementation has the following limitations:

1. **External Subtitles**: External subtitle tracks are not supported for offline playback yet
2. **Multiple Versions**: Only the downloaded version is available (no quality switching)
3. **Advanced Media Info**: Complex media information parsing is simplified
4. **Resume Positions**: Resume positions from the progress cache are not yet integrated

## Future Enhancements

Potential improvements for offline playback:

1. **Subtitle Support**: Download and cache external subtitle files
2. **Resume Integration**: Use the progress cache for accurate resume positions
3. **Quality Selection**: Allow downloading multiple quality versions
4. **Background Sync**: Sync playback progress when connectivity is restored
5. **Media Info**: Parse and reconstruct full PlexMediaInfo for advanced features

## Usage

Users can play offline media in two ways:

1. **From Discover Screen**: Tap on any completed download shown in the "Downloaded Content" section
2. **From Downloads Screen**: Either tap on a completed download or use the "Play" option from the menu

The offline playback is transparent to users - they use the same video player interface and controls as online playback.
