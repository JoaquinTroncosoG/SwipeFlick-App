import 'package:flutter/material.dart';
import 'package:swipeflick/core/constants/app_colors.dart';
import 'package:swipeflick/ui/features/favorites/screens/favorites_screen.dart';
import 'package:swipeflick/ui/features/home/screens/home_screen.dart';
import 'package:swipeflick/ui/features/profile/screens/profile_screen.dart';
import 'package:swipeflick/ui/features/room/screens/room_hub_screen.dart';
import 'package:swipeflick/ui/features/swipe/screens/solo_swipe_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  void _navigateToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> screens = [
      HomeScreen(
        onStartSoloSwipe: () => _navigateToTab(1),
        onOpenRoomsTab: () => _navigateToTab(2),
      ),
      const SoloSwipeScreen(),
      const RoomHubScreen(),
      FavoritesScreen(
        onGoToSwipe: () => _navigateToTab(1),
      ),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(top: BorderSide(color: AppColors.surfaceBorder, width: 0.8)),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _navigateToTab,
          backgroundColor: AppColors.surface,
          indicatorColor: AppColors.accent.withValues(alpha: 0.18),
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.home_rounded, color: AppColors.accent),
              label: 'Inicio',
            ),
            NavigationDestination(
              icon: Icon(Icons.swipe_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.swipe_rounded, color: AppColors.accent),
              label: 'Deslizar',
            ),
            NavigationDestination(
              icon: Icon(Icons.people_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.people_alt_rounded, color: AppColors.accent),
              label: 'Salas',
            ),
            NavigationDestination(
              icon: Icon(Icons.bookmark_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.bookmark_rounded, color: AppColors.accent),
              label: 'Biblioteca',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded, color: AppColors.textSecondary),
              selectedIcon: Icon(Icons.person_rounded, color: AppColors.accent),
              label: 'Perfil',
            ),
          ],
        ),
      ),
    );
  }
}
