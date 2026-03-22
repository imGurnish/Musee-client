import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/floating_player_panel.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:musee/core/player/player_cubit.dart';
import 'package:musee/core/player/player_state.dart';

class BottomNavBar extends StatefulWidget {
  final int selectedIndex;
  const BottomNavBar({super.key, required this.selectedIndex});

  @override
  State<BottomNavBar> createState() => _BottomNavBarState();
}

class _BottomNavBarState extends State<BottomNavBar> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final cubit = GetIt.I<PlayerCubit>();

    return BlocBuilder<PlayerCubit, PlayerViewState>(
      bloc: cubit,
      builder: (context, state) {
        final hasTrack = state.track != null;
        final barHeight = hasTrack ? 180.0 : 68.0;
        final boxHeight = hasTrack ? 200.0 : 60.0;

        return BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8.0,
          color: colorScheme.surface,
          elevation: 8,
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
                    // _buildNavItem(
                    //   context,
                    //   Icons.money_outlined,
                    //   Icons.money,
                    //   3,
                    //   'Premium',
                    //   '/premium',
                    // ),
                    // _buildNavItem(
                    //   context,
                    //   Icons.add_outlined,
                    //   Icons.add,
                    //   4,
                    //   'Create',
                    //   '/create',
                    // ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
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
          if (!isSelected) {
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
