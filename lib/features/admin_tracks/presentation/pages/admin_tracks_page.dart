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
    _searchCtrl.addListener(_onSearchTextChanged);
    context.read<AdminTracksBloc>().add(LoadTracks(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _searchTracks({int page = 0, int? limit, String? search}) {
    final currentLimit = limit ?? _limit;
    final query = search ?? _searchCtrl.text.trim();
    context.read<AdminTracksBloc>().add(
      LoadTracks(
        page: page,
        limit: currentLimit,
        search: query.isEmpty ? null : query,
      ),
    );
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

  void _showMobileTrackMenu(Track track, bool selected) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              track.title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(selected ? Icons.check_box : Icons.check_box_outline_blank),
            title: Text(selected ? 'Deselect' : 'Select'),
            onTap: () {
              Navigator.pop(ctx);
              _toggleSelectTrack(track, !selected);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/admin/tracks/${track.trackId}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteOne(track);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search Tracks',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by track title',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchTracks(),
                ),
              ),
              if (_searchCtrl.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                    _searchTracks();
                  },
                ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _searchTracks();
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(42, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSearchFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search by track title',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchTracks(),
                  ),
                ),
                if (_searchCtrl.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                      _searchTracks();
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _searchTracks();
          },
          icon: const Icon(Icons.search_rounded),
          label: const Text('Search'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 768;
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
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isMobile
                    ? _buildMobileSearchFilters(theme)
                    : _buildDesktopSearchFilters(theme),
              ),
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
                            onPressed: () => _searchTracks(),
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
                                      elevation: 0,
                                      child: InkWell(
                                        onTap: () => context.push('/admin/tracks/${t.trackId}'),
                                        onLongPress: () => _toggleSelectTrack(t, !selected),
                                        child: Padding(
                                          padding: const EdgeInsets.all(12),
                                          child: Row(
                                            children: [
                                              Checkbox(
                                                value: selected,
                                                onChanged: (v) => _toggleSelectTrack(t, v ?? false),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      t.title,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.textTheme.titleSmall,
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      artists,
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                      style: theme.textTheme.bodySmall,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: t.isPublished
                                                            ? Colors.green.withOpacity(0.15)
                                                            : Colors.orange.withOpacity(0.15),
                                                        borderRadius: BorderRadius.circular(6),
                                                      ),
                                                      child: Text(
                                                        t.isPublished ? 'Published' : 'Draft',
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          fontWeight: FontWeight.w500,
                                                          color: t.isPublished ? Colors.green[700] : Colors.orange[700],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              IconButton(
                                                icon: const Icon(Icons.more_vert),
                                                onPressed: () => _showMobileTrackMenu(t, selected),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              // Wide: DataTable
                              final useCompactActions = c.maxWidth < 1100;
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  dataRowMinHeight: 60,
                                  dataRowMaxHeight: 60,
                                  columnSpacing: useCompactActions ? 20 : 28,
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
                                          useCompactActions
                                              ? PopupMenuButton<String>(
                                                  tooltip: 'Actions',
                                                  onSelected: (value) {
                                                    if (value == 'details') {
                                                      context.push('/admin/tracks/${t.trackId}');
                                                    } else if (value == 'delete') {
                                                      _confirmDeleteOne(t);
                                                    }
                                                  },
                                                  itemBuilder: (context) => const [
                                                    PopupMenuItem<String>(
                                                      value: 'details',
                                                      child: Text('View Details'),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'delete',
                                                      child: Text('Delete'),
                                                    ),
                                                  ],
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(4),
                                                    child: Icon(Icons.more_vert),
                                                  ),
                                                )
                                              : Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    IconButton(
                                                      tooltip: 'View Details',
                                                      icon: const Icon(Icons.info_outline),
                                                      visualDensity: VisualDensity.compact,
                                                      onPressed: () => context.push('/admin/tracks/${t.trackId}'),
                                                    ),
                                                    IconButton(
                                                      tooltip: 'Delete',
                                                      icon: const Icon(Icons.delete_outline),
                                                      visualDensity: VisualDensity.compact,
                                                      onPressed: () => _confirmDeleteOne(t),
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
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primaryContainer,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Total: ${state.total}',
                                      style: theme.textTheme.labelSmall?.copyWith(
                                        color: theme.colorScheme.onPrimaryContainer,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  SizedBox(
                                    height: 36,
                                    width: 36,
                                    child: FilledButton.tonal(
                                      onPressed: state.page > 0
                                          ? () => _searchTracks(
                                                page: state.page - 1,
                                                limit: state.limit,
                                                search: state.search,
                                              )
                                          : null,
                                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                                      child: const Icon(Icons.chevron_left, size: 18),
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${state.page + 1} / $totalPages',
                                  style: theme.textTheme.labelSmall,
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 8,
                                children: [
                                  SizedBox(
                                    height: 36,
                                    width: 36,
                                    child: FilledButton.tonal(
                                      onPressed: state.page < totalPages - 1
                                          ? () => _searchTracks(
                                                page: state.page + 1,
                                                limit: state.limit,
                                                search: state.search,
                                              )
                                          : null,
                                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                                      child: const Icon(Icons.chevron_right, size: 18),
                                    ),
                                  ),
                                  PopupMenuButton<int>(
                                    initialValue: _limit,
                                    onSelected: (v) {
                                      setState(() => _limit = v);
                                      _searchTracks(limit: v);
                                    },
                                    itemBuilder: (context) => [10, 20, 50, 100]
                                        .map((e) => PopupMenuItem(
                                              value: e,
                                              child: Text(e.toString()),
                                            ))
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: theme.colorScheme.outline),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        spacing: 4,
                                        children: [
                                          Text(_limit.toString(), style: theme.textTheme.labelSmall),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 16,
                                            color: theme.colorScheme.onSurfaceVariant,
                                          ),
                                        ],
                                      ),
                                    ),
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
