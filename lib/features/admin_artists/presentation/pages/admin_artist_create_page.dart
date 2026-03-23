import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
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

  final _artistIdCtrl = TextEditingController(); // existing
  final _nameCtrl = TextEditingController(); // new user optional
  final _emailCtrl = TextEditingController(); // new user optional
  final _passwordCtrl = TextEditingController(); // new user optional

  final _bioCtrl = TextEditingController(); // required

  // Optional artist fields
  final _genresCtrl = TextEditingController(); // comma-separated
  final _debutYearCtrl = TextEditingController();
  bool _verified = false;
  final _socialLinksCtrl = TextEditingController(); // JSON map
  final _monthlyListenersCtrl = TextEditingController();
  DateTime? _dob;

  // Country/Region pickers
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
    _passwordCtrl.dispose();
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
            return UuidPageResult(items: const [], total: 0);
          }
        },
      ),
    );
    if (sel != null) {
      setState(() {
        _countryId = sel.id;
        _countryLabel = sel.label;
        // Reset region if country changes
        _regionId = null;
        _regionLabel = null;
      });
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
          final qp = {
            'page': page,
            'limit': limit,
            if (q != null && q.isNotEmpty) 'q': q,
            if (_countryId != null) 'country_id': _countryId,
          };
          try {
            final res = await client.get(
              '${AppSecrets.backendUrl}/api/admin/regions',
              queryParameters: qp,
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

  void _submit() {
    if (_formKey.currentState?.validate() != true) return;

    Map<String, dynamic>? social;
    if (_socialLinksCtrl.text.trim().isNotEmpty) {
      try {
        final parsed = jsonDecode(_socialLinksCtrl.text.trim());
        if (parsed is Map<String, dynamic>) social = parsed;
      } catch (_) {}
    }

    final genres = _genresCtrl.text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final debutYear = int.tryParse(_debutYearCtrl.text.trim());
    final monthly = int.tryParse(_monthlyListenersCtrl.text.trim());

    context.read<AdminArtistsBloc>().add(
      CreateArtistEvent(
        artistId: _linkExisting ? _artistIdCtrl.text.trim() : null,
        name: !_linkExisting ? _nameCtrl.text.trim().takeIfNotEmpty() : null,
        email: !_linkExisting ? _emailCtrl.text.trim().takeIfNotEmpty() : null,
        password: !_linkExisting ? _passwordCtrl.text.takeIfNotEmpty() : null,
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

    Navigator.of(context).pop();
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Admin • Create Artist')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                const SizedBox(height: 12),
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
                    decoration: const InputDecoration(
                      labelText: 'User name (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(
                      labelText: 'User email (optional)',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _passwordCtrl,
                    decoration: const InputDecoration(
                      labelText: 'User password (optional)',
                    ),
                    obscureText: true,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          readOnly: true,
                          decoration: InputDecoration(
                            labelText: 'Country (optional)',
                            hintText: _countryLabel ?? 'Select country',
                          ),
                          onTap: _pickCountry,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickCountry,
                        tooltip: 'Select Country',
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
                            labelText: 'Region (required)',
                            hintText: _regionLabel ?? 'Select region',
                          ),
                          validator: (v) =>
                              (_regionId == null || _regionId!.isEmpty)
                              ? 'Region is required'
                              : null,
                          onTap: _pickRegion,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: _pickRegion,
                        tooltip: 'Select Region',
                        icon: const Icon(Icons.search),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
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
                // Optional artist info
                Text(
                  'Optional artist details',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _genresCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Genres (comma separated)',
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _debutYearCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Debut year'),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: _verified,
                  onChanged: (v) => setState(() => _verified = v),
                  title: const Text('Verified artist'),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _socialLinksCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Social links (JSON map)',
                    hintText: '{"instagram": "@handle"}',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _monthlyListenersCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Monthly listeners',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Date of birth (optional)',
                          hintText: _dob != null
                              ? _dob!.toIso8601String().split('T').first
                              : 'Pick date',
                        ),
                        onTap: _pickDateOfBirth,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Pick date',
                      onPressed: _pickDateOfBirth,
                      icon: const Icon(Icons.calendar_today),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
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

extension _StrX on String {
  String? takeIfNotEmpty() => trim().isEmpty ? null : trim();
}
