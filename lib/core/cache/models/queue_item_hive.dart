import 'package:hive/hive.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';

part 'queue_item_hive.g.dart';

/// Hive-backed model for persisting queue items.
/// Separate from the Equatable domain entity to keep persistence out of the domain layer.
@HiveType(typeId: 2)
class HiveQueueItem extends HiveObject {
  @HiveField(0)
  late String trackId;

  @HiveField(1)
  late String title;

  @HiveField(2)
  late String artist;

  @HiveField(3)
  String? album;

  @HiveField(4)
  String? imageUrl;

  @HiveField(5)
  String? localImagePath;

  @HiveField(6)
  int? durationSeconds;

  @HiveField(7)
  late String uid;

  @HiveField(8)
  late DateTime addedAt;

  /// Convert from domain entity
  static HiveQueueItem fromQueueItem(QueueItem item) {
    return HiveQueueItem()
      ..trackId = item.trackId
      ..title = item.title
      ..artist = item.artist
      ..album = item.album
      ..imageUrl = item.imageUrl
      ..localImagePath = item.localImagePath
      ..durationSeconds = item.durationSeconds
      ..uid = item.uid
      ..addedAt = DateTime.now();
  }

  /// Convert to domain entity
  QueueItem toQueueItem() {
    return QueueItem(
      uid: uid,
      trackId: trackId,
      title: title,
      artist: artist,
      album: album,
      imageUrl: imageUrl,
      localImagePath: localImagePath,
      durationSeconds: durationSeconds,
    );
  }
}
