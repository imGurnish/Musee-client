import 'dart:async';

import 'package:flutter/material.dart';
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

  Future<void> _enqueueImport(JioSaavnSearchItem item) async {
    try {
      final ImportJobStatus queued;
      switch (_selectedType) {
        case AdminImportContentType.track:
          queued = await _queueClient.enqueueTrack(item.id);
          break;
        case AdminImportContentType.album:
          queued = await _queueClient.enqueueAlbum(item.id);
          break;
        case AdminImportContentType.playlist:
          queued = await _queueClient.enqueuePlaylist(item.id);
          break;
      }

      if (!mounted) return;
      setState(() {
        _jobs[queued.jobId] = queued;
        _jobTitles[queued.jobId] = item.title;
      });
      _showSnack('Queued ${_labelForType(_selectedType)} import for ${item.title}');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Import from JioSaavn'),
        actions: [
          IconButton(
            tooltip: 'Import queue',
            onPressed: _showQueueSheet,
            icon: Badge(
              isLabelVisible: _activeJobsCount > 0,
              label: Text('$_activeJobsCount'),
              child: const Icon(Icons.queue),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildTypeChip(AdminImportContentType.track),
                _buildTypeChip(AdminImportContentType.album),
                _buildTypeChip(AdminImportContentType.playlist),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search ${_labelForType(_selectedType)}',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _searching ? null : _search,
                  child: _searching
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _results.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      itemCount: _results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final item = _results[index];
                        return Card(
                          child: ListTile(
                            leading: item.imageUrl == null
                                ? _leadingIconForType(_selectedType)
                                : Image.network(
                                    item.imageUrl!,
                                    width: 48,
                                    height: 48,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => _leadingIconForType(_selectedType),
                                  ),
                            title: Text(item.title),
                            subtitle: Text(item.subtitle ?? item.id),
                            trailing: IconButton(
                              tooltip: 'Queue import',
                              onPressed: () => _enqueueImport(item),
                              icon: const Icon(Icons.download),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeChip(AdminImportContentType type) {
    return ChoiceChip(
      label: Text(_labelForType(type)),
      selected: _selectedType == type,
      onSelected: (_) {
        setState(() {
          _selectedType = type;
          _results = const [];
        });
      },
    );
  }

  Widget _buildEmptyState() {
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }

    return Center(
      child: Text(
        'Search ${_labelForType(_selectedType)} and use the download icon to queue server import.',
        textAlign: TextAlign.center,
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

  Icon _leadingIconForType(AdminImportContentType type) {
    switch (type) {
      case AdminImportContentType.track:
        return const Icon(Icons.music_note);
      case AdminImportContentType.album:
        return const Icon(Icons.album);
      case AdminImportContentType.playlist:
        return const Icon(Icons.queue_music);
    }
  }

  void _showQueueSheet() {
    final sortedJobs = _jobs.values.toList()
      ..sort((a, b) {
        final aTime = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bTime = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bTime.compareTo(aTime);
      });

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return SafeArea(
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.65,
            child: sortedJobs.isEmpty
                ? const Center(child: Text('No import jobs yet'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: sortedJobs.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final job = sortedJobs[index];
                      final title = _jobTitles[job.jobId] ?? job.sourceId;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      '${job.type.toUpperCase()} - $title',
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                  _statusPill(job.status),
                                ],
                              ),
                              const SizedBox(height: 8),
                              LinearProgressIndicator(
                                value: (job.progress.clamp(0, 100)) / 100,
                                minHeight: 7,
                              ),
                              const SizedBox(height: 8),
                              Text('Progress: ${job.progress}% | Job: ${job.jobId}'),
                              if ((job.error ?? '').isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(
                                    job.error!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _statusPill(String status) {
    final normalized = status.toLowerCase();
    final Color color;
    switch (normalized) {
      case 'success':
        color = Colors.green;
        break;
      case 'failed':
      case 'not_found':
        color = Colors.red;
        break;
      case 'running':
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
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        normalized,
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
