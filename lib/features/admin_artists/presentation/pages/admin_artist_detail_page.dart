import 'dart:convert';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/admin_artists/data/models/artist_model.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:musee/features/admin_artists/domain/usecases/update_artist.dart';
import 'package:musee/features/admin_users/domain/usecases/update_user.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminArtistDetailPage extends StatefulWidget {
  final String artistId;
  const AdminArtistDetailPage({super.key, required this.artistId});

  @override
  State<AdminArtistDetailPage> createState() => _AdminArtistDetailPageState();
}

class _DetailData {
  final ArtistModel artist;
  final Map<String, dynamic> users;
  _DetailData(this.artist, this.users);
}

class _AdminArtistDetailPageState extends State<AdminArtistDetailPage> {
  late Future<_DetailData> _future;
  bool _saving = false;

  final _formKey = GlobalKey<FormState>();
  final _bioCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();
  final _debutYearCtrl = TextEditingController();
  bool _isVerified = false;
  final _socialLinksCtrl = TextEditingController();
  final _monthlyListenersCtrl = TextEditingController();
  String? _regionId;
  String? _regionLabel;
  DateTime? _dateOfBirth;

  Uint8List? _coverBytes;
  String? _coverFilename;
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  final _userNameCtrl = TextEditingController();
  String? _userId;
  String? _originalUserName;

