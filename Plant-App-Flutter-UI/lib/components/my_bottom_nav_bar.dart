import 'package:flutter/material.dart';
import 'package:urbangreen/constants.dart';

class MyBottomNavBar extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onItemTapped;

  const MyBottomNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? kDarkSurfaceColor : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? kDarkBorderSubtle : Colors.transparent,
            width: 1,
          ),
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                context: context,
                index: 0,
                icon: Icons.yard_outlined,
                activeIcon: Icons.yard,
                label: 'Garden',
              ),
              _buildNavItem(
                context: context,
                index: 1,
                icon: Icons.sensors_outlined,
                activeIcon: Icons.sensors,
                label: 'Sensors',
              ),
              const SizedBox(width: 48), // Space for floating center AI scanner button
              _buildNavItem(
                context: context,
                index: 2,
                icon: Icons.storefront_outlined,
                activeIcon: Icons.storefront,
                label: 'Shop',
              ),
              _buildNavItem(
                context: context,
                index: 3,
                icon: Icons.account_circle_outlined,
                activeIcon: Icons.account_circle,
                label: 'Profile',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = selectedIndex == index;
    final activeColor = isDark ? kSecondaryColor : kPrimaryColor;
    final inactiveColor = isDark ? kDarkTextSecondary : kTextSecondary;
    final activeBg = isDark
        ? kPrimaryLight.withValues(alpha: 0.22)
        : kAccentMint.withValues(alpha: 0.6);

    return GestureDetector(
      onTap: () => onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              size: 22,
              color: isSelected ? activeColor : inactiveColor,
            ),
            if (isSelected) ...[
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: activeColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
