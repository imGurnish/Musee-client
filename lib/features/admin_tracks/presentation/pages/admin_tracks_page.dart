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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Tracks'),
        actions: [
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
            Expanded(
              child: BlocBuilder<AdminTracksBloc, AdminTracksState>(
                builder: (context, state) {
                  if (state is AdminTracksLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminTracksFailure) {
                    return Center(
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (state is AdminTracksPageLoaded) {
                    final List<Track> items = state.items;
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
                                    final artists = t.artists.isNotEmpty
                                        ? t.artists
                                              .map((a) => a.name)
                                              .join(', ')
                                        : '—';
                                    return Card(
                                      child: ListTile(
                                        leading: const Icon(Icons.music_note),
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
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Delete track?',
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete "${t.title}"? This cannot be undone.',
                                                    ),
                                                    actions: [
                                                      TextButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              false,
                                                            ),
                                                        child: const Text(
                                                          'Cancel',
                                                        ),
                                                      ),
                                                      FilledButton(
                                                        onPressed: () =>
                                                            Navigator.pop(
                                                              ctx,
                                                              true,
                                                            ),
                                                        child: const Text(
                                                          'Delete',
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                );
                                                if (confirm == true &&
                                                    context.mounted) {
                                                  context
                                                      .read<AdminTracksBloc>()
                                                      .add(
                                                        DeleteTrackEvent(
                                                          t.trackId,
                                                        ),
                                                      );
                                                }
                                              },
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
                                  columns: const [
                                    DataColumn(label: Text('Title')),
                                    DataColumn(label: Text('Artists')),
                                    DataColumn(label: Text('Published')),
                                    DataColumn(label: Text('Created')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: items.map((t) {
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
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          title: const Text(
                                                            'Delete track?',
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to delete "${t.title}"? This cannot be undone.',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    false,
                                                                  ),
                                                              child: const Text(
                                                                'Cancel',
                                                              ),
                                                            ),
                                                            FilledButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    true,
                                                                  ),
                                                              child: const Text(
                                                                'Delete',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );
                                                  if (confirm == true &&
                                                      context.mounted) {
                                                    context
                                                        .read<AdminTracksBloc>()
                                                        .add(
                                                          DeleteTrackEvent(
                                                            t.trackId,
                                                          ),
                                                        );
                                                  }
                                                },
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ${state.total}'),
                            Row(
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
                                Text('Page ${state.page + 1} of $totalPages'),
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
