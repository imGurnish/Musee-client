import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class QueueItem extends Equatable {
  final String trackId;
  final String title;
  final String artist; // comma-separated artists
  final String? album;
  final String? imageUrl;
  final String? localImagePath;
  final int? durationSeconds;
  final String? artistId;
  final String? albumId;
  final String? playlistId;

  final String uid;

  QueueItem({
    String? uid,
    required this.trackId,
    required this.title,
    required this.artist,
    this.album,
    this.imageUrl,
    this.localImagePath,
    this.durationSeconds,
    this.artistId,
    this.albumId,
    this.playlistId,
  }) : uid = uid ?? const Uuid().v4();

  @override
  List<Object?> get props => [
    uid,
    trackId,
    title,
    artist,
    album,
    imageUrl,
    localImagePath,
    durationSeconds,
    artistId,
    albumId,
    playlistId,
  ];

  QueueItem copyWith({
    String? uid,
    String? trackId,
    String? title,
    String? artist,
    String? album,
    String? imageUrl,
    String? localImagePath,
    int? durationSeconds,
    String? artistId,
    String? albumId,
    String? playlistId,
  }) {
    return QueueItem(
      uid: uid ?? this.uid,
      trackId: trackId ?? this.trackId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      imageUrl: imageUrl ?? this.imageUrl,
      localImagePath: localImagePath ?? this.localImagePath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      artistId: artistId ?? this.artistId,
      albumId: albumId ?? this.albumId,
      playlistId: playlistId ?? this.playlistId,
    );
  }

  factory QueueItem.fromExpandedJson(Map<String, dynamic> json) {
    String artists = '';
    String? artistId;
    final rawArtists = json['artists'];
    if (rawArtists is List) {
      artists = rawArtists
          .map((a) => (a['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .join(', ');
      if (rawArtists.isNotEmpty) {
        artistId = (rawArtists.first['id'] ?? rawArtists.first['artist_id'])?.toString();
      }
    } else if (rawArtists is String) {
      artists = rawArtists;
    } else if (json['artist'] is String) {
      artists = json['artist'];
    }

    artistId ??= (json['artist_id'] ?? json['artist']?['id'] ?? json['artist']?['artist_id'])?.toString();
    final albumId = (json['album']?['id'] ?? json['album_id'] ?? json['album']?['album_id'])?.toString();
    final playlistId = (json['playlist_id'] ?? json['playlist']?['id'])?.toString();

    final imageUrl =
        (json['album']?['cover_url'] ?? json['image_url'] ?? json['cover_url'])
            ?.toString();
    return QueueItem(
      trackId: (json['track_id'] ?? json['id']).toString(),
      title: (json['title'] ?? '').toString(),
      artist: artists,
      album: (json['album']?['title'] ?? json['album_title'])?.toString(),
      imageUrl: imageUrl,
      durationSeconds: (json['duration'] as num?)?.toInt(),
      artistId: artistId,
      albumId: albumId,
      playlistId: playlistId,
    );
  }
}
