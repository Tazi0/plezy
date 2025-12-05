import 'package:json_annotation/json_annotation.dart';
import 'plex_metadata.dart';

part 'download_queue_item.g.dart';

@JsonSerializable()
class DownloadQueueItem {
  final String id;
  final String ratingKey;
  final String serverId;
  final String serverName;
  final PlexMetadata metadata;
  final DownloadPriority priority;
  final DateTime queuedAt;

  const DownloadQueueItem({
    required this.id,
    required this.ratingKey,
    required this.serverId,
    required this.serverName,
    required this.metadata,
    required this.priority,
    required this.queuedAt,
  });

  factory DownloadQueueItem.fromJson(Map<String, dynamic> json) =>
      _$DownloadQueueItemFromJson(json);

  Map<String, dynamic> toJson() => _$DownloadQueueItemToJson(this);

  DownloadQueueItem copyWith({
    String? id,
    String? ratingKey,
    String? serverId,
    String? serverName,
    PlexMetadata? metadata,
    DownloadPriority? priority,
    DateTime? queuedAt,
  }) {
    return DownloadQueueItem(
      id: id ?? this.id,
      ratingKey: ratingKey ?? this.ratingKey,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      metadata: metadata ?? this.metadata,
      priority: priority ?? this.priority,
      queuedAt: queuedAt ?? this.queuedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DownloadQueueItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum DownloadPriority { low, normal, high }
