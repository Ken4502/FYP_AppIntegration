import 'package:flutter/material.dart';
import '../constants.dart';

/// A standardized, accessible circular back button with high contrast
/// and comfortable 40x40 touch target conforming to mobile UX guidelines.
class StandardBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;

  const StandardBackButton({
    super.key,
    this.onPressed,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultBg = isDark ? kDarkCardColor : kBackgroundColor;
    final defaultIcon = isDark ? kDarkTextPrimary : kTextPrimary;
    final defaultBorder = isDark ? kDarkBorderSubtle : kBorderSubtle;

    return Center(
      child: Material(
        color: backgroundColor ?? defaultBg,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed ?? () => Navigator.maybePop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: defaultBorder, width: 1.2),
            ),
            child: Icon(
              Icons.arrow_back_rounded,
              size: 22,
              color: iconColor ?? defaultIcon,
            ),
          ),
        ),
      ),
    );
  }
}

/// A standardized AppBar for the UrbanGreen application, providing:
/// - Consistent toolbar height (66-70dp) ensuring labels and back button are never cramped
/// - Standardized accessible circular back button
/// - Visual hierarchy: Bold prominent title + optional subtitle
/// - Seamless background matching botanical surface tokens
class StandardAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? titleWidget;
  final Widget? leading;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final double toolbarHeight;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Color? backgroundColor;

  const StandardAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.titleWidget,
    this.leading,
    this.actions,
    this.bottom,
    this.toolbarHeight = 68.0,
    this.showBackButton = true,
    this.onBack,
    this.backgroundColor,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(toolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canPop = ModalRoute.of(context)?.canPop ?? false;
    final shouldShowBack = showBackButton && (canPop || onBack != null);
    final titleColor = isDark ? kDarkTextPrimary : kTextPrimary;
    final subtitleColor = isDark ? kDarkTextSecondary : kTextSecondary;
    final defaultBg = isDark ? kDarkSurfaceColor : kSurfaceColor;

    Widget? effectiveLeading = leading;
    if (effectiveLeading == null && shouldShowBack) {
      effectiveLeading = Padding(
        padding: const EdgeInsets.only(left: 14),
        child: StandardBackButton(onPressed: onBack),
      );
    }

    Widget effectiveTitle = titleWidget ??
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 19,
                color: titleColor,
                letterSpacing: -0.3,
              ),
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 11,
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        );

    return AppBar(
      toolbarHeight: toolbarHeight,
      leadingWidth: shouldShowBack ? 62 : null,
      leading: effectiveLeading,
      automaticallyImplyLeading: false,
      titleSpacing: shouldShowBack ? 8 : 16,
      title: effectiveTitle,
      actions: actions,
      bottom: bottom,
      backgroundColor: backgroundColor ?? defaultBg,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }
}
