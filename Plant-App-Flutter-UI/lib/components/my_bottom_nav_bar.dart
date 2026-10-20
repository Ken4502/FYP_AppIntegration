import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final unselectedColor = theme.bottomNavigationBarTheme.unselectedItemColor;

    Widget buildNavItem(
        {required String iconPath,
        required int index,
        required String label}) {
      final color = selectedIndex == index ? primaryColor : unselectedColor;
      return IconButton(
        icon: SvgPicture.asset(
          iconPath,
          colorFilter: ColorFilter.mode(
            color ?? Colors.grey, // Fallback to grey
            BlendMode.srcIn,
          ),
          semanticsLabel: label,
        ),
        onPressed: () => onItemTapped(index),
      );
    }

    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8.0,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          buildNavItem(
              iconPath: "assets/icons/flower.svg",
              index: 0,
              label: 'Plants Management'),
          buildNavItem(
              iconPath: "assets/icons/iot_icon.svg",
              index: 1,
              label: 'IoT Management'),
          const SizedBox(width: kDefaultPaddingExtraLarge), // The space for the FAB
          buildNavItem(
              iconPath: "assets/icons/shopping_icon.svg",
              index: 2,
              label: 'E-commerce Shop'),
          buildNavItem(
              iconPath: "assets/icons/user-icon.svg",
              index: 3,
              label: 'Account'),
        ],
      ),
    );
  }
}
