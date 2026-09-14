import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';

/// Profile header section.
/// Displays:
/// - Avatar or initials fallback
/// - Display name and email from user metadata
/// - Email verified badge
class ProfileHeader extends StatelessWidget {
  const ProfileHeader({super.key});

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
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = Supabase.instance.client.auth.currentUser;
        final customName =
            (user?.userMetadata?['custom_display_name'] as String?) ?? '';
        final fullName = (user?.userMetadata?['full_name'] as String?) ?? '';
        final resolvedName = customName.isNotEmpty ? customName : fullName;
        final email = user?.email ?? '';
        final displayName = resolvedName.isNotEmpty ? resolvedName : email;
        final isVerified = user?.emailConfirmedAt != null;
        final initials = _initials(
          resolvedName.isNotEmpty ? resolvedName : email,
        );

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
              // Avatar container
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: const Color(0xFF2A7D8F).withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: const Color(0xFF2A7D8F).withValues(alpha: 0.25),
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

              // Username container
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

              // Email verified badge
              if (isVerified)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.verified_rounded,
                      color: CupertinoColors.systemBlue,
                      size: 15,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      context.t('Email Verified', 'Email vérifié'),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
