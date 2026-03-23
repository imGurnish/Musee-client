// Admin Import Page - Main UI for Jio Saavn imports

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/core/error/app_logger.dart';
import 'package:musee/features/admin_import/data/models/import_models.dart';
import 'package:musee/features/admin_import/presentation/bloc/admin_import_bloc.dart';

class AdminImportPage extends StatefulWidget {
  const AdminImportPage({Key? key}) : super(key: key);

  @override
  State<AdminImportPage> createState() => _AdminImportPageState();
}

class _AdminImportPageState extends State<AdminImportPage> {
  final _searchController = TextEditingController();
  String _selectedTab = 'albums'; // albums, tracks, artists

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _handleSearch(String query) {
    if (query.isEmpty) return;

    final bloc = context.read<AdminImportBloc>();

    switch (_selectedTab) {
      case 'tracks':
        bloc.add(SearchTracksEvent(query: query));
        break;
      case 'artists':
        bloc.add(SearchArtistsEvent(query: query));
        break;
      case 'albums':
      default:
        bloc.add(SearchAlbumsEvent(query: query));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jio Saavn Import'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Search & Import from Jio Saavn',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                // Tab Selection
                Row(
                  children: [
                    _buildTab('Albums', 'albums'),
                    const SizedBox(width: 12),
                    _buildTab('Tracks', 'tracks'),
                    const SizedBox(width: 12),
                    _buildTab('Artists', 'artists'),
                  ],
                ),
                const SizedBox(height: 16),
                // Search Field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search $_selectedTab...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {});
                  },
                  onSubmitted: _handleSearch,
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                  onPressed: () => _handleSearch(_searchController.text),
                ),
              ],
            ),
          ),
          const Divider(),
          // Results Section
          Expanded(
            child: BlocBuilder<AdminImportBloc, AdminImportState>(
              builder: (context, state) {
                if (state is AdminImportLoading) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                if (state is AdminImportError) {
                  return _buildErrorWidget(context, state);
                }

                if (state is AdminImportSearchAlbumsSuccess) {
                  return _buildAlbumsResult(state.albums);
                }

                if (state is AdminImportSearchTracksSuccess) {
                  return _buildTracksResult(state.tracks);
                }

                if (state is AdminImportSearchArtistsSuccess) {
                  return _buildArtistsResult(state.artists);
                }

                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.music_note,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Search for $_selectedTab to get started',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String label, String value) {
    final isSelected = _selectedTab == value;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTab = value;
          _searchController.clear();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.blue : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildAlbumsResult(List<JioAlbumModel> albums) {
    return ListView.builder(
      itemCount: albums.length,
      itemBuilder: (context, index) {
        final album = albums[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: album.image != null
                ? Image.network(
                    album.image!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.album, size: 56),
                  )
                : const Icon(Icons.album, size: 56),
            title: Text(album.title),
            subtitle: Text(
              '${album.artists.isNotEmpty ? album.artists.map((a) => a.name).join(', ') : 'Unknown Artist'}\n'
              '${album.tracks.length} tracks',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward),
            isThreeLine: true,
            onTap: () => _showAlbumDetails(album),
          ),
        );
      },
    );
  }

  Widget _buildTracksResult(List<JioTrackModel> tracks) {
    return ListView.builder(
      itemCount: tracks.length,
      itemBuilder: (context, index) {
        final track = tracks[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: track.album.image != null
                ? Image.network(
                    track.album.image!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.music_note, size: 56),
                  )
                : const Icon(Icons.music_note, size: 56),
            title: Text(track.title),
            subtitle: Text(
              '${track.artists.isNotEmpty ? track.artists.map((a) => a.name).join(', ') : 'Unknown Artist'}\n'
              '${track.album.title} • ${_formatDuration(track.duration)}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward),
            isThreeLine: true,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Track import coming soon. Use album import instead.'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildArtistsResult(List<JioArtistModel> artists) {
    return ListView.builder(
      itemCount: artists.length,
      itemBuilder: (context, index) {
        final artist = artists[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: artist.image != null
                ? Image.network(
                    artist.image!,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.person, size: 56),
                  )
                : const Icon(Icons.person, size: 56),
            title: Text(artist.name),
            subtitle: Text(
              artist.bio ?? 'No bio available',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: const Icon(Icons.arrow_forward),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Artist import coming soon. Use album import instead.'),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget(BuildContext context, AdminImportError state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'Error',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              state.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<AdminImportBloc>().add(const ClearErrorEvent());
            },
            child: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  void _showAlbumDetails(JioAlbumModel album) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => AdminImportAlbumDetailsSheet(
        album: album,
        onImport: _performImport,
      ),
    );
  }

  void _performImport(JioAlbumModel album, String artistName, String? artistBio) {
    final bloc = context.read<AdminImportBloc>();

    appLogger.info('[ImportPage] Starting import for album: ${album.title}');

    bloc.add(ImportAlbumEvent(
      jioSaavnAlbumId: album.id,
      artistName: artistName,
      artistBio: artistBio,
      isPublished: false,
      dryRun: false,
    ));

    Navigator.pop(context); // Close bottom sheet

    // Show import progress dialog
    _showImportProgressDialog();
  }

  void _showImportProgressDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => BlocBuilder<AdminImportBloc, AdminImportState>(
        builder: (dialogContext, state) {
          if (state is AdminImportLoading) {
            return AlertDialog(
              title: const Text('Importing Album'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(state.message),
                ],
              ),
            );
          }

          if (state is AdminImportSuccess) {
            Future.microtask(() {
              Navigator.pop(dialogContext);
              _showImportSuccessDialog(state);
            });
            return const SizedBox.shrink();
          }

          if (state is AdminImportError) {
            Future.microtask(() {
              Navigator.pop(dialogContext);
              _showImportErrorDialog(state);
            });
            return const SizedBox.shrink();
          }

          return const SizedBox.shrink();
        },
      ),
    );
  }

  void _showImportSuccessDialog(AdminImportSuccess state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✓ Import Successful'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            const SizedBox(height: 16),
            _buildResultItem(
              'Session ID',
              state.sessionId,
            ),
            _buildResultItem(
              'Tracks Imported',
              '${state.result['tracksImported'] ?? 0}',
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminImportBloc>().add(const ClearErrorEvent());
              _searchController.clear();
              setState(() {});
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  void _showImportErrorDialog(AdminImportError state) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('✗ Import Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(state.message),
            if (state.transaction != null) ...[
              const SizedBox(height: 16),
              const Text('Transaction Summary:'),
              _buildResultItem(
                'Records Created',
                '${state.transaction?['createdCount'] ?? 0}',
              ),
              _buildResultItem(
                'Records Updated',
                '${state.transaction?['updatedCount'] ?? 0}',
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<AdminImportBloc>().add(const ClearErrorEvent());
            },
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '$minutes:${secs.toString().padLeft(2, '0')}';
  }
}

// Album Details Bottom Sheet
class AdminImportAlbumDetailsSheet extends StatefulWidget {
  final JioAlbumModel album;
  final Function(JioAlbumModel, String, String?) onImport;

  const AdminImportAlbumDetailsSheet({
    Key? key,
    required this.album,
    required this.onImport,
  }) : super(key: key);

  @override
  State<AdminImportAlbumDetailsSheet> createState() =>
      _AdminImportAlbumDetailsSheetState();
}

class _AdminImportAlbumDetailsSheetState
    extends State<AdminImportAlbumDetailsSheet> {
  late TextEditingController _artistNameController;
  late TextEditingController _artistBioController;

  @override
  void initState() {
    super.initState();
    _artistNameController = TextEditingController(
      text: widget.album.artists.isNotEmpty
          ? widget.album.artists.first.name
          : '',
    );
    _artistBioController = TextEditingController(
      text: widget.album.artists.isNotEmpty
          ? widget.album.artists.first.bio
          : '',
    );
  }

  @override
  void dispose() {
    _artistNameController.dispose();
    _artistBioController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                if (widget.album.image != null)
                  Image.network(
                    widget.album.image!,
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.album, size: 100),
                  ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.album.title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${widget.album.tracks.length} tracks',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text(
              'Import Configuration',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _artistNameController,
              decoration: InputDecoration(
                labelText: 'Artist Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistBioController,
              decoration: InputDecoration(
                labelText: 'Artist Bio (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.download),
                    label: const Text('Import Album'),
                    onPressed: () {
                      widget.onImport(
                        widget.album,
                        _artistNameController.text,
                        _artistBioController.text.isEmpty
                            ? null
                            : _artistBioController.text,
                      );
                    },
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
