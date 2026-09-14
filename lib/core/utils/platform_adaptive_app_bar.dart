import 'package:flutter/material.dart';
import 'language_cubit/language_cubit.dart';

// Custom app bar used accross all widget screens.
// Replaces the default [AppBar] with a platform-specific design.
class PlatformAdaptiveAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  const PlatformAdaptiveAppBar({
    super.key,
    required this.title,
    this.backgroundColor = const Color(0xFFF8F9F8),
    this.titlePadding = const EdgeInsets.only(top: 10),
  });

  final String title;
  final Color backgroundColor;
  final EdgeInsetsGeometry titlePadding;

  static const double _kToolbarHeight = 58;

  bool _isCupertinoPlatform(TargetPlatform platform) {
    return platform == TargetPlatform.iOS || platform == TargetPlatform.macOS;
  }

  @override
  Size get preferredSize => const Size.fromHeight(_kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final platform = Theme.of(context).platform;
    final useCupertino = _isCupertinoPlatform(platform);

    return AppBar(
      toolbarHeight: _kToolbarHeight,
      centerTitle: useCupertino,
      title: Padding(
        padding: titlePadding,
        child: Text(
          context.tr(title),
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: Colors.black,
            fontSize: 18,
          ),
        ),
      ),
      backgroundColor: backgroundColor,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }
}
