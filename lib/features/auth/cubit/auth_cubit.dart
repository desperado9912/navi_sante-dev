import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_services.dart';
import '../widgets/auth_email_validator.dart';
import '../../../core/utils/security_logger.dart';
import '../../../core/utils/app_error_mapper.dart';

part 'auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthServices _authServices;

  AuthCubit({AuthServices? authServices})
    : _authServices = authServices ?? AuthServices(),
      super(const AuthInitial());

  // ── Login ──────────────────────────────────────────────────────
  Future<void> login({required String email, required String password}) async {
    emit(const AuthLoading());

    final normalizedEmail = email.trim().toLowerCase();

    if (!emailRegex.hasMatch(normalizedEmail)) {
      emit(const AuthError('Please enter a valid email address.'));
      return;
    }

    try {
      final response = await _authServices.signInWithEmailPassword(
        normalizedEmail,
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

      await SecurityLogger.log(
        eventType: SecurityLogger.loginSuccess,
        email: normalizedEmail,
      );

      emit(const AuthSuccess());
    } on AuthException catch (e) {
      final mapped = AppErrorMapper.mapAuthError(e.message);
      emit(AuthError(mapped.message));
    } catch (error, stackTrace) {
      debugPrint('Unexpected Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      final mapped = AppErrorMapper.mapGeneral(error);
      emit(AuthError(mapped.message));
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

      // Email Validation before signup calls AppEmailValidator file
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

      // Duplicate Email Check
      // signUp returns a 200 if the email exists.
      final identities = user.identities;
      if (identities != null && identities.isEmpty) {
        emit(const AuthError('An account with this email may already exist.'),
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
          const AuthError('An account with this email may already exist.'),
        );
      } else {
        final mapped = AppErrorMapper.mapAuthError(errorMsg);
        emit(AuthError(mapped.message));
      }
    } catch (error, stackTrace) {
      debugPrint('Unexpected Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      final mapped = AppErrorMapper.mapGeneral(error);
      emit(AuthError(mapped.message));
    }
  }

  // Sanitize metadata
  String _sanitizeMetadata(String input) {
    return input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '').trim();
  }

  // ── Forgot Password ────────────────────────────────────────────
  // Request password-reset edge function from supabase
  // Sends reset email to user
  Future<void> sendPasswordReset({required String email}) async {
    emit(const AuthLoading());
    final normalizedEmail = email.trim().toLowerCase();
    try {
      await Supabase.instance.client.functions.invoke(
        'request-password-reset',
        body: {'email': normalizedEmail},
      );

      await SecurityLogger.log(
        eventType: SecurityLogger.passwordResetRequest,
        email: normalizedEmail,
      );

      emit(const AuthPasswordResetSent());
    } catch (_) {
      emit(const AuthPasswordResetSent());
    }
  }

  // ── Google Sign In ─────────────────────────────────────────────
  Future<void> signInWithGoogle() async {
    emit(const AuthLoading());
    try {
      final response = await _authServices.nativeGoogleSignIn();

      if (response.user == null) {
        emit(const AuthError('Google sign in failed. Please try again.'));
        return;
      }

      await SecurityLogger.log(eventType: SecurityLogger.loginSuccess);

      emit(const AuthSuccess());

    } on AuthException catch (e) {
      final mapped = AppErrorMapper.mapAuthError(e.message);
      emit(AuthError(mapped.message));
    } catch (error, stackTrace) {
      final message = error.toString();
      if (message.contains('Sign In process aborted')) {
        emit(const AuthInitial());
        return;
      }
      debugPrint('Unexpected Google Auth Error: $error');
      debugPrint('Stack Trace: $stackTrace');
      final mapped = AppErrorMapper.mapGeneral(error);
      emit(AuthError(mapped.message));
    }
  }

  // ── Logout ─────────────────────────────────────────────────────
  Future<void> logout() async {
    try {
      await _authServices.signOut();
    } catch (e) {
      debugPrint('[AuthCubit] Logout error: $e');
      rethrow; // let the UI handle showing an error snackbar
    }
  }

  void reset() => emit(const AuthInitial());
}
