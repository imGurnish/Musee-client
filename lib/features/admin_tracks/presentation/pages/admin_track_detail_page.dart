import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:musee/features/admin_artists/domain/usecases/list_artists.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:musee/features/admin_albums/domain/usecases/list_albums.dart';
import 'package:musee/features/admin_tracks/domain/entities/track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/get_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/update_track.dart';
import 'package:musee/features/admin_tracks/domain/usecases/link_track_artist.dart';
import 'package:musee/features/admin_tracks/domain/usecases/update_track_artist_role.dart';
import 'package:musee/features/admin_tracks/domain/usecases/unlink_track_artist.dart';
import 'package:musee/init_dependencies.dart';

class AdminTrackDetailPage extends StatefulWidget {
  final String trackId;
  const AdminTrackDetailPage({super.key, required this.trackId});

  @override
  State<AdminTrackDetailPage> createState() => _AdminTrackDetailPageState();
}

class _AdminTrackDetailPageState extends State<AdminTrackDetailPage> {
  Track? _track;
  bool _loading = true;
  String? _error;
  bool _saving = false;

  // Editable fields
  final _titleCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _lyricsCtrl = TextEditingController();
  final _albumCtrl = TextEditingController();
  bool _isExplicit = false;
  bool _isPublished = false;
  String? _albumId;
  String? _albumLabel;

