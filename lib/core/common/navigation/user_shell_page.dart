import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';

class UserShellPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const UserShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width > 720;
    final theme = Theme.of(context);

    final bottomNavBar = BottomNavBar(
      selectedIndex: _selectedIndexFromBranch(navigationShell.currentIndex),
      onItemSelected: (index) {
        final branchIndex = _branchIndexFromNav(index);
        if (branchIndex == null) return;

        if (branchIndex == 3) {
          context.go('/create?fresh=${DateTime.now().microsecondsSinceEpoch}');
          return;
        }

        navigationShell.goBranch(
          branchIndex,
          initialLocation: index == 1,
        );
      },
      onItemReselected: (index) {
        if (index == 0) {
          navigationShell.goBranch(0, initialLocation: true);
        } else if (index == 1) {
          navigationShell.goBranch(1, initialLocation: true);
        } else if (index == 4) {
          context.go('/create?fresh=${DateTime.now().microsecondsSinceEpoch}');
        }
      },
    );

    if (isWide) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              bottom: 0.0,
              child: navigationShell,
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: bottomNavBar,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: navigationShell,
      bottomNavigationBar: bottomNavBar,
    );
  }

  int _selectedIndexFromBranch(int branchIndex) {
    switch (branchIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 3:
        return 4;
      default:
        return 0;
    }
  }

  int? _branchIndexFromNav(int navIndex) {
    switch (navIndex) {
      case 0:
        return 0;
      case 1:
        return 1;
      case 2:
        return 2;
      case 4:
        return 3;
      default:
        return null;
    }
  }
}
