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
  int _page = 0;
  int _limit = 20;
  int _total = 0;
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _items = const [];

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onSearchTextChanged);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearchTextChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchTextChanged() {
    if (!mounted) return;
    setState(() {});
  }

  Map<String, String> _headers() {
    final token = Supabase.instance.client.auth.currentSession?.accessToken;
    return {
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Future<void> _load({int? page, int? limit}) async {
    final nextPage = page ?? _page;
    final nextLimit = limit ?? _limit;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = GetIt.I<dio.Dio>();
      final res = await client.get(
        '${AppSecrets.backendUrl}/api/admin/playlists',
        queryParameters: {
          'page': nextPage,
          'limit': nextLimit,
          if (_searchCtrl.text.trim().isNotEmpty) 'q': _searchCtrl.text.trim(),
        },
        options: dio.Options(headers: _headers()),
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      final list = (data['items'] as List? ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _page = (data['page'] as num?)?.toInt() ?? nextPage;
        _limit = (data['limit'] as num?)?.toInt() ?? nextLimit;
        _total = (data['total'] as num?)?.toInt() ?? list.length;
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
      await _load(page: 0);
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
      await _load(page: _page);
    } on dio.DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message ?? 'Delete failed')));
    }
  }

  void _showMobileMenu(Map<String, dynamic> row) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              row['name']?.toString() ?? 'Untitled',
              style: Theme.of(context).textTheme.titleLarge,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('View Details'),
            onTap: () {
              Navigator.pop(ctx);
              context.push('/admin/playlists/${row['playlist_id']}');
            },
          ),
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('Edit'),
            onTap: () {
              Navigator.pop(ctx);
              _upsert(existing: row);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            title: const Text('Delete', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(ctx);
              _delete(row['playlist_id'].toString());
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMobileSearchFilters(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Search Playlists',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.search_rounded,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search playlists',
                    border: InputBorder.none,
                    isDense: true,
                    hintStyle: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _load(page: 0),
                ),
              ),
              if (_searchCtrl.text.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _searchCtrl.clear();
                    setState(() {});
                    _load(page: 0);
                  },
                ),
              const SizedBox(width: 6),
              FilledButton.tonal(
                onPressed: () {
                  FocusScope.of(context).unfocus();
                  _load(page: 0);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(42, 36),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.arrow_forward_rounded, size: 18),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopSearchFilters(ThemeData theme) {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Search playlists',
                      border: InputBorder.none,
                      isDense: true,
                      hintStyle: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _load(page: 0),
                  ),
                ),
                if (_searchCtrl.text.trim().isNotEmpty)
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.close_rounded, size: 18),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() {});
                      _load(page: 0);
                    },
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.tonalIcon(
          onPressed: () {
            FocusScope.of(context).unfocus();
            _load(page: 0);
          },
          icon: const Icon(Icons.search_rounded),
          label: const Text('Search'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(110, 42),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isMobile = MediaQuery.of(context).size.width < 760;
    final isSearchMobile = MediaQuery.of(context).size.width < 768;
    final totalPages = (_total / _limit).ceil().clamp(1, 999999);
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
            Card(
              elevation: 0,
              color: theme.colorScheme.surfaceContainerLowest,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: isSearchMobile
                    ? _buildMobileSearchFilters(theme)
                    : _buildDesktopSearchFilters(theme),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final row = _items[index];
                        if (isMobile) {
                          return Card(
                            elevation: 0,
                            child: InkWell(
                              onTap: () => context.push('/admin/playlists/${row['playlist_id']}'),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      child: Text(
                                        (row['name']?.toString().isNotEmpty == true)
                                            ? row['name'].toString()[0].toUpperCase()
                                            : 'P',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row['name']?.toString() ?? 'Untitled',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: theme.textTheme.titleSmall,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            'language: ${row['language_code'] ?? '—'}',
                                            style: theme.textTheme.bodySmall,
                                          ),
                                          const SizedBox(height: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: row['is_public'] == true
                                                  ? Colors.green.withOpacity(0.15)
                                                  : Colors.orange.withOpacity(0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              row['is_public'] == true ? 'Public' : 'Private',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: row['is_public'] == true
                                                    ? Colors.green[700]
                                                    : Colors.orange[700],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.more_vert),
                                      onPressed: () => _showMobileMenu(row),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }
                        return ListTile(
                          onTap: () => context.push('/admin/playlists/${row['playlist_id']}'),
                          title: Text(row['name']?.toString() ?? 'Untitled'),
                          subtitle: Text(
                            'playlist_id: ${row['playlist_id']}\n'
                            'public: ${row['is_public'] == true ? 'yes' : 'no'} '
                            '• language: ${row['language_code'] ?? '—'}',
                          ),
                          isThreeLine: true,
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'edit') {
                                _upsert(existing: row);
                              } else if (value == 'delete') {
                                _delete(row['playlist_id'].toString());
                              }
                            },
                            itemBuilder: (context) => const [
                              PopupMenuItem<String>(
                                value: 'edit',
                                child: Text('Edit'),
                              ),
                              PopupMenuItem<String>(
                                value: 'delete',
                                child: Text('Delete'),
                              ),
                            ],
                            child: const Icon(Icons.more_vert),
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Total: $_total',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: FilledButton.tonal(
                          onPressed: _page > 0 ? () => _load(page: _page - 1) : null,
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Icon(Icons.chevron_left, size: 18),
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_page + 1} / $totalPages',
                      style: theme.textTheme.labelSmall,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      SizedBox(
                        height: 36,
                        width: 36,
                        child: FilledButton.tonal(
                          onPressed: _page < (totalPages - 1) ? () => _load(page: _page + 1) : null,
                          style: FilledButton.styleFrom(padding: EdgeInsets.zero),
                          child: const Icon(Icons.chevron_right, size: 18),
                        ),
                      ),
                      PopupMenuButton<int>(
                        initialValue: _limit,
                        onSelected: (v) {
                          setState(() => _limit = v);
                          _load(page: 0, limit: v);
                        },
                        itemBuilder: (context) => [10, 20, 50, 100]
                            .map((e) => PopupMenuItem(value: e, child: Text(e.toString())))
                            .toList(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.colorScheme.outline),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            spacing: 4,
                            children: [
                              Text(_limit.toString(), style: theme.textTheme.labelSmall),
                              Icon(Icons.arrow_drop_down, size: 16, color: theme.colorScheme.onSurfaceVariant),
                            ],
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
    );
  }
}
