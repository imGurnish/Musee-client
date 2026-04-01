import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:musee/core/common/widgets/bottom_nav_bar.dart';

class UserShellPage extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const UserShellPage({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndexFromBranch(navigationShell.currentIndex),
        onItemSelected: (index) {
          final branchIndex = _branchIndexFromNav(index);
          if (branchIndex == null) return;

          navigationShell.goBranch(branchIndex);
        },
        onItemReselected: (index) {
          if (index == 0) {
            navigationShell.goBranch(0, initialLocation: true);
          }
        },
      ),
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
