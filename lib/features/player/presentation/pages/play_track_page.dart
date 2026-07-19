import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/navigation/routes.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/providers/music_provider_registry.dart';
import 'package:musee/core/utils/show_snackbar.dart';
import 'package:musee/features/player/domain/entities/queue_item.dart';
import 'package:musee/init_dependencies.dart';

class PlayTrackPage extends StatefulWidget {
  final String trackId;

  const PlayTrackPage({super.key, required this.trackId});

  @override
  State<PlayTrackPage> createState() => _PlayTrackPageState();
}

class _PlayTrackPageState extends State<PlayTrackPage> {
  bool _handled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !_handled) {
        _handled = true;
        unawaited(_playTrackAndRedirect());
      }
    });
  }

  Future<void> _playTrackAndRedirect() async {
    final registry = serviceLocator<MusicProviderRegistry>();
    final track = await registry.getTrack(widget.trackId);

    if (!mounted) {
      return;
    }

    if (track == null) {
      showSnackBar(context, 'Could not load track.');
      context.go(Routes.dashboard);
      return;
    }

    final primaryArtist = track.artists.isNotEmpty ? track.artists.first : null;
    final artistsList = track.artists
        .map(
          (artist) => PlayerTrackArtist(
            id: artist.id,
            name: artist.name,
          ),
        )
        .toList();

    unawaited(
      context.read<PlayerCubit>().playTrackById(
        trackId: track.id,
        title: track.title,
        artist: track.artistName,
        album: track.albumTitle,
        imageUrl: track.imageUrl,
        artistId: primaryArtist?.id,
        albumId: track.albumId,
        artistsList: artistsList,
      ),
    );

    if (mounted) {
      context.go(Routes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}