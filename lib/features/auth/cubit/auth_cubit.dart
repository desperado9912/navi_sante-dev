import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_services.dart';
import '../../../core/utils/auth_email_validator.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthServices _authServices;

  AuthCubit({AuthServices? authServices})
    : _authServices = authServices ?? AuthServices(),
      super(const AuthInitial());

  static final _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
  );


  // ── Login ──────────────────────────────────────────────────────
  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());
    final formatError = _emailRegex.hasMatch(email.trim().toLowerCase())
        ? null
        : 'Please enter a valid email address.';

    if (formatError != null) {
      emit(AuthError(formatError));
      return;
    }
    try {
      final response = await _authServices.signInWithEmailPassword(
        email.trim().toLowerCase(),
        password,
      );

      if (response.user == null) {
        emit(const AuthError('Login failed. Please try again.'));
        return;
      }

      // Check if email is verified before allowing login
      if (response.user!.emailConfirmedAt == null) {
        emit(const AuthEmailNotVerified());
        return;
      }

      emit(const AuthSuccess());
    } on AuthException catch (e) {
      emit(AuthError(_mapAuthError(e.message)));
    } catch (error, stackTrace) {
      debugPrint('Unexpected Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      emit(const AuthError('An unexpected error occurred.'));
    }
  }

  // ── Sign Up ────────────────────────────────────────────────────
  Future<void> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    emit(const AuthLoading());
    try {
      // Normalize email to lowercase and sanitize metadata
      final normalizedEmail = email.trim().toLowerCase();
      final sanitizedFullName = _sanitizeMetadata(fullName.trim());

      // ── Email Validation (MUST happen BEFORE signup) ────────────
      // Validate: format + disposable domains + DNS reachability
      // This runs BEFORE creating the account to prevent orphaned records
      final emailError = await AppEmailValidator.validate(normalizedEmail);
      if (emailError != null) {
        emit(AuthError(emailError));
        return;
      }

      final response = await _authServices.signUpWithEmailPassword(
        normalizedEmail,
        password,
        fullName: sanitizedFullName,
      );

      final user = response.user;
      if (user == null) {
        emit(const AuthError('Sign up failed. Please try again.'));
        return;
      }

      // ── Duplicate Email Check (Enumeration Protection) ──────────
      // When "Enable email enumerations protection" is ON in Supabase,
      // signUp returns a 200 OK but with no identities if the email exists.
      final identities = user.identities;
      if (identities != null && identities.isEmpty) {
        emit(
          const AuthError(
            'Email address already exists. Please try with a different email address.',
          ),
        );
        return;
      }

      emit(const AuthEmailNotVerified());
    } on AuthException catch (e) {
      final errorMsg = e.message;
      debugPrint('📧 Signup Auth Exception: $errorMsg');

      // Handle cases where protection is OFF and it throws a direct error
      if (errorMsg.toLowerCase().contains('user already registered') ||
          errorMsg.toLowerCase().contains('already exists') ||
          errorMsg.toLowerCase().contains('duplicate')) {
        emit(
          const AuthError(
            'Email address already exists. Please try with a different email address.',
          ),
        );
      } else {
        emit(AuthError(_mapAuthError(errorMsg)));
      }
    } catch (error, stackTrace) {
      debugPrint('Unexpected Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      emit(const AuthError('An unexpected error occurred.'));
    }
  }

  // ── Forgot Password ────────────────────────────────────────────
  Future<void> sendPasswordReset({required String email}) async {
    emit(const AuthLoading());
    try {
      final normalizedEmail = email.trim().toLowerCase();
      await Supabase.instance.client.auth.resetPasswordForEmail(
        normalizedEmail,
      );
      // Always emit success to avoid email enumeration attacks for reset
      emit(const AuthSuccess());
    } on AuthException catch (e) {
      debugPrint('Password reset request: ${e.message}');
      emit(const AuthSuccess());
    } catch (error) {
      debugPrint('Password reset error: $error');
      emit(const AuthSuccess());
    }
  }

  void reset() => emit(const AuthInitial());

  // ── Sanitize metadata to prevent injection attacks ─────────────
  String _sanitizeMetadata(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  // ── Human-readable Supabase error messages ─────────────────────
  String _mapAuthError(String raw) {
    final msg = raw.toLowerCase();
    if (msg.contains('invalid login credentials') ||
        msg.contains('invalid credentials')) {
      return 'Incorrect email or password.';
    }
    if (msg.contains('email not confirmed')) {
      return 'Please verify your email before logging in.';
    }
    if (msg.contains('user already registered') ||
        msg.contains('already exists')) {
      return 'If an account exists with that email, a verification link has been sent.';
    }
    if (msg.contains('password should be at least')) {
      return 'Password must be at least 8 characters.';
    }
    if (msg.contains('unable to validate email')) {
      return 'Please enter a valid email address.';
    }
    if (msg.contains('email rate limit')) {
      return 'Too many attempts. Please wait a moment.';
    }
    return raw;
  }
}
