// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'queue_item_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HiveQueueItemAdapter extends TypeAdapter<HiveQueueItem> {
  @override
  final int typeId = 2;

  @override
  HiveQueueItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return HiveQueueItem()
      ..trackId = fields[0] as String
      ..title = fields[1] as String
      ..artist = fields[2] as String
      ..album = fields[3] as String?
      ..imageUrl = fields[4] as String?
      ..localImagePath = fields[5] as String?
      ..durationSeconds = fields[6] as int?
      ..uid = fields[7] as String
      ..addedAt = fields[8] as DateTime;
  }

  @override
  void write(BinaryWriter writer, HiveQueueItem obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.trackId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.artist)
      ..writeByte(3)
      ..write(obj.album)
      ..writeByte(4)
      ..write(obj.imageUrl)
      ..writeByte(5)
      ..write(obj.localImagePath)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.uid)
      ..writeByte(8)
      ..write(obj.addedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HiveQueueItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
