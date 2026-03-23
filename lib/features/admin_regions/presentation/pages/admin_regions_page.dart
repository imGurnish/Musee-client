import 'package:dio/dio.dart' as dio;
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/secrets/app_secrets.dart';
import 'package:musee/features/admin_artists/presentation/widgets/uuid_picker_dialog.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRegionsPage extends StatefulWidget {
  const AdminRegionsPage({super.key});

  @override
  State<AdminRegionsPage> createState() => _AdminRegionsPageState();
}

class _AdminRegionsPageState extends State<AdminRegionsPage> {
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
        '${AppSecrets.backendUrl}/api/admin/regions',
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

  Future<UuidPickResult?> _pickCountry() async {
    return showDialog<UuidPickResult>(
      context: context,
      builder: (ctx) => UuidPickerDialog(
        title: 'Pick country',
        fetchPage: (page, limit, query) async {
          try {
            final client = GetIt.I<dio.Dio>();
            final res = await client.get(
              '${AppSecrets.backendUrl}/api/admin/countries',
              queryParameters: {
                'page': page,
                'limit': limit,
                if (query != null && query.isNotEmpty) 'q': query,
              },
              options: dio.Options(headers: _headers()),
            );
            final data = Map<String, dynamic>.from(res.data as Map);
            final items = (data['items'] as List? ?? const [])
                .map((e) => Map<String, dynamic>.from(e as Map))
                .map(
                  (e) => UuidItem(
                    id: e['country_id'].toString(),
                    label: '${e['code']} • ${e['name']}',
                  ),
                )
                .toList();
            return UuidPageResult(
              items: items,
              total: (data['total'] as num?)?.toInt() ?? items.length,
            );
          } on dio.DioException {
            return UuidPageResult(items: const [], total: 0);
          }
        },
      ),
    );
  }

  Future<void> _upsert({Map<String, dynamic>? existing}) async {
    final codeCtrl = TextEditingController(text: existing?['code']?.toString());
    final nameCtrl = TextEditingController(text: existing?['name']?.toString());
    String? countryId = existing?['country_id']?.toString();
    String? countryLabel = existing?['country_id']?.toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: Text(existing == null ? 'Create region' : 'Edit region'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeCtrl,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      countryLabel == null
                          ? 'Country not selected'
                          : 'Country: $countryLabel',
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      final picked = await _pickCountry();
                      if (picked == null) return;
                      setLocalState(() {
                        countryId = picked.id;
                        countryLabel = picked.label;
                      });
                    },
                    child: const Text('Pick'),
                  ),
                ],
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
    if (countryId == null || countryId!.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a country')));
      return;
    }

    try {
      final client = GetIt.I<dio.Dio>();
      final body = {
        'code': codeCtrl.text.trim(),
        'name': nameCtrl.text.trim(),
        'country_id': countryId,
      };
      if (existing == null) {
        await client.post(
          '${AppSecrets.backendUrl}/api/admin/regions',
          data: body,
          options: dio.Options(headers: _headers()),
        );
      } else {
        await client.patch(
          '${AppSecrets.backendUrl}/api/admin/regions/${existing['region_id']}',
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
        title: const Text('Delete region?'),
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
        '${AppSecrets.backendUrl}/api/admin/regions/$id',
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
        title: const Text('Admin • Regions'),
        actions: [
          IconButton(
            onPressed: () => _upsert(),
            icon: const Icon(Icons.add),
            tooltip: 'Create region',
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
                      hintText: 'Search regions',
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
                          title: Text('${row['code']} • ${row['name']}'),
                          subtitle: Text(
                            'region_id: ${row['region_id']}\ncountry_id: ${row['country_id']}',
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
                                    _delete(row['region_id'].toString()),
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
