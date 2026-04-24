import 'package:flutter/material.dart';
import 'package:mobile/ui/core/widgets/app_bottom_nav_bar.dart';

class TabAccentStrip extends StatelessWidget {
  const TabAccentStrip({super.key, required this.tab});

  final AppBottomNavTab tab;

  @override
  Widget build(BuildContext context) {
    final accent = _tabAccentColor(tab);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        height: 8,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.92),
              accent.withValues(alpha: 0.42),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      ),
    );
  }
}

Color _tabAccentColor(AppBottomNavTab tab) {
  switch (tab) {
    case AppBottomNavTab.home:
      return const Color(0xFF4F7CFF);
    case AppBottomNavTab.search:
      return const Color(0xFF00A991);
    case AppBottomNavTab.messages:
      return const Color(0xFF8C5BFF);
    case AppBottomNavTab.profile:
      return const Color(0xFFFF6B4A);
  }
}
