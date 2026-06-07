import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';

class BottomBarSpacing extends StatelessWidget {
  final double mobileHeight;

  const BottomBarSpacing({super.key, this.mobileHeight = 16.0});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    if (!isWide) {
      return SizedBox(height: mobileHeight);
    }

    final playerCubit = GetIt.I<PlayerCubit>();
    return BlocBuilder<PlayerCubit, PlayerViewState>(
      bloc: playerCubit,
      builder: (context, state) {
        final hasTrack = state.track != null;
        final barHeight = hasTrack ? 136.0 : 68.0;
        return SizedBox(height: barHeight + 24.0); // Adds slightly more buffer for comfort
      },
    );
  }
}

class SliverBottomBarSpacing extends StatelessWidget {
  final double mobileHeight;

  const SliverBottomBarSpacing({super.key, this.mobileHeight = 16.0});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: BottomBarSpacing(mobileHeight: mobileHeight),
    );
  }
}
