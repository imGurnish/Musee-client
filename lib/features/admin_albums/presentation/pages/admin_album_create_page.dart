import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:musee/features/admin_artists/domain/usecases/list_artists.dart';
import 'package:musee/features/admin_albums/domain/usecases/create_album.dart';
import 'package:musee/init_dependencies.dart';

class AdminAlbumCreatePage extends StatefulWidget {
  const AdminAlbumCreatePage({super.key});

  @override
  State<AdminAlbumCreatePage> createState() => _AdminAlbumCreatePageState();
}

class _AdminAlbumCreatePageState extends State<AdminAlbumCreatePage> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();

  String? _ownerArtistId;
  String? _ownerArtistLabel;
  bool _isPublished = false;
  PlatformFile? _coverFile;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descriptionCtrl.dispose();
    _genresCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (res != null && res.files.isNotEmpty) {
      setState(() => _coverFile = res.files.first);
    }
  }

  Future<void> _pickOwnerArtist() async {
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Pick owner artist',
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
                        '${a.userName?.isNotEmpty == true
                            ? a.userName!
                            : 'Artist'} • ${a.id}',
                  ),
                )
                .toList();
            return UuidPageResult(items: items, total: tuple.$2);
          });
        },
      ),
    );
    if (picked != null) {
      setState(() {
        _ownerArtistId = picked.id;
        _ownerArtistLabel = picked.label;
      });
    }
  }

  void _showSnack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState?.validate() != true) return;
    if (_ownerArtistId == null || _ownerArtistId!.isEmpty) {
      _showSnack('Please pick an owner artist', error: true);
      return;
    }
    final genres = _genresCtrl.text.trim().isEmpty
        ? null
        : _genresCtrl.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList();
    final create = serviceLocator<CreateAlbum>();
    final res = await create(
      CreateAlbumParams(
        title: _titleCtrl.text.trim(),
        description: _descriptionCtrl.text.trim().isEmpty
            ? null
            : _descriptionCtrl.text.trim(),
        genres: genres,
        isPublished: _isPublished,
        artistId: _ownerArtistId!,
        coverBytes: _coverFile?.bytes,
        coverFilename: _coverFile?.name,
      ),
    );
    res.fold((f) => _showSnack(f.message, error: true), (_) {
      _showSnack('Album created');
      context.go('/admin/albums');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Album'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push(Routes.adminImport),
            icon: const Icon(Icons.cloud_download),
            label: const Text('Import from JioSaavn'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Title *',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Required'
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Owner artist',
                          ),
                          readOnly: true,
                          controller: TextEditingController(
                            text:
                                _ownerArtistLabel ??
                                (_ownerArtistId ?? ''),
                          ),
                          onTap: _pickOwnerArtist,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _descriptionCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _genresCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Genres (comma-separated)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: _isPublished,
                        onChanged: (v) =>
                            setState(() => _isPublished = v ?? false),
                      ),
                      const Text('Published'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 72,
                        height: 72,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(8),
                          image: _coverFile?.bytes != null
                              ? DecorationImage(
                                  image: MemoryImage(
                                    _coverFile!.bytes as Uint8List,
                                  ),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _coverFile?.bytes == null
                            ? const Icon(Icons.image)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _coverFile?.name ?? 'No cover selected',
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
                                if (_coverFile != null)
                                  TextButton.icon(
                                    onPressed: () =>
                                        setState(() => _coverFile = null),
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
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => context.pop(),
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
      ),
    );
  }
}
