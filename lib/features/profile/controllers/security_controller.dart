import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/utils/security_logger.dart';

/// Controller responsible for managing account security settings,
/// including checking active login providers, changing passwords,
/// linking credentials for OAuth users, and performing secure account deletion.
class SecurityController extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Evaluates authentication providers list of the current user.
  /// Returns [true] if the user has an email/password credential.
  bool checkHasPassword() {
    final user = _supabase.auth.currentUser;
    if (user == null) return false;

    // Check identities first
    final identities = user.identities ?? [];
    final hasEmailIdentity = identities.any((id) => id.provider == 'email');
    if (hasEmailIdentity) return true;

    // Check app metadata providers list
    final providers = user.appMetadata['providers'] as List<dynamic>? ?? [];
    if (providers.contains('email')) return true;

    // Check local metadata flag (set during password linking for OAuth users)
    final userMetadata = user.userMetadata ?? {};
    if (userMetadata['password_linked'] == true) return true;

    return false;
  }

  /// Updates existing password for standard email/password users.
  /// Enforces re-authentication using the [currentPassword] before updating.
  Future<void> updatePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user session active.');
      }

      // Re-authenticate user to prevent session hijacking
      await _supabase.auth.signInWithPassword(
        email: user.email!,
        password: currentPassword,
      );

      // Perform standard password update
      await _supabase.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Refresh session to rotate tokens cleanly
      await _supabase.auth.refreshSession();

      // Log success event
      await SecurityLogger.log(
        eventType: 'password_updated_success',
        userId: user.id,
        email: user.email,
        metadata: {'flow': 'change_password_reauth'},
      );
    } catch (e) {
      // Log failure event
      final user = _supabase.auth.currentUser;
      await SecurityLogger.log(
        eventType: 'password_updated_failure',
        userId: user?.id,
        email: user?.email,
        metadata: {'error': e.toString()},
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Binds/links a password credential to an OAuth-only user.
  /// Updates the password hash on the active social user account.
  Future<void> linkPassword({required String newPassword}) async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null || user.email == null) {
        throw Exception('No user session active.');
      }

      // Update password directly (binds email/password authentication capabilities)
      // Also set a metadata flag to persist UI state immediately
      await _supabase.auth.updateUser(
        UserAttributes(
          password: newPassword,
          data: {'password_linked': true},
        ),
      );

      // Refresh session to rotate tokens cleanly and force providers sync
      await _supabase.auth.refreshSession();

      // Log success event
      await SecurityLogger.log(
        eventType: 'password_linked_success',
        userId: user.id,
        email: user.email,
        metadata: {'flow': 'oauth_password_link'},
      );
    } catch (e) {
      final user = _supabase.auth.currentUser;
      await SecurityLogger.log(
        eventType: 'password_linked_failure',
        userId: user?.id,
        email: user?.email,
        metadata: {'error': e.toString()},
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// Handles secure user account drop and purges all credentials,
  /// clears Hive caches, and signs out locally.
  Future<void> deleteAccount() async {
    _setLoading(true);
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        throw Exception('No user session active.');
      }

      final userId = user.id;
      final userEmail = user.email;

      // 1. Delete user row in public.users (fail silently if it fails)
      try {
        await _supabase.from('users').delete().eq('id', userId);
      } catch (e) {
        debugPrint('[SecurityController] Failed to delete public user row: $e');
      }

      // 2. Call secure user drop database RPC
      try {
        await _supabase.rpc('delete_user');
      } catch (e) {
        debugPrint('[SecurityController] delete_user RPC failed: $e. Retrying delete_user_account...');
        try {
          await _supabase.rpc('delete_user_account');
        } catch (e2) {
          debugPrint('[SecurityController] delete_user_account RPC failed: $e2');
          throw Exception('Backend account deletion function is missing in Supabase. Account was not deleted.');
        }
      }

      // 3. Clear Hive Caches
      for (final name in ['app_cache', 'news_cache']) {
        if (Hive.isBoxOpen(name)) {
          await Hive.box(name).clear();
        }
      }

      // 4. Log security event
      await SecurityLogger.log(
        eventType: 'account_deletion_success',
        userId: userId,
        email: userEmail,
        metadata: {'deleted_at': DateTime.now().toIso8601String()},
      );

      // 5. Sign out locally to wipe tokens and notify AuthGate
      await _supabase.auth.signOut(scope: SignOutScope.local);
    } catch (e) {
      final user = _supabase.auth.currentUser;
      await SecurityLogger.log(
        eventType: 'account_deletion_failure',
        userId: user?.id,
        email: user?.email,
        metadata: {'error': e.toString()},
      );
      rethrow;
    } finally {
      _setLoading(false);
    }
  }
}
