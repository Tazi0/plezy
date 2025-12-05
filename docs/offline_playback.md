# Offline Downloads & Playback Implementation

This document describes how offline media downloads and playback have been implemented in Plezy.

## Overview

The offline functionality allows users to download media files from Plex servers and play them locally using the existing video player infrastructure. Downloads are real video files fetched from Plex and stored locally for offline access.

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

### Real Video Downloads

- **Actual File Downloads**: Downloads are real video files from Plex servers, not simulations
- **Direct Stream URLs**: Uses Plex API to get direct video stream URLs
- **Progress Tracking**: Real-time download progress with bytes downloaded/total size
- **File Storage**: Videos saved to app documents directory with hashed filenames
- **Retry Logic**: Automatic retry (up to 3 attempts) with exponential backoff
- **Cancellation**: Downloads can be cancelled mid-progress
- **File Validation**: Verifies downloaded files exist and have valid size

### File Path Handling

- Offline media files are stored in `{AppDocuments}/Downloads/`
- Filenames use format: `{SafeTitle}_{Hash8}.mp4`
- Hash prevents filename conflicts for items with same title
- The video player treats local file paths the same as remote URLs

### Download Process

1. **URL Acquisition**: Get direct stream URL from Plex API using `PlexClient.getVideoUrl()`
2. **File Creation**: Create local file path and ensure parent directory exists
3. **HTTP Download**: Stream video data using Dio with progress callbacks
4. **Progress Updates**: Update database and emit progress events in real-time
5. **Completion**: Mark as completed and remove from download queue
6. **Error Handling**: Cleanup partial files on failure, retry up to 3 times

### Download Management

- **Queue Management**: Downloads are queued and processed sequentially
- **Cancellation**: Active downloads can be cancelled via UI
- **Storage Cleanup**: Failed/cancelled downloads automatically clean up files
- **Database Persistence**: Download progress and metadata stored in SQLite

### Metadata Compatibility

- The existing PlexMetadata model is reused for offline playback
- Full metadata (title, description, episode info, etc.) preserved during download
- Resume positions and other playback features work normally

### Error Handling

- **Network Errors**: Automatic retry with exponential backoff
- **File System Errors**: Clean up partial downloads on write failures
- **Cancellation**: Graceful handling of user-cancelled downloads
- **Server Errors**: Clear error messages for authentication/permission issues
- **Storage Issues**: Validation of available disk space and write permissions

## Limitations

Current implementation has the following limitations:

1. **Sequential Downloads**: Only one download at a time (prevents server overload)
2. **External Subtitles**: External subtitle tracks are not downloaded yet
3. **Quality Selection**: Downloads use default quality from Plex (future: quality selection UI)
4. **Background Downloads**: Downloads pause when app is backgrounded
5. **Storage Management**: No automatic cleanup based on storage limits

## Future Enhancements

Potential improvements for the download system:

1. **Quality Selection**: UI to choose download quality (720p, 1080p, 4K)
2. **Subtitle Downloads**: Download and cache external subtitle files
3. **Concurrent Downloads**: Support multiple simultaneous downloads
4. **Background Downloads**: Continue downloads when app is backgrounded
5. **Storage Management**: Automatic cleanup based on storage limits and LRU
6. **Smart Downloads**: Download next episodes automatically
7. **Bandwidth Controls**: Limit download speed and WiFi-only options
8. **Download Scheduling**: Schedule downloads for off-peak hours

## Usage

### Downloading Content

1. **Browse Content**: Navigate to any movie or episode detail screen
2. **Download Button**: Tap the download button (arrow down icon)
3. **Progress Tracking**: Monitor download progress in the Downloads screen
4. **Completion**: Content appears in "Downloaded Content" section when complete

### Playing Offline Content

1. **From Discover Screen**: Tap on any completed download in the "Downloaded Content" section
2. **From Downloads Screen**: Tap on a completed download or use "Play" from the menu
3. **Automatic Detection**: System automatically uses local files when available

### Managing Downloads

1. **View Progress**: Downloads screen shows active and completed downloads
2. **Cancel Downloads**: Use menu option to cancel active downloads
3. **Delete Content**: Remove downloaded files to free up storage
4. **Clear All**: Bulk delete all downloads if needed

The offline experience is transparent - users see the same video player interface and controls for both online streaming and offline playback.
