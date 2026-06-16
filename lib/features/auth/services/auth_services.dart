import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import "package:supabase_flutter/supabase_flutter.dart";

// Handles all authentication providers and backend api services for auth.
class AuthServices {
  // Prevents OAuth services to overwrite User's Display Name
  String get currentDisplayName {
    final meta = _supabase.auth.currentUser?.userMetadata;
    final custom = meta?['custom_display_name'] as String?;
    if (custom != null && custom.trim().isNotEmpty) return custom;
    final fullName = meta?['full_name'] as String?;
    return fullName ?? '';
  }

  // 1. SUPABASE CLIENT
  final _supabase = Supabase.instance.client;

  //sign in with email & password
  Future<AuthResponse> signInWithEmailPassword(
    String email,
    String password,
  ) async {
    return await _supabase.auth.signInWithPassword(
      email: email.toLowerCase(),
      password: password,
    );
  }

  //sign up with email & password
  Future<AuthResponse> signUpWithEmailPassword(
    String email,
    String password, {
    required String fullName,
  }) async {
    return await _supabase.auth.signUp(
      email: email.toLowerCase(),
      password: password,
      data: {'full_name': fullName, 'custom_display_name': fullName},
    );
  }

  //sign out with local scope
  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  //signout with global scope
  Future<void> signOutGlobal() async {
    await _supabase.auth.signOut(scope: SignOutScope.global);
  }

  // Update display name (in app settings)
  Future<void> updateDisplayName(String newName) async {
    await _supabase.auth.updateUser(
      UserAttributes(data: {'custom_display_name': newName}),
    );
  }

  //current session check
  bool get hasSession => _supabase.auth.currentSession != null;

  // 2. GOOGLE OAUTH CLIENT
  //sign in / continue with Google
  Future<AuthResponse> nativeGoogleSignIn() async {
    final GoogleSignInAccount? googleUser;
    try {
      googleUser = await GoogleSignIn.instance.authenticate();
    } on PlatformException catch (e) {
      debugPrint(
        '[AuthServices] Google PlatformException: ${e.code} - ${e.message}',
      );
      if (e.code == 'sign_in_canceled') {
        throw Exception('Sign In process aborted.');
      }
      rethrow;
    } catch (e) {
      debugPrint('[AuthServices] Google authenticate exception: $e');
      rethrow;
    }

    final String? idToken = googleUser.authentication.idToken;

    if (idToken == null) {
      throw Exception('Failed to retrieve ID token.');
    }

    final response = await _supabase.auth.signInWithIdToken(
      provider: OAuthProvider.google,
      idToken: idToken,
    );

    // Seed user metadata from OAuth provider for brand-new OAuth users only.
    // but keep already existing users' metadata
    final user = response.user;
    if (user != null) {
      final existing = user.userMetadata?['custom_display_name'] as String?;
      if (existing == null || existing.trim().isEmpty) {
        final googleName = user.userMetadata?['full_name'] as String? ?? '';
        if (googleName.isNotEmpty) {
          await _supabase.auth.updateUser(
            UserAttributes(data: {'custom_display_name': googleName}),
          );
        }
      }
    }

    return response;
  }

  // 3. APPLE CLIENT
  // TODO: sign in / continue with Apple
}
