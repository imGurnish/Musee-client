import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
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
  Artist? _selectedArtist;

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

  void _openCreateDialog() {
    context.push('/admin/artists/create-new');
  }

  // Note: Editing is handled on the detail page now. No inline edit dialog here.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Artists'),
        actions: [
          IconButton(
            onPressed: _openCreateDialog,
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Create artist',
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
                      hintText: 'Search by name',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onSubmitted: (v) => context.read<AdminArtistsBloc>().add(
                      LoadArtists(
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
              child: BlocBuilder<AdminArtistsBloc, AdminArtistsState>(
                builder: (context, state) {
                  if (state is AdminArtistsLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is AdminArtistsFailure) {
                    return Center(
                      child: Text(
                        state.message,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.error,
                        ),
                      ),
                    );
                  }
                  if (state is AdminArtistsPageLoaded) {
                    final artists = state.items;
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
                                  itemCount: artists.length,
                                  separatorBuilder: (context, index) =>
                                      const SizedBox(height: 8),
                                  itemBuilder: (context, i) {
                                    final a = artists[i];
                                    return Card(
                                      child: ListTile(
                                        leading: CircleAvatar(
                                          radius: 22,
                                          backgroundImage: a.avatarUrl != null
                                              ? NetworkImage(a.avatarUrl!)
                                              : null,
                                          child: a.avatarUrl == null
                                              ? Text(
                                                  a.name.isNotEmpty
                                                      ? a.name[0].toUpperCase()
                                                      : '?',
                                                )
                                              : null,
                                        ),
                                        title: Text(a.name),
                                        selected: _selectedArtist?.id == a.id,
                                        onTap: () => context.push(
                                          '/admin/artists/${a.id}',
                                        ),
                                        trailing: Wrap(
                                          spacing: 4,
                                          children: [
                                            IconButton(
                                              icon: const Icon(
                                                Icons.info_outline,
                                              ),
                                              onPressed: () => context.push(
                                                '/admin/artists/${a.id}',
                                              ),
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
                                                      'Delete artist?',
                                                    ),
                                                    content: Text(
                                                      'Are you sure you want to delete ${a.name}?',
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
                                                      .read<AdminArtistsBloc>()
                                                      .add(
                                                        DeleteArtistEvent(a.id),
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
                                    DataColumn(label: Text('Avatar')),
                                    DataColumn(label: Text('Name')),
                                    DataColumn(label: Text('Created')),
                                    DataColumn(label: Text('Actions')),
                                  ],
                                  rows: artists.map((a) {
                                    return DataRow(
                                      selected: _selectedArtist?.id == a.id,
                                      onSelectChanged: (_) => context.push(
                                        '/admin/artists/${a.id}',
                                      ),
                                      cells: [
                                        DataCell(
                                          CircleAvatar(
                                            radius: 16,
                                            backgroundImage: a.avatarUrl != null
                                                ? NetworkImage(a.avatarUrl!)
                                                : null,
                                            child: a.avatarUrl == null
                                                ? Text(
                                                    a.name.isNotEmpty
                                                        ? a.name[0]
                                                              .toUpperCase()
                                                        : '?',
                                                  )
                                                : null,
                                          ),
                                        ),
                                        DataCell(Text(a.name)),
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
                                                onPressed: () => context.push(
                                                  '/admin/artists/${a.id}',
                                                ),
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
                                                            'Delete artist?',
                                                          ),
                                                          content: Text(
                                                            'Are you sure you want to delete ${a.name}?',
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
                                                        .read<
                                                          AdminArtistsBloc
                                                        >()
                                                        .add(
                                                          DeleteArtistEvent(
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
                        if (_selectedArtist != null) ...[
                          const SizedBox(height: 12),
                          _ArtistDetails(artist: _selectedArtist!),
                        ],
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Total: ${state.total}'),
                            Row(
                              children: [
                                IconButton(
                                  onPressed: state.page > 0
                                      ? () => context
                                            .read<AdminArtistsBloc>()
                                            .add(
                                              LoadArtists(
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
                                      ? () => context
                                            .read<AdminArtistsBloc>()
                                            .add(
                                              LoadArtists(
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

class _ArtistDetails extends StatelessWidget {
  final Artist artist;
  const _ArtistDetails({required this.artist});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: artist.avatarUrl != null
                      ? NetworkImage(artist.avatarUrl!)
                      : null,
                  child: artist.avatarUrl == null
                      ? const Icon(Icons.person)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Created: '
                        '${artist.createdAt?.toLocal().toString().split('.').first ?? '—'}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (artist.coverUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  artist.coverUrl!,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            if (artist.coverUrl != null) const SizedBox(height: 12),
            Text('Bio', style: theme.textTheme.titleSmall),
            const SizedBox(height: 6),
            SelectableText(
              artist.bio.isNotEmpty ? artist.bio : '—',
              style: theme.textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateArtistDialog extends StatefulWidget {
  const _CreateArtistDialog();

  @override
  State<_CreateArtistDialog> createState() => _CreateArtistDialogState();
}

class _CreateArtistDialogState extends State<_CreateArtistDialog> {
  final _formKey = GlobalKey<FormState>();
  bool _linkExisting = true;
  final _artistIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _regionIdCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  List<int>? _avatarBytes;
  String? _avatarFilename;
  List<int>? _coverBytes;
  String? _coverFilename;

  @override
  void dispose() {
    _artistIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _regionIdCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
      setState(() {
        _avatarBytes = res.files.first.bytes;
        _avatarFilename = res.files.first.name;
      });
    }
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
      setState(() {
        _coverBytes = res.files.first.bytes;
        _coverFilename = res.files.first.name;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    final bloc = context.read<AdminArtistsBloc>();
    bloc.add(
      CreateArtistEvent(
        artistId: _linkExisting ? _artistIdCtrl.text.trim() : null,
        name: !_linkExisting ? _nameCtrl.text.trim() : null,
        email: !_linkExisting ? _emailCtrl.text.trim() : null,
        password: !_linkExisting ? _passwordCtrl.text : null,
        regionId: !_linkExisting ? _regionIdCtrl.text.trim() : null,
        bio: _bioCtrl.text.trim(),
        coverBytes: _coverBytes,
        coverFilename: _coverFilename,
        avatarBytes: _avatarBytes,
        avatarFilename: _avatarFilename,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create artist',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Switch(
                      value: _linkExisting,
                      onChanged: (v) => setState(() => _linkExisting = v),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _linkExisting
                          ? 'Link existing user by ID'
                          : 'Create new user for artist',
                    ),
                  ],
                ),
                if (_linkExisting) ...[
                  TextFormField(
                    controller: _artistIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Artist User ID (uuid)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Required (user id)'
                        : null,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(labelText: 'User name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'User email'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'User password (optional)',
                    ),
                    obscureText: true,
                    // Password is optional when creating a new artist user
                    validator: (v) => null,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _regionIdCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Region ID (required)',
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Region ID is required'
                        : null,
                  ),
                ],
                const SizedBox(height: 8),
                TextFormField(
                  controller: _bioCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Bio (required)',
                  ),
                  maxLines: 3,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Bio is required'
                      : null,
                ),
                const SizedBox(height: 12),
                // Cover picker
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: Colors.black12,
                        borderRadius: BorderRadius.circular(8),
                        image: _coverBytes != null
                            ? DecorationImage(
                                image: MemoryImage(
                                  Uint8List.fromList(_coverBytes!),
                                ),
                                fit: BoxFit.cover,
                              )
                            : null,
                      ),
                      child: _coverBytes == null
                          ? const Icon(Icons.image)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _coverFilename ?? 'No cover selected',
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickCover,
                                icon: const Icon(Icons.image),
                                label: const Text('Select cover'),
                              ),
                              if (_coverBytes != null)
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _coverBytes = null;
                                    _coverFilename = null;
                                  }),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Avatar picker (for linked user on create)
                Row(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: _avatarBytes != null
                          ? MemoryImage(Uint8List.fromList(_avatarBytes!))
                          : null,
                      child: _avatarBytes == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _avatarFilename ?? 'No avatar selected',
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 8,
                            children: [
                              OutlinedButton.icon(
                                onPressed: _pickAvatar,
                                icon: const Icon(Icons.person),
                                label: const Text('Select avatar'),
                              ),
                              if (_avatarBytes != null)
                                TextButton.icon(
                                  onPressed: () => setState(() {
                                    _avatarBytes = null;
                                    _avatarFilename = null;
                                  }),
                                  icon: const Icon(Icons.clear),
                                  label: const Text('Clear'),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _submit,
                      child: const Text('Create'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EditArtistDialog extends StatefulWidget {
  final Artist artist;
  const _EditArtistDialog({required this.artist});

  @override
  State<_EditArtistDialog> createState() => _EditArtistDialogState();
}

class _EditArtistDialogState extends State<_EditArtistDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _bioCtrl;
  List<int>? _coverBytes;
  String? _coverFilename;

  @override
  void initState() {
    super.initState();
    _bioCtrl = TextEditingController(text: widget.artist.bio);
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
      setState(() {
        _coverBytes = res.files.first.bytes;
        _coverFilename = res.files.first.name;
      });
    }
  }

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;
    context.read<AdminArtistsBloc>().add(
      UpdateArtistEvent(
        id: widget.artist.id,
        bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
        coverBytes: _coverBytes,
        coverFilename: _coverFilename,
      ),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Edit artist',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioCtrl,
                decoration: const InputDecoration(labelText: 'Bio'),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.black12,
                      borderRadius: BorderRadius.circular(8),
                      image: _coverBytes != null
                          ? DecorationImage(
                              image: MemoryImage(
                                Uint8List.fromList(_coverBytes!),
                              ),
                              fit: BoxFit.cover,
                            )
                          : (widget.artist.coverUrl != null
                                ? DecorationImage(
                                    image: NetworkImage(
                                      widget.artist.coverUrl!,
                                    ),
                                    fit: BoxFit.cover,
                                  )
                                : null),
                    ),
                    child:
                        (_coverBytes == null && widget.artist.coverUrl == null)
                        ? const Icon(Icons.image)
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _coverFilename ?? 'No cover selected',
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _pickCover,
                              icon: const Icon(Icons.image),
                              label: const Text('Select cover'),
                            ),
                            if (_coverBytes != null)
                              TextButton.icon(
                                onPressed: () => setState(() {
                                  _coverBytes = null;
                                  _coverFilename = null;
                                }),
                                icon: const Icon(Icons.clear),
                                label: const Text('Clear'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _submit, child: const Text('Save')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
