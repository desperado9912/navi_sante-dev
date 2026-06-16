// Centralized exception and errors-to-human-message mapper.
//
// Translates raw debug, Supabase, auth, network, and general exceptions
// into user-friendly messages with appropriate [FeedbackType] categorization.
// Prevents debug strings from ever reaching the UI.

import 'app_error_ui.dart';

class MappedError {
  final String message;
  final FeedbackType type;

  const MappedError(this.message, this.type);
}

class AppErrorMapper {
  AppErrorMapper._();

  // Auth errors (login / signup / OAuth)
  static MappedError mapAuthError(String raw) {
    final msg = raw.toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return const MappedError(
        'Incorrect email or password.',
        FeedbackType.error,
      );
    }
    if (msg.contains('email not confirmed')) {
      return const MappedError(
        'Please verify your email before logging in.',
        FeedbackType.warning,
      );
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists') ||
        msg.contains('duplicate')) {
      return const MappedError(
        'An account with this email may already exist.',
        FeedbackType.error,
      );
    }
    if (msg.contains('password should be at least')) {
      return const MappedError(
        'Password must be at least 8 characters.',
        FeedbackType.error,
      );
    }
    if (msg.contains('unable to validate email')) {
      return const MappedError(
        'Please enter a valid email address.',
        FeedbackType.error,
      );
    }
    if (msg.contains('email rate limit') || msg.contains('rate limit')) {
      return const MappedError(
        'Too many attempts. Please wait a moment and try again.',
        FeedbackType.warning,
      );
    }

    // Catch-all: never return the raw string
    return const MappedError(
      'Something went wrong. Please try again.',
      FeedbackType.error,
    );
  }

  // Password change and update
  static String mapPasswordError(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Current password is incorrect.';
    }
    if (msg.contains('same_password') ||
        msg.contains('new password should be different') ||
        msg.contains('should be different from the old password')) {
      return 'New password must be different from your current password.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 8 characters.';
    }
    if (msg.contains('no user session') ||
        msg.contains('session expired') ||
        msg.contains('not authenticated')) {
      return 'Your session has expired. Please log in again.';
    }
    if (_isNetworkError(msg)) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    return 'Failed to update password. Please try again.';
  }

  // Account deletion errors
  static String mapDeleteAccountError(Object error) {
    final msg = error.toString().toLowerCase();

    if (msg.contains('account deletion failed')) {
      return 'Unable to delete account. Please try again or contact support.';
    }
    if (msg.contains('no user session') || msg.contains('not authenticated')) {
      return 'Your session has expired. Please log in again.';
    }
    if (_isNetworkError(msg)) {
      return 'Unable to connect. Please check your internet connection and try again.';
    }

    return 'Unable to delete account. Please try again or contact support.';
  }

  // General catch-all mapper
  static MappedError mapGeneral(Object error) {
    final msg = error.toString().toLowerCase();

    if (_isNetworkError(msg)) {
      return const MappedError(
        'Unable to connect. Please check your internet connection and try again.',
        FeedbackType.warning,
      );
    }
    if (msg.contains('no user session') ||
        msg.contains('session expired') ||
        msg.contains('not authenticated')) {
      return const MappedError(
        'Your session has expired. Please log in again.',
        FeedbackType.warning,
      );
    }

    return const MappedError(
      'Something went wrong. Please try again.',
      FeedbackType.error,
    );
  }

  // Network error detection
  static bool _isNetworkError(String msg) {
    return msg.contains('socketexception') ||
        msg.contains('connection refused') ||
        msg.contains('connection timed out') ||
        msg.contains('network is unreachable') ||
        msg.contains('handshakeexception') ||
        msg.contains('no internet') ||
        msg.contains('failed host lookup') ||
        msg.contains('clientexception');
  }
}
