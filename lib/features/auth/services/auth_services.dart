import "package:supabase_flutter/supabase_flutter.dart";

class AuthServices {
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
      data: {'full_name': fullName},
    );
  }

  //sign in with Google

  //sign up with Google

  //sign in with Apple

  //sign up with Apple

  //sign out with local scope
  Future<void> signOut() async {
    await _supabase.auth.signOut(scope: SignOutScope.local);
  }

  //signout with global scope
  Future<void> signOutGlobal() async {
    await _supabase.auth.signOut(scope: SignOutScope.global);
  }

  //current session check
  bool get hasSession => _supabase.auth.currentSession != null;
}
