import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/floating_player_panel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int>? onItemSelected;
  final ValueChanged<int>? onItemReselected;

  const BottomNavBar({
    super.key,
    required this.selectedIndex,
    this.onItemSelected,
    this.onItemReselected,
  });

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cubit = GetIt.I<PlayerCubit>();

    return BlocListener<PlayerCubit, PlayerViewState>(
      bloc: cubit,
      listenWhen: (previous, current) {
        return previous.errorMessage != current.errorMessage &&
            current.errorMessage != null &&
            current.errorMessage!.trim().isNotEmpty;
      },
      listener: (context, state) {
        final message = state.errorMessage;
        if (message == null || message.trim().isEmpty) return;

        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;

        messenger
          ..hideCurrentSnackBar()
          ..hideCurrentMaterialBanner()
          ..showMaterialBanner(
            MaterialBanner(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              actions: [
                TextButton(
                  onPressed: messenger.hideCurrentMaterialBanner,
                  child: const Text('Dismiss'),
                ),
              ],
            ),
          );

        Future<void>.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          messenger.hideCurrentMaterialBanner();
        });
      },
      child: BlocBuilder<PlayerCubit, PlayerViewState>(
        bloc: cubit,
        builder: (context, state) {
          final hasTrack = state.track != null;
          final barHeight = hasTrack ? 136.0 : 68.0;
          final boxHeight = hasTrack ? 128.0 : 60.0;

          final screenWidth = MediaQuery.of(context).size.width;
          final isWide = screenWidth > 720;

          final Widget bar;

          if (isWide) {
            bar = Material(
              color: colorScheme.surfaceContainerHigh,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
                side: BorderSide(
                  color: colorScheme.onSurface.withValues(alpha: 0.12),
                  width: 1.0,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                height: barHeight,
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    if (hasTrack) const FloatingPlayerPanel(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: <Widget>[
                        _buildNavItem(
                          context,
                          Icons.home_outlined,
                          Icons.home,
                          0,
                          'Home',
                          '/dashboard',
                        ),
                        _buildNavItem(
                          context,
                          Icons.search_outlined,
                          Icons.search,
                          1,
                          'Search',
                          '/search',
                        ),
                        _buildNavItem(
                          context,
                          Icons.library_books_outlined,
                          Icons.library_books,
                          2,
                          'Your Library',
                          '/library',
                        ),
                        _buildNavItem(
                          context,
                          Icons.add_outlined,
                          Icons.add,
                          4,
                          'Create',
                          '/create',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          } else {
            bar = Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: colorScheme.onSurface.withValues(alpha: 0.12),
                    width: 1.0,
                  ),
                ),
              ),
              child: BottomAppBar(
                shape: const CircularNotchedRectangle(),
                notchMargin: 8.0,
                color: colorScheme.surfaceContainerHigh,
                elevation: 0,
                padding: const EdgeInsets.all(4),
                height: barHeight,
                child: SizedBox(
                  height: boxHeight,
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      if (hasTrack) const FloatingPlayerPanel(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: <Widget>[
                          _buildNavItem(
                            context,
                            Icons.home_outlined,
                            Icons.home,
                            0,
                            'Home',
                            '/dashboard',
                          ),
                          _buildNavItem(
                            context,
                            Icons.search_outlined,
                            Icons.search,
                            1,
                            'Search',
                            '/search',
                          ),
                          _buildNavItem(
                            context,
                            Icons.library_books_outlined,
                            Icons.library_books,
                            2,
                            'Your Library',
                            '/library',
                          ),
                          _buildNavItem(
                            context,
                            Icons.add_outlined,
                            Icons.add,
                            4,
                            'Create',
                            '/create',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          if (isWide) {
            return SizedBox(
              height: barHeight,
              child: Padding(
                padding: const EdgeInsets.only(left: 24.0, right: 24.0),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: bar,
                  ),
                ),
              ),
            );
          }
          return bar;
        },
      ),
    );
  }

  // Helper widget to build each navigation item to avoid code repetition.
  Widget _buildNavItem(
    BuildContext context,
    IconData unselectedIcon,
    IconData selectedIcon,
    int index,
    String tooltip,
    String route,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final isSelected = widget.selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () {
          if (isSelected) {
            widget.onItemReselected?.call(index);
            return;
          }

          if (widget.onItemSelected != null) {
            widget.onItemSelected!(index);
          } else {
            context.push(route);
          }
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 60,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected
                    ? colorScheme.primary
                    : colorScheme.onSurface.withAlpha(153),
                size: 24,
              ),
              const SizedBox(height: 4),
              Text(
                tooltip,
                style: TextStyle(
                  fontSize: 12,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurface.withAlpha(153),
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
