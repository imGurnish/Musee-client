import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import '../bloc/admin_tracks_bloc.dart';
import '../../domain/entities/track.dart';

class AdminTracksPage extends StatefulWidget {
  const AdminTracksPage({super.key});

  @override
  State<AdminTracksPage> createState() => _AdminTracksPageState();
}

class _AdminTracksPageState extends State<AdminTracksPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 20;
  final Set<String> _selectedTrackIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<AdminTracksBloc>().add(LoadTracks(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _confirmDeleteOne(Track track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete track?'),
        content: Text(
          'Are you sure you want to delete "${track.title}"? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<AdminTracksBloc>().add(DeleteTrackEvent(track.trackId));
      setState(() => _selectedTrackIds.remove(track.trackId));
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedTrackIds.length;
    if (count == 0) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected tracks?'),
        content: Text(
          'Delete $count selected track(s)? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete All'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      context.read<AdminTracksBloc>().add(
        DeleteTracksEvent(_selectedTrackIds.toList(growable: false)),
      );
      setState(() => _selectedTrackIds.clear());
    }
  }

  void _toggleSelectTrack(Track track, bool selected) {
    setState(() {
      if (selected) {
        _selectedTrackIds.add(track.trackId);
      } else {
        _selectedTrackIds.remove(track.trackId);
      }
    });
  }

  void _toggleSelectAllVisible(List<Track> tracks, bool selected) {
    setState(() {
      if (selected) {
        _selectedTrackIds.addAll(tracks.map((e) => e.trackId));
      } else {
        _selectedTrackIds.removeAll(tracks.map((e) => e.trackId));
      }
    });
  }

  void _clearSelection() => setState(_selectedTrackIds.clear);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Tracks'),
        actions: [
          if (_selectedTrackIds.isNotEmpty)
            IconButton(
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete selected (${_selectedTrackIds.length})',
            ),
          IconButton(
            onPressed: () => context.push(Routes.adminTrackCreate),
            icon: const Icon(Icons.library_music),
            tooltip: 'Create track',
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by title',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (v) => context.read<AdminTracksBloc>().add(
                      LoadTracks(
                        page: 0,
                        limit: _limit,
                        search: v.trim().isEmpty ? null : v.trim(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                DropdownButton<int>(
                  value: _limit,
                  onChanged: (v) {
                    if (v == null) return;
                    setState(() => _limit = v);
                    context.read<AdminTracksBloc>().add(
                      LoadTracks(
                        page: 0,
                        limit: v,
                        search: _searchCtrl.text.trim().isEmpty
                            ? null
                            : _searchCtrl.text.trim(),
                      ),
                    );
                  },
                  items: const [10, 20, 50, 100]
                      .map(
                        (e) => DropdownMenuItem(
                          value: e,
                          child: Text('Page size: $e'),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_selectedTrackIds.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: theme.colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${_selectedTrackIds.length} selected',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onSecondaryContainer,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: _clearSelection,
                      child: const Text('Clear'),
                    ),
                    FilledButton.icon(
                      onPressed: _confirmDeleteSelected,
                      icon: const Icon(Icons.delete_sweep_outlined),
                      label: const Text('Delete'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: BlocBuilder<AdminTracksBloc, AdminTracksState>(
                builder: (context, state) {
                  if (state is AdminTracksLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminTracksFailure) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            state.message,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.error,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => context.read<AdminTracksBloc>().add(
                              LoadTracks(
                                page: 0,
                                limit: _limit,
                                search: _searchCtrl.text.trim().isEmpty
                                    ? null
                                    : _searchCtrl.text.trim(),
                              ),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is AdminTracksPageLoaded) {
                    final List<Track> items = state.items;
                    final visibleIds = items.map((t) => t.trackId).toSet();
                    final stale = _selectedTrackIds.difference(visibleIds);
                    if (stale.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _selectedTrackIds.removeAll(stale));
                      });
                    }
                    final totalPages = (state.total / state.limit).ceil().clamp(
                      1,
                      999999,
                    );
                    return Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final isMobile = c.maxWidth < 700;
                              if (items.isEmpty) {
                                return const Center(
                                  child: Text('No tracks found'),
                                );
                              }
                              if (isMobile) {
                                return ListView.separated(
                                  itemCount: items.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, index) {
                                    final t = items[index];
                                    final selected = _selectedTrackIds.contains(
                                      t.trackId,
                                    );
                                    final artists = t.artists.isNotEmpty
                                        ? t.artists
                                              .map((a) => a.name)
                                              .join(', ')
                                        : '—';
                                    return Card(
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: selected,
                                          onChanged: (v) =>
                                              _toggleSelectTrack(t, v ?? false),
                                        ),
                                        title: Text(t.title),
                                        subtitle: Text(artists),
                                        onTap: () => context.push(
                                          '/admin/tracks/${t.trackId}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            if (t.isPublished)
                                              const Icon(
                                                Icons.public,
                                                size: 18,
                                                color: Colors.green,
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  _confirmDeleteOne(t),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              // Wide: DataTable
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    DataColumn(
                                      label: Checkbox(
                                        value: items.isNotEmpty &&
                                            _selectedTrackIds.containsAll(
                                              items.map((e) => e.trackId),
                                            ),
                                        onChanged: (v) => _toggleSelectAllVisible(
                                          items,
                                          v ?? false,
                                        ),
                                      ),
                                    ),
                                    const DataColumn(label: Text('Title')),
                                    const DataColumn(label: Text('Artists')),
                                    const DataColumn(label: Text('Published')),
                                    const DataColumn(label: Text('Created')),
                                    const DataColumn(label: Text('Actions')),
                                  ],
                                  rows: items.map((t) {
                                    final selected = _selectedTrackIds.contains(
                                      t.trackId,
                                    );
                                    final artists = t.artists.isNotEmpty
                                        ? t.artists
                                              .map((a) => a.name)
                                              .join(', ')
                                        : '—';
                                    return DataRow(
                                      onSelectChanged: (_) => context.push(
                                        '/admin/tracks/${t.trackId}',
                                      ),
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: selected,
                                            onChanged: (v) =>
                                                _toggleSelectTrack(
                                                  t,
                                                  v ?? false,
                                                ),
                                          ),
                                        ),
                                        DataCell(Text(t.title)),
                                        DataCell(
                                          SizedBox(
                                            width: 280,
                                            child: Text(
                                              artists,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                        DataCell(
                                          Icon(
                                            t.isPublished
                                                ? Icons.check
                                                : Icons.close,
                                            size: 18,
                                            color: t.isPublished
                                                ? Colors.green
                                                : Colors.redAccent,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            t.createdAt
                                                .toLocal()
                                                .toString()
                                                .split('.')
                                                .first,
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteOne(t),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList(),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Total: ${state.total}',
                                style: theme.textTheme.titleSmall,
                              ),
                              Wrap(
                                spacing: 8,
                                children: [
                                  IconButton(
                                    onPressed: state.page > 0
                                        ? () =>
                                              context.read<AdminTracksBloc>().add(
                                                LoadTracks(
                                                  page: state.page - 1,
                                                  limit: state.limit,
                                                  search: state.search,
                                                ),
                                              )
                                        : null,
                                    icon: const Icon(Icons.chevron_left),
                                  ),
                                  Center(
                                    child: Text(
                                      'Page ${state.page + 1} of $totalPages',
                                      style: theme.textTheme.bodySmall,
                                    ),
                                  ),
                                  IconButton(
                                    onPressed: state.page < totalPages - 1
                                        ? () =>
                                              context.read<AdminTracksBloc>().add(
                                                LoadTracks(
                                                  page: state.page + 1,
                                                  limit: state.limit,
                                                  search: state.search,
                                                ),
                                              )
                                        : null,
                                    icon: const Icon(Icons.chevron_right),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
