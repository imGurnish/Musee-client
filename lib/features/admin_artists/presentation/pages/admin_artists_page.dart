import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/admin_artists/presentation/bloc/admin_artists_bloc.dart';
import 'package:musee/features/admin_artists/domain/entities/artist.dart';

class AdminArtistsPage extends StatefulWidget {
  const AdminArtistsPage({super.key});

  @override
  State<AdminArtistsPage> createState() => _AdminArtistsPageState();
}

class _AdminArtistsPageState extends State<AdminArtistsPage> {
  final TextEditingController _searchCtrl = TextEditingController();
  int _limit = 20;
  final Set<String> _selectedArtistIds = <String>{};

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchTextChanged);
    context.read<AdminArtistsBloc>().add(LoadArtists(page: 0, limit: _limit));
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

  void _searchArtists({int page = 0, int? limit}) {
    final currentLimit = limit ?? _limit;
    context.read<AdminArtistsBloc>().add(
      LoadArtists(
        page: page,
        limit: currentLimit,
        search: _searchCtrl.text.trim().isEmpty ? null : _searchCtrl.text.trim(),
      ),
    );
  }

  void _goCreatePage() => context.push('/admin/artists/create-new');

  void _goDetail(Artist artist) => context.push('/admin/artists/${artist.id}');

  Future<void> _confirmDeleteOne(Artist artist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete artist?'),
        content: Text(
          'Are you sure you want to delete ${artist.name}? This cannot be undone.',
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
      context.read<AdminArtistsBloc>().add(DeleteArtistEvent(artist.id));
      setState(() => _selectedArtistIds.remove(artist.id));
    }
  }

  Future<void> _confirmDeleteSelected() async {
    final count = _selectedArtistIds.length;
    if (count == 0) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete selected artists?'),
        content:
            Text('Delete $count selected artist(s)? This cannot be undone.'),
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
      context.read<AdminArtistsBloc>().add(
        DeleteArtistsEvent(_selectedArtistIds.toList(growable: false)),
      );
      setState(() => _selectedArtistIds.clear());
    }
  }

  void _toggleSelectArtist(Artist artist, bool selected) {
    setState(() {
      if (selected) {
        _selectedArtistIds.add(artist.id);
      } else {
        _selectedArtistIds.remove(artist.id);
      }
    });
  }

  void _toggleSelectAllVisible(List<Artist> artists, bool selected) {
    setState(() {
      if (selected) {
        _selectedArtistIds.addAll(artists.map((e) => e.id));
      } else {
        _selectedArtistIds.removeAll(artists.map((e) => e.id));
      }
    });
  }

  void _clearSelection() => setState(_selectedArtistIds.clear);

  Widget _buildMobileSearchFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search Artists',
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
                    hintText: 'Search by artist name',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _searchArtists(),
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
                    _searchArtists();
                  },
                ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _searchArtists();
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
                      hintText: 'Search by artist name',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _searchArtists(),
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
                      _searchArtists();
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
            _searchArtists();
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

  Widget _buildDesktopArtistsTable(List<Artist> artists) {
    final desktopWidth = MediaQuery.of(context).size.width;
    final useCompactActions = desktopWidth < 1400;

    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          dataRowMinHeight: 62,
          dataRowMaxHeight: 62,
          columnSpacing: useCompactActions ? 16 : 22,
          columns: [
            DataColumn(
              label: Checkbox(
                value: artists.isNotEmpty &&
                    _selectedArtistIds.containsAll(artists.map((e) => e.id)),
                onChanged: (v) => _toggleSelectAllVisible(artists, v ?? false),
              ),
            ),
            const DataColumn(label: Text('Avatar')),
            const DataColumn(label: Text('Name')),
            const DataColumn(label: Text('Email')),
            const DataColumn(label: Text('Verified')),
            const DataColumn(label: Text('Genres')),
            const DataColumn(label: Text('Listeners')),
            const DataColumn(label: Text('Created')),
            const DataColumn(label: Text('Actions')),
          ],
          rows: artists.map((a) {
            final selected = _selectedArtistIds.contains(a.id);
            return DataRow(
              cells: [
                DataCell(
                  Checkbox(
                    value: selected,
                    onChanged: (v) => _toggleSelectArtist(a, v ?? false),
                  ),
                ),
                DataCell(
                  CircleAvatar(
                    radius: 16,
                    backgroundImage:
                        a.avatarUrl != null ? NetworkImage(a.avatarUrl!) : null,
                    child: a.avatarUrl == null ? const Icon(Icons.person, size: 16) : null,
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 170,
                    child: Text(
                      a.name.isEmpty ? '—' : a.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 230,
                    child: Text(
                      (a.userEmail != null && a.userEmail!.isNotEmpty)
                          ? a.userEmail!
                          : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(
                  Icon(
                    a.isVerified ? Icons.verified : Icons.radio_button_unchecked,
                    size: 18,
                    color: a.isVerified ? Colors.green : Colors.grey,
                  ),
                ),
                DataCell(
                  SizedBox(
                    width: 180,
                    child: Text(
                      a.genres.isNotEmpty ? a.genres.take(2).join(', ') : '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                DataCell(Text(a.monthlyListeners.toString())),
                DataCell(
                  Text(a.createdAt?.toLocal().toString().split('.').first ?? '—'),
                ),
                DataCell(
                  useCompactActions
                      ? PopupMenuButton<String>(
                          tooltip: 'Actions',
                          onSelected: (value) {
                            if (value == 'details') {
                              _goDetail(a);
                            } else if (value == 'delete') {
                              _confirmDeleteOne(a);
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
                              onPressed: () => _goDetail(a),
                            ),
                            IconButton(
                              tooltip: 'Delete',
                              icon: const Icon(Icons.delete_outline),
                              visualDensity: VisualDensity.compact,
                              onPressed: () => _confirmDeleteOne(a),
                            ),
                          ],
                        ),
                ),
              ],
            );
          }).toList(),
          showCheckboxColumn: false,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 1280;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Artists'),
        actions: [
          if (_selectedArtistIds.isNotEmpty)
            IconButton(
              onPressed: _confirmDeleteSelected,
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Delete selected (${_selectedArtistIds.length})',
            ),
          IconButton(
            onPressed: _goCreatePage,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Create artist',
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
            if (_selectedArtistIds.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                          '${_selectedArtistIds.length} selected',
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
              child: BlocBuilder<AdminArtistsBloc, AdminArtistsState>(
                builder: (context, state) {
                  if (state is AdminArtistsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminArtistsFailure) {
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
                            onPressed: () => _searchArtists(),
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    );
                  }
                  if (state is AdminArtistsPageLoaded) {
                    final artists = state.items;
                    final visibleIds = artists.map((a) => a.id).toSet();
                    final stale = _selectedArtistIds.difference(visibleIds);
                    if (stale.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (!mounted) return;
                        setState(() => _selectedArtistIds.removeAll(stale));
                      });
                    }
                    final totalPages = (state.total / state.limit).ceil().clamp(1, 999999);
                    return Column(
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, c) {
                              final isLargeScreen = c.maxWidth >= 1280;
                              final useRichListTile = c.maxWidth >= 900;
                              if (isLargeScreen) {
                                return _buildDesktopArtistsTable(artists);
                              }
                              return Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListView.separated(
                                    itemCount: artists.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                                    itemBuilder: (context, i) {
                                      final a = artists[i];
                                      final selected = _selectedArtistIds.contains(a.id);
                                      return _ArtistCard(
                                        artist: a,
                                        selected: selected,
                                        hasSelection: _selectedArtistIds.isNotEmpty,
                                        isLargeScreen: useRichListTile,
                                        onSelect: (sel) => _toggleSelectArtist(a, sel),
                                        onEdit: () => _goDetail(a),
                                        onDelete: () => _confirmDeleteOne(a),
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 36,
                                    width: 36,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                                      onPressed: state.page > 0
                                          ? () => _searchArtists(page: state.page - 1, limit: state.limit)
                                          : null,
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
                                children: [
                                  SizedBox(
                                    height: 36,
                                    width: 36,
                                    child: FilledButton.tonal(
                                      style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                                      onPressed: state.page < (totalPages - 1)
                                          ? () => _searchArtists(page: state.page + 1, limit: state.limit)
                                          : null,
                                      child: const Icon(Icons.chevron_right, size: 18),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  PopupMenuButton<int>(
                                    initialValue: _limit,
                                    onSelected: (v) {
                                      setState(() => _limit = v);
                                      _searchArtists(limit: v);
                                    },
                                    itemBuilder: (context) => [10, 20, 50, 100]
                                        .map((e) => PopupMenuItem(value: e, child: Text(e.toString())))
                                        .toList(),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: theme.colorScheme.outline),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
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

class _ArtistCard extends StatelessWidget {
  final Artist artist;
  final bool selected;
  final bool hasSelection;
  final bool isLargeScreen;
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArtistCard({
    required this.artist,
    required this.selected,
    required this.hasSelection,
    required this.isLargeScreen,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compactEmail = (artist.userEmail != null && artist.userEmail!.isNotEmpty)
      ? (artist.userEmail!.length > 24
        ? '${artist.userEmail!.substring(0, 24)}...'
        : artist.userEmail!)
      : 'No email';
    final createdText = artist.createdAt?.toLocal().toString().split('.').first ?? '—';
    final accentColor = selected
        ? theme.colorScheme.primary
        : theme.colorScheme.outlineVariant;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        if (hasSelection) {
          onSelect(!selected);
        } else {
          onEdit();
        }
      },
      onLongPress: () => onSelect(!selected),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: accentColor.withOpacity(selected ? 0.45 : 0.30)),
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLowest,
            ],
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: accentColor.withOpacity(0.7)),
                  ),
                  child: CircleAvatar(
                    radius: isLargeScreen ? 26 : 24,
                    backgroundImage: artist.avatarUrl != null
                        ? NetworkImage(artist.avatarUrl!)
                        : null,
                    child: artist.avatarUrl == null
                        ? const Icon(Icons.person)
                        : null,
                  ),
                ),
                if (selected)
                  Positioned(
                    top: -3,
                    right: -3,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          iconSize: 18,
                          icon: const Icon(Icons.more_vert),
                          tooltip: 'Actions',
                          onPressed: () => _showMobileMenu(context),
                        ),
                      ),
                    ],
                  ),
                  if (artist.bio.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        artist.bio,
                        maxLines: isLargeScreen ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (artist.isVerified)
                        _ArtistTag(
                          icon: Icons.verified_outlined,
                          label: 'Verified',
                          backgroundColor:
                              theme.colorScheme.primaryContainer,
                          foregroundColor:
                              theme.colorScheme.onPrimaryContainer,
                        ),
                      if (artist.genres.isNotEmpty)
                        _ArtistTag(
                          icon: Icons.music_note_outlined,
                          label: artist.genres.take(isLargeScreen ? 2 : 1).join(', '),
                        ),
                    ],
                  ),
                  if (isLargeScreen) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _ArtistTag(
                          icon: Icons.alternate_email,
                          label: compactEmail,
                        ),
                        _ArtistTag(
                          icon: Icons.graphic_eq,
                          label: '${artist.monthlyListeners} listeners',
                        ),
                        _ArtistTag(
                          icon: Icons.calendar_today_outlined,
                          label: createdText,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMobileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              artist.name,
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
              onSelect(!selected);
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              onEdit();
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              onDelete();
            },
          ),
        ],
      ),
    );
  }
}

class _ArtistTag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const _ArtistTag({
    required this.label,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 12,
              color: foregroundColor ?? theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: foregroundColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
