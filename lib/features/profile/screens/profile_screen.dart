import 'dart:io' show Platform;
import 'package:navi_sante/features/navigation_menu.dart' show navBottomPadding;
import 'package:share_plus/share_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:navi_sante/features/profile/screens/account_info.dart';
import 'package:navi_sante/features/profile/screens/saved_facilities.dart';
import 'package:navi_sante/features/profile/screens/security_screen.dart';
import 'package:navi_sante/features/profile/screens/notifications_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../features/auth/cubit/auth_cubit.dart';
import '../controllers/profile_controller.dart';
import '../widgets/language_sheet.dart';
import '../widgets/profile_header.dart';
import '../widgets/settings_tiles.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _profileController = ProfileController();

  // Local language state only — app-level LanguageCubit will replace this.
  String _langCode = 'en';
  String get _langLabel => _langCode == 'en' ? 'English' : 'Français';

  // App metadata
  // Will be read from package_info_plus when version management is set up.
  static const _appVersion = 'V2.4.0.';
  static const _copyright = 'Copyright © 2026 NaviSanté';

  @override
  void initState() {
    super.initState();
    _profileController.loadHealthScore();
  }

  @override
  void dispose() {
    _profileController.dispose();
    super.dispose();
  }

  // ────────────────────────────────────────────────────────────────
  // Tiles Button Functions
  // ────────────────────────────────────────────────────────────────

  //language picker
  Future<void> _openLanguagePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => LanguageBottomSheet(currentCode: _langCode),
    );
    if (selected != null && mounted) {
      setState(() => _langCode = selected);
      // TODO: propagate to app-level LanguageCubit when localisation is built
    }
  }

  //URL launcher
  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    final canOpen = await canLaunchUrl(uri);
    if (!canOpen) {
      _showErrorSnackBar('Could not open the link.');
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // Store URL placeholders
  static const _androidStoreUrl =
      'https://play.google.com/store/apps'; // TODO: replace with real URL
  static const _iosStoreUrl =
      'https://apps.apple.com/app'; // TODO: replace with real URL

  //Share app button
  Future<void> _shareApp() async {
    final String appLink = Platform.isIOS ? _iosStoreUrl : _androidStoreUrl;

    await SharePlus.instance.share(
      ShareParams(
        text: 'NaviSanté Application: $appLink',
      )
    ); 
  }

  //Rate app button
  Future<void> _rateApp() async {
    final url = Platform.isIOS ? _iosStoreUrl : _androidStoreUrl;
    await _launchUrl(url);
  }

  //help & support button
  Future<void> _helpAndSupport(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'contact@navisante.com', //TODO: Add real contact email.
      queryParameters: {'subject': 'NaviSanté Contact'},
    );

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      // Show error message
      if (!context.mounted) return;
      _showErrorSnackBar('No email app found. Please contact contact@navisante.com directly.');
    }
  }

  //About Navisante button
  Future<void> _aboutNavisante(BuildContext context) async {
    final Uri webUri = Uri.parse('https://navisante.com/about'); //TODO: Replace with real about link

    if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.inAppWebView);
    } else{
      if (!context.mounted) return;
      _showErrorSnackBar('Could not open the link.');
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Logout
  // ────────────────────────────────────────────────────────────────

  //logout button
  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: const Text(
          'Are you sure you want to log out of your account?',
          style: TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                color: Color(0xFF888780),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text(
              'Log Out',
              style: TextStyle(
                color: Color(0xFFC0392B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _performLogout();
  }

  //perform logout Function
  Future<void> _performLogout() async {
    // Show non-dismissible loading overlay to prevent any interaction
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
        ),
      ),
    );

    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      // 1. Clear all Hive caches before signout
      for (final name in ['app_cache', 'news_cache']) {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
        }
      }

      // 2. Sign out — local scope (clears session on this device only)
      if (mounted) await context.read<AuthCubit>().logout();

      // AuthGate automatically redirects to /login after state change.
      navigator.pop(); // dismiss loader safely
    } catch (e) {
      //dismiss loader on error
      navigator.pop();
      if (mounted) {
        _showErrorSnackBar('Sign out failed. Please try again.');
      }
    }
  }

  // ────────────────────────────────────────────────────────────────
  // Navigation helpers
  // ────────────────────────────────────────────────────────────────

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: const Color(0xFF2A7D8F),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 2),
        ),
      );
  }

  // ────────────────────────────────────────────────────────────────
  // Language tile trailing widget
  // ────────────────────────────────────────────────────────────────
  Widget get _langTrailing => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF2A7D8F).withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _langLabel,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2A7D8F),
          ),
        ),
      ),
      const SizedBox(width: 6),
      const Icon(
        CupertinoIcons.chevron_right,
        size: 16,
        color: Color(0xFF888780),
      ),
    ],
  );

  // ────────────────────────────────────────────────────────────────
  // page Builder
  // ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 20, bottom: navBottomPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Profile header ──────────────────────────────
            ProfileHeader(controller: _profileController),
            const SizedBox(height: 24),

            // ── Section label ───────────────────────────────
            const Padding(
              padding: EdgeInsets.only(left: 24, bottom: 10),
              child: Text(
                'Settings',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888780),
                  letterSpacing: 0.5,
                ),
              ),
            ),

            // ── Group 1 ─────────────────────────────────────
            _TileGroup(
              children: [
                SettingsTile(
                  icon: CupertinoIcons.person,
                  title: 'Account Information',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const AccountInfo(),
                      ),
                    );
                  },
                ),

                SettingsTile(
                  icon: CupertinoIcons.bookmark,
                  title: 'Saved facilities',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const SavedFacilities(),
                      ),
                    );
                  },
                ),

                SettingsTile(
                  icon: CupertinoIcons.lock,
                  title: 'Security',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const SecurityScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 30),

            // ── Group 2 ─────────────────────────────────────
            _TileGroup(
              children: [
                SettingsTile(
                  icon: CupertinoIcons.bell,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.push(
                      context,
                      CupertinoPageRoute(
                        builder: (context) => const NotificationsScreen(),
                      ),
                    );
                  },
                ),

                SettingsTile(
                  icon: CupertinoIcons.globe,
                  title: 'Language',
                  onTap: _openLanguagePicker,
                  trailing: _langTrailing,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // ── Group 3 ─────────────────────────────────────
            _TileGroup(
              children: [
                SettingsTile(
                  icon: CupertinoIcons.question_circle,
                  title: 'Help & support',
                  onTap: () => _helpAndSupport(context),
                ),

                SettingsTile(
                  icon: CupertinoIcons.doc_text,
                  title: 'About NaviSanté',
                  onTap: () => _aboutNavisante(context),
                ),

                SettingsTile(
                  icon: CupertinoIcons.share,
                  title: 'Share NaviSanté',
                  onTap: _shareApp,
                ),

                SettingsTile(
                  icon: CupertinoIcons.chat_bubble_text,
                  title: 'Love the app? Rate us',
                  onTap: _rateApp,
                ),
              ],
            ),
            const SizedBox(height: 30),

            // ── Logout button ────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: OutlinedButton(
                onPressed: _confirmLogout,
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFC0392B),
                  side: const BorderSide(color: Color(0xFFC0392B), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  minimumSize: const Size(double.infinity, 52),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      CupertinoIcons.square_arrow_right,
                      size: 20,
                      color: Color(0xFFC0392B),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFC0392B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── Footer ───────────────────────────────────────
            Center(
              child: Column(
                children: const [
                  Text(
                    _copyright,
                    style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    _appVersion,
                    style: TextStyle(fontSize: 12, color: Color(0xFF888780)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Internal grouping widget
// ────────────────────────────────────────────────────────────────────────────

/// Wraps a list of [SettingsTile] widgets with consistent horizontal padding
/// and an 8px gap between each tile.
///
/// Private to this file — not exported as a reusable widget because it
/// has no meaning outside the settings screen context.
class _TileGroup extends StatelessWidget {
  final List<Widget> children;
  const _TileGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: List.generate(
          children.length * 2 - 1,
          (i) => i.isOdd ? const SizedBox(height: 8) : children[i ~/ 2],
        ),
      ),
    );
  }
}
