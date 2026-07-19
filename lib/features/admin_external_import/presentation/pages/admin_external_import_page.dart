import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:musee/features/admin_external_import/data/admin_import_queue_client.dart';
import 'package:musee/features/admin_external_import/data/jiosaavn_api_client.dart';
import 'package:musee/init_dependencies.dart';

enum AdminImportContentType { track, album, playlist }

class AdminExternalImportPage extends StatefulWidget {
  const AdminExternalImportPage({super.key});

  @override
  State<AdminExternalImportPage> createState() => _AdminExternalImportPageState();
}

class _AdminExternalImportPageState extends State<AdminExternalImportPage> {
  final TextEditingController _queryCtrl = TextEditingController();

  AdminImportContentType _selectedType = AdminImportContentType.album;
  bool _searching = false;
  bool _polling = false;
  List<JioSaavnSearchItem> _results = const [];
  final Map<String, ImportJobStatus> _jobs = {};
  final Map<String, String> _jobTitles = {};
  Timer? _pollTimer;

  JioSaavnApiClient get _searchClient => serviceLocator<JioSaavnApiClient>();
  AdminImportQueueClient get _queueClient => serviceLocator<AdminImportQueueClient>();

  int get _activeJobsCount => _jobs.values.where((job) => !job.isTerminal).length;

  @override
  void initState() {
    super.initState();
    _loadRecentJobs();
  }

  Future<void> _loadRecentJobs() async {
    try {
      final jobs = await _queueClient.getRecentJobs();
      if (!mounted) return;
      setState(() {
        for (final job in jobs) {
          _jobs[job.jobId] = job;
        }
      });
      _ensurePolling();
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _queryCtrl.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _searching = true;
      _results = const [];
    });