  PlatformFile? _audioFile;
  PlatformFile? _videoFile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _durationCtrl.dispose();
    _lyricsCtrl.dispose();
    _albumCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final get = serviceLocator<GetTrack>();
    final res = await get(GetTrackParams(widget.trackId));
    res.fold(
      (f) => setState(() {
        _error = f.message;
        _loading = false;
      }),
      (t) => setState(() {
        _track = t;
        _titleCtrl.text = t.title;
        _durationCtrl.text = t.duration.toString();
        _lyricsCtrl.text = t.lyricsUrl ?? '';
        _isExplicit = t.isExplicit;
        _isPublished = t.isPublished;
        _albumId = t.albumId;
        _albumLabel = t.albumId ?? '';
        _albumCtrl.text = _albumLabel ?? '';
        _loading = false;
      }),
    );
  }

  void _showSnack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
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
        _albumLabel = picked.label;
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

  Future<void> _save() async {
    if (_track == null) return;
    if (_saving) return;
    final duration = int.tryParse(_durationCtrl.text.trim());
    setState(() => _saving = true);
    final update = serviceLocator<UpdateTrack>();
    final res = await update(
      UpdateTrackParams(
        id: _track!.trackId,
        title: _titleCtrl.text.trim().isEmpty ? null : _titleCtrl.text.trim(),
        albumId: _albumId,
        duration: duration,
        lyricsUrl: _lyricsCtrl.text.trim().isEmpty
            ? null
            : _lyricsCtrl.text.trim(),
        isExplicit: _isExplicit,
        isPublished: _isPublished,
        audioBytes: _audioFile?.bytes,
        audioFilename: _audioFile?.name,
        videoBytes: _videoFile?.bytes,
        videoFilename: _videoFile?.name,
      ),
    );
    res.fold(
      (f) {
        _showSnack(f.message, error: true);
        setState(() => _saving = false);
      },
      (t) async {
        setState(() {
          _track = t;
          _audioFile = null;
          _videoFile = null;
        });
        _showSnack('Saved');
        await _load();
        if (mounted) setState(() => _saving = false);
      },
    );
  }

  Future<void> _addArtist() async {
    if (_track == null) return;
    final picked = await showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Add artist to track',
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
      final link = serviceLocator<LinkTrackArtist>();
      final r = await link(
        LinkTrackArtistParams(
          trackId: _track!.trackId,
          artistId: picked.id,
          role: 'viewer',
        ),
      );
      r.fold((f) => _showSnack(f.message, error: true), (_) => _load());
    }
  }

  Future<void> _updateRole(String artistId, String role) async {
    if (_track == null) return;
    final upd = serviceLocator<UpdateTrackArtistRole>();
    final r = await upd(
      UpdateTrackArtistRoleParams(
        trackId: _track!.trackId,
        artistId: artistId,
        role: role,
      ),
    );
    r.fold((f) => _showSnack(f.message, error: true), (_) => _load());
  }

  Future<void> _removeArtist(String artistId) async {
    if (_track == null) return;
    final rem = serviceLocator<UnlinkTrackArtist>();
    final r = await rem(
      UnlinkTrackArtistParams(trackId: _track!.trackId, artistId: artistId),
    );
    r.fold((f) => _showSnack(f.message, error: true), (_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final content = _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : _track == null
        ? const Center(child: Text('Not found'))
        : Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: ListView(
                  children: [
                    _headerSection(),
                    const SizedBox(height: 16),
                    _artistsSection(),
                    const SizedBox(height: 16),
                    _audioVariantsSection(),
                  ],
                ),
              ),
            ),
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Track details'),
        actions: [
          IconButton(
            onPressed: _saving ? null : _save,
            tooltip: _saving ? 'Saving…' : 'Save',
            icon: const Icon(Icons.save),
          ),
        ],
      ),
      body: Stack(
        children: [
          content,
          if (_saving)
            Positioned.fill(
              child: AbsorbPointer(
                absorbing: true,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.35),
                  child: const Center(
                    child: _UploadingIndicator(label: 'Uploading changes…'),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _headerSection() {
    final t = _track!;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, c) {
            final isNarrow = c.maxWidth < 700;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                TextFormField(
                  controller: _titleCtrl,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 8),
                // Album picker
                TextFormField(
                  readOnly: true,
                  decoration: const InputDecoration(labelText: 'Album'),
                  controller: _albumCtrl,
                  onTap: _pickAlbum,
                ),
                const SizedBox(height: 8),
                // Duration + Lyrics
                isNarrow
                    ? Column(
                        children: [
                          TextFormField(
                            controller: _durationCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Duration (seconds)',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _lyricsCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Lyrics URL',
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _durationCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Duration (seconds)',
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
                      ),
                const SizedBox(height: 8),
                // Toggles and media buttons
                if (isNarrow)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 16,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isExplicit,
                                onChanged: (v) =>
                                    setState(() => _isExplicit = v ?? false),
                              ),
                              const Text('Explicit'),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Checkbox(
                                value: _isPublished,
                                onChanged: (v) =>
                                    setState(() => _isPublished = v ?? false),
                              ),
                              const Text('Published'),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickAudio,
                            icon: const Icon(Icons.audiotrack),
                            label: Text(
                              _audioFile?.name == null
                                  ? 'Replace audio'
                                  : _audioFile!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : _pickVideo,
                            icon: const Icon(Icons.movie_creation_outlined),
                            label: Text(
                              _videoFile?.name == null
                                  ? 'Replace video'
                                  : _videoFile!.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _saving ? null : _save,
                            icon: const Icon(Icons.save),
                            label: const Text('Save'),
                          ),
                        ],
                      ),
                    ],
                  )
                else
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
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickAudio,
                        icon: const Icon(Icons.audiotrack),
                        label: Text(
                          _audioFile?.name == null
                              ? 'Replace audio'
                              : _audioFile!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: _saving ? null : _pickVideo,
                        icon: const Icon(Icons.movie_creation_outlined),
                        label: Text(
                          _videoFile?.name == null
                              ? 'Replace video'
                              : _videoFile!.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save),
                        label: const Text('Save'),
                      ),
                    ],
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 8,
                  children: [
                    _metaChip('Track ID', t.trackId),
                    _metaChip(
                      'Created',
                      t.createdAt.toLocal().toString().split('.').first,
                    ),
                    _metaChip(
                      'Updated',
                      t.updatedAt.toLocal().toString().split('.').first,
                    ),
                    _metaChip('Plays', t.playCount.toString()),
                    _metaChip('Likes', t.likesCount.toString()),
                    _metaChip('Popularity', t.popularityScore.toString()),
                    if (t.videoUrl != null && t.videoUrl!.isNotEmpty)
                      _metaChip('Video', t.videoUrl!),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _metaChip(String label, String value) {
    return Chip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          Text(value),
        ],
      ),
    );
  }

  Widget _artistsSection() {
    final t = _track!;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Artists',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                OutlinedButton.icon(
                  onPressed: _addArtist,
                  icon: const Icon(Icons.person_add),
                  label: const Text('Add artist'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (t.artists.isEmpty)
              const Text('No artists linked yet.')
            else
              Column(
                children: [
                  for (final a in t.artists)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundImage: a.avatarUrl != null
                            ? NetworkImage(a.avatarUrl!)
                            : null,
                        child: a.avatarUrl == null
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      title: Text(a.name.isNotEmpty ? a.name : a.artistId),
                      subtitle: Text(a.artistId),
                      trailing: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          DropdownButton<String>(
                            value: a.role ?? 'viewer',
                            items: const [
                              DropdownMenuItem(
                                value: 'owner',
                                child: Text('owner'),
                              ),
                              DropdownMenuItem(
                                value: 'editor',
                                child: Text('editor'),
                              ),
                              DropdownMenuItem(
                                value: 'viewer',
                                child: Text('viewer'),
                              ),
                            ],
                            onChanged: (v) {
                              if (v != null) _updateRole(a.artistId, v);
                            },
                          ),
                          IconButton(
                            tooltip: 'Remove',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => _removeArtist(a.artistId),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _audioVariantsSection() {
    final t = _track!;
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Audio variants',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            if (t.audios.isEmpty)
              const Text('No processed variants yet.')
            else
              Column(
                children: [
                  for (final a in t.audios)
                    ListTile(
                      leading: const Icon(Icons.library_music_outlined),
                      title: Text('${a.bitrate} kbps • .${a.ext}'),
                      subtitle: Text(a.path),
                      trailing: Text(
                        a.createdAt?.toLocal().toString().split('.').first ??
                            '',
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
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
