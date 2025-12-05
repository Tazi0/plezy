import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../i18n/strings.g.dart';
import '../models/plex_metadata.dart';
import '../providers/offline_provider.dart';
import '../utils/app_logger.dart';

class DownloadButton extends StatelessWidget {
  final PlexMetadata metadata;
  final String serverId;
  final String serverName;
  final bool showText;
  final IconData? customIcon;
  final double? iconSize;

  const DownloadButton({
    super.key,
    required this.metadata,
    required this.serverId,
    required this.serverName,
    this.showText = true,
    this.customIcon,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineProvider>(
      builder: (context, offlineProvider, child) {
        final isDownloaded = offlineProvider.isCompleted(
          metadata.ratingKey,
          serverId,
        );
        final isDownloading = offlineProvider.isDownloading(
          metadata.ratingKey,
          serverId,
        );
        final progress = offlineProvider.getDownloadProgress(
          '${serverId}_${metadata.ratingKey}',
        );

        if (isDownloaded) {
          return _buildDownloadedButton(context);
        }

        if (isDownloading) {
          return _buildDownloadingButton(context, progress);
        }

        return _buildDownloadButton(context, offlineProvider);
      },
    );
  }

  Widget _buildDownloadButton(
    BuildContext context,
    OfflineProvider offlineProvider,
  ) {
    final theme = Theme.of(context);

    return showText
        ? ElevatedButton.icon(
            onPressed: () => _handleDownload(context, offlineProvider),
            icon: Icon(customIcon ?? Icons.download, size: iconSize ?? 18),
            label: Text(t.offline.download),
            style: ElevatedButton.styleFrom(
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              backgroundColor: theme.colorScheme.primaryContainer,
            ),
          )
        : IconButton(
            onPressed: () => _handleDownload(context, offlineProvider),
            icon: Icon(
              customIcon ?? Icons.download,
              size: iconSize ?? 24,
              color: theme.colorScheme.primary,
            ),
            tooltip: t.offline.download,
          );
  }

  Widget _buildDownloadingButton(BuildContext context, double progress) {
    final theme = Theme.of(context);

    if (showText) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withOpacity(0.7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 2,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${t.offline.downloading} ${(progress * 100).toInt()}%',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    } else {
      return Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: iconSize ?? 24,
            height: iconSize ?? 24,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          Icon(
            Icons.download,
            size: (iconSize ?? 24) * 0.6,
            color: theme.colorScheme.primary,
          ),
        ],
      );
    }
  }

  Widget _buildDownloadedButton(BuildContext context) {
    final theme = Theme.of(context);

    return showText
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.green.shade600,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.download_done, size: 18, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  t.offline.completed,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          )
        : Icon(
            Icons.download_done,
            size: iconSize ?? 24,
            color: Colors.green.shade600,
          );
  }

  Future<void> _handleDownload(
    BuildContext context,
    OfflineProvider offlineProvider,
  ) async {
    try {
      // Check if we have connectivity before starting download
      if (!offlineProvider.hasConnectivity) {
        _showSnackBar(context, 'Cannot download while offline', isError: true);
        return;
      }

      await offlineProvider.downloadMedia(metadata, serverId, serverName);

      _showSnackBar(context, 'Download started for ${metadata.title}');

      appLogger.d('Started download for: ${metadata.title}');
    } catch (e) {
      appLogger.e('Failed to start download: $e');

      _showSnackBar(
        context,
        'Failed to start download: ${e.toString()}',
        isError: true,
      );
    }
  }

  void _showSnackBar(
    BuildContext context,
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade600 : null,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
      ),
    );
  }
}

class DownloadListTile extends StatelessWidget {
  final PlexMetadata metadata;
  final String serverId;
  final String serverName;
  final VoidCallback? onTap;

  const DownloadListTile({
    super.key,
    required this.metadata,
    required this.serverId,
    required this.serverName,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      leading: Container(
        width: 56,
        height: 80,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          _getTypeIcon(metadata.type),
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        metadata.title ?? 'Unknown Title',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (metadata.year != null) Text('${metadata.year}'),
          if (metadata.type == 'episode' && metadata.grandparentTitle != null)
            Text(
              metadata.grandparentTitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
      trailing: DownloadButton(
        metadata: metadata,
        serverId: serverId,
        serverName: serverName,
        showText: false,
        iconSize: 20,
      ),
      onTap: onTap,
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'movie':
        return Icons.movie;
      case 'episode':
        return Icons.tv;
      case 'season':
        return Icons.playlist_play;
      case 'show':
        return Icons.tv;
      default:
        return Icons.video_library;
    }
  }
}
