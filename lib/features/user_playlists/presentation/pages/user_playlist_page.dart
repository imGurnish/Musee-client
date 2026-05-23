import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'dart:math';
import 'dart:ui' show ImageFilter;
import 'package:dio/dio.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/core/common/widgets/player_bottom_sheet.dart';
import 'package:musee/features/user_playlists/presentation/bloc/user_playlist_bloc.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';
import 'package:musee/core/common/widgets/playing_bars_animation.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/core/download/download_manager.dart';
import 'package:musee/features/listening_history/data/repositories/listening_history_repository.dart';
import 'package:musee/features/user_playlists/domain/entities/user_playlist.dart';

class UserPlaylistPage extends StatefulWidget {
  final String playlistId;

  const UserPlaylistPage({super.key, required this.playlistId});

  @override
  State<UserPlaylistPage> createState() => _UserPlaylistPageState();
}

class _UserPlaylistPageState extends State<UserPlaylistPage> {
  late final UserPlaylistBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = GetIt.I<UserPlaylistBloc>();
    _bloc.add(UserPlaylistLoadRequested(widget.playlistId));
  }

  @override
  void didUpdateWidget(UserPlaylistPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) {
      _bloc.add(UserPlaylistLoadRequested(widget.playlistId));
    }
  }

  @override
  void dispose() {
    _bloc.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserPlaylistBloc>.value(
      value: _bloc,
      child: _UserPlaylistView(playlistId: widget.playlistId),
    );
  }
}

class _UserPlaylistView extends StatefulWidget {
  final String playlistId;
  const _UserPlaylistView({required this.playlistId});

  @override
  State<_UserPlaylistView> createState() => _UserPlaylistViewState();
}

