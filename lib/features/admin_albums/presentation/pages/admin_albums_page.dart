import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/admin_albums/domain/entities/album.dart';
import 'package:musee/features/admin_albums/presentation/bloc/admin_albums_bloc.dart';

class AdminAlbumsPage extends StatefulWidget {
  const AdminAlbumsPage({super.key});

  @override
  State<AdminAlbumsPage> createState() => _AdminAlbumsPageState();
}

class _AdminAlbumsPageState extends State<AdminAlbumsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 20;
  final Set<String> _selectedAlbumIds = <String>{};

  @override
  void initState() {
    super.initState();
    context.read<AdminAlbumsBloc>().add(LoadAlbums(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _openCreateDialog() => context.push('/admin/albums/create-new');

  void _openDetail(Album a) => context.push('/admin/albums/${a.id}');

  Future<void> _confirmDeleteOne(Album album) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete album?'),
        content: Text(
          'Are you sure you want to delete "${album.title}"? This will delete all associated tracks and their assets.',
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
      context.read<AdminAlbumsBloc>().add(DeleteAlbumEvent(album.id));
      setState(() => _selectedAlbumIds.remove(album.id));
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedAlbumIds.length;
    if (count == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected albums?'),
        content: Text(
          'Delete $count selected album(s)? This will delete all their tracks and assets. This cannot be undone.',
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
      context.read<AdminAlbumsBloc>().add(
        DeleteAlbumsEvent(_selectedAlbumIds.toList(growable: false)),
      );
      setState(() => _selectedAlbumIds.clear());
    }
  }

  void _toggleSelectAlbum(Album album, bool selected) {
    setState(() {
      if (selected) {
        _selectedAlbumIds.add(album.id);
      } else {
        _selectedAlbumIds.remove(album.id);
      }
    });
  }

  void _toggleSelectAllVisible(List<Album> albums, bool selected) {
    setState(() {
      if (selected) {
        _selectedAlbumIds.addAll(albums.map((e) => e.id));
      } else {
        _selectedAlbumIds.removeAll(albums.map((e) => e.id));
      }
    });
  }

  void _clearSelection() => setState(_selectedAlbumIds.clear);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Albums'),
        actions: [
          if (_selectedAlbumIds.isNotEmpty)
            IconButton(
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete selected (${_selectedAlbumIds.length})',
            ),
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.add_photo_alternate_outlined),
            tooltip: 'Create album',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final isMobile = c.maxWidth < 760;
                    return isMobile
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(
                                'Search & Filters',
                                style: theme.textTheme.titleSmall,
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _searchCtrl,
                                decoration: InputDecoration(
                                  hintText: 'Search by title',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onSubmitted: (v) => context.read<AdminAlbumsBloc>().add(
                                  LoadAlbums(
                                    page: 0,
                                    limit: _limit,
                                    search: v.isEmpty ? null : v.trim(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButton<int>(
                                      value: _limit,
                                      isExpanded: true,
                                      onChanged: (v) {
                                        if (v == null) return;
                                        setState(() => _limit = v);
                                        context.read<AdminAlbumsBloc>().add(
                                          LoadAlbums(
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
                                  ),
                                ],
                              ),
                            ],
                          )
                        : Row(
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
                                  onSubmitted: (v) => context.read<AdminAlbumsBloc>().add(
                                    LoadAlbums(
                                      page: 0,
                                      limit: _limit,
                                      search: v.isEmpty ? null : v.trim(),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 210,
                                child: DropdownButton<int>(
                                  value: _limit,
                                  isExpanded: true,
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _limit = v);
                                    context.read<AdminAlbumsBloc>().add(
                                      LoadAlbums(
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
                              ),
                            ],
                          );
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_selectedAlbumIds.isNotEmpty)
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
                          '${_selectedAlbumIds.length} selected',
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
              child: BlocBuilder<AdminAlbumsBloc, AdminAlbumsState>(
                builder: (context, state) {
                  if (state is AdminAlbumsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminAlbumsFailure) {
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
                            onPressed: () => context.read<AdminAlbumsBloc>().add(
                              LoadAlbums(
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
                  if (state is AdminAlbumsPageLoaded) {
                    final albums = state.items;
                    final visibleIds = albums.map((a) => a.id).toSet();
                    final stale = _selectedAlbumIds.difference(visibleIds);
                    if (stale.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _selectedAlbumIds.removeAll(stale));
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
                              if (isMobile) {
                                return ListView.separated(
                                  itemCount: albums.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final a = albums[i];
                                    final isSelected =
                                        _selectedAlbumIds.contains(a.id);
                                    return Card(
                                      child: ListTile(
                                        leading: Checkbox(
                                          value: isSelected,
                                          onChanged: (v) =>
                                              _toggleSelectAlbum(a, v ?? false),
                                        ),
                                        title: Text(a.title),
                                        subtitle: Text(a.description ?? ''),
                                        onTap: () => _openDetail(a),
                                        trailing: Wrap(
                                          spacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
                                            ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: a.coverUrl != null
                                                  ? Image.network(
                                                      a.coverUrl!,
                                                      width: 40,
                                                      height: 40,
                                                      fit: BoxFit.cover,
                                                    )
                                                  : Container(
                                                      width: 40,
                                                      height: 40,
                                                      color: Colors.black12,
                                                      child: const Icon(
                                                        Icons.album,
                                                        size: 20,
                                                      ),
                                                    ),
                                            ),
                                            if (a.isPublished)
                                              const Icon(
                                                Icons.public,
                                                size: 18,
                                                color: Colors.green,
                                              ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.info_outline,
                                              ),
                                              onPressed: () => _openDetail(a),
                                            ),
                                            IconButton(
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                              onPressed: () =>
                                                  _confirmDeleteOne(a),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                );
                              }

                              // wide: DataTable
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: [
                                    DataColumn(
                                      label: Checkbox(
                                        value: albums.isNotEmpty &&
                                            _selectedAlbumIds.containsAll(
                                              albums.map((e) => e.id),
                                            ),
                                        onChanged: (v) =>
                                            _toggleSelectAllVisible(
                                              albums,
                                              v ?? false,
                                            ),
                                      ),
                                    ),
                                    const DataColumn(label: Text('Cover')),
                                    const DataColumn(label: Text('Title')),
                                    const DataColumn(label: Text('Published')),
                                    const DataColumn(label: Text('Created')),
                                    const DataColumn(label: Text('Actions')),
                                  ],
                                  rows: albums.map((a) {
                                    final isSelected =
                                        _selectedAlbumIds.contains(a.id);
                                    return DataRow(
                                      cells: [
                                        DataCell(
                                          Checkbox(
                                            value: isSelected,
                                            onChanged: (v) =>
                                                _toggleSelectAlbum(
                                                  a,
                                                  v ?? false,
                                                ),
                                          ),
                                        ),
                                        DataCell(
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            child: a.coverUrl != null
                                                ? Image.network(
                                                    a.coverUrl!,
                                                    width: 40,
                                                    height: 40,
                                                    fit: BoxFit.cover,
                                                  )
                                                : Container(
                                                    width: 40,
                                                    height: 40,
                                                    color: Colors.black12,
                                                    child: const Icon(
                                                      Icons.album,
                                                      size: 20,
                                                    ),
                                                  ),
                                          ),
                                        ),
                                        DataCell(Text(a.title)),
                                        DataCell(
                                          Icon(
                                            a.isPublished
                                                ? Icons.check
                                                : Icons.close,
                                            size: 18,
                                            color: a.isPublished
                                                ? Colors.green
                                                : Colors.redAccent,
                                          ),
                                        ),
                                        DataCell(
                                          Text(
                                            a.createdAt
                                                    ?.toLocal()
                                                    .toString()
                                                    .split('.')
                                                    .first ??
                                                '—',
                                          ),
                                        ),
                                        DataCell(
                                          Row(
                                            children: [
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.info_outline,
                                                ),
                                                onPressed: () => _openDetail(a),
                                              ),
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.delete_outline,
                                                ),
                                                onPressed: () =>
                                                    _confirmDeleteOne(a),
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
                                              context.read<AdminAlbumsBloc>().add(
                                                LoadAlbums(
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
                                    onPressed: state.page < (totalPages - 1)
                                        ? () =>
                                              context.read<AdminAlbumsBloc>().add(
                                                LoadAlbums(
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
