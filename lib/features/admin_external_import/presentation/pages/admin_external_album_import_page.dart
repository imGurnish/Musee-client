import 'package:flutter/material.dart';
import 'package:musee/features/admin_external_import/data/admin_external_import_service.dart';
import 'package:musee/features/admin_external_import/data/jiosaavn_api_client.dart';
import 'package:musee/init_dependencies.dart';

class AdminExternalAlbumImportPage extends StatefulWidget {
  const AdminExternalAlbumImportPage({super.key});

  @override
  State<AdminExternalAlbumImportPage> createState() =>
      _AdminExternalAlbumImportPageState();
}

class _AdminExternalAlbumImportPageState
    extends State<AdminExternalAlbumImportPage> {
  final _queryCtrl = TextEditingController();

  bool _loadingSearch = false;
  bool _loadingInfo = false;
  bool _importing = false;
  List<JioSaavnSearchItem> _results = const [];
  JioSaavnSearchItem? _selected;
  JioSaavnAlbumDetail? _detail;

  AdminExternalImportService get _service =>
      serviceLocator<AdminExternalImportService>();

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  void _showSnack(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _search() async {
    final query = _queryCtrl.text.trim();
    if (query.isEmpty) return;

    setState(() {
      _loadingSearch = true;
      _selected = null;
      _detail = null;
    });

    try {
      final items = await _service.searchAlbums(query);
      if (!mounted) return;
      setState(() => _results = items);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Search failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingSearch = false);
    }
  }

  Future<void> _fetchInfo() async {
    if (_selected == null) return;
    setState(() => _loadingInfo = true);
    try {
      final detail = await _service.fetchAlbumInfo(_selected!.id);
      if (!mounted) return;
      setState(() => _detail = detail);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Fetch info failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _loadingInfo = false);
    }
  }

  Future<void> _import() async {
    if (_selected == null) return;
    setState(() => _importing = true);
    try {
      final result = await _service.importAlbum(_selected!.id);
      if (!mounted) return;
      if (result.alreadyExisted) {
        _showSnack('Album already exists: ${result.entityId}');
      } else {
        _showSnack(
          'Album imported: ${result.entityId} (tracks: ${result.importedTracks})',
        );
      }
    } catch (e) {
      if (!mounted) return;
      _showSnack('Import failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import Album from JioSaavn')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _queryCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search album',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: _loadingSearch ? null : _search,
                  child: _loadingSearch
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Search'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Card(
                      child: ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final item = _results[index];
                          final selected = _selected?.id == item.id;
                          return ListTile(
                            selected: selected,
                            leading: item.imageUrl != null
                                ? Image.network(
                                    item.imageUrl!,
                                    width: 40,
                                    height: 40,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        const Icon(Icons.album),
                                  )
                                : const Icon(Icons.album),
                            title: Text(item.title),
                            subtitle: Text(item.subtitle ?? item.id),
                            onTap: () => setState(() {
                              _selected = item;
                              _detail = null;
                            }),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: _selected == null
                            ? const Center(child: Text('Select an album'))
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _selected!.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      OutlinedButton(
                                        onPressed: _loadingInfo ? null : _fetchInfo,
                                        child: _loadingInfo
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                ),
                                              )
                                            : const Text('Fetch Info'),
                                      ),
                                      const SizedBox(width: 8),
                                      FilledButton(
                                        onPressed: _importing ? null : _import,
                                        child: _importing
                                            ? const SizedBox(
                                                height: 16,
                                                width: 16,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Text('Import Album'),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 24),
                                  if (_detail != null) ...[
                                    Text('External Album ID: ${_detail!.id}'),
                                    Text('Language: ${_detail!.language ?? '-'}'),
                                    Text('Release Date: ${_detail!.releaseDate ?? '-'}'),
                                    Text('Songs: ${_detail!.songs.length}'),
                                    const SizedBox(height: 8),
                                    const Text(
                                      'Artists',
                                      style: TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    const SizedBox(height: 6),
                                    ..._detail!.artists
                                        .take(6)
                                        .map((artist) => Text('• ${artist.name} (${artist.externalId})')),
                                  ] else
                                    const Text('Click "Fetch Info" to preview metadata.'),
                                ],
                              ),
                      ),
                    ),
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
