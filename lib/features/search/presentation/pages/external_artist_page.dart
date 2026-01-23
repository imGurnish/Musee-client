import 'package:musee/core/common/widgets/loader.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/features/search/data/datasources/external_music_data_source.dart';
import 'package:musee/features/search/presentation/widgets/external_badge.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/features/search/presentation/pages/external_album_page.dart';
import 'package:musee/core/download/download_manager.dart';

class ExternalArtistPage extends StatefulWidget {
  final String artistId;
  final String artistName;
  final String? initialImageUrl;

  const ExternalArtistPage({
    super.key,
    required this.artistId,
    required this.artistName,
    this.initialImageUrl,
  });

  @override
  State<ExternalArtistPage> createState() => _ExternalArtistPageState();
}

class _ExternalArtistPageState extends State<ExternalArtistPage> {
  final ExternalMusicDataSource _dataSource = ExternalMusicDataSource();
  ExternalMusicSearchResult? _searchResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    // Fallback strategy: Search for the artist name to get top songs and albums
    final result = await _dataSource.search(widget.artistName);
    if (mounted) {
      setState(() {
        _searchResult = result;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.artistName)),
        body: const Center(child: Loader()),
      );
    }

    final result = _searchResult!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.artistName,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: widget.initialImageUrl != null
                  ? Image.network(
                      widget.initialImageUrl!,
                      fit: BoxFit.cover,
                      color: Colors.black54,
                      colorBlendMode: BlendMode.darken,
                    )
                  : Container(color: Colors.grey[900]),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const ExternalBadge(),
                  const SizedBox(width: 8),
                  Text(
                    'Artist',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            ),
          ),
          if (result.songs.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Text(
                  'Top Songs',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final song = result.songs[index];
                return _ArtistSongTile(song: song, dataSource: _dataSource);
              }, childCount: result.songs.length),
            ),
          ],
          if (result.albums.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                child: Text(
                  'Top Albums',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final album = result.albums[index];
                return ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      album.imageUrl ?? '',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.album),
                    ),
                  ),
                  title: Text(album.title),
                  subtitle: Text(album.year ?? 'Album'),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => ExternalAlbumPage(
                          albumId: album.id,
                          initialTitle: album.title,
                          initialImageUrl: album.imageUrl,
                        ),
                      ),
                    );
                  },
                );
              }, childCount: result.albums.length),
            ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _ArtistSongTile extends StatelessWidget {
  final ExternalMusicSong song;
  final ExternalMusicDataSource dataSource;

  const _ArtistSongTile({required this.song, required this.dataSource});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: SizedBox(
          width: 48,
          height: 48,
          child: song.imageUrl != null
              ? Image.network(song.imageUrl!, fit: BoxFit.cover)
              : const Icon(Icons.music_note),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.album ?? '',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.download_rounded),
            onPressed: () {
              GetIt.I<DownloadManager>().addToQueue('external:${song.id}');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Added to downloads')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.play_arrow_rounded),
            onPressed: () => _play(context),
          ),
        ],
      ),
      onTap: () => _play(context),
    );
  }

  Future<void> _play(BuildContext context) async {
    // We need to fetch full details to get encrypted URL or preview URL
    // (ExternalMusicSong search result might not have URL)
    String? playableUrl = song.url;

    // Actually search result 'url' field is permalink, not media url.
    // We must call getSongById.
    final detail = await dataSource.getSongById(song.id);
    if (detail != null) {
      playableUrl = dataSource.getPlayableUrl(detail);
    }

    if (playableUrl == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Unable to load song')));
      }
      return;
    }

    final item = QueueItem(
      trackId: 'external:${song.id}',
      title: song.title,
      artist: song.primaryArtists ?? 'Unknown',
      album: song.album,
      imageUrl: song.imageUrl,
      durationSeconds: song.duration,
    );

    await GetIt.I<PlayerCubit>().addToQueue([item]);
    await GetIt.I<PlayerCubit>().playFromQueueTrackId(item.trackId);
  }
}
