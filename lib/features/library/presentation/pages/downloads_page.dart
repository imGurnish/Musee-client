import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/cache/models/cached_track.dart';
import 'package:musee/core/cache/services/audio_cache_service.dart';
import 'package:musee/core/cache/services/track_cache_service.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/core/player/player_cubit.dart';

class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  final TrackCacheService _trackCache = GetIt.I<TrackCacheService>();
  final AudioCacheService _audioCache = GetIt.I<AudioCacheService>();
  late Future<List<CachedTrack>> _offlineTracksFuture;
  bool _isMutating = false;

  @override
  void initState() {
    super.initState();
    _offlineTracksFuture = _trackCache.getOfflineAvailable();
  }

  void _refreshOfflineTracks() {
    setState(() {
      _offlineTracksFuture = _trackCache.getOfflineAvailable();
    });
  }

  Future<void> _pullToRefresh() async {
    _refreshOfflineTracks();
    await _offlineTracksFuture;
  }

  Future<void> _deleteTrack(CachedTrack track, {bool confirm = true}) async {
    final shouldDelete = confirm ? await _confirmTrackDelete(track) : true;
    if (!shouldDelete || _isMutating) return;

    setState(() => _isMutating = true);
    try {
      await _audioCache.deleteAudio(track.trackId);
      track.localAudioPath = null;
      track.audioSizeBytes = 0;
      await track.save();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Removed "${track.title}" from downloads')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not remove downloaded track')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
        _refreshOfflineTracks();
      }
    }
  }

  Future<void> _clearAllDownloads() async {
    if (_isMutating) return;

    final shouldClear = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear all downloads?'),
        content: const Text(
          'This will remove all downloaded songs from this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear all'),
          ),
        ],
      ),
    );

    if (shouldClear != true) return;

    setState(() => _isMutating = true);
    try {
      final tracks = await _trackCache.getOfflineAvailable();
      for (final track in tracks) {
        await _audioCache.deleteAudio(track.trackId);
        track.localAudioPath = null;
        track.audioSizeBytes = 0;
        await track.save();
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All downloaded songs removed')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not clear downloads')),
      );
    } finally {
      if (mounted) {
        setState(() => _isMutating = false);
        _refreshOfflineTracks();
      }
    }
  }

  Future<bool> _confirmTrackDelete(CachedTrack track) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove download?'),
        content: Text('Remove "${track.title}" from local storage?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _playTrack(CachedTrack track) {
    context.read<PlayerCubit>().playTrackById(
      trackId: track.trackId,
      title: track.title,
      artist: track.artistName,
      album: track.albumTitle,
      imageUrl: track.albumCoverUrl,
    );
  }

  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const units = ['B', 'KB', 'MB', 'GB'];
    double size = bytes.toDouble();
    int unitIndex = 0;
    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex++;
    }
    final value = size >= 100
        ? size.toStringAsFixed(0)
        : size.toStringAsFixed(1);
    return '$value ${units[unitIndex]}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Downloads'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOfflineTracks,
          ),
          IconButton(
            tooltip: 'Clear all downloads',
            onPressed: _clearAllDownloads,
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _pullToRefresh,
        child: BlocBuilder<DownloadManager, DownloadState>(
          builder: (context, downloadState) {
            final activeDownloads = downloadState.status.entries
                .where(
                  (entry) =>
                      entry.value == DownloadStatus.downloading ||
                      entry.value == DownloadStatus.pending,
                )
                .map((entry) => entry.key)
                .toList();

            final failedDownloads = downloadState.status.entries
                .where((entry) => entry.value == DownloadStatus.failed)
                .toList();

            return FutureBuilder<List<CachedTrack>>(
              future: _offlineTracksFuture,
              builder: (context, snapshot) {
                final tracks = snapshot.data ?? const <CachedTrack>[];
                final totalBytes = tracks.fold<int>(
                  0,
                  (sum, track) => sum + track.audioSizeBytes,
                );

                return CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            Chip(
                              label: Text('${tracks.length} downloaded'),
                              avatar: const Icon(Icons.download_done_rounded),
                            ),
                            Chip(
                              label: Text(_formatBytes(totalBytes)),
                              avatar: const Icon(Icons.sd_storage_rounded),
                            ),
                            if (activeDownloads.isNotEmpty)
                              Chip(
                                label: Text('${activeDownloads.length} active'),
                                avatar: const Icon(Icons.downloading_rounded),
                              ),
                          ],
                        ),
                      ),
                    ),

                    if (activeDownloads.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            'Active downloads',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final trackId = activeDownloads[index];
                          final progress =
                              downloadState.progress[trackId] ?? 0.0;
                          final status = downloadState.status[trackId];
                          final isPending = status == DownloadStatus.pending;

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Card(
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                title: Text(
                                  isPending
                                      ? 'Queued track'
                                      : 'Downloading track',
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 8),
                                    Text(
                                      trackId,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    LinearProgressIndicator(
                                      value: isPending ? null : progress,
                                    ),
                                  ],
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.close),
                                  onPressed: () => context
                                      .read<DownloadManager>()
                                      .cancel(trackId),
                                ),
                              ),
                            ),
                          );
                        }, childCount: activeDownloads.length),
                      ),
                    ],

                    if (failedDownloads.isNotEmpty) ...[
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Text(
                            'Failed downloads',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final entry = failedDownloads[index];
                          final trackId = entry.key;
                          final error =
                              downloadState.errors[trackId] ??
                              'Download failed';

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Card(
                              child: ListTile(
                                title: const Text('Failed track'),
                                subtitle: Text(
                                  '$trackId\n$error',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                isThreeLine: true,
                                trailing: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () => context
                                      .read<DownloadManager>()
                                      .addToQueue(trackId),
                                ),
                              ),
                            ),
                          );
                        }, childCount: failedDownloads.length),
                      ),
                    ],

                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(
                          'Downloaded tracks',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    if (snapshot.connectionState == ConnectionState.waiting)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      )
                    else if (tracks.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.download_for_offline_outlined,
                                    size: 36,
                                    color: theme.colorScheme.primary,
                                  ),
                                  const SizedBox(height: 12),
                                  const Text('No downloaded tracks yet'),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Downloaded songs will appear here.',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      )
                    else
                      SliverList(
                        delegate: SliverChildBuilderDelegate((context, index) {
                          final track = tracks[index];

                          return Padding(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                            child: Dismissible(
                              key: ValueKey(track.trackId),
                              direction: DismissDirection.endToStart,
                              confirmDismiss: (_) => _confirmTrackDelete(track),
                              onDismissed: (_) =>
                                  _deleteTrack(track, confirm: false),
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.errorContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  Icons.delete_outline,
                                  color: theme.colorScheme.onErrorContainer,
                                ),
                              ),
                              child: Card(
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  leading: _buildArtwork(track),
                                  title: Text(
                                    track.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    '${track.artistName} • ${_formatBytes(track.audioSizeBytes)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: PopupMenuButton<String>(
                                    onSelected: (value) {
                                      if (value == 'play') {
                                        _playTrack(track);
                                      } else if (value == 'delete') {
                                        _deleteTrack(track);
                                      }
                                    },
                                    itemBuilder: (context) => const [
                                      PopupMenuItem<String>(
                                        value: 'play',
                                        child: Text('Play'),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'delete',
                                        child: Text('Remove download'),
                                      ),
                                    ],
                                  ),
                                  onTap: () => _playTrack(track),
                                ),
                              ),
                            ),
                          );
                        }, childCount: tracks.length),
                      ),

                    if (_isMutating)
                      const SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: LinearProgressIndicator(),
                        ),
                      ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),
                  ],
                );
              },
            );
          },
        ),
      ),
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
    final theme = Theme.of(context);
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.music_note, color: theme.colorScheme.onSurfaceVariant),
    );
  }
}