  ArtistModel? _original;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
  }

  @override
  void dispose() {
    _bioCtrl.dispose();
    _genresCtrl.dispose();
    _debutYearCtrl.dispose();
    _socialLinksCtrl.dispose();
    _monthlyListenersCtrl.dispose();
    _userNameCtrl.dispose();
    super.dispose();
  }

  Future<_DetailData> _fetch() async {
    final client = GetIt.I<dio.Dio>();
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    final res = await client.get(
      '${AppSecrets.backendUrl}/api/admin/artists/${widget.artistId}',
      options: dio.Options(
        headers: {
          'Accept': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
    );
    final data = (res.data as Map).cast<String, dynamic>();
    final model = ArtistModel.fromJson(data);
    final users = (data['users'] as Map?)?.cast<String, dynamic>() ?? const {};

    _original = model;
    _bioCtrl.text = model.bio;
    _genresCtrl.text = model.genres.join(', ');
    _debutYearCtrl.text = model.debutYear?.toString() ?? '';
    _isVerified = model.isVerified;
    _socialLinksCtrl.text =
        model.socialLinks == null ? '' : _prettyJson(model.socialLinks!);
    _monthlyListenersCtrl.text = model.monthlyListeners.toString();
    _regionId = model.regionId;
    _dateOfBirth = model.dateOfBirth;

    if (users.isNotEmpty) {
      _userId = users['id'] as String?;
      _userNameCtrl.text = users['name'] as String? ?? '';
      _originalUserName = _userNameCtrl.text;
    }

    return _DetailData(model, users);
  }

  String _prettyJson(Map<String, dynamic> map) {
    return const JsonEncoder.withIndent('  ').convert(map);
  }

  Map<String, dynamic> _buildPatchBody() {
    final body = <String, dynamic>{};
    if (_original == null) return body;
    final o = _original!;

    if (_bioCtrl.text.trim() != o.bio) body['bio'] = _bioCtrl.text.trim();

    final genres = _genresCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (genres != o.genres) body['genres'] = genres;

    final debutYear = int.tryParse(_debutYearCtrl.text.trim());
    if (debutYear != o.debutYear) body['debut_year'] = debutYear;

    if (_isVerified != o.isVerified) body['is_verified'] = _isVerified;

    final monthly = int.tryParse(_monthlyListenersCtrl.text.trim());
    if (monthly != o.monthlyListeners) body['monthly_listeners'] = monthly;

    if (_regionId != o.regionId) body['region_id'] = _regionId;

    if (_dateOfBirth != o.dateOfBirth) body['date_of_birth'] = _dateOfBirth;

    if (_socialLinksCtrl.text.trim().isNotEmpty) {
      try {
        final decoded = JsonDecoder().convert(_socialLinksCtrl.text.trim());
        if (decoded is Map<String, dynamic>) {
          final oSocialStr = _original!.socialLinks == null
              ? null
              : const JsonEncoder().convert(_original!.socialLinks);
          final nSocialStr = const JsonEncoder().convert(decoded);
          if (oSocialStr != nSocialStr) body['social_links'] = decoded;
        }
      } catch (_) {}
    }

    return body;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final artistBody = _buildPatchBody();
    final bool hasCoverFile = _coverBytes != null && _coverFilename != null;

    final bool hasUserId = _userId != null && _userId!.isNotEmpty;
    final bool nameChanged =
        (_userNameCtrl.text.trim() != (_originalUserName ?? ''));
    final bool hasAvatarFile = _avatarBytes != null && _avatarFilename != null;

    if (artistBody.isEmpty && !hasCoverFile && !nameChanged && !hasAvatarFile) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    try {
      if (artistBody.isNotEmpty || hasCoverFile) {
        final updateArtist = GetIt.I<UpdateArtist>();
        final res = await updateArtist(
          UpdateArtistParams(
            id: widget.artistId,
            bio: artistBody['bio'] as String?,
            coverBytes: hasCoverFile ? _coverBytes!.toList() : null,
            coverFilename: hasCoverFile ? _coverFilename : null,
            genres: artistBody['genres'] as List<String>?,
            debutYear: artistBody['debut_year'] as int?,
            isVerified: artistBody['is_verified'] as bool?,
            socialLinks:
                artistBody['social_links'] as Map<String, dynamic>?,
            monthlyListeners: artistBody['monthly_listeners'] as int?,
            regionId: artistBody['region_id'] as String?,
            dateOfBirth: artistBody['date_of_birth'] as DateTime?,
          ),
        );
        res.match(
          (l) => throw Exception(l.message),
          (r) {},
        );
      }

      if (hasUserId && (nameChanged || hasAvatarFile)) {
        final updateUser = GetIt.I<UpdateUser>();
        final res = await updateUser(
          UpdateUserParams(
            id: _userId!,
            name: nameChanged ? _userNameCtrl.text.trim() : null,
            avatarBytes: hasAvatarFile ? _avatarBytes!.toList() : null,
            avatarFilename: hasAvatarFile ? _avatarFilename : null,
          ),
        );
        res.match(
          (l) => throw Exception(l.message),
          (r) {},
        );
      }

      try {
        if (hasCoverFile) {
          final oldCover = _original?.coverUrl;
          if (oldCover != null && oldCover.isNotEmpty) {
            await NetworkImage(oldCover).evict();
          }
        }
        if (hasAvatarFile) {
          final oldAvatar = _original?.avatarUrl;
          if (oldAvatar != null && oldAvatar.isNotEmpty) {
            await NetworkImage(oldAvatar).evict();
          }
        }
      } catch (_) {}

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved')),
      );
      setState(() {
        _future = _fetch();
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickRegion() async {
    final sel = await showDialog<UuidPickResult>(
      context: context,
      builder: (_) => UuidPickerDialog(
        title: 'Select Region',
        fetchPage: (page, limit, q) async {
          final client = GetIt.I<dio.Dio>();
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          try {
            final res = await client.get(
              '${AppSecrets.backendUrl}/api/admin/regions',
              queryParameters: {
                'page': page,
                'limit': limit,
                if (q != null && q.isNotEmpty) 'q': q,
              },
              options: dio.Options(
                headers: {
                  'Accept': 'application/json',
                  if (token != null) 'Authorization': 'Bearer $token',
                },
              ),
            );
            final data = (res.data as Map).cast<String, dynamic>();
            final items = (data['items'] as List).cast<dynamic>();
            return UuidPageResult(
              items: items
                  .map(
                    (e) => UuidItem(
                      id: e['region_id'] as String,
                      label: '${e['code']} • ${e['name']}',
                    ),
                  )
                  .toList(),
              total: data['total'] as int,
            );
          } on dio.DioException {
            rethrow;
          }
        },
      ),
    );
    if (sel != null) {
      setState(() {
        _regionId = sel.id;
        _regionLabel = sel.label;
      });
    }
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickCoverFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) return;
    setState(() {
      _coverBytes = file.bytes;
      _coverFilename = file.name;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DetailData>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: const Text('Artist Details')),
            body: Center(child: Text('Error: ${snapshot.error}')),
          );
        }
        if (!snapshot.hasData) {
          return Scaffold(
            appBar: AppBar(title: const Text('Artist Details')),
            body: const Center(child: Text('No data')),
          );
        }

        final detailData = snapshot.data!;
        final artist = detailData.artist;
        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Artist Details'),
            actions: [
              if (_saving)
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: _save,
                  icon: const Icon(Icons.save_outlined),
                  tooltip: 'Save',
                ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Hero summary card
                    Card(
                      elevation: 0,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Hero(
                              tag: 'avatar-${artist.id}',
                              child: CircleAvatar(
                                radius: 40,
                                backgroundImage: artist.avatarUrl != null
                                    ? NetworkImage(artist.avatarUrl!)
                                    : null,
                                child: artist.avatarUrl == null
                                    ? const Icon(Icons.person, size: 40)
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    artist.name,
                                    style: theme.textTheme.headlineSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    artist.id,
                                    style: theme.textTheme.labelSmall,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 8),
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
                                            color: theme.colorScheme
                                                .primaryContainer,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                          ),
                                          child: Text(
                                            'Verified',
                                            style: theme.textTheme.labelSmall
                                                ?.copyWith(
                                              color: theme.colorScheme
                                                  .onPrimaryContainer,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Basic info section
                    _SectionCard(
                      title: 'Basic Information',
                      icon: Icons.info_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _bioCtrl,
                            decoration: InputDecoration(
                              labelText: 'Bio',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Bio is required'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Artist metadata section
                    _SectionCard(
                      title: 'Artist Metadata',
                      icon: Icons.music_note_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            controller: _genresCtrl,
                            decoration: InputDecoration(
                              labelText: 'Genres (comma-separated)',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _ResponsiveRow(
                            children: [
                              TextFormField(
                                controller: _debutYearCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Debut Year',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              TextFormField(
                                controller: _monthlyListenersCtrl,
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(
                                  labelText: 'Monthly Listeners',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SwitchListTile(
                            title: const Text('Verified'),
                            value: _isVerified,
                            onChanged: (v) => setState(() => _isVerified = v),
                            contentPadding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Location & dates section
                    _SectionCard(
                      title: 'Location & Dates',
                      icon: Icons.location_on_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Region',
                              hintText: _regionLabel ?? 'Select',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onTap: _pickRegion,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: 'Date of Birth',
                              hintText: _dateOfBirth != null
                                  ? _dateOfBirth!
                                      .toIso8601String()
                                      .split('T')
                                      .first
                                  : 'Pick date',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            onTap: _pickDateOfBirth,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Social & cover section
                    _SectionCard(
                      title: 'Media & Social',
                      icon: Icons.link_outlined,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CoverPickerRow(
                            coverUrl: artist.coverUrl,
                            previewBytes: _coverBytes,
                            pickedName: _coverFilename,
                            onPick: _pickCoverFile,
                            onClear: () {
                              setState(() {
                                _coverBytes = null;
                                _coverFilename = null;
                              });
                            },
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _socialLinksCtrl,
                            decoration: InputDecoration(
                              labelText: 'Social Links (JSON)',
                              hintText: '{"instagram": "@handle"}',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            maxLines: 3,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20),
                const SizedBox(width: 8),
                Text(title, style: theme.textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _CoverPickerRow extends StatelessWidget {
  final String? coverUrl;
  final Uint8List? previewBytes;
  final String? pickedName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _CoverPickerRow({
    required this.coverUrl,
    required this.previewBytes,
    required this.pickedName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final hasRemote = coverUrl != null && coverUrl!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 72,
            height: 72,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: previewBytes != null
                ? Image.memory(previewBytes!, fit: BoxFit.cover)
                : hasRemote
                ? Image.network(
                    coverUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.image_outlined),
                  )
                : const Icon(Icons.image_outlined),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(pickedName ?? 'No image selected'),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.image),
                    label: const Text('Choose cover'),
                    onPressed: onPick,
                  ),
                  if (pickedName != null)
                    TextButton.icon(
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear'),
                      onPressed: onClear,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ResponsiveRow extends StatelessWidget {
  final List<Widget> children;
  const _ResponsiveRow({required this.children});

  Widget _normalizeChild(Widget child) {
    if (child is Expanded) return child.child;
    if (child is Flexible) return child.child;
    return child;
  }

  @override
  Widget build(BuildContext context) {
    final normalizedChildren = children.map(_normalizeChild).toList();
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 600) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int i = 0; i < normalizedChildren.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                normalizedChildren[i],
              ],
            ],
          );
        }
        return Row(
          children: [
            for (int i = 0; i < normalizedChildren.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: normalizedChildren[i]),
            ],
          ],
        );
      },
    );
  }
}
