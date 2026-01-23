import 'package:musee/core/common/widgets/loader.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/features/search/data/datasources/external_music_data_source.dart';
import 'package:musee/features/search/presentation/widgets/external_badge.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/download/download_manager.dart';

class ExternalAlbumPage extends StatefulWidget {
  final String albumId;
  final String? initialTitle;
  final String? initialImageUrl;

  const ExternalAlbumPage({
    super.key,
    required this.albumId,
    this.initialTitle,
    this.initialImageUrl,
  });

  @override
  State<ExternalAlbumPage> createState() => _ExternalAlbumPageState();
}

class _ExternalAlbumPageState extends State<ExternalAlbumPage> {
  final ExternalMusicDataSource _dataSource = ExternalMusicDataSource();
  ExternalMusicAlbumDetail? _albumDetail;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    // Extract actual ID if prefixed
    final id = widget.albumId.startsWith('external:')
        ? widget.albumId.substring('external:'.length)
        : widget.albumId;

    final detail = await _dataSource.getAlbumDetails(id);
    if (mounted) {
      setState(() {
        _albumDetail = detail;
        _isLoading = false;
        if (detail == null) {
          _errorMessage = 'Could not load album details';
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show partial content (header) if we have initial data, even while loading
    if (_isLoading && _albumDetail == null) {
      if (widget.initialTitle != null) {
        return Scaffold(
          appBar: AppBar(title: const Text('Album')),
          body: Column(
            children: [
              _buildHeader(
                title: widget.initialTitle!,
                imageUrl: widget.initialImageUrl,
                subtitle: 'Loading...',
              ),
              const Expanded(child: Center(child: Loader())),
            ],
          ),
        );
      }
      return const Scaffold(body: Center(child: Loader()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Album')),
        body: Center(child: Text(_errorMessage!)),
      );
    }

    final album = _albumDetail!;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                album.title,
                style: const TextStyle(
                  shadows: [Shadow(color: Colors.black, blurRadius: 4)],
                ),
              ),
              background: album.imageUrl != null
                  ? Image.network(
                      album.imageUrl!,
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const ExternalBadge(),
                      const SizedBox(width: 8),
                      Text(
                        album.year ?? '',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  if (album.primaryArtists != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      album.primaryArtists!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
          ),
          SliverList(
            delegate: SliverChildBuilderDelegate((context, index) {
              final song = album.songs[index];
              return _ExternalTrackTile(
                song: song,
                album: album,
                dataSource: _dataSource,
              );
            }, childCount: album.songs.length),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }

  Widget _buildHeader({
    required String title,
    String? imageUrl,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
              ),
            ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) Text(subtitle),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ExternalTrackTile extends StatelessWidget {
  final ExternalMusicSongDetail song;
  final ExternalMusicAlbumDetail album;
  final ExternalMusicDataSource dataSource;

  const _ExternalTrackTile({
    required this.song,
    required this.album,
    required this.dataSource,
  });

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
              : (album.imageUrl != null
                    ? Image.network(album.imageUrl!, fit: BoxFit.cover)
                    : const Icon(Icons.music_note)),
        ),
      ),
      title: Text(song.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        song.primaryArtists ?? album.primaryArtists ?? 'Unknown Artist',
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
    final url = dataSource.getPlayableUrl(song);
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load URL for this song')),
      );
      return;
    }

    final item = QueueItem(
      trackId: 'external:${song.id}',
      title: song.title,
      artist: song.primaryArtists ?? album.primaryArtists ?? 'Unknown',
      album: album.title,
      imageUrl: song.imageUrl ?? album.imageUrl,
      durationSeconds: song.duration,
    );

    await GetIt.I<PlayerCubit>().addToQueue([item]);
    await GetIt.I<PlayerCubit>().playFromQueueTrackId(item.trackId);
  }
}
