import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_bloc.dart';
import 'package:musee/features/cast/presentation/bloc/cast_state.dart';
import 'cast_pairing_sheet.dart';

class CastButton extends StatelessWidget {
  final double size;
  final Color? color;

  const CastButton({
    super.key,
    this.size = 24.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CastBloc, CastState>(
      builder: (context, state) {
        final isCasting = state is CastActive;
        final theme = Theme.of(context);
        final cs = theme.colorScheme;
        final activeColor = cs.primary;
        final inactiveColor = color ?? cs.onSurfaceVariant;

        return IconButton(
          iconSize: size,
          tooltip: isCasting ? 'Casting active' : 'Cast or Sync',
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
              key: ValueKey(isCasting),
              color: isCasting ? activeColor : inactiveColor,
              size: size,
            ),
          ),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => const CastPairingSheet(),
            );
          },
        );
      },
    );
  }
}
