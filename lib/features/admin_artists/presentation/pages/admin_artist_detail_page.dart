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

  // Form controllers
  final _bioCtrl = TextEditingController();
  final _coverUrlCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();
  final _debutYearCtrl = TextEditingController();
  bool _isVerified = false;
  final _socialLinksCtrl = TextEditingController();
  final _monthlyListenersCtrl = TextEditingController();
  String? _regionId;
  String? _regionLabel;
  DateTime? _dateOfBirth;

  // File selections
  Uint8List? _coverBytes;
  String? _coverFilename;
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  // Linked user fields
  final _userNameCtrl = TextEditingController();
  String? _userId;
  String? _originalUserName;

  // Original snapshot for reset/dirty check
  ArtistModel? _original;

  @override
  void initState() {
    super.initState();
    _future = _fetch();
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

    // Initialize form fields
    _original = model;
    _bioCtrl.text = model.bio;
    _coverUrlCtrl.text = model.coverUrl ?? '';
    _genresCtrl.text = (model.genres).join(', ');
    _debutYearCtrl.text = model.debutYear?.toString() ?? '';
    _isVerified = model.isVerified;
    _socialLinksCtrl.text = model.socialLinks == null
        ? ''
        : _prettyJson(model.socialLinks!);
    _monthlyListenersCtrl.text = model.monthlyListeners.toString();
    _regionId = model.regionId;
    _regionLabel = null; // resolved lazily in picker; show id initially
    _dateOfBirth = model.dateOfBirth;

    // Linked user init
    _userNameCtrl.text = (users['name'] as String?) ?? model.name;
    _originalUserName = _userNameCtrl.text;
    _userId = users['user_id'] as String?;
    _avatarBytes = null;
    _avatarFilename = null;
    _coverBytes = null;
    _coverFilename = null;

    return _DetailData(model, users);
  }

  String _prettyJson(Map<String, dynamic> m) {
    try {
      return const JsonEncoder.withIndent('  ').convert(m);
    } catch (_) {
      return m.toString();
    }
  }

  Map<String, dynamic> _buildPatchBody() {
    final Map<String, dynamic> body = {};
    if (_original == null) return body;
    final o = _original!;

    if (_bioCtrl.text.trim() != o.bio) body['bio'] = _bioCtrl.text.trim();
    final coverUrl = _coverUrlCtrl.text.trim();
    if ((o.coverUrl ?? '') != coverUrl) {
      body['cover_url'] = coverUrl.isEmpty ? null : coverUrl;
    }

    final genres = _genresCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (genres.join('|') != o.genres.join('|')) body['genres'] = genres;

    final debut = int.tryParse(_debutYearCtrl.text.trim());
    if (debut != null && debut != o.debutYear) body['debut_year'] = debut;

    if (_isVerified != o.isVerified) body['is_verified'] = _isVerified;

    final monthly = int.tryParse(_monthlyListenersCtrl.text.trim());
    if (monthly != null && monthly != o.monthlyListeners) {
      body['monthly_listeners'] = monthly;
    }

    if ((_regionId ?? '') != (o.regionId ?? '')) body['region_id'] = _regionId;

    final dobStr = _dateOfBirth?.toIso8601String().split('T').first;
    final oDobStr = o.dateOfBirth?.toIso8601String().split('T').first;
    if (dobStr != oDobStr) body['date_of_birth'] = dobStr;

    // Proper social_links parsing
    Map<String, dynamic>? social;
    if (_socialLinksCtrl.text.trim().isNotEmpty) {
      try {
        final decoded = JsonDecoder().convert(_socialLinksCtrl.text.trim());
        if (decoded is Map<String, dynamic>) social = decoded;
      } catch (_) {}
    }
    final oSocialStr = _original!.socialLinks == null
        ? null
        : const JsonEncoder().convert(_original!.socialLinks);
    final nSocialStr = social == null
        ? null
        : const JsonEncoder().convert(social);
    if (oSocialStr != nSocialStr) body['social_links'] = social;

    return body;
  }

  Future<void> _save() async {
    final artistBody = _buildPatchBody();
    final bool hasCoverFile = _coverBytes != null && _coverFilename != null;

    // Determine user changes
    final bool hasUserId = _userId != null && _userId!.isNotEmpty;
    final bool nameChanged =
        (_userNameCtrl.text.trim() != (_originalUserName ?? ''));
    final bool hasAvatarFile = _avatarBytes != null && _avatarFilename != null;

    if (artistBody.isEmpty && !hasCoverFile && !nameChanged && !hasAvatarFile) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No changes to save')));
      return;
    }

    // 1) Update artist via usecase (supports cover file in repo)
    if (artistBody.isNotEmpty || hasCoverFile) {
      final updateArtist = GetIt.I<UpdateArtist>();
      // Recompute structured fields for params based on keys present
      List<String>? genres;
      if (artistBody.containsKey('genres')) {
        genres = _genresCtrl.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final int? debutYear = artistBody.containsKey('debut_year')
          ? int.tryParse(_debutYearCtrl.text.trim())
          : null;
      final bool? isVerified = artistBody.containsKey('is_verified')
          ? _isVerified
          : null;
      final int? monthly = artistBody.containsKey('monthly_listeners')
          ? int.tryParse(_monthlyListenersCtrl.text.trim())
          : null;
      Map<String, dynamic>? social;
      if (artistBody.containsKey('social_links') &&
          _socialLinksCtrl.text.trim().isNotEmpty) {
        try {
          final decoded = JsonDecoder().convert(_socialLinksCtrl.text.trim());
          if (decoded is Map<String, dynamic>) social = decoded;
        } catch (_) {}
      }
      final String? coverUrl = artistBody.containsKey('cover_url')
          ? _coverUrlCtrl.text.trim()
          : null;
      final String? bio = artistBody.containsKey('bio')
          ? _bioCtrl.text.trim()
          : null;
      final String? region = artistBody.containsKey('region_id')
          ? _regionId
          : null;
      final DateTime? dob = artistBody.containsKey('date_of_birth')
          ? _dateOfBirth
          : null;

      final res = await updateArtist(
        UpdateArtistParams(
          id: widget.artistId,
          bio: bio,
          coverUrl: coverUrl?.isEmpty == true ? null : coverUrl,
          coverBytes: hasCoverFile ? _coverBytes!.toList() : null,
          coverFilename: hasCoverFile ? _coverFilename : null,
          genres: genres,
          debutYear: debutYear,
          isVerified: isVerified,
          socialLinks: social,
          monthlyListeners: monthly,
          regionId: region,
          dateOfBirth: dob,
        ),
      );
      res.match((l) {
        throw Exception(l.message);
      }, (r) {});
    }

    // 2) Update linked user via usecase
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
      res.match((l) {
        throw Exception(l.message);
      }, (r) {});
    }

    // Evict cached images so next paint fetches fresh content when URLs remain the same
    try {
      if (hasCoverFile || artistBody.containsKey('cover_url')) {
        final oldCover = _original?.coverUrl;
        if (oldCover != null && oldCover.isNotEmpty) {
          await NetworkImage(oldCover).evict();
        }
      }
      if (hasAvatarFile) {
        final oldAvatar = _original?.avatarUrl;
        if (kDebugMode) {
          print('Evicting old avatar URL: $oldAvatar');
        }
        if (oldAvatar != null && oldAvatar.isNotEmpty) {
          await NetworkImage(oldAvatar).evict();
        }
      }
    } catch (_) {
      // ignore eviction errors
    }

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Changes saved')));
    setState(() {
      _future = _fetch();
    });
  }

  void _resetForm() {
    if (_original == null) return;
    final o = _original!;
    _bioCtrl.text = o.bio;
    _coverUrlCtrl.text = o.coverUrl ?? '';
    _genresCtrl.text = o.genres.join(', ');
    _debutYearCtrl.text = o.debutYear?.toString() ?? '';
    _isVerified = o.isVerified;
    _socialLinksCtrl.text = o.socialLinks == null
        ? ''
        : _prettyJson(o.socialLinks!);
    _monthlyListenersCtrl.text = o.monthlyListeners.toString();
    _regionId = o.regionId;
    _regionLabel = null;
    _dateOfBirth = o.dateOfBirth;
    _coverBytes = null;
    _coverFilename = null;
    _avatarBytes = null;
    _avatarFilename = null;
    _userNameCtrl.text = _originalUserName ?? _userNameCtrl.text;
    setState(() {});
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
              return UuidPageResult(items: const [], total: 0);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Artist Detail'),
        actions: [
          TextButton(onPressed: _resetForm, child: const Text('Cancel')),
          const SizedBox(width: 8),
          FilledButton(onPressed: _save, child: const Text('Save')),
          const SizedBox(width: 8),
        ],
      ),
      body: FutureBuilder<_DetailData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          final data = snapshot.data!;
          return _ArtistDetailBody(
            artist: data.artist,
            users: data.users,
            bioCtrl: _bioCtrl,
            coverUrlCtrl: _coverUrlCtrl,
            genresCtrl: _genresCtrl,
            debutYearCtrl: _debutYearCtrl,
            isVerified: _isVerified,
            onVerifiedChanged: (v) => setState(() => _isVerified = v),
            socialLinksCtrl: _socialLinksCtrl,
            monthlyListenersCtrl: _monthlyListenersCtrl,
            regionId: _regionId,
            regionLabel: _regionLabel,
            onPickRegion: _pickRegion,
            dateOfBirth: _dateOfBirth,
            onPickDob: _pickDob,
            onPickCover: _pickCover,
            onClearCover: _clearCover,
            onPickAvatar: _pickAvatar,
            onClearAvatar: _clearAvatar,
            userNameCtrl: _userNameCtrl,
            coverBytes: _coverBytes,
            avatarBytes: _avatarBytes,
          );
        },
      ),
    );
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dateOfBirth = picked);
  }

  Future<void> _pickCover() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
      setState(() {
        _coverBytes = res.files.first.bytes!;
        _coverFilename = res.files.first.name;
      });
    }
  }

  void _clearCover() {
    setState(() {
      _coverBytes = null;
      _coverFilename = null;
    });
  }

  Future<void> _pickAvatar() async {
    final res = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
      setState(() {
        _avatarBytes = res.files.first.bytes!;
        _avatarFilename = res.files.first.name;
      });
    }
  }

  void _clearAvatar() {
    setState(() {
      _avatarBytes = null;
      _avatarFilename = null;
    });
  }
}

