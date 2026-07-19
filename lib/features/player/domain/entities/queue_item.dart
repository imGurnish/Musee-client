import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class PlayerTrackArtist extends Equatable {
  final String id;
  final String name;
  final String? role;

  const PlayerTrackArtist({
    required this.id,
    required this.name,
    this.role,
  });

  @override
  List<Object?> get props => [id, name, role];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'role': role,
      };

  factory PlayerTrackArtist.fromJson(Map<String, dynamic> json) =>
      PlayerTrackArtist(
        id: (json['id'] ?? json['artist_id'] ?? '').toString(),
        name: (json['name'] ?? '').toString(),
        role: json['role']?.toString(),
      );
}

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
  final List<PlayerTrackArtist> artistsList;

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
    List<PlayerTrackArtist>? artistsList,
  })  : uid = uid ?? const Uuid().v4(),
        artistsList = artistsList ?? (
          (artistId != null && artist.isNotEmpty)
              ? [PlayerTrackArtist(id: artistId, name: artist, role: 'owner')]
              : const []
        );

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
        artistsList,
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
    List<PlayerTrackArtist>? artistsList,
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
      artistsList: artistsList ?? this.artistsList,
    );
  }

  factory QueueItem.fromExpandedJson(Map<String, dynamic> json) {
    String artists = '';
    String? artistId;
    List<PlayerTrackArtist> artistsList = [];
    final rawArtists = json['artists'];
    if (rawArtists is List) {
      final sortedArtists = List<Map<String, dynamic>>.from(
          rawArtists.map((a) => Map<String, dynamic>.from(a as Map)));
      // Sort artists: role 'owner' comes first, then others
      sortedArtists.sort((a, b) {
        final aRole = a['role']?.toString().toLowerCase();
        final bRole = b['role']?.toString().toLowerCase();
        if (aRole == 'owner' && bRole != 'owner') return -1;
        if (bRole == 'owner' && aRole != 'owner') return 1;
        return 0;
      });

      artistsList =
          sortedArtists.map((a) => PlayerTrackArtist.fromJson(a)).toList();

      artists = sortedArtists
          .map((a) => (a['name'] ?? '').toString())
          .where((s) => s.isNotEmpty)
          .join(', ');

      if (sortedArtists.isNotEmpty) {
        final ownerArtist = sortedArtists.firstWhere(
          (a) => a['role']?.toString().toLowerCase() == 'owner',
          orElse: () => sortedArtists.first,
        );
        artistId = (ownerArtist['id'] ?? ownerArtist['artist_id'])?.toString();
      }
    } else if (rawArtists is String) {
      artists = rawArtists;
    } else if (json['artist'] is String) {
      artists = json['artist'];
    }

    artistId ??= (json['artist_id'] ??
            json['artist']?['id'] ??
            json['artist']?['artist_id'])
        ?.toString();

    if (artistsList.isEmpty && artists.isNotEmpty) {
      artistsList = [
        PlayerTrackArtist(
          id: artistId ?? '',
          name: artists,
          role: 'owner',
        )
      ];
    }

    final albumId = (json['album']?['id'] ??
            json['album_id'] ??
            json['album']?['album_id'])
        ?.toString();
    final playlistId =
        (json['playlist_id'] ?? json['playlist']?['id'])?.toString();

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
      artistsList: artistsList,
    );
  }
}
