// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'download_queue_item.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DownloadQueueItem _$DownloadQueueItemFromJson(Map<String, dynamic> json) =>
    DownloadQueueItem(
      id: json['id'] as String,
      ratingKey: json['ratingKey'] as String,
      serverId: json['serverId'] as String,
      serverName: json['serverName'] as String,
      metadata: PlexMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      priority: $enumDecode(_$DownloadPriorityEnumMap, json['priority']),
      queuedAt: DateTime.parse(json['queuedAt'] as String),
    );

Map<String, dynamic> _$DownloadQueueItemToJson(DownloadQueueItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'ratingKey': instance.ratingKey,
      'serverId': instance.serverId,
      'serverName': instance.serverName,
      'metadata': instance.metadata,
      'priority': _$DownloadPriorityEnumMap[instance.priority]!,
      'queuedAt': instance.queuedAt.toIso8601String(),
    };

const _$DownloadPriorityEnumMap = {
  DownloadPriority.low: 'low',
  DownloadPriority.normal: 'normal',
  DownloadPriority.high: 'high',
};
