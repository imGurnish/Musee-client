import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPlaylistsPage extends StatefulWidget {
  const AdminPlaylistsPage({super.key});

  @override
  State<AdminPlaylistsPage> createState() => _AdminPlaylistsPageState();
}

class _AdminPlaylistsPageState extends State<AdminPlaylistsPage> {
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = GetIt.I<dio.Dio>();
      final res = await client.get(
        '${AppSecrets.backendUrl}/api/admin/playlists',
        queryParameters: {
          'page': 0,
          'limit': 100,
          if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
        },
        options: dio.Options(headers: _headers()),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final list = (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _items = list;
        _loading = false;
      });
    } on dio.DioException catch (e) {
      setState(() {
        _error = (e.response?.data is Map)
            ? (Map<String, dynamic>.from(
                    e.response!.data as Map,
                  )['error']?.toString() ??
                  e.message)
            : e.message;
        _loading = false;
      });
    }
  }

  Future<void> _upsert({Map<String, dynamic>? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString());
    final descCtrl = TextEditingController(
      text: existing?['description']?.toString(),
    );
    final langCtrl = TextEditingController(
      text: existing?['language_code']?.toString(),
    );
    bool isPublic = (existing?['is_public'] as bool?) ?? true;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Create playlist' : 'Edit playlist'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              TextField(
                controller: descCtrl,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              TextField(
                controller: langCtrl,
                decoration: const InputDecoration(
                  labelText: 'Language code (optional)',
                ),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                value: isPublic,
                onChanged: (v) => setLocalState(() => isPublic = v),
                title: const Text('Public playlist'),
                contentPadding: EdgeInsets.zero,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      final client = GetIt.I<dio.Dio>();
      final body = {
        'name': nameCtrl.text.trim(),
        'description': descCtrl.text.trim(),
        'is_public': isPublic,
        if (langCtrl.text.trim().isNotEmpty)
          'language_code': langCtrl.text.trim(),
      };
      if (existing == null) {
        await client.post(
          '${AppSecrets.backendUrl}/api/admin/playlists',
          data: body,
          options: dio.Options(headers: _headers()),
        );
      } else {
        await client.patch(
          '${AppSecrets.backendUrl}/api/admin/playlists/${existing['playlist_id']}',
          data: body,
          options: dio.Options(headers: _headers()),
        );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Saved')));
      }
      await _load();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Request failed')));
    }
  }

  Future<void> _delete(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete playlist?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final client = GetIt.I<dio.Dio>();
      await client.delete(
        '${AppSecrets.backendUrl}/api/admin/playlists/$id',
        options: dio.Options(headers: _headers()),
      );
      await _load();
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Delete failed')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin • Playlists'),
        actions: [
          IconButton(
            onPressed: () => _upsert(),
            icon: const Icon(Icons.add),
            tooltip: 'Create playlist',
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
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search playlists',
                    ),
                    onSubmitted: (_) => _load(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(onPressed: _load, child: const Text('Search')),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final row = _items[index];
                        return ListTile(
                          onTap: () {
                            context.push(
                              '/admin/playlists/${row['playlist_id']}',
                            );
                          },
                          title: Text(row['name']?.toString() ?? 'Untitled'),
                          subtitle: Text(
                            'playlist_id: ${row['playlist_id']}\n'
                            'public: ${row['is_public'] == true ? 'yes' : 'no'} '
                            '• language: ${row['language_code'] ?? '—'}',
                          ),
                          isThreeLine: true,
                          trailing: Wrap(
                            spacing: 4,
                            children: [
                              IconButton(
                                onPressed: () => _upsert(existing: row),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                onPressed: () =>
                                    _delete(row['playlist_id'].toString()),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
