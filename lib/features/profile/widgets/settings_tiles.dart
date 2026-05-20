import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Atomic settings tile.
///
/// Accepts an [icon], [title], [onTap] callback, and an optional
/// [trailing] widget. Defaults to a chevron when trailing is null.
/// Contains no hardcoded labels, routes, or business logic.
class SettingsTile extends StatelessWidget {
  final IconData     icon;
  final String       title;
  final VoidCallback onTap;
  final Widget?      trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // ── Icon container ──────────────────────────────
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: const Color(0xFF2A7D8F), size: 22),
            ),
            const SizedBox(width: 14),

            // ── Title ────────────────────────────────────────
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),

            // ── Trailing ─────────────────────────────────────
            trailing ??
                const Icon(
                  CupertinoIcons.chevron_right,
                  size: 18,
                  color: Color(0xFF5F6368),
                ),
          ],
        ),
      ),
    );
  }
}