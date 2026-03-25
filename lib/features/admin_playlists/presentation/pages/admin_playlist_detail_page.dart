import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/features/admin_playlists/presentation/bloc/admin_playlist_detail_bloc.dart';

class AdminPlaylistDetailPage extends StatefulWidget {
  final String playlistId;

  const AdminPlaylistDetailPage({
    super.key,
    required this.playlistId,
  });

  @override
  State<AdminPlaylistDetailPage> createState() =>
      _AdminPlaylistDetailPageState();
}

class _AdminPlaylistDetailPageState extends State<AdminPlaylistDetailPage> {
  final _searchController = TextEditingController();
  int _searchPage = 0;

  @override
  void initState() {
    super.initState();
    context.read<AdminPlaylistDetailBloc>()
        .add(LoadPlaylistDetails(widget.playlistId));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearch({bool reset = false}) {
    if (reset) {
      _searchPage = 0;
    }
    context.read<AdminPlaylistDetailBloc>().add(
      SearchTracksEvent(
        query: _searchController.text.trim().isEmpty
            ? null
            : _searchController.text.trim(),
        page: _searchPage,
      ),
    );
  }

  void _onAddTrack(String trackId) {
    context.read<AdminPlaylistDetailBloc>().add(AddTrackEvent(trackId));
    _searchController.clear();
    _searchPage = 0;
  }

  void _onRemoveTrack(String trackId) {
    context.read<AdminPlaylistDetailBloc>().add(RemoveTrackEvent(trackId));
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AdminPlaylistDetailBloc, AdminPlaylistDetailState>(
      listener: (context, state) {
        if (state is AdminPlaylistDetailLoaded && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manage Playlist'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
        ),
        body: BlocBuilder<AdminPlaylistDetailBloc, AdminPlaylistDetailState>(
          builder: (context, state) {
            if (state is AdminPlaylistDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (state is AdminPlaylistDetailError) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 48,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(state.message),
                  ],
                ),
              );
            }

            if (state is! AdminPlaylistDetailLoaded) {
              return const SizedBox.shrink();
            }

            return SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isMobile = constraints.maxWidth < 768;
                    
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Playlist Header
                        _PlaylistHeader(playlist: state.playlist),
                        const SizedBox(height: 24),

                        // Track Search Section
                        if (isMobile)
                          _buildMobileSearchSection(context, state)
                        else
                          _buildDesktopLayout(context, state, isMobile),
                      ],
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildMobileSearchSection(
    BuildContext context,
    AdminPlaylistDetailLoaded state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current Tracks Section
        Text(
          'Tracks (${state.playlist.tracks?.length ?? 0})',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildTracksList(context, state),
        const SizedBox(height: 24),
        
        // Search Section
        Text(
          'Add Tracks',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        _buildSearchWidget(context, state),
        const SizedBox(height: 12),
        _buildSearchResults(context, state),
      ],
    );
  }

  Widget _buildDesktopLayout(
    BuildContext context,
    AdminPlaylistDetailLoaded state,
    bool isMobile,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Left: Current Tracks
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Tracks (${state.playlist.tracks?.length ?? 0})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildTracksList(context, state),
            ],
          ),
        ),
        const SizedBox(width: 24),
        // Right: Search and Add
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Tracks',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              _buildSearchWidget(context, state),
              const SizedBox(height: 12),
              _buildSearchResults(context, state),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTracksList(BuildContext context, AdminPlaylistDetailLoaded state) {
    final tracks = state.playlist.tracks ?? [];
    
    if (tracks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).dividerColor,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'No tracks in this playlist',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).hintColor,
            ),
          ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: tracks.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final track = tracks[index];
          final duration = _formatDuration(track.duration);

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            title: Text(
              track.title,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            subtitle: Text(
              duration,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            trailing: state.isRemovingTrack
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: () => _onRemoveTrack(track.trackId),
                    tooltip: 'Remove from playlist',
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSearchWidget(BuildContext context, AdminPlaylistDetailLoaded state) {
    return Column(
      children: [
        TextField(
          controller: _searchController,
          decoration: InputDecoration(
            hintText: 'Search tracks...',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _onSearch(reset: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton(
                onPressed: state.isSearching ? null : () => _onSearch(reset: true),
                child: state.isSearching
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : const Text('Search'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchResults(BuildContext context, AdminPlaylistDetailLoaded state) {
    final hasQuery = _searchController.text.trim().isNotEmpty;

    if (state.searchResults.isEmpty && !state.isSearching && !hasQuery) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'Search tracks to add them to this playlist.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    if (state.searchResults.isEmpty && state.isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.searchResults.isEmpty && !state.isSearching && hasQuery) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          'No tracks found.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final playlistTrackIds =
        state.playlist.tracks?.map((t) => t.trackId).toSet() ?? {};

    return Container(
      constraints: const BoxConstraints(maxHeight: 400),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        itemCount: state.searchResults.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final track = state.searchResults[index];
          final alreadyInPlaylist = playlistTrackIds.contains(track.trackId);
          final duration = _formatDuration(track.duration);
          final artists = track.artistNames.join(', ');

          return Material(
            color: Colors.transparent,
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              enabled: !alreadyInPlaylist,
              title: Text(
                track.title,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    artists.isEmpty ? 'Unknown Artist' : artists,
                    style: Theme.of(context).textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    duration,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                  ),
                ],
              ),
              trailing: alreadyInPlaylist
                  ? Chip(
                      label: const Text('Added'),
                      avatar: const Icon(Icons.check, size: 16),
                      onDeleted: null,
                    )
                  : IconButton.filledTonal(
                      onPressed: state.isAddingTrack
                          ? null
                          : () => _onAddTrack(track.trackId),
                      icon: state.isAddingTrack
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add),
                      tooltip: 'Add to playlist',
                    ),
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    return '${minutes}:${secs.toString().padLeft(2, '0')}';
  }
}

class _PlaylistHeader extends StatelessWidget {
  final dynamic playlist;

  const _PlaylistHeader({required this.playlist});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Playlist Cover
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 100,
                height: 100,
                child: Image.network(
                  playlist.coverUrl ??
                      'https://xvpputhovrhgowfkjhfv.supabase.co/storage/v1/object/public/covers/playlists/default_cover.png',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: Colors.grey[300],
                    child: const Icon(Icons.music_note),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Playlist Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Text(
                    playlist.name ?? 'Untitled',
                    style: Theme.of(context).textTheme.headlineSmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  if (playlist.description != null &&
                      playlist.description!.isNotEmpty)
                    Text(
                      playlist.description!,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Chip(
                        label: Text(
                          '${playlist.tracks?.length ?? 0} tracks',
                        ),
                        avatar: const Icon(Icons.music_note, size: 16),
                      ),
                      if (playlist.language != null)
                        Chip(
                          label: Text(playlist.language!.toUpperCase()),
                        ),
                      Chip(
                        label: Text(
                          playlist.isPublic ? 'Public' : 'Private',
                        ),
                        avatar: Icon(
                          playlist.isPublic ? Icons.public : Icons.lock,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
