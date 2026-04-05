import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SecurityLogger {
  SecurityLogger._();

  static final _db = Supabase.instance.client;

  static const loginSuccess         = 'login_success';
  static const loginFailure         = 'login_failure';
  static const signupSuccess        = 'signup_success';
  static const signupFailure        = 'signup_failure';
  static const passwordResetRequest = 'password_reset_requested';
  static const emailNotVerified     = 'login_email_not_verified';
  static const disposableEmail      = 'signup_disposable_email_blocked';
  static const tokenRefreshed       = 'token_refreshed';
  static const sessionExpired       = 'session_expired';
  static const signOut              = 'sign_out';

  static Future<void> log({
    required String eventType,
    String? email,
    String? userId,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final currentUser = _db.auth.currentUser;
      await _db.from('security_logs').insert({
        'event_type': eventType,
        'user_id':    userId ?? currentUser?.id,
        'email':      email ?? currentUser?.email,
        'metadata':   metadata ?? {},
      });
    } catch (e) {
      debugPrint('[SecurityLogger] Failed to write log: $e');
    }
  }
}