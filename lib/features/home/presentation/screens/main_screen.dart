import 'dart:io';
import 'package:build_up/features/insight/presentation/insights_screen.dart';
import 'package:build_up/features/step_tracking/presentation/screens/gps_tracking_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../settings/presentation/setting_screen.dart';
import '../../../social/presentation/screens/social_screen.dart';
import '../../../step_tracking/presentation/screens/dashboard_screen.dart';

class MainNavigationScreen extends ConsumerStatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  ConsumerState<MainNavigationScreen> createState() =>
      _MainNavigationScreenState();
}

class _MainNavigationScreenState extends ConsumerState<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardView(),
    InsightsScreen(),
    ChallengeScreen(),
    GpsTrackingScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      extendBody: false,
      body: _screens[_currentIndex],
      bottomNavigationBar: Container(
        height: 90,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF141618),
            borderRadius: BorderRadius.circular(40),
            border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavItem(0, Icons.home_filled),
              _buildNavItem(1, Icons.auto_graph_rounded),
              _buildNavItem(2, Icons.groups_rounded),
              _buildNavItem(3, Icons.location_on),
              _buildNavItem(4, Icons.settings),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon) {
    final isSelected = _currentIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primaryEmerald : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: isSelected ? Colors.black : AppColors.textSecondary,
          size: 24,
        ),
      ),
    );
  }
}
