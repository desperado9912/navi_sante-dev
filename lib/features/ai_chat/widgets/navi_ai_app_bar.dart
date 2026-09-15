import 'package:flutter/material.dart';
import 'ai_chat_style.dart';

/// Same chrome as [PlatformAdaptiveAppBar] plus the history clock.
/// That shared bar has no `actions` slot — do not change it.
class NaviAiAppBar extends StatelessWidget implements PreferredSizeWidget {
  const NaviAiAppBar({super.key, required this.onHistoryTap});

  final VoidCallback onHistoryTap;

  @override
  Size get preferredSize => const Size.fromHeight(58);

  @override
  Widget build(BuildContext context) {
    final cupertino =
        Theme.of(context).platform == TargetPlatform.iOS ||
        Theme.of(context).platform == TargetPlatform.macOS;
    return AppBar(
      toolbarHeight: 58,
      centerTitle: cupertino,
      title: const Padding(
        padding: EdgeInsets.only(top: 10),
        child: Text(
          'Navi AI',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: Color(0xFF1A1A1A),
            fontSize: 18,
          ),
        ),
      ),
      backgroundColor: kNaviChatBg,
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: [
        Padding(
          padding: const EdgeInsets.only(top: 6, right: 4),
          child: IconButton(
            tooltip: t(context, 'Chat history', 'Historique'),
            onPressed: onHistoryTap,
            icon: const Icon(Icons.access_time_rounded, color: Color(0xFF1A1A1A)),
          ),
        ),
      ],
    );
  }
}
