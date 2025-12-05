// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_media_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OfflineMediaItem _$OfflineMediaItemFromJson(Map<String, dynamic> json) =>
    OfflineMediaItem(
      id: json['id'] as String,
      ratingKey: json['ratingKey'] as String,
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      title: json['title'] as String,
      type: $enumDecode(_$OfflineMediaTypeEnumMap, json['type']),
      status: $enumDecode(_$OfflineMediaStatusEnumMap, json['status']),
      localPath: json['localPath'] as String,
      fileSize: (json['fileSize'] as num).toInt(),
      downloadedSize: (json['downloadedSize'] as num).toInt(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      completedAt: json['completedAt'] == null
          ? null
          : DateTime.parse(json['completedAt'] as String),
      error: json['error'] as String?,
      mediaInfo: json['mediaInfo'] as Map<String, dynamic>?,
    );

Map<String, dynamic> _$OfflineMediaItemToJson(OfflineMediaItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ratingKey': instance.ratingKey,
      'serverId': instance.serverId,
      'serverName': instance.serverName,
      'title': instance.title,
      'type': _$OfflineMediaTypeEnumMap[instance.type]!,
      'status': _$OfflineMediaStatusEnumMap[instance.status]!,
      'localPath': instance.localPath,
      'fileSize': instance.fileSize,
      'downloadedSize': instance.downloadedSize,
      'createdAt': instance.createdAt.toIso8601String(),
      'completedAt': instance.completedAt?.toIso8601String(),
      'error': instance.error,
      'mediaInfo': instance.mediaInfo,
    };

const _$OfflineMediaTypeEnumMap = {
  OfflineMediaType.movie: 'movie',
  OfflineMediaType.episode: 'episode',
  OfflineMediaType.season: 'season',
  OfflineMediaType.series: 'series',
};

const _$OfflineMediaStatusEnumMap = {
  OfflineMediaStatus.pending: 'pending',
  OfflineMediaStatus.downloading: 'downloading',
  OfflineMediaStatus.completed: 'completed',
  OfflineMediaStatus.failed: 'failed',
};