class _ArtistDetailBody extends StatelessWidget {
  final ArtistModel artist;
  final Map<String, dynamic> users;
  final TextEditingController bioCtrl;
  final TextEditingController coverUrlCtrl;
  final TextEditingController genresCtrl;
  final TextEditingController debutYearCtrl;
  final bool isVerified;
  final ValueChanged<bool> onVerifiedChanged;
  final TextEditingController socialLinksCtrl;
  final TextEditingController monthlyListenersCtrl;
  final String? regionId;
  final String? regionLabel;
  final VoidCallback onPickRegion;
  final DateTime? dateOfBirth;
  final VoidCallback onPickDob;
  final VoidCallback onPickCover;
  final VoidCallback onClearCover;
  final VoidCallback onPickAvatar;
  final VoidCallback onClearAvatar;
  final TextEditingController userNameCtrl;
  final Uint8List? coverBytes;
  final Uint8List? avatarBytes;

  const _ArtistDetailBody({
    required this.artist,
    required this.users,
    required this.bioCtrl,
    required this.coverUrlCtrl,
    required this.genresCtrl,
    required this.debutYearCtrl,
    required this.isVerified,
    required this.onVerifiedChanged,
    required this.socialLinksCtrl,
    required this.monthlyListenersCtrl,
    required this.regionId,
    required this.regionLabel,
    required this.onPickRegion,
    required this.dateOfBirth,
    required this.onPickDob,
    required this.onPickCover,
    required this.onClearCover,
    required this.onPickAvatar,
    required this.onClearAvatar,
    required this.userNameCtrl,
    required this.coverBytes,
    required this.avatarBytes,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userName = users['name'] as String? ?? artist.name;
    final email = users['email'] as String?;
    final userType = users['user_type'] as String?;
    final subscription = users['subscription_type'] as String?;
    final followers = users['followers_count'] as int?;
    final followings = users['followings_count'] as int?;
    final playlists = users['playlists'] is List
        ? (users['playlists'] as List).length
        : null;
    final planId = users['plan_id'] as String?;
    final userId = users['user_id'] as String?;
    final lastLogin = users['last_login_at'] as String?;
    final userCreated = users['created_at'] as String?;
    final userUpdated = users['updated_at'] as String?;
    final settings = users['settings'];
    final favorites = users['favorites'];
    final settingsCount = settings is Map ? settings.length : null;
    final favoritesCount = favorites is Map ? favorites.length : null;

    String dateOnly(DateTime? dt) =>
        dt == null ? '—' : dt.toIso8601String().split('T').first;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 36,
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
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            userName,
                            style: theme.textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Chip(
                          label: Text(
                            isVerified ? 'Verified' : 'Unverified',
                            style: TextStyle(
                              color: isVerified
                                  ? theme.colorScheme.onPrimary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          backgroundColor: isVerified
                              ? theme.colorScheme.primary
                              : theme.colorScheme.surfaceContainerHighest,
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (email != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.email, size: 16),
                              const SizedBox(width: 6),
                              Text(email),
                            ],
                          ),
                        if (userType != null)
                          Chip(label: Text('User: $userType')),
                        if (subscription != null)
                          Chip(
                            label: Text('Plan: ${subscription.toUpperCase()}'),
                          ),
                        if (userId != null)
                          Chip(label: Text('User ID: $userId')),
                        if (planId != null)
                          Chip(label: Text('plan_id: $planId')),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Cover
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: AspectRatio(
              aspectRatio: 16 / 6,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (coverBytes != null)
                    Image.memory(coverBytes!, fit: BoxFit.cover)
                  else if (artist.coverUrl != null)
                    Image.network(artist.coverUrl!, fit: BoxFit.cover)
                  else
                    Container(
                      color: theme.colorScheme.surfaceContainerHighest,
                      alignment: Alignment.center,
                      child: const Icon(Icons.image, size: 48),
                    ),
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FilledButton.tonal(
                            onPressed: onPickCover,
                            child: const Text('Change cover'),
                          ),
                          const SizedBox(width: 8),
                          if (coverBytes != null)
                            OutlinedButton(
                              onPressed: onClearCover,
                              child: const Text('Clear'),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Quick stats
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(
                avatar: const Icon(Icons.headphones, size: 16),
                label: Text('Monthly: ${artist.monthlyListeners}'),
              ),
              if (followers != null)
                Chip(
                  avatar: const Icon(Icons.people, size: 16),
                  label: Text('Followers: $followers'),
                ),
              if (followings != null)
                Chip(
                  avatar: const Icon(Icons.person_add, size: 16),
                  label: Text('Following: $followings'),
                ),
              if (playlists != null)
                Chip(
                  avatar: const Icon(Icons.queue_music, size: 16),
                  label: Text('Playlists: $playlists'),
                ),
              if (lastLogin != null)
                Chip(
                  avatar: const Icon(Icons.login, size: 16),
                  label: Text('Last login: $lastLogin'),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Editable form
          Text('Artist profile', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextFormField(
            controller: bioCtrl,
            maxLines: 4,
            decoration: const InputDecoration(labelText: 'Bio'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: coverUrlCtrl,
            decoration: const InputDecoration(labelText: 'Cover URL'),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: genresCtrl,
            decoration: const InputDecoration(
              labelText: 'Genres (comma separated)',
            ),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: debutYearCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Debut year'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: isVerified,
            onChanged: onVerifiedChanged,
            title: const Text('Verified'),
            contentPadding: EdgeInsets.zero,
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: monthlyListenersCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Monthly listeners'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Region',
                    hintText: regionLabel ?? regionId ?? 'Select region',
                  ),
                  onTap: onPickRegion,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onPickRegion,
                icon: const Icon(Icons.search),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Date of birth',
                    hintText: dateOfBirth != null
                        ? dateOnly(dateOfBirth)
                        : 'Pick date',
                  ),
                  onTap: onPickDob,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: onPickDob,
                icon: const Icon(Icons.calendar_today),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: socialLinksCtrl,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Social links (JSON map)',
              hintText: '{"instagram": "@handle"}',
            ),
          ),

          const SizedBox(height: 16),

          // Audit
          Text('Audit', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              Chip(label: Text('Artist ID: ${artist.id}')),
              Chip(
                label: Text(
                  'Created: ${artist.createdAt?.toLocal().toString().split('.').first ?? '—'}',
                ),
              ),
              Chip(
                label: Text(
                  'Updated: ${artist.updatedAt?.toLocal().toString().split('.').first ?? '—'}',
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          Text('Linked user', style: theme.textTheme.titleMedium),
          const SizedBox(height: 6),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Wrap(
                spacing: 16,
                runSpacing: 8,
                children: [
                  // Avatar picker + preview
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 28,
                        backgroundImage: avatarBytes != null
                            ? MemoryImage(avatarBytes!)
                            : (artist.avatarUrl != null
                                      ? NetworkImage(artist.avatarUrl!)
                                      : null)
                                  as ImageProvider<Object>?,
                        child: (artist.avatarUrl == null && avatarBytes == null)
                            ? const Icon(Icons.person)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      FilledButton.tonal(
                        onPressed: onPickAvatar,
                        child: const Text('Change avatar'),
                      ),
                      const SizedBox(width: 8),
                      if (avatarBytes != null)
                        OutlinedButton(
                          onPressed: onClearAvatar,
                          child: const Text('Clear'),
                        ),
                    ],
                  ),
                  SizedBox(
                    width: 280,
                    child: TextFormField(
                      controller: userNameCtrl,
                      decoration: const InputDecoration(labelText: 'User name'),
                    ),
                  ),
                  if (email != null) _kv('Email', email),
                  if (userType != null) _kv('User type', userType),
                  if (subscription != null) _kv('Subscription', subscription),
                  if (planId != null) _kv('Plan ID', planId),
                  if (userId != null) _kv('User ID', userId),
                  if (followers != null) _kv('Followers', '$followers'),
                  if (followings != null) _kv('Following', '$followings'),
                  if (playlists != null) _kv('Playlists', '$playlists'),
                  if (settingsCount != null)
                    _kv('Settings keys', '$settingsCount'),
                  if (favoritesCount != null)
                    _kv('Favorites keys', '$favoritesCount'),
                  if (userCreated != null) _kv('User created', userCreated),
                  if (userUpdated != null) _kv('User updated', userUpdated),
                  if (lastLogin != null) _kv('Last login', lastLogin),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Widget _kv(String k, String v) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('$k: ', style: const TextStyle(fontWeight: FontWeight.w600)),
      Flexible(child: Text(v)),
    ],
  );
}
