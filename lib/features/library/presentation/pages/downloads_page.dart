import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  late Future<List<CachedTrack>> _offlineTracksFuture;

  @override
  void initState() {
    super.initState();
    _refreshOfflineTracks();
  }

  void _refreshOfflineTracks() {
    setState(() {
      _offlineTracksFuture = GetIt.I<TrackCacheService>().getOfflineAvailable();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOfflineTracks,
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Section 1: Active Downloads
          BlocBuilder<DownloadManager, DownloadState>(
            builder: (context, state) {
              final activeDownloads = state.status.entries
                  .where(
                    (e) =>
                        e.value == DownloadStatus.downloading ||
                        e.value == DownloadStatus.pending,
                  )
                  .map((e) => e.key)
                  .toList();

              if (activeDownloads.isEmpty) {
                return const SliverToBoxAdapter(child: SizedBox.shrink());
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  if (index == 0) {
                    return const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text(
                        'Downloading...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  final trackId = activeDownloads[index - 1];
                  final progress = state.progress[trackId] ?? 0.0;
                  return ListTile(
                    title: Text('Track ID: $trackId'),
                    // We don't have title here unless we fetch from TrackCache or Registry.
                    // Ideally DownloadManager should store basic metadata or we fetch it.
                    // For now, showing ID is a fallback, but we can try to fetch cached track if available.
                    subtitle: LinearProgressIndicator(value: progress),
                    trailing: IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () =>
                          context.read<DownloadManager>().cancel(trackId),
                    ),
                  );
                }, childCount: activeDownloads.length + 1),
              );
            },
          ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Downloaded',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ),

          // Section 2: Completed Downloads
          FutureBuilder<List<CachedTrack>>(
            future: _offlineTracksFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('No downloaded tracks'),
                    ),
                  ),
                );
              }

              final tracks = snapshot.data!;
              return SliverList(
                delegate: SliverChildBuilderDelegate((context, index) {
                  final track = tracks[index];
                  return ListTile(
                    leading: _buildArtwork(track),
                    title: Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(track.artistName),
                    trailing: IconButton(
                      icon: const Icon(Icons.play_arrow_rounded),
                      onPressed: () {
                        context.read<PlayerCubit>().playTrackById(
                          trackId: track.trackId,
                          title: track.title,
                          artist: track.artistName,
                          album: track.albumTitle,
                          imageUrl: track.albumCoverUrl,
                        );
                      },
                    ),
                    onTap: () {
                      context.read<PlayerCubit>().playTrackById(
                        trackId: track.trackId,
                        title: track.title,
                        artist: track.artistName,
                        album: track.albumTitle,
                        imageUrl: track.albumCoverUrl,
                      );
                    },
                  );
                }, childCount: tracks.length),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: const BottomNavBar(selectedIndex: 2),
    );
  }

  Widget _buildArtwork(CachedTrack track) {
    if (track.localImagePath != null) {
      final file = File(track.localImagePath!);
      if (file.existsSync()) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Image.file(file, width: 48, height: 48, fit: BoxFit.cover),
        );
      }
    }
    if (track.albumCoverUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.network(
          track.albumCoverUrl!,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.music_note),
        ),
      );
    }
    return Container(
      width: 48,
      height: 48,
      color: Colors.grey[800],
      child: const Icon(Icons.music_note),
    );
  }
}
