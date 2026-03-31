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
  final TextEditingController _pageCtrl = TextEditingController();
  int _limit = 20;
  int _currentPage = 0;
  final Set<String> _selectedAlbumIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchTextChanged);
    context.read<AdminAlbumsBloc>().add(LoadAlbums(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    _pageCtrl.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  void _openCreateDialog() => context.push('/admin/albums/create-new');

  void _openDetail(Album a) => context.push('/admin/albums/${a.id}');

  void _loadPage(int page) {
    _currentPage = page;
    context.read<AdminAlbumsBloc>().add(
      LoadAlbums(
        page: page,
        limit: _limit,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      ),
    );
  }

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
    final isMobile = MediaQuery.of(context).size.width < 768;

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
            // Search & Filter Card
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
            const SizedBox(height: 16),

            // Selection Indicator
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

            // Album List
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
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () => _loadPage(_currentPage),
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

                    final totalPages =
                        (state.total / state.limit).ceil().clamp(1, 999999);

                    return Column(
                      children: [
                        Expanded(
                          child: isMobile
                              ? _buildMobileAlbumList(albums)
                              : _buildDesktopAlbumList(albums),
                        ),
                        const SizedBox(height: 16),
                        _buildPaginationFooter(
                          theme,
                          state,
                          totalPages,
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

  Widget _buildMobileSearchFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search Albums',
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
                    hintText: 'Search by album title',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _loadPage(0),
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
                    _loadPage(0);
                  },
                ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _loadPage(0);
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
                      hintText: 'Search by album title',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _loadPage(0),
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
                      _loadPage(0);
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
            _loadPage(0);
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

  Widget _buildMobileAlbumList(List<Album> albums) {
    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No albums found',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: albums.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final album = albums[i];
        final isSelected = _selectedAlbumIds.contains(album.id);

        return Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => _openDetail(album),
            onLongPress: () => _toggleSelectAlbum(album, !isSelected),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Selection indicator or Album Cover - Tap to select
                  GestureDetector(
                    onTap: () => _toggleSelectAlbum(album, !isSelected),
                    child: Stack(
                      alignment: Alignment.topRight,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: album.coverUrl != null
                              ? Image.network(
                                  album.coverUrl!,
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                )
                              : Container(
                                  width: 60,
                                  height: 60,
                                  color: Colors.grey[200],
                                  child: const Icon(Icons.album, size: 30),
                                ),
                        ),
                        if (isSelected)
                          Positioned(
                            top: -4,
                            right: -4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          album.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        if (album.description != null)
                          Text(
                            album.description!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Colors.grey[600],
                                ),
                          ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: album.isPublished
                                ? Colors.green.withOpacity(0.15)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                album.isPublished ? Icons.check_circle : Icons.schedule,
                                size: 14,
                                color:
                                    album.isPublished ? Colors.green[700] : Colors.orange[700],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                album.isPublished ? 'Published' : 'Draft',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: album.isPublished ? Colors.green[700] : Colors.orange[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMobileMenu(album),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showMobileMenu(Album album) {
    final isSelected = _selectedAlbumIds.contains(album.id);
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              album.title,
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              isSelected ? Icons.check_box : Icons.check_box_outline_blank,
            ),
            title: Text(isSelected ? 'Deselect' : 'Select'),
            onTap: () {
              Navigator.pop(ctx);
              _toggleSelectAlbum(album, !isSelected);
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(ctx);
              _openDetail(album);
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Icon(
              album.isPublished ? Icons.visibility_off : Icons.visibility,
            ),
            title: Text(
              album.isPublished ? 'Unpublish' : 'Publish',
            ),
            onTap: () {
              Navigator.pop(ctx);
              context.read<AdminAlbumsBloc>().add(
                UpdateAlbumEvent(
                  id: album.id,
                  isPublished: !album.isPublished,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _confirmDeleteOne(album);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopAlbumList(List<Album> albums) {
    final desktopWidth = MediaQuery.of(context).size.width;
    final useCompactActions = desktopWidth < 1200;

    if (albums.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.album, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No albums found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 64,
          dataRowMaxHeight: 64,
          columnSpacing: useCompactActions ? 20 : 28,
          columns: [
            DataColumn(
              label: Checkbox(
                value: albums.isNotEmpty &&
                    _selectedAlbumIds.containsAll(albums.map((e) => e.id)),
                onChanged: (v) => _toggleSelectAllVisible(albums, v ?? false),
              ),
            ),
            const DataColumn(label: Text('Cover')),
            const DataColumn(label: Text('Title')),
            const DataColumn(label: Text('Status')),
            const DataColumn(label: Text('Created')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: albums.map((a) {
            final isSelected = _selectedAlbumIds.contains(a.id);
            return DataRow(
              cells: [
                DataCell(
                  Checkbox(
                    value: isSelected,
                    onChanged: (v) => _toggleSelectAlbum(a, v ?? false),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: ClipOval(
                      child: a.coverUrl != null
                          ? Image.network(
                              a.coverUrl!,
                              fit: BoxFit.cover,
                            )
                          : Container(
                              color: Colors.grey[200],
                              child: const Icon(Icons.album, size: 22),
                            ),
                    ),
                  ),
                ),
                DataCell(Text(a.title)),
                DataCell(
                  Tooltip(
                    message: a.isPublished ? 'Published' : 'Draft',
                    child: Icon(
                      a.isPublished ? Icons.check_circle : Icons.schedule,
                      color: a.isPublished ? Colors.green : Colors.orange,
                      size: 20,
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    a.createdAt?.toLocal().toString().split('.').first ?? '—',
                  ),
                ),
                DataCell(
                  useCompactActions
                      ? PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (value) {
                            if (value == 'toggle') {
                              context.read<AdminAlbumsBloc>().add(
                                UpdateAlbumEvent(
                                  id: a.id,
                                  isPublished: !a.isPublished,
                                ),
                              );
                            } else if (value == 'details') {
                              _openDetail(a);
                            } else if (value == 'delete') {
                              _confirmDeleteOne(a);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              value: 'toggle',
                              child: Text(a.isPublished ? 'Unpublish' : 'Publish'),
                            ),
                            const PopupMenuItem<String>(
                              value: 'details',
                              child: Text('View Details'),
                            ),
                            const PopupMenuItem<String>(
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
                            Tooltip(
                              message: a.isPublished ? 'Unpublish' : 'Publish',
                              child: IconButton(
                                icon: Icon(
                                  a.isPublished ? Icons.visibility : Icons.visibility_off,
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () {
                                  context.read<AdminAlbumsBloc>().add(
                                    UpdateAlbumEvent(
                                      id: a.id,
                                      isPublished: !a.isPublished,
                                    ),
                                  );
                                },
                              ),
                            ),
                            Tooltip(
                              message: 'View Details',
                              child: IconButton(
                                icon: const Icon(Icons.info_outline),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openDetail(a),
                              ),
                            ),
                            Tooltip(
                              message: 'Delete',
                              child: IconButton(
                                icon: const Icon(Icons.delete_outline),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _confirmDeleteOne(a),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPaginationFooter(
    ThemeData theme,
    AdminAlbumsPageLoaded state,
    int totalPages,
  ) {
    final isMobile = MediaQuery.of(context).size.width < 768;
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: isMobile ? _buildMobilePaginationCompact(theme, state, totalPages) 
                      : _buildDesktopPaginationCompact(theme, state, totalPages),
    );
  }

  Widget _buildMobilePaginationCompact(
    ThemeData theme,
    AdminAlbumsPageLoaded state,
    int totalPages,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Total + Previous
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${state.total}',
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
                onPressed: state.page > 0 ? () => _loadPage(state.page - 1) : null,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.chevron_left, size: 18),
              ),
            ),
          ],
        ),
        // Center: Page info
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${state.page + 1}/$totalPages',
            style: theme.textTheme.labelSmall,
          ),
        ),
        // Right: Next + Items per page
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 36,
              width: 36,
              child: FilledButton.tonal(
                onPressed: state.page < (totalPages - 1) ? () => _loadPage(state.page + 1) : null,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.chevron_right, size: 18),
              ),
            ),
            PopupMenuButton<int>(
              initialValue: _limit,
              onSelected: (v) {
                setState(() => _limit = v);
                _loadPage(0);
              },
              itemBuilder: (context) => [10, 20, 50, 100]
                  .map((e) => PopupMenuItem(
                    value: e,
                    child: Text(e.toString()),
                  ))
                  .toList(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.colorScheme.outline),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 2,
                  children: [
                    Text(
                      _limit.toString(),
                      style: theme.textTheme.labelSmall,
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDesktopPaginationCompact(
    ThemeData theme,
    AdminAlbumsPageLoaded state,
    int totalPages,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Total + Previous
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${state.total}',
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
                onPressed: state.page > 0 ? () => _loadPage(state.page - 1) : null,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.chevron_left, size: 18),
              ),
            ),
          ],
        ),
        // Center: Page info
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
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
          ],
        ),
        // Right: Next + Items per page
        Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 8,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              height: 36,
              width: 36,
              child: FilledButton.tonal(
                onPressed: state.page < (totalPages - 1) ? () => _loadPage(state.page + 1) : null,
                style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                child: const Icon(Icons.chevron_right, size: 18),
              ),
            ),
            PopupMenuButton<int>(
              initialValue: _limit,
              onSelected: (v) {
                setState(() => _limit = v);
                _loadPage(0);
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
                    Text(
                      _limit.toString(),
                      style: theme.textTheme.labelSmall,
                    ),
                    Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

}
