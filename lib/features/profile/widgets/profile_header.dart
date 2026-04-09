import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controllers/profile_controller.dart';

/// Profile header section.
///
/// Displays:
/// - Avatar with initials fallback (image upload wired in future sprint)
/// - Display name from [user_metadata.full_name]
/// - Email verified badge (derived from [emailConfirmedAt])
/// - Health score with trend indicator (placeholder via [ProfileController])
class ProfileHeader extends StatelessWidget {
  final ProfileController controller;

  const ProfileHeader({super.key, required this.controller});

  /// Derives initials from a full name.
  /// "John Doe" → "JD"   |   "Alice" → "A"   |   "" → "?"
  String _initials(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return '?';
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final fullName = (user?.userMetadata?['full_name'] as String?) ?? '';
    final email = user?.email ?? '';
    final displayName = fullName.isNotEmpty ? fullName : email;
    final isVerified = user?.emailConfirmedAt != null;
    final initials = _initials(fullName.isNotEmpty ? fullName : email);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          // ── Avatar ────────────────────────────────────────────
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: const Color(0xFF2A7D8F).withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2A7D8F).withOpacity(0.25),
                width: 2,
              ),
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2A7D8F),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Display name ────────────────────────────────────────
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // ── Email verified badge ────────────────────────────────
          if (isVerified)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF2A7D8F),
                  size: 15,
                ),
                SizedBox(width: 4),
                Text(
                  'Email Verified',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF2A7D8F),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFFF0F0F0), height: 1),
          const SizedBox(height: 18),

          // ── Health Score ────────────────────────────────────────
          ListenableBuilder(
            listenable: controller,
            builder: (context, _) => Column(
              children: [
                const Text(
                  'Health Score',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF5F6368),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Score number
                    Text(
                      controller.healthScore.toStringAsFixed(0),
                      style: const TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2A7D8F),
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Trend indicator
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Icon(
                            controller.isTrendPositive
                                ? Icons.trending_up_rounded
                                : Icons.trending_down_rounded,
                            color: controller.isTrendPositive
                                ? const Color(0xFF2A7D8F)
                                : const Color(0xFFC0392B),
                            size: 18,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '${controller.isTrendPositive ? '+' : '-'}'
                            '${controller.healthScoreTrend}%',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: controller.isTrendPositive
                                  ? const Color(0xFF2A7D8F)
                                  : const Color(0xFFC0392B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
