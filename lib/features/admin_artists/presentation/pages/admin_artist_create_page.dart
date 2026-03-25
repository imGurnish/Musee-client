import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/admin_artists/presentation/bloc/admin_artists_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../widgets/uuid_picker_dialog.dart';

class AdminArtistCreatePage extends StatefulWidget {
  const AdminArtistCreatePage({super.key});

  @override
  State<AdminArtistCreatePage> createState() => _AdminArtistCreatePageState();
}

class _AdminArtistCreatePageState extends State<AdminArtistCreatePage> {
  final _formKey = GlobalKey<FormState>();
  bool _linkExisting = true;
  bool _saving = false;

  final _artistIdCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  final _genresCtrl = TextEditingController();
  final _debutYearCtrl = TextEditingController();
  bool _verified = false;
  final _socialLinksCtrl = TextEditingController();
  final _monthlyListenersCtrl = TextEditingController();
  DateTime? _dob;

  String? _countryId;
  String? _countryLabel;
  String? _regionId;
  String? _regionLabel;

  Uint8List? _avatarBytes;
  String? _avatarFilename;
  Uint8List? _coverBytes;
  String? _coverFilename;

  @override
  void dispose() {
    _artistIdCtrl.dispose();
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _bioCtrl.dispose();
    _genresCtrl.dispose();
    _debutYearCtrl.dispose();
    _socialLinksCtrl.dispose();
    _monthlyListenersCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickCountry() async {
    final sel = await showDialog<UuidPickResult>(
      context: context,
      builder: (_) => UuidPickerDialog(
        title: 'Select Country',
        fetchPage: (page, limit, q) async {
          final client = GetIt.I<dio.Dio>();
          final token =
              Supabase.instance.client.auth.currentSession?.accessToken;
          try {
            final res = await client.get(
              '${AppSecrets.backendUrl}/api/admin/countries',
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
                      id: e['country_id'] as String,
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
        _countryId = sel.id;
        _countryLabel = sel.label;
      });
    }
  }

  Future<void> _pickRegion() async {
    if (_countryId == null) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a country first')),
      );
      return;
    }
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
                'country_id': _countryId,
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
                      label: e['name'] as String,
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

  Future<void> _submit() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;

    Map<String, dynamic>? social;
    if (_socialLinksCtrl.text.trim().isNotEmpty) {
      try {
        social = Map<String, dynamic>.from(
          jsonDecode(_socialLinksCtrl.text) as Map,
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid social links JSON')),
        );
        return;
      }
    }

    final genres = _genresCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final debutYear = int.tryParse(_debutYearCtrl.text.trim());
    final monthly = int.tryParse(_monthlyListenersCtrl.text.trim());

    setState(() => _saving = true);

    context.read<AdminArtistsBloc>().add(
      CreateArtistEvent(
        artistId: _linkExisting ? _artistIdCtrl.text.trim() : null,
        name: !_linkExisting ? _nameCtrl.text.trim().takeIfNotEmpty() : null,
        email: !_linkExisting ? _emailCtrl.text.trim().takeIfNotEmpty() : null,
        bio: _bioCtrl.text.trim(),
        coverBytes: _coverBytes?.toList(),
        coverFilename: _coverFilename,
        avatarBytes: _avatarBytes?.toList(),
        avatarFilename: _avatarFilename,
        genres: genres.isEmpty ? null : genres,
        debutYear: debutYear,
        isVerified: _verified,
        socialLinks: social,
        monthlyListeners: monthly,
        regionId: _regionId,
        dateOfBirth: _dob,
      ),
    );
  }

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Artist'),
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
              tooltip: 'Create',
              icon: const Icon(Icons.check),
              onPressed: _submit,
            ),
        ],
      ),
      body: BlocListener<AdminArtistsBloc, AdminArtistsState>(
        listener: (context, state) {
          if (!_saving) return;
          if (state is AdminArtistsFailure) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
            return;
          }
          if (state is AdminArtistsPageLoaded) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Artist created')),
            );
            Navigator.of(context).pop();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                // Link vs Create section
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Artist User',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Link existing user'),
                          subtitle: Text(
                            _linkExisting
                                ? 'Link by user ID'
                                : 'Create new user for artist',
                          ),
                          value: _linkExisting,
                          onChanged: (v) => setState(() => _linkExisting = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        if (_linkExisting) ...[
                          TextFormField(
                            controller: _artistIdCtrl,
                            decoration: InputDecoration(
                              labelText: 'User ID (UUID)',
                              prefixIcon: const Icon(Icons.badge_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'User ID is required'
                                : null,
                          ),
                        ] else ...[
                          TextFormField(
                            controller: _nameCtrl,
                            decoration: InputDecoration(
                              labelText: 'Full Name',
                              prefixIcon: const Icon(Icons.person_outline),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Name is required'
                                : null,
                          ),
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              prefixIcon:
                                  const Icon(Icons.alternate_email_outlined),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            validator: (v) {
                              final value = v?.trim() ?? '';
                              if (value.isEmpty) return 'Email is required';
                              final emailRegex =
                                  RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                              if (!emailRegex.hasMatch(value)) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 10),
                          LayoutBuilder(
                            builder: (context, c) {
                              final isMobile = c.maxWidth < 500;
                              return isMobile
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.stretch,
                                      children: [
                                        TextFormField(
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            labelText: 'Country',
                                            prefixIcon: const Icon(
                                                Icons.public_outlined),
                                            hintText:
                                                _countryLabel ?? 'Select',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onTap: _pickCountry,
                                        ),
                                        const SizedBox(height: 10),
                                        TextFormField(
                                          readOnly: true,
                                          decoration: InputDecoration(
                                            labelText: 'Region',
                                            prefixIcon: const Icon(
                                                Icons.location_on_outlined),
                                            hintText:
                                                _regionLabel ?? 'Select',
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onTap: _pickRegion,
                                        ),
                                      ],
                                    )
                                  : Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            readOnly: true,
                                            decoration: InputDecoration(
                                              labelText: 'Country',
                                              prefixIcon: const Icon(
                                                  Icons.public_outlined),
                                              hintText: _countryLabel ??
                                                  'Select',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onTap: _pickCountry,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: TextFormField(
                                            readOnly: true,
                                            decoration: InputDecoration(
                                              labelText: 'Region',
                                              prefixIcon: const Icon(
                                                  Icons.location_on_outlined),
                                              hintText: _regionLabel ??
                                                  'Select',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                            ),
                                            onTap: _pickRegion,
                                          ),
                                        ),
                                      ],
                                    );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Artist info
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Artist Details',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _bioCtrl,
                          decoration: InputDecoration(
                            labelText: 'Bio',
                            prefixIcon:
                                const Icon(Icons.description_outlined),
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
                ),
                const SizedBox(height: 12),
                // Optional fields
                Card(
                  elevation: 0,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Additional Info',
                          style: theme.textTheme.titleSmall,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _genresCtrl,
                          decoration: InputDecoration(
                            labelText: 'Genres (comma-separated)',
                            prefixIcon: const Icon(Icons.music_note_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        LayoutBuilder(
                          builder: (context, c) {
                            final isMobile = c.maxWidth < 500;
                            return isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      TextFormField(
                                        controller: _debutYearCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Debut Year',
                                          prefixIcon: const Icon(
                                              Icons.calendar_today_outlined),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      TextFormField(
                                        controller: _monthlyListenersCtrl,
                                        keyboardType: TextInputType.number,
                                        decoration: InputDecoration(
                                          labelText: 'Monthly Listeners',
                                          prefixIcon: const Icon(
                                              Icons.headphones_outlined),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: TextFormField(
                                          controller: _debutYearCtrl,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Debut Year',
                                            prefixIcon: const Icon(
                                                Icons.calendar_today_outlined),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: TextFormField(
                                          controller: _monthlyListenersCtrl,
                                          keyboardType:
                                              TextInputType.number,
                                          decoration: InputDecoration(
                                            labelText: 'Monthly Listeners',
                                            prefixIcon: const Icon(
                                                Icons.headphones_outlined),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                          },
                        ),
                        const SizedBox(height: 10),
                        SwitchListTile(
                          title: const Text('Verified artist'),
                          value: _verified,
                          onChanged: (v) => setState(() => _verified = v),
                          contentPadding: EdgeInsets.zero,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          controller: _socialLinksCtrl,
                          decoration: InputDecoration(
                            labelText: 'Social Links (JSON)',
                            hintText: '{"instagram": "@handle"}',
                            prefixIcon: const Icon(Icons.link_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 10),
                        TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: const Icon(Icons.cake_outlined),
                            hintText: _dob != null
                                ? _dob!.toIso8601String().split('T').first
                                : 'Pick date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onTap: _pickDateOfBirth,
                        ),
                        const SizedBox(height: 10),
                        _CoverPickerTile(
                          pickedName: _coverFilename,
                          onPick: _pickCoverFile,
                          onClear: () => setState(() {
                            _coverBytes = null;
                            _coverFilename = null;
                          }),
                        ),
                      ],
                    ),
                  ),
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

class _CoverPickerTile extends StatelessWidget {
  final String? pickedName;
  final VoidCallback onPick;
  final VoidCallback onClear;

  const _CoverPickerTile({
    required this.pickedName,
    required this.onPick,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.image_outlined, size: 18),
        const SizedBox(width: 8),
        const Expanded(child: Text('Artist Cover (optional)')),
        if (pickedName != null)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                pickedName!,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        if (pickedName != null)
          IconButton(
            tooltip: 'Clear',
            icon: const Icon(Icons.close),
            onPressed: onClear,
          ),
        FilledButton.tonal(onPressed: onPick, child: const Text('Choose')),
      ],
    );
  }
}

extension _StrX on String {
  String? takeIfNotEmpty() => trim().isEmpty ? null : trim();
}
