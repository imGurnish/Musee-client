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
      ..isExplicit = fields[7] == null ? false : fields[7] as bool
      ..localAudioPath = fields[8] as String?
      ..streamingUrl = fields[9] as String?
      ..cachedAt = fields[10] as DateTime
      ..lastPlayedAt = fields[11] as DateTime?
      ..audioSizeBytes = fields[12] == null ? 0 : fields[12] as int
      ..sourceProvider = fields[13] == null ? 'musee' : fields[13] as String
      ..localImagePath = fields[14] as String?
      ..playCount = fields[15] == null ? 0 : fields[15] as int
      ..hlsMasterUrl = fields[16] as String?
      ..hlsVariantUrls = (fields[17] as Map?)?.cast<String, String>()
      ..cachedHlsBitrate = fields[18] as int?
      ..cachedHlsVariantUrl = fields[19] as String?
      ..isDownloaded = fields[20] == null ? false : fields[20] as bool
      ..downloadState = fields[21] as String?
      ..downloadedAudioPath = fields[22] as String?
      ..downloadedAudioSizeBytes = fields[23] == null ? 0 : fields[23] as int
      ..downloadedHlsBitrate = fields[24] as int?
      ..downloadedHlsVariantUrl = fields[25] as String?;
  }

  @override
  void write(BinaryWriter writer, CachedTrack obj) {
    writer
      ..writeByte(26)
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
      ..write(obj.playCount)
      ..writeByte(16)
      ..write(obj.hlsMasterUrl)
      ..writeByte(17)
      ..write(obj.hlsVariantUrls)
      ..writeByte(18)
      ..write(obj.cachedHlsBitrate)
      ..writeByte(19)
      ..write(obj.cachedHlsVariantUrl)
      ..writeByte(20)
      ..write(obj.isDownloaded)
      ..writeByte(21)
      ..write(obj.downloadState)
      ..writeByte(22)
      ..write(obj.downloadedAudioPath)
      ..writeByte(23)
      ..write(obj.downloadedAudioSizeBytes)
      ..writeByte(24)
      ..write(obj.downloadedHlsBitrate)
      ..writeByte(25)
      ..write(obj.downloadedHlsVariantUrl);
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
      ..trackIds = (fields[5] as List).cast<String>()
      ..cachedAt = fields[6] as DateTime
      ..sourceProvider = fields[7] as String
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