class _UserPlaylistViewState extends State<_UserPlaylistView>
    with SingleTickerProviderStateMixin {
  bool _isLiked = false;
  late final AnimationController _likeAnimController;
  String? _loadedPlaylistId;

  List<UserPlaylistTrack>? _recommendedTracks;
  bool _isLoadingRecommendations = false;
  String? _recommendationsError;

  final ScrollController _scrollController = ScrollController();
  int _recommendationsPage = 0;
  bool _recommendationsReachedEnd = false;
  final Set<String> _seenRecommendationTrackIds = {};

  @override
  void initState() {
    super.initState();
    _likeAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _scrollController.addListener(_onScroll);
    _fetchRecommendations();
  }

  @override
  void didUpdateWidget(_UserPlaylistView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playlistId != widget.playlistId) {
      _isLiked = false;
      _loadedPlaylistId = null;
      _recommendedTracks = null;
      _allRecommendedTrackIds = null;
      _isLoadingRecommendations = false;
      _recommendationsError = null;
      _recommendationsPage = 0;
      _recommendationsReachedEnd = false;
      _seenRecommendationTrackIds.clear();
      _fetchRecommendations();
    }
  }

  void _onScroll() {
    if (_isLoadingRecommendations || _recommendationsReachedEnd) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchRecommendations(loadMore: true);
    }
  }

  // Holds the full list of recommended track IDs fetched from /api/recommendations
  List<String>? _allRecommendedTrackIds;
  static const int _recPageSize = 20;

  Future<void> _fetchRecommendations({bool loadMore = false}) async {
    if (!mounted) return;
    if (loadMore && (_isLoadingRecommendations || _recommendationsReachedEnd)) return;

    if (!loadMore) {
      setState(() {
        _recommendationsPage = 0;
        _recommendationsReachedEnd = false;
        _recommendedTracks = null;
        _allRecommendedTrackIds = null;
        _seenRecommendationTrackIds.clear();
      });
    }

    setState(() {
      _isLoadingRecommendations = true;
      _recommendationsError = null;
    });

    try {
      final dio = GetIt.I<Dio>();
      final supabase = GetIt.I<SupabaseClient>();
      final token = supabase.auth.currentSession?.accessToken;
      final authHeader = {'Authorization': 'Bearer $token'};

      // ── Step 1: Fetch personalised track IDs from the recommendations API ──
      // Only fetch the ID list once; subsequent "load more" pages slice from it.
      if (_allRecommendedTrackIds == null) {
        List<String> recommendedIds = [];

        // Primary: /api/recommendations (personalised, returns track_ids)
        try {
          final recRes = await dio.get(
            '${AppSecrets.backendUrl}/api/recommendations',
            queryParameters: {'limit': 100, 'type': 'discovery'},
            options: Options(headers: authHeader),
          );
          if (recRes.data is Map) {
            final data = recRes.data as Map<String, dynamic>;
            final ids = data['track_ids'] as List<dynamic>? ?? [];
            recommendedIds = ids.map((e) => e.toString()).toList();
          }
        } catch (_) {
          // If personalised recs fail, fall through to trending
        }

        // Fallback: /api/user/dashboard/trending — extract track-type items
        if (recommendedIds.isEmpty) {
          try {
            final trendRes = await dio.get(
              '${AppSecrets.backendUrl}/api/user/dashboard/trending',
              queryParameters: {'page': 0, 'limit': 100},
              options: Options(headers: authHeader),
            );
            final rawItems = trendRes.data is Map
                ? (trendRes.data['items'] as List<dynamic>? ?? [])
                : (trendRes.data is List ? trendRes.data as List<dynamic> : []);
            for (final item in rawItems) {
              if (item is Map) {
                final type = item['type']?.toString().toLowerCase();
                final id = item['track_id']?.toString() ?? item['id']?.toString();
                if ((type == 'track' || type == null) && id != null && id.isNotEmpty) {
                  recommendedIds.add(id);
                }
              }
            }
          } catch (_) {}
        }

        // Last resort: /api/user/tracks (user's own library)
        if (recommendedIds.isEmpty) {
          try {
            final libRes = await dio.get(
              '${AppSecrets.backendUrl}/api/user/tracks',
              queryParameters: {'page': 0, 'limit': 100},
              options: Options(headers: authHeader),
            );
            final rawItems = libRes.data is Map
                ? ((libRes.data['items'] ?? libRes.data['tracks'] ?? libRes.data['data'] ?? []) as List<dynamic>)
                : (libRes.data is List ? libRes.data as List<dynamic> : []);
            for (final item in rawItems) {
              if (item is Map) {
                final id = item['track_id']?.toString() ?? item['id']?.toString();
                if (id != null && id.isNotEmpty) recommendedIds.add(id);
              }
            }
          } catch (_) {}
        }

        _allRecommendedTrackIds = recommendedIds;
      }

      // ── Step 2: Slice the next page of IDs & resolve full metadata ──
      final allIds = _allRecommendedTrackIds!;
      final offset = _recommendationsPage * _recPageSize;
      final pageIds = allIds.skip(offset).take(_recPageSize).toList();

      if (pageIds.isEmpty) {
        if (mounted) {
          setState(() {
            _recommendedTracks ??= [];
            _isLoadingRecommendations = false;
            _recommendationsReachedEnd = true;
          });
        }
        return;
      }

      // Resolve metadata in parallel (up to _recPageSize concurrent requests)
      final List<UserPlaylistTrack> resolved = [];
      await Future.wait(pageIds.map((trackId) async {
        try {
          final res = await dio.get(
            '${AppSecrets.backendUrl}/api/user/tracks/$trackId',
            options: Options(headers: authHeader),
          );
          final item = res.data as Map<String, dynamic>? ?? {};
          final trackArtists = (item['artists'] as List<dynamic>? ?? const [])
              .map((a) => UserPlaylistArtist(
                    artistId: a['artist_id']?.toString() ?? a['id']?.toString() ?? '',
                    name: a['name']?.toString() ?? 'Unknown Artist',
                    avatarUrl: a['avatar_url']?.toString(),
                  ))
              .toList();
          resolved.add(UserPlaylistTrack(
            trackId: item['track_id']?.toString() ?? item['id']?.toString() ?? trackId,
            title: item['title']?.toString() ?? 'Unknown Track',
            duration: (item['duration'] as num?)?.toInt() ?? 0,
            isExplicit: item['is_explicit'] == true,
            coverUrl: _extractTrackCoverUrl(item),
            artists: trackArtists,
          ));
        } catch (_) {
          // Skip tracks whose metadata can't be fetched
        }
      }));

      if (mounted) {
        setState(() {
          final currentList = _recommendedTracks ?? <UserPlaylistTrack>[];
          for (final track in resolved) {
            if (_seenRecommendationTrackIds.add(track.trackId)) {
              currentList.add(track);
            }
          }
          _recommendedTracks = currentList;
          _isLoadingRecommendations = false;
          _recommendationsPage++;
          // Reached end when this page returned fewer items than requested
          // OR when there are no more IDs left to page through
          _recommendationsReachedEnd =
              resolved.isEmpty || (offset + _recPageSize) >= allIds.length;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recommendationsError = e.toString();
          _isLoadingRecommendations = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _likeAnimController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadPreference(String playlistId) {
    if (_loadedPlaylistId == playlistId) return;
    _loadedPlaylistId = playlistId;
    final repo = GetIt.I<ListeningHistoryRepository>();
    repo.getPlaylistPreference(playlistId).then((pref) {
      if (mounted && pref == 1 && !_isLiked) {
        setState(() => _isLiked = true);
      }
    });
  }

  void _toggleLike(String playlistId) {
    final repo = GetIt.I<ListeningHistoryRepository>();
    setState(() {
      _isLiked = !_isLiked;
    });
    if (_isLiked) {
      _likeAnimController.forward(from: 0);
      repo.likePlaylist(playlistId);
    } else {
      repo.clearPlaylistPreference(playlistId);
    }
  }

  String _fmtDuration(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  String _fmtDurationLong(int seconds) {
    final hours = seconds ~/ 3600;
    final mins = (seconds % 3600) ~/ 60;
    if (hours == 0) return '$mins min';
    return '${hours}h ${mins}m';
  }

  void _showPlaylistOptions(BuildContext pageContext, UserPlaylistDetail playlist) {
    final theme = Theme.of(pageContext);
    final cs = theme.colorScheme;
    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: cs.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag handle
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 4),
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                // Playlist identity row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: playlist.coverUrl != null
                            ? Image.network(
                                playlist.coverUrl!,
                                width: 52,
                                height: 52,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 52,
                                  height: 52,
                                  color: cs.primaryContainer,
                                  child: Icon(Icons.music_note_rounded,
                                      color: cs.onPrimaryContainer),
                                ),
                              )
                            : Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: cs.primaryContainer,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(Icons.music_note_rounded,
                                    color: cs.onPrimaryContainer, size: 26),
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              playlist.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (playlist.description != null &&
                                playlist.description!.isNotEmpty)
                              Text(
                                playlist.description!,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: cs.onSurfaceVariant,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(height: 1, color: cs.outlineVariant),
                // Edit option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.primaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.edit_rounded,
                        size: 20, color: cs.onPrimaryContainer),
                  ),
                  title: const Text('Edit Details',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text('Change name, description or visibility'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showEditPlaylistSheet(pageContext, playlist);
                  },
                ),
                // Delete option
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: cs.errorContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.delete_outline_rounded,
                        size: 20, color: cs.onErrorContainer),
                  ),
                  title: Text(
                    'Delete Playlist',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: cs.error),
                  ),
                  subtitle: const Text('This cannot be undone'),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showDeleteConfirmationDialog(pageContext, playlist);
                  },
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDeleteConfirmationDialog(
      BuildContext pageContext, UserPlaylistDetail playlist) {
    final bloc = pageContext.read<UserPlaylistBloc>();
    final theme = Theme.of(pageContext);
    final cs = theme.colorScheme;
    showDialog(
      context: pageContext,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.delete_forever_rounded,
                color: cs.onErrorContainer, size: 28),
          ),
          title: const Text('Delete Playlist',
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w700)),
          content: Text(
            'Are you sure you want to delete "${playlist.name}"? This action cannot be undone.',
            textAlign: TextAlign.center,
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actionsPadding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          actions: [
            OutlinedButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                bloc.add(UserPlaylistDeleted(playlist.playlistId));
              },
              style: FilledButton.styleFrom(
                backgroundColor: cs.error,
                foregroundColor: cs.onError,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void _showEditPlaylistSheet(
      BuildContext pageContext, UserPlaylistDetail playlist) {
    final nameController = TextEditingController(text: playlist.name);
    final descController =
        TextEditingController(text: playlist.description ?? '');
    bool isPublic = playlist.isPublic;
    bool isCollaborative = playlist.isCollaborative;
    final bloc = pageContext.read<UserPlaylistBloc>();

    showModalBottomSheet(
      context: pageContext,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme = Theme.of(pageContext);
        final cs = theme.colorScheme;
        return StatefulBuilder(
          builder: (sbCtx, setSheetState) {
            return Padding(
              // Pushes sheet up when keyboard appears
              padding: EdgeInsets.only(
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
              child: Container(
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Drag handle
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 20),
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: cs.onSurfaceVariant.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: cs.primaryContainer,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.edit_rounded,
                                  size: 20, color: cs.onPrimaryContainer),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'Edit Playlist',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Name field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: nameController,
                          textCapitalization: TextCapitalization.words,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Playlist Name',
                            hintText: 'Give it a great name…',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: cs.primary, width: 1.5),
                            ),
                            prefixIcon: Icon(Icons.title_rounded,
                                color: cs.onSurfaceVariant),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Description field
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: descController,
                          maxLines: 2,
                          textCapitalization: TextCapitalization.sentences,
                          style: theme.textTheme.bodyLarge,
                          decoration: InputDecoration(
                            labelText: 'Description',
                            hintText: 'Optional — describe the vibe…',
                            filled: true,
                            fillColor: cs.surfaceContainerHighest
                                .withValues(alpha: 0.4),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide.none,
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: BorderSide(
                                  color: cs.primary, width: 1.5),
                            ),
                            prefixIcon: Padding(
                              padding: const EdgeInsets.only(bottom: 24),
                              child: Icon(Icons.notes_rounded,
                                  color: cs.onSurfaceVariant),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Toggles section
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Column(
                          children: [
                            _EditToggleRow(
                              icon: Icons.public_rounded,
                              label: 'Public',
                              subtitle: 'Anyone can find & listen',
                              value: isPublic,
                              onChanged: (v) =>
                                  setSheetState(() => isPublic = v),
                              activeColor: cs.primary,
                            ),
                            const SizedBox(height: 8),
                            _EditToggleRow(
                              icon: Icons.group_rounded,
                              label: 'Collaborative',
                              subtitle: 'Friends can add & remove tracks',
                              value: isCollaborative,
                              onChanged: (v) =>
                                  setSheetState(() => isCollaborative = v),
                              activeColor: cs.secondary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // Action buttons
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => Navigator.pop(sheetContext),
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: FilledButton(
                                onPressed: () {
                                  final name =
                                      nameController.text.trim();
                                  if (name.isEmpty) {
                                    ScaffoldMessenger.of(sbCtx)
                                        .showSnackBar(
                                      const SnackBar(
                                          content: Text(
                                              'Playlist name cannot be empty')),
                                    );
                                    return;
                                  }
                                  Navigator.pop(sheetContext);
                                  bloc.add(UserPlaylistUpdated(
                                    playlistId: playlist.playlistId,
                                    name: name,
                                    description:
                                        descController.text.trim(),
                                    isPublic: isPublic,
                                    isCollaborative: isCollaborative,
                                  ));
                                },
                                style: FilledButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(14)),
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14),
                                ),
                                child: const Text('Save Changes'),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final playerCubit = GetIt.I<PlayerCubit>();
    final downloadManager = context.read<DownloadManager>();


    return Scaffold(
      body: SafeArea(
        child: BlocConsumer<UserPlaylistBloc, UserPlaylistState>(
          listener: (context, state) {
            if (state.isDeleted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Playlist deleted successfully'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
              Navigator.of(context).pop();
            } else if (state.error != null && state.playlist != null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: ${state.error}'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: theme.colorScheme.error,
                ),
              );
            }
          },
          builder: (context, state) {
            if (state.isLoading && state.playlist == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.error != null && state.playlist == null) {
              return Center(
                child: Text('Failed to load playlist: ${state.error}'),
              );
            }
            final playlist = state.playlist;
            if (playlist == null) {
              return const Center(
                child: Text('Playlist is not available right now'),
              );
            }
            _loadPreference(playlist.playlistId);
            final playlistTrackIds = playlist.tracks.map((t) => t.trackId).toSet();
            final displayedRecommendations = _recommendedTracks
                ?.where((t) => !playlistTrackIds.contains(t.trackId))
                .toList() ?? [];
            final creatorName = playlist.artists.isNotEmpty
                ? (playlist.artists.first.name ?? 'Unknown Creator')
                : 'Unknown Creator';
            final trackCount = playlist.tracks.length;
            final totalDuration = playlist.totalDuration;
            final explicitCount = playlist.tracks.where((t) => t.isExplicit).length;
            final canPlayPlaylist = playlist.tracks.isNotEmpty;

            final currentUserId = GetIt.I<SupabaseClient>().auth.currentUser?.id;
            // Show menu if: user is in artists list, OR the playlist has no
            // artists yet (newly-created empty playlist always belongs to creator).
            final isCreator = currentUserId != null &&
                (playlist.artists.isEmpty ||
                    playlist.artists.first.artistId == currentUserId);

            Future<void> playTrack(
              String trackId, {
              required String title,
              required String artist,
              String? artistId,
            }) async {
              if (!context.mounted) return;
              // Don't pre-fetch URL — showPlayerBottomSheet with trackId
              // (and no audioUrl) uses playTrackById which shows metadata
              // instantly while resolving the stream URL in the background.
              await showPlayerBottomSheet(
                context,
                title: title,
                artist: artist,
                album: playlist.name,
                imageUrl: playlist.coverUrl,
                trackId: trackId,
                artistId: artistId,
                playlistId: playlist.playlistId,
                openSheet: false,
              );
            }

            void downloadTrack(String trackId) {
              downloadManager.addToQueue(trackId);
            }

            void downloadAllTracks() {
              final trackIds = playlist.tracks
                  .map((track) => track.trackId)
                  .toSet()
                  .toList();
              for (final trackId in trackIds) {
                downloadManager.addToQueue(trackId);
              }
            }

            return CustomScrollView(
              controller: _scrollController,
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 410,
                  backgroundColor: theme.colorScheme.surface,
                  title: Text(
                    playlist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  actions: [
                    if (isCreator)
                      IconButton(
                        icon: const Icon(Icons.more_vert_rounded),
                        onPressed: () => _showPlaylistOptions(context, playlist),
                        tooltip: 'Playlist options',
                      ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    collapseMode: CollapseMode.parallax,
                    background: _PlaylistHeader(
                      playlistId: playlist.playlistId,
                      title: playlist.name,
                      creator: creatorName,
                      description: playlist.description,
                      coverUrl: playlist.coverUrl,
                      trackCount: trackCount,
                      totalDuration: _fmtDurationLong(totalDuration),
                      explicitCount: explicitCount,
                      isPublic: playlist.isPublic,
                      isCollaborative: playlist.isCollaborative,
                      collaborators: playlist.collaborators,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            SizedBox(
                              width: 52,
                              height: 52,
                              child: IconButton.filled(
                                onPressed: canPlayPlaylist
                                    ? () async {
                                        final first = playlist.tracks.first;
                                        final firstArtist = first.artists.isNotEmpty
                                            ? first.artists.first
                                            : null;
                                        final artists = firstArtist?.name ?? creatorName;
                                        // Replace queue with all playlist tracks
                                        final queueItems = playlist.tracks
                                            .map((track) {
                                              final trackArtists =
                                                  track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map((a) =>
                                                                a.name ??
                                                                'Unknown Artist')
                                                            .join(', ')
                                                      : creatorName;
                                              return QueueItem(
                                                trackId: track.trackId,
                                                title: track.title,
                                                artist: trackArtists,
                                                album: playlist.name,
                                                imageUrl: playlist.coverUrl,
                                                durationSeconds: track.duration,
                                              );
                                            })
                                            .toList();
                                        await playerCubit.replaceQueue(queueItems);
                                        await playTrack(
                                          first.trackId,
                                          title: first.title,
                                          artist: artists,
                                          artistId: firstArtist?.artistId,
                                        );
                                      }
                                    : null,
                                icon: const Icon(
                                  Icons.play_arrow_rounded,
                                  size: 26,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Like button
                            ScaleTransition(
                              scale: Tween<double>(begin: 1.0, end: 1.3)
                                  .chain(CurveTween(curve: Curves.elasticOut))
                                  .animate(_likeAnimController),
                              child: SizedBox(
                                width: 44,
                                height: 44,
                                child: IconButton(
                                  onPressed: () => _toggleLike(playlist.playlistId),
                                  icon: AnimatedSwitcher(
                                    duration: const Duration(milliseconds: 250),
                                    transitionBuilder: (child, animation) =>
                                        FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                                    child: Icon(
                                      _isLiked
                                          ? Icons.favorite_rounded
                                          : Icons.favorite_border_rounded,
                                      key: ValueKey(_isLiked),
                                      color: _isLiked
                                          ? Colors.redAccent
                                          : theme.colorScheme.onSurfaceVariant,
                                      size: 24,
                                    ),
                                  ),
                                  tooltip: _isLiked ? 'Unlike' : 'Like',
                                ),
                              ),
                            ),
                            if (playlist.isCollaborative) ...[
                              const SizedBox(width: 12),
                              IconButton(
                                onPressed: () {
                                  final inviteUrl = '${AppSecrets.backendUrl}/playlists/join/${playlist.playlistId}';
                                  Clipboard.setData(ClipboardData(text: inviteUrl));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Collaborator invite link copied! Share it with friends.'),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      backgroundColor: theme.colorScheme.primary,
                                    ),
                                  );
                                },
                                icon: const Icon(Icons.person_add_alt_1_rounded),
                                color: theme.colorScheme.primary,
                                tooltip: 'Invite Collaborators',
                              ),
                            ],
                            const Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.outlined(
                                    onPressed: canPlayPlaylist
                                        ? () async {
                                            final randomTrack = playlist.tracks[
                                                Random().nextInt(trackCount)];
                                            final randomArtist = randomTrack.artists.isNotEmpty
                                                ? randomTrack.artists.first
                                                : null;
                                            final artists = randomArtist != null
                                                ? randomTrack.artists
                                                      .map((a) => a.name ?? 'Unknown Artist')
                                                      .join(', ')
                                                : creatorName;
                                            // Replace queue with all playlist tracks
                                            final queueItems = playlist.tracks
                                                .map((track) {
                                                  final trackArtists =
                                                      track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map(
                                                              (a) =>
                                                                  a.name ??
                                                                  'Unknown Artist',
                                                            )
                                                            .join(', ')
                                                      : creatorName;
                                                  return QueueItem(
                                                    trackId: track.trackId,
                                                    title: track.title,
                                                    artist: trackArtists,
                                                    album: playlist.name,
                                                    imageUrl: playlist.coverUrl,
                                                    durationSeconds:
                                                        track.duration,
                                                  );
                                                })
                                                .toList();
                                            await playerCubit
                                                .replaceQueue(queueItems);
                                            await playTrack(
                                              randomTrack.trackId,
                                              title: randomTrack.title,
                                              artist: artists,
                                              artistId: randomArtist?.artistId,
                                            );
                                          }
                                        : null,
                                    icon: const Icon(
                                      Icons.shuffle_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Shuffle',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.filledTonal(
                                    onPressed: playlist.tracks.isEmpty
                                        ? null
                                        : () async {
                                            final queueItems = playlist.tracks
                                                .map((track) {
                                                  final artists =
                                                      track.artists.isNotEmpty
                                                      ? track.artists
                                                            .map(
                                                              (a) =>
                                                                  a.name ??
                                                                  'Unknown Artist',
                                                            )
                                                            .join(', ')
                                                      : creatorName;
                                                  return QueueItem(
                                                    trackId: track.trackId,
                                                    title: track.title,
                                                    artist: artists,
                                                    album: playlist.name,
                                                    imageUrl: playlist.coverUrl,
                                                    durationSeconds:
                                                        track.duration,
                                                  );
                                                })
                                                .toList();
                                            await playerCubit
                                                .addToQueue(queueItems);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context)
                                                  .showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Added $trackCount tracks to queue',
                                                  ),
                                                ),
                                              );
                                            }
                                          },
                                    icon: const Icon(
                                      Icons.queue_music_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Queue all',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 40,
                                  height: 40,
                                  child: IconButton.filled(
                                    onPressed: playlist.tracks.isEmpty
                                        ? null
                                        : () {
                                            downloadAllTracks();
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Added $trackCount tracks to downloads',
                                                ),
                                              ),
                                            );
                                          },
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          theme.colorScheme.primary,
                                      foregroundColor:
                                          theme.colorScheme.onPrimary,
                                    ),
                                    icon: const Icon(
                                      Icons.download_for_offline_rounded,
                                      size: 19,
                                    ),
                                    tooltip: 'Download all tracks',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Row(
                      children: [
                        Text(
                          'Tracks',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$trackCount',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          _fmtDurationLong(totalDuration),
                          style: theme.textTheme.labelLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final t = playlist.tracks[index];
                      final artists = t.artists.isNotEmpty
                          ? t.artists
                              .map((a) => a.name ?? 'Unknown')
                              .join(', ')
                          : creatorName;
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: Material(
                          color: theme.colorScheme.surfaceContainerHighest
                              .withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(18),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () async {
                              // Replace queue with all playlist tracks starting from this one
                              final queueItems = playlist.tracks
                                  .skip(index)
                                  .map((track) {
                                    final trackArtists =
                                        track.artists.isNotEmpty
                                            ? track.artists
                                                  .map((a) =>
                                                      a.name ??
                                                      'Unknown Artist')
                                                  .join(', ')
                                            : creatorName;
                                    return QueueItem(
                                      trackId: track.trackId,
                                      title: track.title,
                                      artist: trackArtists,
                                      album: playlist.name,
                                      imageUrl: playlist.coverUrl,
                                      durationSeconds: track.duration,
                                    );
                                  })
                                  .toList();
                              await playerCubit.replaceQueue(queueItems);
                              final trackArtist = t.artists.isNotEmpty
                                  ? t.artists.first
                                  : null;
                              await playTrack(
                                t.trackId,
                                title: t.title,
                                artist: artists,
                                artistId: trackArtist?.artistId,
                              );
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  BlocBuilder<PlayerCubit, PlayerViewState>(
                                    builder: (context, state) {
                                      final isActive = state.track?.trackId == t.trackId;
                                      final isPlaying = isActive && state.playing;
                                      return Container(
                                        width: 34,
                                        height: 34,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isActive
                                              ? theme.colorScheme.primary
                                              : theme.colorScheme.primaryContainer,
                                        ),
                                        child: isActive
                                            ? Center(
                                                child: PlayingBarsAnimation(
                                                  width: 14,
                                                  height: 14,
                                                  barCount: 3,
                                                  barWidth: 2,
                                                  gap: 1.5,
                                                  color: theme.colorScheme.onPrimary,
                                                  isPlaying: isPlaying,
                                                ),
                                              )
                                            : Text(
                                                '${index + 1}',
                                                style: theme.textTheme.labelMedium
                                                    ?.copyWith(
                                                      fontWeight: FontWeight.w700,
                                                      color: theme.colorScheme
                                                          .onPrimaryContainer,
                                                    ),
                                              ),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                t.title,
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis,
                                                style: theme
                                                    .textTheme.titleMedium
                                                    ?.copyWith(
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$artists • ${_fmtDuration(t.duration)}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style:
                                              theme.textTheme.bodySmall,
                                        ),
                                        if (playlist.isTrackCached(t.trackId) ||
                                            playlist.isTrackOffline(
                                              t.trackId,
                                            ) ||
                                            t.isExplicit)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              top: 6,
                                            ),
                                            child: Wrap(
                                              spacing: 6,
                                              runSpacing: 4,
                                              children: [
                                                if (t.isExplicit)
                                                  _TrackStatusChip(
                                                    icon:
                                                        Icons.explicit_rounded,
                                                    foregroundColor: theme
                                                        .colorScheme
                                                        .onTertiaryContainer,
                                                    backgroundColor: theme
                                                        .colorScheme
                                                        .tertiaryContainer,
                                                  ),
                                                if (playlist.isTrackCached(
                                                  t.trackId,
                                                ))
                                                  const _TrackStatusChip(
                                                    icon: Icons
                                                        .cloud_done_rounded,
                                                  ),
                                                if (playlist.isTrackOffline(
                                                  t.trackId,
                                                ))
                                                  const _TrackStatusChip(
                                                    icon: Icons
                                                        .offline_bolt_rounded,
                                                  ),
                                              ],
                                            ),
                                          ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.play_arrow_rounded,
                                    ),
                                    tooltip: 'Play',
                                    onPressed: () async {
                                      // Replace queue with all playlist tracks starting from this one
                                      final queueItems = playlist.tracks
                                          .skip(index)
                                          .map((track) {
                                            final trackArtists = track.artists
                                                    .isNotEmpty
                                                ? track.artists
                                                      .map((a) =>
                                                          a.name ??
                                                          'Unknown Artist')
                                                      .join(', ')
                                                : creatorName;
                                            return QueueItem(
                                              trackId: track.trackId,
                                              title: track.title,
                                              artist: trackArtists,
                                              album: playlist.name,
                                              imageUrl: playlist.coverUrl,
                                              durationSeconds:
                                                  track.duration,
                                            );
                                          })
                                          .toList();
                                      await playerCubit
                                          .replaceQueue(queueItems);
                                      final trackArtist = t.artists.isNotEmpty
                                          ? t.artists.first
                                          : null;
                                      await playTrack(
                                        t.trackId,
                                        title: t.title,
                                        artist: artists,
                                        artistId: trackArtist?.artistId,
                                      );
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.more_horiz_rounded),
                                    tooltip: 'More',
                                    onPressed: () async {
                                      final supabase = GetIt.I<SupabaseClient>();
                                      final currentUserId = supabase.auth.currentUser?.id;
                                      final isCreator = playlist.artists.isNotEmpty &&
                                          playlist.artists.first.artistId == currentUserId;
                                      final isCollaborator = playlist.collaborators.any((c) => c.artistId == currentUserId);
                                      final canRemoveTrack = isCreator || isCollaborator || playlist.isCollaborative;

                                      final action =
                                          await showModalBottomSheet<String>(
                                            context: context,
                                            builder: (context) {
                                              return SafeArea(
                                                child: Column(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.queue_music_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Add to queue',
                                                      ),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            context,
                                                            'queue',
                                                          ),
                                                    ),
                                                    ListTile(
                                                      leading: const Icon(
                                                        Icons.download_rounded,
                                                      ),
                                                      title: const Text(
                                                        'Download',
                                                      ),
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            context,
                                                            'download',
                                                          ),
                                                    ),
                                                    if (canRemoveTrack) ...[
                                                      ListTile(
                                                        leading: const Icon(
                                                          Icons.delete_outline_rounded,
                                                          color: Colors.redAccent,
                                                        ),
                                                        title: const Text(
                                                          'Remove from playlist',
                                                          style: TextStyle(color: Colors.redAccent),
                                                        ),
                                                        onTap: () =>
                                                            Navigator.pop(
                                                              context,
                                                              'remove',
                                                            ),
                                                      ),
                                                    ],
                                                  ],
                                                ),
                                              );
                                            },
                                          );
                                      if (action == 'queue') {
                                        final item = QueueItem(
                                          trackId: t.trackId,
                                          title: t.title,
                                          artist: artists,
                                          album: playlist.name,
                                          imageUrl: playlist.coverUrl,
                                          durationSeconds: t.duration,
                                        );
                                        await playerCubit
                                            .addToQueue([item]);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Added to queue'),
                                            ),
                                          );
                                        }
                                      } else if (action == 'download') {
                                        downloadTrack(t.trackId);
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(
                                            const SnackBar(
                                              content:
                                                  Text('Added to downloads'),
                                            ),
                                          );
                                        }
                                      } else if (action == 'remove') {
                                        if (!context.mounted) return;
                                        context.read<UserPlaylistBloc>().add(
                                              UserPlaylistTrackRemoved(
                                                playlist.playlistId,
                                                t.trackId,
                                              ),
                                            );
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: playlist.tracks.length,
                  ),
                ),
                if (playlist.artists.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Creator',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: 86,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: playlist.artists.length,
                              separatorBuilder: (_, _) =>
                                  const SizedBox(width: 12),
                              itemBuilder: (context, index) {
                                final artist = playlist.artists[index];
                                return _ArtistChip(
                                  name: artist.name ?? 'Unknown Creator',
                                  avatarUrl: artist.avatarUrl,
                                  // Playlist creators are users, not music
                                  // artists — do not navigate on tap.
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // ── Recommended Tracks Section ─────────────────────
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Recommended',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Based on this playlist's vibe",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(CupertinoIcons.refresh, size: 18),
                          tooltip: 'Refresh Recommendations',
                          onPressed: _fetchRecommendations,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_recommendedTracks == null && _isLoadingRecommendations)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(
                        child: CupertinoActivityIndicator(),
                      ),
                    ),
                  )
                else if (_recommendationsError != null && (_recommendedTracks == null || _recommendedTracks!.isEmpty))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Center(
                        child: Text(
                          'Could not load recommendations: $_recommendationsError',
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  )
                else if (displayedRecommendations.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                      child: Center(
                        child: Text(
                          'No new recommendations right now. Check back later!',
                          style: TextStyle(fontSize: 12, color: Colors.white30),
                        ),
                      ),
                    ),
                  )
                else ...[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final rec = displayedRecommendations[index];
                        final recArtists = rec.artists.isNotEmpty
                            ? rec.artists.map((a) => a.name ?? 'Unknown').join(', ')
                            : 'Unknown Artist';

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(12),
                            onTap: () async {
                              await playTrack(
                                rec.trackId,
                                title: rec.title,
                                artist: recArtists,
                                artistId: rec.artists.isNotEmpty ? rec.artists.first.artistId : null,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: SizedBox(
                                      width: 40,
                                      height: 40,
                                      child: rec.coverUrl != null && rec.coverUrl!.isNotEmpty
                                          ? Image.network(
                                              rec.coverUrl!,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, _, _) => Container(
                                                color: Colors.white10,
                                                child: const Icon(
                                                  CupertinoIcons.music_note,
                                                  color: Colors.white30,
                                                  size: 20,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              color: Colors.white10,
                                              child: const Icon(
                                                CupertinoIcons.music_note,
                                                color: Colors.white30,
                                                size: 20,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          rec.title,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),

                                        const SizedBox(height: 2),
                                        Text(
                                          recArtists,
                                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6)),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(CupertinoIcons.add_circled, color: theme.colorScheme.primary),
                                    tooltip: 'Add to Playlist',
                                    onPressed: () {
                                      context.read<UserPlaylistBloc>().add(
                                        UserPlaylistTrackAdded(playlist.playlistId, rec.trackId),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: displayedRecommendations.length,
                    ),
                  ),
                  if (_isLoadingRecommendations)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 24.0),
                        child: Center(
                          child: CupertinoActivityIndicator(),
                        ),
                      ),
                    ),
                ],

                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }

  String? _extractTrackCoverUrl(Map<String, dynamic> item) {
    final directCover = item['cover_url']?.toString();
    if (directCover != null && directCover.isNotEmpty) return directCover;

    final imageUrl = item['image_url']?.toString();
    if (imageUrl != null && imageUrl.isNotEmpty) return imageUrl;

    final albumCover = item['album_cover_url']?.toString();
    if (albumCover != null && albumCover.isNotEmpty) return albumCover;

    final album = item['album'];
    if (album is Map) {
      final nestedCover = album['cover_url']?.toString();
      if (nestedCover != null && nestedCover.isNotEmpty) return nestedCover;
    }

    return null;
  }
}

class _TrackStatusChip extends StatelessWidget {
  final IconData icon;
  final Color? foregroundColor;
  final Color? backgroundColor;

  const _TrackStatusChip({
    required this.icon,
    this.foregroundColor,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        icon,
        size: 13,
        color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}

class _PlaylistHeader extends StatelessWidget {
  final String playlistId;
  final String title;
  final String creator;
  final String? description;
  final String? coverUrl;
  final int trackCount;
  final String totalDuration;
  final int explicitCount;
  final bool isPublic;
  final bool isCollaborative;
  final List<UserPlaylistArtist> collaborators;

  const _PlaylistHeader({
    required this.playlistId,
    required this.title,
    required this.creator,
    required this.coverUrl,
    required this.trackCount,
    required this.totalDuration,
    required this.explicitCount,
    required this.isPublic,
    required this.description,
    required this.isCollaborative,
    required this.collaborators,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return LayoutBuilder(
      builder: (context, constraints) {
        final artSize = isNarrow ? 150.0 : 220.0;
        final art = ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: artSize,
            height: artSize,
            child: BlocBuilder<PlayerCubit, PlayerViewState>(
              builder: (context, state) {
                final isActive = state.track?.playlistId == playlistId;
                final isPlaying = isActive && state.playing;
                final img = coverUrl == null
                    ? Container(
                        color: theme.colorScheme.surfaceContainerHighest,
                        child: const Icon(Icons.queue_music_rounded, size: 64),
                      )
                    : Image.network(
                        coverUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: const Icon(Icons.queue_music_rounded, size: 64),
                        ),
                      );

                return Stack(
                  children: [
                    Positioned.fill(child: img),
                    if (isActive)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.35),
                          child: Center(
                            child: ClipOval(
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.15),
                                      width: 1,
                                    ),
                                  ),
                                  child: Center(
                                    child: PlayingBarsAnimation(
                                      width: 24,
                                      height: 24,
                                      barCount: 4,
                                      barWidth: 3,
                                      gap: 2,
                                      color: Colors.white,
                                      isPlaying: isPlaying,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        );

        return Stack(
          fit: StackFit.expand,
          children: [
            if (coverUrl != null)
              Opacity(
                opacity: 0.32,
                child: Image.network(
                  coverUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.22),
                    theme.colorScheme.surface.withValues(alpha: 0.92),
                    theme.colorScheme.surface,
                  ],
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
                child: isNarrow
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          art,
                          const SizedBox(height: 14),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'Playlist • $creator',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.titleMedium,
                              ),
                              if (isCollaborative && collaborators.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                _CollaboratorAvatars(collaborators: collaborators),
                              ],
                            ],
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaChip(label: '$trackCount tracks'),
                              _MetaChip(label: totalDuration),
                              if (explicitCount > 0)
                                _MetaChip(label: '$explicitCount explicit'),
                              if (isPublic)
                                _MetaChip(label: 'Public'),
                              if (isCollaborative)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(999),
                                    border: Border.all(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(CupertinoIcons.person_3_fill, size: 12, color: theme.colorScheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Collaborative',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      )
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          art,
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.displaySmall?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Text(
                                      'Playlist • $creator',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    if (isCollaborative && collaborators.isNotEmpty) ...[
                                      const SizedBox(width: 12),
                                      _CollaboratorAvatars(collaborators: collaborators),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _MetaChip(label: '$trackCount tracks'),
                                    _MetaChip(label: totalDuration),
                                    if (explicitCount > 0)
                                      _MetaChip(
                                        label: '$explicitCount explicit',
                                      ),
                                    if (isPublic) _MetaChip(label: 'Public'),
                                    if (isCollaborative)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(
                                            color: theme.colorScheme.primary.withValues(alpha: 0.3),
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(CupertinoIcons.person_3_fill, size: 12, color: theme.colorScheme.primary),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Collaborative',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.primary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CollaboratorAvatars extends StatelessWidget {
  final List<UserPlaylistArtist> collaborators;

  const _CollaboratorAvatars({required this.collaborators});

  @override
  Widget build(BuildContext context) {
    if (collaborators.isEmpty) return const SizedBox.shrink();

    // Show up to 4 collaborators
    final showCount = min(4, collaborators.length);

    return SizedBox(
      height: 28,
      width: 20.0 + (showCount * 14.0),
      child: Stack(
        children: List.generate(showCount, (index) {
          final c = collaborators[index];
          return Positioned(
            left: index * 14.0,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1.5),
              ),
              child: CircleAvatar(
                radius: 11,
                backgroundColor: Colors.grey.shade800,
                backgroundImage: c.avatarUrl != null ? NetworkImage(c.avatarUrl!) : null,
                child: c.avatarUrl == null
                    ? Text(
                        (c.name ?? '?').substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: Colors.white),
                      )
                    : null,
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String label;

  const _MetaChip({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ArtistChip extends StatelessWidget {
  final String name;
  final String? avatarUrl;

  const _ArtistChip({required this.name, this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(
          alpha: 0.55,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
            child: avatarUrl == null
                ? const Icon(Icons.person_rounded, size: 18)
                : null,
          ),
          const SizedBox(height: 6),
          Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

/// A compact toggle row used inside the edit-playlist bottom sheet.
class _EditToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;

  const _EditToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: value
            ? activeColor.withValues(alpha: 0.08)
            : cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? activeColor.withValues(alpha: 0.35)
              : cs.outline.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: value
                  ? activeColor.withValues(alpha: 0.15)
                  : cs.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 18,
              color: value ? activeColor : cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: value ? activeColor : cs.onSurface,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          CupertinoSwitch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: activeColor,
          ),
        ],
      ),
    );
  }
}