    try {
      final List<JioSaavnSearchItem> items;
      switch (_selectedType) {
        case AdminImportContentType.track:
          items = await _searchClient.searchTracks(query);
          break;
        case AdminImportContentType.album:
          items = await _searchClient.searchAlbums(query);
          break;
        case AdminImportContentType.playlist:
          items = await _searchClient.searchPlaylists(query);
          break;
      }

      if (!mounted) return;
      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Search failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _enqueueImportById(String id, String title, AdminImportContentType type) async {
    try {
      final ImportJobStatus queued;
      switch (type) {
        case AdminImportContentType.track:
          queued = await _queueClient.enqueueTrack(id);
          break;
        case AdminImportContentType.album:
          queued = await _queueClient.enqueueAlbum(id);
          break;
        case AdminImportContentType.playlist:
          queued = await _queueClient.enqueuePlaylist(id);
          break;
      }

      if (!mounted) return;
      setState(() {
        _jobs[queued.jobId] = queued;
        _jobTitles[queued.jobId] = title;
      });
      _showSnack('Queued ${_labelForType(type)} import for $title');
      _ensurePolling();
    } catch (e) {
      if (!mounted) return;
      _showSnack('Failed to queue import: $e', error: true);
    }
  }

  void _ensurePolling() {
    _pollTimer ??= Timer.periodic(const Duration(seconds: 3), (_) {
      _pollActiveJobs();
    });
    _pollActiveJobs();
  }

  Future<void> _pollActiveJobs() async {
    if (_polling) return;
    final activeJobIds = _jobs.values.where((job) => !job.isTerminal).map((job) => job.jobId).toList();
    if (activeJobIds.isEmpty) {
      _pollTimer?.cancel();
      _pollTimer = null;
      return;
    }

    _polling = true;
    try {
      for (final jobId in activeJobIds) {
        final status = await _queueClient.getStatus(jobId);
        if (!mounted) return;
        setState(() => _jobs[jobId] = status);
      }
    } catch (_) {
      // Keep polling even if one round fails due to transient network issues.
    } finally {
      _polling = false;
    }
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red : null,
      ),
    );
  }

  void _showItemDetails(JioSaavnSearchItem item) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _ItemDetailsSheet(
          item: item,
          type: _selectedType,
          client: _searchClient,
          onEnqueue: _enqueueImportById,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      appBar: AppBar(
        title: const Text('JioSaavn External Import'),
        actions: [
          IconButton(
            tooltip: 'Check Broken Tracks',
            onPressed: _showBrokenTracksSheet,
            icon: const Icon(Icons.build_circle_rounded),
          ),
          IconButton(
            tooltip: 'Import Queue',
            onPressed: _showQueueSheet,
            icon: Badge(
              isLabelVisible: _activeJobsCount > 0,
              label: Text('$_activeJobsCount'),
              child: const Icon(Icons.queue_play_next_rounded),
            ),
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isMobile ? double.infinity : 900),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sliding Animated Pills for Type Selector
              Center(
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypePill(AdminImportContentType.album, 'Album', Icons.album_rounded),
                      _buildTypePill(AdminImportContentType.playlist, 'Playlist', Icons.queue_music_rounded),
                      _buildTypePill(AdminImportContentType.track, 'Track', Icons.music_note_rounded),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Search Input Box
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: TextField(
                  controller: _queryCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search ${_labelForType(_selectedType)} on JioSaavn...',
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(left: 12, right: 8),
                      child: Icon(Icons.search_rounded, color: theme.colorScheme.primary),
                    ),
                    suffixIcon: _queryCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.cancel_rounded),
                            onPressed: () {
                              _queryCtrl.clear();
                              setState(() => _results = const []);
                            },
                          )
                        : null,
                  ),
                  onSubmitted: (_) => _search(),
                  onChanged: (val) {
                    setState(() {}); // Updates visibility of cancel button
                  },
                ),
              ),
              const SizedBox(height: 16),
              // Results section
              Expanded(
                child: _searching
                    ? const Center(child: CircularProgressIndicator())
                    : _results.isEmpty
                        ? _buildEmptyState(theme)
                        : ListView.separated(
                            itemCount: _results.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = _results[index];
                              return Card(
                                elevation: 0,
                                color: theme.colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  side: BorderSide(
                                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                  ),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: item.imageUrl == null
                                        ? _leadingIconForType(_selectedType, theme)
                                        : Image.network(
                                            item.imageUrl!,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) => _leadingIconForType(_selectedType, theme),
                                          ),
                                  ),
                                  title: Text(
                                    item.title,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: Text(
                                    item.subtitle ?? item.id,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  onTap: () => _showItemDetails(item),
                                  trailing: IconButton(
                                    tooltip: 'Queue Import',
                                    style: IconButton.styleFrom(
                                      backgroundColor: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                                      foregroundColor: theme.colorScheme.primary,
                                    ),
                                    onPressed: () => _enqueueImportById(item.id, item.title, _selectedType),
                                    icon: const Icon(Icons.download_rounded),
                                  ),
                                ),
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

  Widget _buildTypePill(AdminImportContentType type, String label, IconData icon) {
    final isSelected = _selectedType == type;
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedType = type;
          _results = const [];
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? theme.colorScheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: isSelected ? theme.colorScheme.onPrimary : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.import_contacts_rounded,
            size: 64,
            color: theme.colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Explore & Ingest Music',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Search for tracks, albums, or playlists on JioSaavn.\nClick on an item to preview its tracks before importing.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  String _labelForType(AdminImportContentType type) {
    switch (type) {
      case AdminImportContentType.track:
        return 'Track';
      case AdminImportContentType.album:
        return 'Album';
      case AdminImportContentType.playlist:
        return 'Playlist';
    }
  }

  Widget _leadingIconForType(AdminImportContentType type, ThemeData theme) {
    final iconData = type == AdminImportContentType.track
        ? Icons.music_note_rounded
        : type == AdminImportContentType.album
            ? Icons.album_rounded
            : Icons.queue_music_rounded;

    return Container(
      width: 56,
      height: 56,
      color: theme.colorScheme.surfaceContainer,
      child: Icon(iconData, color: theme.colorScheme.primary),
    );
  }

  void _showQueueSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _QueueManagerSheet(
          jobs: _jobs,
          jobTitles: _jobTitles,
          queueClient: _queueClient,
        );
      },
    );
  }

  void _showBrokenTracksSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _BrokenTracksSheet(
          queueClient: _queueClient,
          onRerunTriggered: (queuedJobs) {
            setState(() {
              for (final job in queuedJobs) {
                final jobId = job['jobId'] as String;
                final title = job['title'] as String;
                final extId = job['externalId'] as String;

                _jobs[jobId] = ImportJobStatus(
                  jobId: jobId,
                  type: 'track',
                  sourceId: extId,
                  status: 'queued',
                  progress: 0,
                  createdAt: DateTime.now(),
                );
                _jobTitles[jobId] = title;
              }
            });
            _ensurePolling();
          },
        );
      },
    );
  }
}

