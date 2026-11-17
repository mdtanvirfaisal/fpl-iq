import 'package:flutter/material.dart';
import '../../core/theme.dart';
import 'home_screen.dart';
import '../live/live_match_centre_screen.dart';
import '../advisor/ai_advisor_screen.dart';
import '../planner/planner_screen.dart';
import '../leagues/leagues_screen.dart';

class MainNavigationShell extends StatefulWidget {
  const MainNavigationShell({super.key});

  @override
  State<MainNavigationShell> createState() => _MainNavigationShellState();
}

class _MainNavigationShellState extends State<MainNavigationShell> {
  int _currentIndex = 0;

  final List<Widget> _screens = const [
    HomeScreen(),
    LiveMatchCentreScreen(),
    AiAdvisorScreen(managerId: 1),
    PlannerScreen(managerId: 1),
    LeaguesScreen(managerId: 1),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppTheme.surfaceVariant, width: 1),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _currentIndex,
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.fplGreen.withValues(alpha: 0.2),
          onDestinationSelected: (idx) {
            setState(() => _currentIndex = idx);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield, color: AppTheme.fplGreen),
              label: 'Squad',
            ),
            NavigationDestination(
              icon: Icon(Icons.sports_soccer_outlined),
              selectedIcon: Icon(Icons.sports_soccer, color: AppTheme.fplGreen),
              label: 'Live',
            ),
            NavigationDestination(
              icon: Icon(Icons.auto_awesome_outlined),
              selectedIcon: Icon(Icons.auto_awesome, color: AppTheme.fplGreen),
              label: 'Advisor',
            ),
            NavigationDestination(
              icon: Icon(Icons.swap_horiz_outlined),
              selectedIcon: Icon(Icons.swap_horiz, color: AppTheme.fplGreen),
              label: 'Planner',
            ),
            NavigationDestination(
              icon: Icon(Icons.leaderboard_outlined),
              selectedIcon: Icon(Icons.leaderboard, color: AppTheme.fplGreen),
              label: 'Leagues',
            ),
          ],
        ),
      ),
    );
  }
}
