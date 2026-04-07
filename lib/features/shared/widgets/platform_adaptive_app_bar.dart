import 'package:flutter/material.dart';

class PlatformAdaptiveAppBar extends StatelessWidget implements PreferredSizeWidget {
  const PlatformAdaptiveAppBar({
    super.key,
    required this.title,
    this.backgroundColor = const Color(0xFFF8F9F8),
  });

  final String title;
  final Color backgroundColor;

  static const double _kToolbarHeight = 64;

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
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
      ),
      backgroundColor: backgroundColor,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
    );
  }
}
