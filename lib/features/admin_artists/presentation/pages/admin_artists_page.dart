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
    context.read<AdminArtistsBloc>().add(LoadArtists(page: 0, limit: _limit));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  void _clearSelection() => setState(_selectedArtistIds.clear);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                                  hintText: 'Search by name',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                onSubmitted: (v) =>
                                    context.read<AdminArtistsBloc>().add(
                                          LoadArtists(
                                            page: 0,
                                            limit: _limit,
                                            search: v.trim().isEmpty
                                                ? null
                                                : v.trim(),
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<int>(
                                initialValue: _limit,
                                isDense: true,
                                decoration: const InputDecoration(
                                  labelText: 'Page size',
                                  prefixIcon: Icon(Icons.tune),
                                ),
                                onChanged: (v) {
                                  if (v == null) return;
                                  setState(() => _limit = v);
                                  context.read<AdminArtistsBloc>().add(
                                    LoadArtists(
                                      page: 0,
                                      limit: v,
                                      search: _searchCtrl.text.trim().isEmpty
                                          ? null
                                          : _searchCtrl.text.trim(),
                                    ),
                                  );
                                },
                                items: const [10, 20, 50, 100]
                                    .map((e) =>
                                        DropdownMenuItem(
                                          value: e,
                                          child: Text('$e / page'),
                                        ))
                                    .toList(),
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Search by name',
                                    prefixIcon: const Icon(Icons.search),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  onSubmitted: (v) =>
                                      context.read<AdminArtistsBloc>().add(
                                            LoadArtists(
                                              page: 0,
                                              limit: _limit,
                                              search: v.trim().isEmpty
                                                  ? null
                                                  : v.trim(),
                                            ),
                                          ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              SizedBox(
                                width: 210,
                                child: DropdownButtonFormField<int>(
                                  initialValue: _limit,
                                  isDense: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Page size',
                                    prefixIcon: Icon(Icons.tune),
                                  ),
                                  onChanged: (v) {
                                    if (v == null) return;
                                    setState(() => _limit = v);
                                    context.read<AdminArtistsBloc>().add(
                                      LoadArtists(
                                        page: 0,
                                        limit: v,
                                        search: _searchCtrl.text.trim().isEmpty
                                            ? null
                                            : _searchCtrl.text.trim(),
                                      ),
                                    );
                                  },
                                  items: const [10, 20, 50, 100]
                                      .map((e) =>
                                          DropdownMenuItem(
                                            value: e,
                                            child: Text('$e / page'),
                                          ))
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
                            onPressed: () =>
                                context.read<AdminArtistsBloc>().add(
                                      LoadArtists(
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
                    final totalPages =
                        (state.total / state.limit).ceil().clamp(1, 999999);
                    return LayoutBuilder(
                      builder: (context, c) {
                        return Column(
                          children: [
                            Expanded(
                              child: Card(
                                elevation: 0,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: ListView.separated(
                                    itemCount: artists.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(height: 8),
                                    itemBuilder: (context, i) {
                                      final a = artists[i];
                                      final selected =
                                          _selectedArtistIds.contains(a.id);
                                      return _ArtistCard(
                                        artist: a,
                                        selected: selected,
                                        onSelect: (sel) =>
                                            _toggleSelectArtist(a, sel),
                                        onEdit: () => _goDetail(a),
                                        onDelete: () =>
                                            _confirmDeleteOne(a),
                                      );
                                    },
                                  ),
                                ),
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
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon:
                                            const Icon(Icons.chevron_left),
                                        onPressed: state.page > 0
                                            ? () =>
                                                context
                                                    .read<
                                                        AdminArtistsBloc>()
                                                    .add(
                                                      LoadArtists(
                                                        page: state.page - 1,
                                                        limit: state.limit,
                                                        search: state.search,
                                                      ),
                                                    )
                                            : null,
                                      ),
                                      Text(
                                        'Page ${state.page + 1} / $totalPages',
                                        style: theme.textTheme.bodySmall,
                                      ),
                                      IconButton(
                                        icon:
                                            const Icon(Icons.chevron_right),
                                        onPressed: state.page < (totalPages - 1)
                                            ? () =>
                                                context
                                                    .read<
                                                        AdminArtistsBloc>()
                                                    .add(
                                                      LoadArtists(
                                                        page: state.page + 1,
                                                        limit: state.limit,
                                                        search: state.search,
                                                      ),
                                                    )
                                            : null,
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
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
  final ValueChanged<bool> onSelect;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ArtistCard({
    required this.artist,
    required this.selected,
    required this.onSelect,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: artist.avatarUrl != null
                      ? NetworkImage(artist.avatarUrl!)
                      : null,
                  child: artist.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        artist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall,
                      ),
                      if (artist.bio.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            artist.bio,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        children: [
                          if (artist.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primaryContainer,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                'Verified',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                          if (artist.genres.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    theme.colorScheme.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                artist.genres.take(1).join(', '),
                                style: theme.textTheme.labelSmall,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (v) => onSelect(v ?? false),
                ),
                Text(selected ? 'Selected' : 'Select'),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  onPressed: onEdit,
                ),
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Delete'),
                  onPressed: onDelete,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