// ----------------------------------------------------
// Details Bottom Sheet Widget
// ----------------------------------------------------
class _ItemDetailsSheet extends StatefulWidget {
  final JioSaavnSearchItem item;
  final AdminImportContentType type;
  final JioSaavnApiClient client;
  final Function(String id, String title, AdminImportContentType type) onEnqueue;

  const _ItemDetailsSheet({
    required this.item,
    required this.type,
    required this.client,
    required this.onEnqueue,
  });

  @override
  State<_ItemDetailsSheet> createState() => _ItemDetailsSheetState();
}

class _ItemDetailsSheetState extends State<_ItemDetailsSheet> {
  bool _loading = true;
  String? _error;
  dynamic _details; // JioSaavnSongDetail, JioSaavnAlbumDetail, JioSaavnPlaylistDetail
  String? _activePreviewSongId;

  @override
  void initState() {
    super.initState();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    try {
      dynamic res;
      switch (widget.type) {
        case AdminImportContentType.track:
          res = await widget.client.getSongDetails(widget.item.id);
          break;
        case AdminImportContentType.album:
          res = await widget.client.getAlbumDetails(widget.item.id);
          break;
        case AdminImportContentType.playlist:
          res = await widget.client.getPlaylistDetails(widget.item.id);
          break;
      }
      if (mounted) {
        setState(() {
          _details = res;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.8,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 12),
                        Text('Fetching external details...', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.error_outline_rounded, size: 48, color: Colors.red),
                              const SizedBox(height: 12),
                              Text('Failed to load: $_error', textAlign: TextAlign.center),
                              const SizedBox(height: 16),
                              FilledButton(onPressed: _fetchDetails, child: const Text('Retry')),
                            ],
                          ),
                        ),
                      )
                    : _buildContent(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    if (widget.type == AdminImportContentType.track) {
      final song = _details as JioSaavnSongDetail;
      final previewUrl = widget.client.getPlayableUrl(song);

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: song.imageUrl == null
                  ? Container(width: 180, height: 180, color: theme.colorScheme.surfaceContainer, child: Icon(Icons.music_note, size: 64, color: theme.colorScheme.primary))
                  : Image.network(song.imageUrl!, width: 180, height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 16),
            Text(song.title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              song.artists.map((a) => a.name).join(', '),
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (song.albumTitle != null) ...[
              const SizedBox(height: 4),
              Text(
                'Album: ${song.albumTitle}',
                style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 24),
            // Preview Player
            if (previewUrl != null) ...[
              Text('Preview Track', style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _PreviewPlayer(url: previewUrl),
              const SizedBox(height: 24),
            ],
            // Stats grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildMetaItem('Duration', _formatDuration(song.duration), theme),
                _buildMetaItem('Language', song.language ?? 'Unknown', theme),
                _buildMetaItem('Explicit', (song.isDrm ?? false) ? 'DRM' : (song.has320kbps ?? false) ? '320kbps' : 'Standard', theme),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
                onPressed: () {
                  widget.onEnqueue(song.id, song.title, AdminImportContentType.track);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.download_rounded),
                label: const Text('Queue Track Import', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      );
    } else {
      // Album or Playlist Details
      final String title;
      final String? subtitle;
      final String? imageUrl;
      final List<JioSaavnSongDetail> songs;

      if (widget.type == AdminImportContentType.album) {
        final album = _details as JioSaavnAlbumDetail;
        title = album.title;
        subtitle = album.artists.map((a) => a.name).join(', ');
        imageUrl = album.imageUrl;
        songs = album.songs;
      } else {
        final playlist = _details as JioSaavnPlaylistDetail;
        title = playlist.title;
        subtitle = playlist.subtitle;
        imageUrl = playlist.imageUrl;
        songs = playlist.songs;
      }

      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: imageUrl == null
                      ? Container(width: 90, height: 90, color: theme.colorScheme.surfaceContainer, child: Icon(widget.type == AdminImportContentType.album ? Icons.album : Icons.queue_music, color: theme.colorScheme.primary))
                      : Image.network(imageUrl, width: 90, height: 90, fit: BoxFit.cover),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      if (subtitle != null && subtitle.isNotEmpty)
                        Text(subtitle, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 8),
                      Text('${songs.length} Tracks | JioSaavn API', style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Bulk Import Button
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: SizedBox(
              width: double.infinity,
              height: 46,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                onPressed: () {
                  widget.onEnqueue(widget.item.id, title, widget.type);
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.download_rounded),
                label: Text('Import Entire ${widget.type == AdminImportContentType.album ? 'Album' : 'Playlist'}', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(),
          Expanded(
            child: songs.isEmpty
                ? const Center(child: Text('No tracks found in this collection'))
                : ListView.builder(
                    itemCount: songs.length,
                    itemBuilder: (context, index) {
                      final song = songs[index];
                      final isPreviewOpen = _activePreviewSongId == song.id;
                      final previewUrl = widget.client.getPlayableUrl(song);

                      return Column(
                        children: [
                          ListTile(
                            leading: Container(
                              width: 32,
                              alignment: Alignment.center,
                              child: Text('${index + 1}', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                            ),
                            title: Text(song.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              song.artists.map((a) => a.name).join(', '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (previewUrl != null)
                                  IconButton(
                                    icon: Icon(isPreviewOpen ? Icons.close_rounded : Icons.play_arrow_rounded),
                                    onPressed: () {
                                      setState(() {
                                        _activePreviewSongId = isPreviewOpen ? null : song.id;
                                      });
                                    },
                                  ),
                                IconButton(
                                  icon: const Icon(Icons.download_rounded),
                                  onPressed: () => widget.onEnqueue(song.id, song.title, AdminImportContentType.track),
                                ),
                              ],
                            ),
                          ),
                          if (isPreviewOpen && previewUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(left: 48, right: 16, bottom: 8),
                              child: _PreviewPlayer(url: previewUrl),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      );
    }
  }

  Widget _buildMetaItem(String label, String value, ThemeData theme) {
    return Column(
      children: [
        Text(label, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  String _formatDuration(int seconds) {
    final sec = seconds % 60;
    final min = (seconds / 60).floor();
    return '$min:${sec.toString().padLeft(2, '0')}';
  }
}

// ----------------------------------------------------
// Preview Player Widget (Local media_kit Instance)
// ----------------------------------------------------
class _PreviewPlayer extends StatefulWidget {
  final String url;
  const _PreviewPlayer({required this.url});

  @override
  State<_PreviewPlayer> createState() => _PreviewPlayerState();
}

class _PreviewPlayerState extends State<_PreviewPlayer> {
  late final Player _player;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  bool _buffering = false;
  StreamSubscription? _playingSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _bufferingSub;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _playingSub = _player.stream.playing.listen((val) {
      if (mounted) setState(() => _playing = val);
    });
    _positionSub = _player.stream.position.listen((val) {
      if (mounted) setState(() => _position = val);
    });
    _durationSub = _player.stream.duration.listen((val) {
      if (mounted) setState(() => _duration = val);
    });
    _bufferingSub = _player.stream.buffering.listen((val) {
      if (mounted) setState(() => _buffering = val);
    });
    _player.open(Media(widget.url), play: false);
  }

  @override
  void dispose() {
    _playingSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _bufferingSub?.cancel();
    _player.dispose();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final sec = d.inSeconds % 60;
    final min = d.inMinutes;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final posStr = _formatDuration(_position);
    final durStr = _formatDuration(_duration);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          IconButton(
            iconSize: 36,
            icon: _buffering
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(_playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
            onPressed: () {
              if (_playing) {
                _player.pause();
              } else {
                _player.play();
              }
            },
          ),
          Expanded(
            child: Column(
              children: [
                Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: math.max(_duration.inMilliseconds.toDouble(), _position.inMilliseconds.toDouble()),
                  onChanged: (val) {
                    _player.seek(Duration(milliseconds: val.toInt()));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(posStr, style: theme.textTheme.bodySmall),
                      Text(durStr, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------
// Queue Manager Bottom Sheet Widget
// ----------------------------------------------------
class _QueueManagerSheet extends StatefulWidget {
  final Map<String, ImportJobStatus> jobs;
  final Map<String, String> jobTitles;
  final AdminImportQueueClient queueClient;

  const _QueueManagerSheet({
    required this.jobs,
    required this.jobTitles,
    required this.queueClient,
  });

  @override
  State<_QueueManagerSheet> createState() => _QueueManagerSheetState();
}

class _QueueManagerSheetState extends State<_QueueManagerSheet> {
  late Map<String, ImportJobStatus> _localJobs;
  Timer? _localPollTimer;
  bool _polling = false;

  @override
  void initState() {
    super.initState();
    _localJobs = Map.from(widget.jobs);
    _startLocalPolling();
  }

  @override
  void dispose() {
    _localPollTimer?.cancel();
    super.dispose();
  }

  void _startLocalPolling() {
    _localPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _pollActiveJobs();
    });
  }

  Future<void> _pollActiveJobs() async {
    if (_polling) return;
    final activeJobIds = _localJobs.values.where((job) => !job.isTerminal).map((job) => job.jobId).toList();
    if (activeJobIds.isEmpty) return;

    _polling = true;
    try {
      for (final jobId in activeJobIds) {
        final status = await widget.queueClient.getStatus(jobId);
        if (!mounted) return;
        setState(() {
          _localJobs[jobId] = status;
          widget.jobs[jobId] = status; // Keep parent in sync
        });
      }
    } catch (_) {} finally {
      _polling = false;
    }
  }

  void _showLogsTerminal(ImportJobStatus job) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _LogsTerminalSheet(
          jobId: job.jobId,
          queueClient: widget.queueClient,
          initialTitle: widget.jobTitles[job.jobId] ?? job.sourceId,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;
    final sortedJobs = _localJobs.values.toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    return Container(
      height: size.height * 0.7,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Import Progress Center', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                if (_localJobs.values.any((j) => !j.isTerminal))
                  Row(
                    children: [
                      const SizedBox(width: 8, height: 8, child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Text('Syncing...', style: theme.textTheme.bodySmall),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: sortedJobs.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.queue_rounded, size: 48, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        const Text('No import jobs running or completed yet'),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: sortedJobs.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final job = sortedJobs[index];
                      final title = widget.jobTitles[job.jobId] ?? job.sourceId;

                      return Card(
                        elevation: 0,
                        color: theme.colorScheme.surfaceContainerLow,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(16),
                          onTap: () => _showLogsTerminal(job),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        job.type == 'track'
                                            ? Icons.music_note_rounded
                                            : job.type == 'album'
                                                ? Icons.album_rounded
                                                : Icons.queue_music_rounded,
                                        size: 16,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    _statusPill(job.status),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: (job.progress.clamp(0, 100)) / 100,
                                    minHeight: 6,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Progress: ${job.progress}%', style: theme.textTheme.bodySmall),
                                    Row(
                                      children: [
                                        Text('View logs', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                                        const SizedBox(width: 2),
                                        Icon(Icons.chevron_right_rounded, size: 14, color: theme.colorScheme.primary),
                                      ],
                                    ),
                                  ],
                                ),
                                if ((job.error ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      job.error!,
                                      style: const TextStyle(color: Colors.red, fontSize: 13),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(String status) {
    final normalized = status.toLowerCase();
    final Color color;
    switch (normalized) {
      case 'success':
      case 'completed':
        color = Colors.green;
        break;
      case 'failed':
      case 'not_found':
        color = Colors.red;
        break;
      case 'running':
      case 'processing':
        color = Colors.blue;
        break;
      case 'queued':
      default:
        color = Colors.orange;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        normalized,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
      ),
    );
  }
}

// ----------------------------------------------------
// Real-time Logs Terminal Drawer Widget
// ----------------------------------------------------
class _LogsTerminalSheet extends StatefulWidget {
  final String jobId;
  final AdminImportQueueClient queueClient;
  final String initialTitle;

  const _LogsTerminalSheet({
    required this.jobId,
    required this.queueClient,
    required this.initialTitle,
  });

  @override
  State<_LogsTerminalSheet> createState() => _LogsTerminalSheetState();
}

class _LogsTerminalSheetState extends State<_LogsTerminalSheet> {
  Timer? _logPollTimer;
  ImportJobStatus? _jobStatus;
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _logPollTimer = Timer.periodic(const Duration(seconds: 2), (_) {
      _fetchLogs();
    });
  }

  @override
  void dispose() {
    _logPollTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchLogs() async {
    try {
      final status = await widget.queueClient.getStatus(widget.jobId);
      if (!mounted) return;
      setState(() {
        _jobStatus = status;
        _loading = false;
      });
      // Scroll to bottom
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
      if (status.isTerminal) {
        _logPollTimer?.cancel();
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Container(
      height: size.height * 0.75,
      decoration: const BoxDecoration(
        color: Color(0xFF121212),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.initialTitle, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text('Job ID: ${widget.jobId}', style: const TextStyle(color: Colors.white54, fontSize: 11)),
                    ],
                  ),
                ),
                if (_jobStatus != null) _statusBadge(_jobStatus!.status),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: Colors.green))
                : Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF070707),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: _jobStatus!.logs.isEmpty
                        ? const Center(child: Text('Waiting for log entries...', style: TextStyle(color: Colors.white30, fontFamily: 'monospace')))
                        : ListView.builder(
                            controller: _scrollController,
                            itemCount: _jobStatus!.logs.length,
                            itemBuilder: (context, index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Text(
                                  '> ${_jobStatus!.logs[index]}',
                                  style: const TextStyle(
                                    color: Color(0xFF00FF00),
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(String status) {
    final color = status.toLowerCase() == 'completed' || status.toLowerCase() == 'success'
        ? Colors.green
        : status.toLowerCase() == 'failed'
            ? Colors.red
            : Colors.blue;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}

// ----------------------------------------------------
// Broken Tracks Bottom Sheet Widget
// ----------------------------------------------------
class _BrokenTracksSheet extends StatefulWidget {
  final AdminImportQueueClient queueClient;
  final Function(List<dynamic>) onRerunTriggered;

  const _BrokenTracksSheet({
    required this.queueClient,
    required this.onRerunTriggered,
  });

  @override
  State<_BrokenTracksSheet> createState() => _BrokenTracksSheetState();
}

class _BrokenTracksSheetState extends State<_BrokenTracksSheet> {
  bool _loading = false;
  bool _rerunning = false;
  List<Map<String, dynamic>> _brokenTracks = [];
  final Set<String> _selectedTrackIds = {};
  String _searchQuery = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _scanForBrokenTracks();
  }

  Future<void> _scanForBrokenTracks() async {
    setState(() {
      _loading = true;
      _error = null;
      _brokenTracks = [];
      _selectedTrackIds.clear();
    });

    try {
      final tracks = await widget.queueClient.getBrokenTracks();
      if (!mounted) return;
      setState(() {
        _brokenTracks = tracks;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _triggerRerun({required bool all}) async {
    final tracksToRerun = all
        ? _brokenTracks
        : _brokenTracks.where((t) => _selectedTrackIds.contains(t['trackId'])).toList();

    if (tracksToRerun.isEmpty) return;

    setState(() => _rerunning = true);

    try {
      final ids = tracksToRerun.map((t) => t['trackId'] as String).toList();
      final jobs = await widget.queueClient.rerunBrokenTracks(ids);

      if (!mounted) return;
      Navigator.pop(context); // Close the sheet
      widget.onRerunTriggered(jobs);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to trigger rerun: $e';
        _rerunning = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    // Filter in-memory by search query
    final filteredTracks = _brokenTracks.where((t) {
      if (_searchQuery.isEmpty) return true;
      final title = (t['title'] ?? '').toString().toLowerCase();
      final album = (t['albumTitle'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return title.contains(query) || album.contains(query);
    }).toList();

    return Container(
      height: size.height * 0.85,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sync_problem_rounded, color: theme.colorScheme.error, size: 28),
                    const SizedBox(width: 10),
                    Text(
                      'Broken Tracks Diagnostic',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
          ),
          const Divider(),

          // Search and bulk select controls (only show if not loading and tracks exist)
          if (!_loading && _brokenTracks.isNotEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Filter broken tracks...',
                          hintStyle: TextStyle(fontSize: 14),
                          border: InputBorder.none,
                          prefixIcon: Icon(Icons.filter_list_rounded, size: 20),
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        onChanged: (val) {
                          setState(() => _searchQuery = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Select/Deselect All Checkbox
                  Checkbox(
                    value: filteredTracks.isNotEmpty &&
                        filteredTracks.every((t) => _selectedTrackIds.contains(t['trackId'])),
                    tristate: filteredTracks.any((t) => _selectedTrackIds.contains(t['trackId'])) &&
                        !filteredTracks.every((t) => _selectedTrackIds.contains(t['trackId'])),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          for (final t in filteredTracks) {
                            _selectedTrackIds.add(t['trackId'] as String);
                          }
                        } else {
                          for (final t in filteredTracks) {
                            _selectedTrackIds.remove(t['trackId'] as String);
                          }
                        }
                      });
                    },
                  ),
                  Text(
                    'Select All',
                    style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

          // Main body
          Expanded(
            child: _loading
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Scanning tracks and verifying Azure blobs...', style: TextStyle(fontWeight: FontWeight.w500)),
                      ],
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 48),
                              const SizedBox(height: 12),
                              Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry Scan'),
                                onPressed: _scanForBrokenTracks,
                              ),
                            ],
                          ),
                        ),
                      )
                    : _brokenTracks.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.check_circle_rounded, color: Colors.green, size: 48),
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'All imports healthy!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                const Text('No tracks with missing Azure storage blobs detected.'),
                              ],
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: filteredTracks.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, index) {
                              final track = filteredTracks[index];
                              final trackId = track['trackId'] as String;
                              final isSelected = _selectedTrackIds.contains(trackId);
                              final reason = track['reason'] as String;

                              return Card(
                                elevation: 0,
                                color: isSelected
                                    ? theme.colorScheme.primaryContainer.withValues(alpha: 0.25)
                                    : theme.colorScheme.surfaceContainerLow,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isSelected
                                        ? theme.colorScheme.primary.withValues(alpha: 0.5)
                                        : theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                                    width: isSelected ? 1.5 : 1.0,
                                  ),
                                ),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(12),
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedTrackIds.remove(trackId);
                                      } else {
                                        _selectedTrackIds.add(trackId);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedTrackIds.add(trackId);
                                              } else {
                                                _selectedTrackIds.remove(trackId);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                track['title'] ?? 'Unknown Title',
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                'Album: ${track['albumTitle'] ?? 'Single'}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: theme.colorScheme.onSurfaceVariant,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'ID: ${track['trackId']} • JioSaavn: ${track['externalId']}',
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Chip(
                                          label: Text(
                                            reason == 'missing_master_path' ? 'Missing HLS Path' : 'Blobs Missing',
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: reason == 'missing_master_path'
                                                  ? theme.colorScheme.onErrorContainer
                                                  : theme.colorScheme.onTertiaryContainer,
                                            ),
                                          ),
                                          backgroundColor: reason == 'missing_master_path'
                                              ? theme.colorScheme.errorContainer
                                              : theme.colorScheme.tertiaryContainer,
                                          padding: EdgeInsets.zero,
                                          visualDensity: VisualDensity.compact,
                                          side: BorderSide.none,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
          ),

          // Bottom repair panel
          if (!_loading && _brokenTracks.isNotEmpty && _error == null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainer,
                border: Border(
                  top: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
                ),
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_selectedTrackIds.length} of ${_brokenTracks.length} selected',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.sync_rounded),
                      label: const Text('Rerun All'),
                      onPressed: _rerunning ? null : () => _triggerRerun(all: true),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      icon: _rerunning
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.build_circle_rounded),
                      label: const Text('Repair Selected'),
                      onPressed: _rerunning || _selectedTrackIds.isEmpty ? null : () => _triggerRerun(all: false),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
