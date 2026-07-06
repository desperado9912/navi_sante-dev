import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Home screen Floating search bar with user profile avatar.
class HeaderSearch extends StatefulWidget {
  const HeaderSearch({super.key});

  @override
  State<HeaderSearch> createState() => _HeaderSearchState();
}

class _HeaderSearchState extends State<HeaderSearch> {

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Container(
          height: 54,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.90),
            borderRadius: BorderRadius.circular(27),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(27),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Padding(
                padding: const EdgeInsets.only(left: 15, right: 8),
                child: Row(
                  children: [
                    const Icon(
                      CupertinoIcons.search,
                      color: Color(0xFF5F6368),
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search hospitals, pharmacies, clinics',
                          hintStyle: TextStyle(
                            color: Color(0xFF5F6368),
                            fontSize: 15,
                            fontWeight: FontWeight.w400,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                        style: TextStyle(fontSize: 15, color: Colors.black87),
                      ),
                    ),

                    // Build account Profile avatar
                    const _SearchBarAvatar(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Profile avatar / initilas init class
class _SearchBarAvatar extends StatelessWidget {
  const _SearchBarAvatar();

  String _initials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '';
    final name = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        // Read the current session on every auth event (name change, refresh, etc.)
        final user = Supabase.instance.client.auth.currentUser;
        final customName =
            (user?.userMetadata?['custom_display_name'] as String?) ?? '';
        final fullName = (user?.userMetadata?['full_name'] as String?) ?? '';
        final resolvedName = customName.isNotEmpty ? customName : fullName;
        final email = user?.email ?? '';

        // Use name if available, otherwise fall back to email for initials.
        final source = resolvedName.isNotEmpty ? resolvedName : email;
        final initials = _initials(source);
        final bool hasInitials = initials.isNotEmpty;

        return Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF2A7D8F).withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: hasInitials
              ? Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2A7D8F),
                      height: 1,
                    ),
                  ),
                )
              // Fallback: no session yet or anonymous user
              : const Icon(
                  CupertinoIcons.profile_circled,
                  color: Color(0xFF5F6368),
                  size: 39,
                ),
        );
      },
    );
  }
}
