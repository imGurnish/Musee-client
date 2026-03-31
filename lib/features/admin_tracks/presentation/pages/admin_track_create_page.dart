import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/features/admin_albums/domain/usecases/list_albums.dart';
import 'package:musee/features/admin_artists/domain/usecases/list_artists.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:musee/features/admin_tracks/domain/usecases/create_track.dart';
import 'package:musee/init_dependencies.dart';

class AdminTrackCreatePage extends StatefulWidget {
  const AdminTrackCreatePage({super.key});

  @override
  State<AdminTrackCreatePage> createState() => _AdminTrackCreatePageState();
}

class _AdminTrackCreatePageState extends State<AdminTrackCreatePage> {
  final _formKey = GlobalKey<FormState>();

  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _lyricsCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();

  String? _albumId;
  bool _isExplicit = false;
  bool _isPublished = false;

  PlatformFile? _audioFile;
  PlatformFile? _videoFile;
  bool _submitting = false;

  // Additional artists to link at creation
  final List<_ArtistLink> _artists = [];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _lyricsCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAlbum() async {
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Pick album',
        fetchPage: (page, limit, query) async {
          final listAlbums = serviceLocator<ListAlbums>();
          final res = await listAlbums(
            ListAlbumsParams(page: page, limit: limit, q: query),
          );
          return res.fold((_) => UuidPageResult(items: const [], total: 0), (
            tuple,
          ) {
            final items = tuple.$1
                .map(
                  (a) => UuidItem(
                    id: a.id,
                    label:
                        '${a.title.isNotEmpty ? a.title : 'Album'} • ${a.id}',
                  ),
                )
                .toList();
            return UuidPageResult(items: items, total: tuple.$2);
          });
        },
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(() {
        _albumId = picked.id;
        _albumCtrl.text = picked.label;
      });
    }
  }

  Future<void> _pickAudio() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['mp3', 'ogg', 'wav', 'm4a'],
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _audioFile = res.files.first);
    }
  }

  Future<void> _pickVideo() async {
    final res = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.video,
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _videoFile = res.files.first);
    }
  }

  Future<void> _addArtist() async {
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Add artist',
        fetchPage: (page, limit, query) async {
          final listArtists = serviceLocator<ListArtists>();
          final res = await listArtists(
            ListArtistsParams(page: page, limit: limit, q: query),
          );
          return res.fold((_) => UuidPageResult(items: const [], total: 0), (
            tuple,
          ) {
            final items = tuple.$1
                .map(
                  (a) => UuidItem(
                    id: a.id,
                    label:
                        '${a.userName?.isNotEmpty == true ? a.userName! : 'Artist'} • ${a.id}',
                  ),
                )
                .toList();
            return UuidPageResult(items: items, total: tuple.$2);
          });
        },
      ),
    );
    if (!mounted) return;
    if (picked != null) {
      setState(
        () => _artists.add(
          _ArtistLink(id: picked.id, label: picked.label, role: 'viewer'),
        ),
      );
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _submit() async {
    if (_submitting) return;
    if (_formKey.currentState?.validate() != true) return;
    if (_albumId == null || _albumId!.isEmpty) {
      _showSnack('Please pick an album', error: true);
      return;
    }
    if (_audioFile?.bytes == null || (_audioFile?.bytes?.isEmpty ?? true)) {
      _showSnack('Please attach an audio file', error: true);
      return;
    }
    final duration = int.tryParse(_durationCtrl.text.trim());
    if (duration == null) {
      _showSnack('Enter a valid duration in seconds', error: true);
      return;
    }
    setState(() => _submitting = true);
    final create = serviceLocator<CreateTrack>();
    final res = await create(
      CreateTrackParams(
        title: _titleCtrl.text.trim(),
        albumId: _albumId!,
        duration: duration,
        lyricsUrl: _lyricsCtrl.text.trim().isEmpty
            ? null
            : _lyricsCtrl.text.trim(),
        isExplicit: _isExplicit,
        isPublished: _isPublished,
        audioBytes: _audioFile!.bytes!,
        audioFilename: _audioFile!.name,
        videoBytes: _videoFile?.bytes,
        videoFilename: _videoFile?.name,
        artists: _artists
            .map((a) => {'artist_id': a.id, 'role': a.role})
            .toList(),
      ),
    );
    res.fold(
      (f) {
        _showSnack(f.message, error: true);
        setState(() => _submitting = false);
      },
      (_) async {
        if (!mounted) return;
        _showSnack('Track created');
        setState(() => _submitting = false);
        context.go('/admin/tracks');
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Track'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(Routes.adminImport),
            icon: const Icon(Icons.cloud_download),
            label: const Text('Import from JioSaavn'),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: ListView(
                    children: [
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 700;
                          if (isNarrow) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Title *',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Album *',
                                  ),
                                  readOnly: true,
                                  controller: _albumCtrl,
                                  onTap: _pickAlbum,
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _titleCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Title *',
                                  ),
                                  validator: (v) =>
                                      (v == null || v.trim().isEmpty)
                                      ? 'Required'
                                      : null,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  decoration: const InputDecoration(
                                    labelText: 'Album *',
                                  ),
                                  readOnly: true,
                                  controller: _albumCtrl,
                                  onTap: _pickAlbum,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 700;
                          if (isNarrow) {
                            return Column(
                              children: [
                                TextFormField(
                                  controller: _durationCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Duration (seconds) *',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: _lyricsCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Lyrics URL',
                                  ),
                                ),
                              ],
                            );
                          }
                          return Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _durationCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                    labelText: 'Duration (seconds) *',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lyricsCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Lyrics URL',
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Checkbox(
                            value: _isExplicit,
                            onChanged: (v) =>
                                setState(() => _isExplicit = v ?? false),
                          ),
                          const Text('Explicit'),
                          const SizedBox(width: 16),
                          Checkbox(
                            value: _isPublished,
                            onChanged: (v) =>
                                setState(() => _isPublished = v ?? false),
                          ),
                          const Text('Published'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Media',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              LayoutBuilder(
                                builder: (context, c) {
                                  final isNarrow = c.maxWidth < 700;
                                  final audioTile = ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(Icons.audiotrack),
                                    title: Text(
                                      _audioFile?.name ??
                                          'Pick audio file (required)',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _submitting
                                              ? null
                                              : _pickAudio,
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text('Choose'),
                                        ),
                                        if (_audioFile != null)
                                          IconButton(
                                            tooltip: 'Clear',
                                            onPressed: _submitting
                                                ? null
                                                : () => setState(
                                                    () => _audioFile = null,
                                                  ),
                                            icon: const Icon(Icons.clear),
                                          ),
                                      ],
                                    ),
                                  );
                                  final videoTile = ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    leading: const Icon(
                                      Icons.movie_creation_outlined,
                                    ),
                                    title: Text(
                                      _videoFile?.name ??
                                          'Pick video (optional)',
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                    trailing: Wrap(
                                      spacing: 8,
                                      children: [
                                        OutlinedButton.icon(
                                          onPressed: _submitting
                                              ? null
                                              : _pickVideo,
                                          icon: const Icon(Icons.upload_file),
                                          label: const Text('Choose'),
                                        ),
                                        if (_videoFile != null)
                                          IconButton(
                                            tooltip: 'Clear',
                                            onPressed: _submitting
                                                ? null
                                                : () => setState(
                                                    () => _videoFile = null,
                                                  ),
                                            icon: const Icon(Icons.clear),
                                          ),
                                      ],
                                    ),
                                  );
                                  if (isNarrow) {
                                    return Column(
                                      children: [
                                        audioTile,
                                        const SizedBox(height: 8),
                                        videoTile,
                                      ],
                                    );
                                  }
                                  return Row(
                                    children: [
                                      Expanded(child: audioTile),
                                      const SizedBox(width: 12),
                                      Expanded(child: videoTile),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Card(
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Additional artists',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 8),
                              if (_artists.isEmpty)
                                const Text('None')
                              else
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _artists
                                      .asMap()
                                      .entries
                                      .map(
                                        (e) => Chip(
                                          label: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(e.value.label),
                                              const SizedBox(width: 8),
                                              DropdownButton<String>(
                                                value: e.value.role,
                                                items: const [
                                                  DropdownMenuItem(
                                                    value: 'viewer',
                                                    child: Text('viewer'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'editor',
                                                    child: Text('editor'),
                                                  ),
                                                  DropdownMenuItem(
                                                    value: 'owner',
                                                    child: Text('owner'),
                                                  ),
                                                ],
                                                onChanged: (v) => setState(
                                                  () => _artists[e.key] = e
                                                      .value
                                                      .copyWith(
                                                        role: v ?? 'viewer',
                                                      ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          onDeleted: () => setState(
                                            () => _artists.removeAt(e.key),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              const SizedBox(height: 8),
                              OutlinedButton.icon(
                                onPressed: _submitting ? null : _addArtist,
                                icon: const Icon(Icons.person_add),
                                label: const Text('Add artist'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      LayoutBuilder(
                        builder: (context, c) {
                          final isNarrow = c.maxWidth < 500;
                          if (isNarrow) {
                            return Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => context.pop(),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: _submitting ? null : _submit,
                                  child: const Text('Create'),
                                ),
                              ],
                            );
                          }
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: _submitting
                                    ? null
                                    : () => context.pop(),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: 8),
                              FilledButton(
                                onPressed: _submitting ? null : _submit,
                                child: const Text('Create'),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_submitting)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: _UploadingIndicator(label: 'Uploading track...'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ArtistLink {
  final String id;
  final String label;
  final String role;
  _ArtistLink({required this.id, required this.label, required this.role});

  _ArtistLink copyWith({String? id, String? label, String? role}) =>
      _ArtistLink(
        id: id ?? this.id,
        label: label ?? this.label,
        role: role ?? this.role,
      );
}

class _UploadingIndicator extends StatelessWidget {
  final String label;
  const _UploadingIndicator({required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const CircularProgressIndicator(),
        const SizedBox(height: 12),
        Text(label, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
