// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cached_track.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class CachedTrackAdapter extends TypeAdapter<CachedTrack> {
  @override
  final int typeId = 0;

  @override
  CachedTrack read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedTrack()
      ..trackId = fields[0] as String
      ..title = fields[1] as String
      ..albumId = fields[2] as String?
      ..albumTitle = fields[3] as String?
      ..albumCoverUrl = fields[4] as String?
      ..artistName = fields[5] as String
      ..durationSeconds = fields[6] as int
      ..isExplicit = fields[7] as bool
      ..localAudioPath = fields[8] as String?
      ..streamingUrl = fields[9] as String?
      ..cachedAt = fields[10] as DateTime
      ..lastPlayedAt = fields[11] as DateTime?
      ..audioSizeBytes = fields[12] as int? ?? 0
      // Handle new fields with defaults for backward compatibility
      ..sourceProvider = (fields[13] as String?) ?? 'musee'
      ..localImagePath = fields[14] as String?
      ..playCount = (fields[15] as int?) ?? 0;
  }

  @override
  void write(BinaryWriter writer, CachedTrack obj) {
    writer
      ..writeByte(16)
      ..writeByte(0)
      ..write(obj.trackId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.albumId)
      ..writeByte(3)
      ..write(obj.albumTitle)
      ..writeByte(4)
      ..write(obj.albumCoverUrl)
      ..writeByte(5)
      ..write(obj.artistName)
      ..writeByte(6)
      ..write(obj.durationSeconds)
      ..writeByte(7)
      ..write(obj.isExplicit)
      ..writeByte(8)
      ..write(obj.localAudioPath)
      ..writeByte(9)
      ..write(obj.streamingUrl)
      ..writeByte(10)
      ..write(obj.cachedAt)
      ..writeByte(11)
      ..write(obj.lastPlayedAt)
      ..writeByte(12)
      ..write(obj.audioSizeBytes)
      ..writeByte(13)
      ..write(obj.sourceProvider)
      ..writeByte(14)
      ..write(obj.localImagePath)
      ..writeByte(15)
      ..write(obj.playCount);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedTrackAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class CachedAlbumAdapter extends TypeAdapter<CachedAlbum> {
  @override
  final int typeId = 1;

  @override
  CachedAlbum read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return CachedAlbum()
      ..albumId = fields[0] as String
      ..title = fields[1] as String
      ..coverUrl = fields[2] as String?
      ..releaseDate = fields[3] as String?
      ..artistName = fields[4] as String
      ..trackIds = (fields[5] as List?)?.cast<String>() ?? []
      ..cachedAt = fields[6] as DateTime
      // Handle new fields with defaults for backward compatibility
      ..sourceProvider = (fields[7] as String?) ?? 'musee'
      ..localCoverPath = fields[8] as String?;
  }

  @override
  void write(BinaryWriter writer, CachedAlbum obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.albumId)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.coverUrl)
      ..writeByte(3)
      ..write(obj.releaseDate)
      ..writeByte(4)
      ..write(obj.artistName)
      ..writeByte(5)
      ..write(obj.trackIds)
      ..writeByte(6)
      ..write(obj.cachedAt)
      ..writeByte(7)
      ..write(obj.sourceProvider)
      ..writeByte(8)
      ..write(obj.localCoverPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedAlbumAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
