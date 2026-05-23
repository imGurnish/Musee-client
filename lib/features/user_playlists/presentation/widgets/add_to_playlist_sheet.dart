import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';
import 'package:musee/features/user_playlists/domain/repository/user_playlists_repository.dart';
import 'package:musee/features/user_playlists/domain/usecases/add_playlist_track.dart';

Future<void> showAddToPlaylistSheet(
  BuildContext context, {
  required String trackId,
  required String trackTitle,
  required String artistNames,
  String? imageUrl,
}) async {
  if (!context.mounted) return;

  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (_) {
      return _AddToPlaylistSheet(
        trackId: trackId,
        trackTitle: trackTitle,
        artistNames: artistNames,
        imageUrl: imageUrl,
      );
    },
  );
}

class _AddToPlaylistSheet extends StatefulWidget {
  final String trackId;
  final String trackTitle;
  final String artistNames;
  final String? imageUrl;

  const _AddToPlaylistSheet({
    required this.trackId,
    required this.trackTitle,
    required this.artistNames,
    this.imageUrl,
  });

  @override
  State<_AddToPlaylistSheet> createState() => _AddToPlaylistSheetState();
}

class _AddToPlaylistSheetState extends State<_AddToPlaylistSheet> {
  late final Future<List<UserPlaylistDetail>> _playlistsFuture;
  final Set<String> _inFlightPlaylistIds = <String>{};

  @override
  void initState() {
    super.initState();
    _playlistsFuture = GetIt.I<UserPlaylistsRepository>().getPlaylists();
  }

  Future<void> _addToPlaylist(UserPlaylistDetail playlist) async {
    if (_inFlightPlaylistIds.contains(playlist.playlistId)) return;

    setState(() {
      _inFlightPlaylistIds.add(playlist.playlistId);
    });

    try {
      await GetIt.I<AddPlaylistTrack>()(playlist.playlistId, widget.trackId);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('Track added to ${playlist.name}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_friendlyError(e))),
      );
    } finally {
      if (mounted) {
        setState(() {
          _inFlightPlaylistIds.remove(playlist.playlistId);
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    return message.startsWith('Exception: ')
        ? message.substring('Exception: '.length)
        : message;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sheetHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      top: false,
      child: SizedBox(
        height: sheetHeight,
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add to playlist',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${widget.trackTitle} • ${widget.artistNames}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: Image.network(
                        widget.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: FutureBuilder<List<UserPlaylistDetail>>(
                  future: _playlistsFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Could not load playlists',
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      );
                    }

                    final playlists = snapshot.data ?? const <UserPlaylistDetail>[];
                    if (playlists.isEmpty) {
                      return Center(
                        child: Text(
                          'No playlists available yet',
                          style: theme.textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: playlists.length,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.zero,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.2),
                      ),
                      itemBuilder: (context, index) {
                        final playlist = playlists[index];
                        final creator = playlist.artists.isNotEmpty
                            ? (playlist.artists.first.name ?? 'Unknown')
                            : 'Unknown';
                        final isBusy = _inFlightPlaylistIds.contains(playlist.playlistId);

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4),
                          leading: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: SizedBox(
                              width: 48,
                              height: 48,
                              child: playlist.coverUrl != null && playlist.coverUrl!.isNotEmpty
                                  ? Image.network(
                                      playlist.coverUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Container(
                                        color: theme.colorScheme.surfaceContainerHighest,
                                        child: const Icon(Icons.queue_music_rounded),
                                      ),
                                    )
                                  : Container(
                                      color: theme.colorScheme.surfaceContainerHighest,
                                      child: const Icon(Icons.queue_music_rounded),
                                    ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  playlist.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (playlist.isCollaborative)
                                Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.people_alt_rounded,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Text('By $creator'),
                          trailing: isBusy
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.chevron_right_rounded),
                          onTap: isBusy ? null : () => _addToPlaylist(playlist),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}