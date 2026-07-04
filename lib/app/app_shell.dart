import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/app_theme_colors.dart';
import '../features/calendar/presentation/screens/calendar_screen.dart';
import '../features/communications/presentation/screens/communications_screen.dart';
import '../features/home/presentation/screens/home_screen.dart';
import '../features/lineup/presentation/screens/lineup_screen.dart';
import '../features/settings/presentation/screens/settings_screen.dart';
import '../features/store/presentation/screens/store_screen.dart';

/// Main app shell with bottom navigation
class AppShell extends StatefulWidget {
  final VoidCallback onLogout;
  const AppShell({super.key, required this.onLogout});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _currentIndex = 0;

  void _navigateTo(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _handleHomeNavigation(int actionIndex) {
    // Map quick action indexes to specific screens
    switch (actionIndex) {
      case 1: // Calendar tab
        _navigateTo(1);
        break;
      case 2: // Lineup (Formación) tab
        _navigateTo(2);
        break;
      case 3: // Noticias tab
        _navigateTo(3);
        break;
      case 4: // Results tab
        _navigateTo(4);
        break;
      case 5: // Settings tab
        _navigateTo(5);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: _buildScreen(),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildScreen() {
    switch (_currentIndex) {
      case 0:
        return HomeScreen(
          key: const ValueKey('home'),
          onNavigate: _handleHomeNavigation,
        );
      case 1:
        return const CalendarScreen(key: ValueKey('calendar'));
      case 2:
        return const LineupScreen(key: ValueKey('lineup'));
      case 3:
        return const CommunicationsScreen(key: ValueKey('communications'));
      case 4:
        return const StoreScreen(key: ValueKey('store'));
      case 5:
        return SettingsScreen(
          key: const ValueKey('settings'),
          onLogout: widget.onLogout,
        );
      default:
        return HomeScreen(
          key: const ValueKey('home'),
          onNavigate: _handleHomeNavigation,
        );
    }
  }

  Widget _buildBottomNav() {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: (index) {
        HapticFeedback.selectionClick();
        _navigateTo(index);
      },
      backgroundColor: context.colors.surface,
      indicatorColor: context.colors.primary.withValues(alpha: 0.1),
      elevation: 0,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      destinations: [
        NavigationDestination(
          icon: Icon(Icons.home_outlined, color: context.colors.textSecondary),
          selectedIcon: Icon(Icons.home, color: context.colors.primary),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.calendar_month_outlined, color: context.colors.textSecondary),
          selectedIcon: Icon(Icons.calendar_month, color: context.colors.primary),
          label: 'Calendario',
        ),
        NavigationDestination(
          icon: Icon(Icons.sports_soccer_outlined, color: context.colors.textSecondary),
          selectedIcon: Icon(Icons.sports_soccer, color: context.colors.primary),
          label: 'Formación',
        ),
        NavigationDestination(
          icon: Badge(
            child: Icon(Icons.campaign_outlined, color: context.colors.textSecondary),
          ),
          selectedIcon: Badge(
            child: Icon(Icons.campaign, color: context.colors.primary),
          ),
          label: 'Noticias',
        ),
        NavigationDestination(
          icon: Icon(Icons.storefront_outlined, color: context.colors.textSecondary),
          selectedIcon: Icon(Icons.storefront, color: context.colors.primary),
          label: 'Tienda',
        ),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined, color: context.colors.textSecondary),
          selectedIcon: Icon(Icons.settings, color: context.colors.primary),
          label: 'Más',
        ),
      ],
    );
  }
}
