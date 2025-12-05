import 'package:json_annotation/json_annotation.dart';

part 'offline_media_item.g.dart';

@JsonSerializable()
class OfflineMediaItem {
  final String id;
  final String ratingKey;
  final String serverId;
  final String serverName;
  final String title;
  final OfflineMediaType type;
  final OfflineMediaStatus status;
  final String localPath;
  final int fileSize;
  final int downloadedSize;
  final DateTime createdAt;
  final DateTime? completedAt;
  final String? error;
  final Map<String, dynamic>? mediaInfo;

  const OfflineMediaItem({
    required this.id,
    required this.ratingKey,
    required this.serverId,
    required this.serverName,
    required this.title,
    required this.type,
    required this.status,
    required this.localPath,
    required this.fileSize,
    required this.downloadedSize,
    required this.createdAt,
    this.completedAt,
    this.error,
    this.mediaInfo,
  });

  factory OfflineMediaItem.fromJson(Map<String, dynamic> json) =>
      _$OfflineMediaItemFromJson(json);

  Map<String, dynamic> toJson() => _$OfflineMediaItemToJson(this);

  double get progress {
    if (fileSize == 0) return 0;
    return downloadedSize / fileSize;
  }

  bool get isCompleted => status == OfflineMediaStatus.completed;
  bool get isDownloading => status == OfflineMediaStatus.downloading;
  bool get isFailed => status == OfflineMediaStatus.failed;
  bool get isPending => status == OfflineMediaStatus.pending;

  OfflineMediaItem copyWith({
    String? id,
    String? ratingKey,
    String? serverId,
    String? serverName,
    String? title,
    OfflineMediaType? type,
    OfflineMediaStatus? status,
    String? localPath,
    int? fileSize,
    int? downloadedSize,
    DateTime? createdAt,
    DateTime? completedAt,
    String? error,
    Map<String, dynamic>? mediaInfo,
  }) {
    return OfflineMediaItem(
      id: id ?? this.id,
      ratingKey: ratingKey ?? this.ratingKey,
      serverId: serverId ?? this.serverId,
      serverName: serverName ?? this.serverName,
      title: title ?? this.title,
      type: type ?? this.type,
      status: status ?? this.status,
      localPath: localPath ?? this.localPath,
      fileSize: fileSize ?? this.fileSize,
      downloadedSize: downloadedSize ?? this.downloadedSize,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      error: error ?? this.error,
      mediaInfo: mediaInfo ?? this.mediaInfo,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OfflineMediaItem &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

enum OfflineMediaType { movie, episode, season, series }

enum OfflineMediaStatus { pending, downloading, completed, failed }
