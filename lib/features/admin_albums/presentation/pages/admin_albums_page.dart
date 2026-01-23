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

  void _openCreateDialog() {
    context.push('/admin/albums/create-new');
  }

  void _openDetail(Album a) {
    context.push('/admin/albums/${a.id}');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Albums'),
        actions: [
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
                    onSubmitted: (v) => context.read<AdminAlbumsBloc>().add(
                      LoadAlbums(
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
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: BlocBuilder<AdminAlbumsBloc, AdminAlbumsState>(
                builder: (context, state) {
                  if (state is AdminAlbumsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminAlbumsFailure) {
                    return Center(
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (state is AdminAlbumsPageLoaded) {
                    final albums = state.items;
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
                                    return Card(
                                      child: ListTile(
                                        leading: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          child: a.coverUrl != null
                                              ? Image.network(
                                                  a.coverUrl!,
                                                  width: 44,
                                                  height: 44,
                                                  fit: BoxFit.cover,
                                                )
                                              : Container(
                                                  width: 44,
                                                  height: 44,
                                                  color: Colors.black12,
                                                  child: const Icon(
                                                    Icons.album,
                                                  ),
                                                ),
                                        ),
                                        title: Text(a.title),
                                        subtitle: Text(a.description ?? ''),
                                        onTap: () => _openDetail(a),
                                        trailing: Wrap(
                                          spacing: 4,
                                          crossAxisAlignment:
                                              WrapCrossAlignment.center,
                                          children: [
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
                                              onPressed: () async {
                                                final confirm = await showDialog<bool>(
                                                  context: context,
                                                  builder: (ctx) => AlertDialog(
                                                    title: const Text(
                                                      'Delete album?',
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete "${a.title}"?',
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
                                                      .read<AdminAlbumsBloc>()
                                                      .add(
                                                        DeleteAlbumEvent(a.id),
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

                              // wide: DataTable
                              return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Cover')),
                                    DataColumn(label: Text('Title')),
                                    DataColumn(label: Text('Published')),
                                    DataColumn(label: Text('Created')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: albums.map((a) {
                                    return DataRow(
                                      cells: [
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
                                                onPressed: () async {
                                                  final confirm =
                                                      await showDialog<bool>(
                                                        context: context,
                                                        builder: (ctx) => AlertDialog(
                                                          title: const Text(
                                                            'Delete album?',
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to delete "${a.title}"?',
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
                                                        .read<AdminAlbumsBloc>()
                                                        .add(
                                                          DeleteAlbumEvent(
                                                            a.id,
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
                                Text('Page ${state.page + 1} of $totalPages'),
                                IconButton(
                                  onPressed: state.page < totalPages - 1
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
