import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/language_cubit.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/language_picker.dart';
import '../../home/home_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  // Password rule trackers
  bool get _hasUppercase => _passwordCtrl.text.contains(RegExp(r'[A-Z]'));
  bool get _hasNumber => _passwordCtrl.text.contains(RegExp(r'[0-9]'));
  bool get _hasMinLength => _passwordCtrl.text.length >= 8;

  @override
  void initState() {
    super.initState();
    // Rebuild password rules UI on every keystroke
    _passwordCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Validators ─────────────────────────────────────────────────
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Full name is required';
    if (value.trim().length < 8) return 'Enter your full name';
    return null;
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'Email is required';
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value.trim())) return 'Enter a valid email';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (!_hasMinLength) return 'At least 8 characters required';
    if (!_hasUppercase) return 'Must contain at least one uppercase letter';
    if (!_hasNumber) return 'Must contain at least one number';
    return null;
  }

  void _onSignup() {
    FocusScope.of(context).unfocus();
    //check button spamming and lock
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    context.read<AuthCubit>().signUp(
      fullName: _nameCtrl.text,
      email: _emailCtrl.text.trim().toLowerCase(),
      password: _passwordCtrl.text,
    );
    _passwordCtrl.clear();

    //unlock after delay
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSubmitting = false);
    });
  }

  //signup page UI
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        // Check for errors FIRST (including duplicate emails)
        if (state is AuthError) {
          // Check if error is due to duplicate email
          if (state.message.toLowerCase().contains('user already registered') ||
              state.message.toLowerCase().contains('already exists')) {
            _showDuplicateEmailError(context);
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          state.message,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: const Color(0xFFC0392B),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  margin: const EdgeInsets.all(16),
                  duration: const Duration(seconds: 3),
                ),
              );
          }
          return; // Don't show verification popup if there's an error
        }

        // Then check for email verification (only if no errors)
        if (state is AuthEmailNotVerified) {
          _showVerificationSentDialog(context);
        }
        if (state is AuthSuccess) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const HomeScreen()),
            (_) => false,
          );
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF8F9F8),
        body: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Top bar ───────────────────────────────────
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'NaviSanté',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2A7D8F),
                          ),
                        ),
                        const LanguagePicker(),
                      ],
                    ),
                    const SizedBox(height: 25),

                    // ── Heading ───────────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isEnglish ? 'Sign Up' : 'Inscription',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang.isEnglish
                                ? 'Create your account'
                                : 'Créez votre compte',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Full name ─────────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => AuthTextField(
                        controller: _nameCtrl,
                        label: lang.isEnglish
                            ? 'Enter Full Name'
                            : 'Nom complet',
                        hint: 'John Doe',
                        prefixIcon: Icons.person_outline_rounded,
                        textInputAction: TextInputAction.next,
                        validator: _validateName,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Email ─────────────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => AuthTextField(
                        controller: _emailCtrl,
                        label: lang.isEnglish
                            ? 'Enter Email Address'
                            : 'Adresse e-mail',
                        hint: 'john@example.com',
                        prefixIcon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Password ──────────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => AuthTextField(
                        controller: _passwordCtrl,
                        label: lang.isEnglish
                            ? 'Enter Password'
                            : 'Mot de passe',
                        hint: '••••••••',
                        prefixIcon: Icons.lock_outline_rounded,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _onSignup,
                        validator: _validatePassword,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Password rules ────────────────────────────
                    _PasswordRules(
                      hasMinLength: _hasMinLength,
                      hasUppercase: _hasUppercase,
                      hasNumber: _hasNumber,
                    ),
                    const SizedBox(height: 22),

                    // ── Sign up button ────────────────────────────
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return BlocBuilder<LanguageCubit, LanguageState>(
                          builder: (context, lang) => SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _onSignup,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2A7D8F),
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: const Color(
                                  0xFF2A7D8F,
                                ),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2.5,
                                      ),
                                    )
                                  : Text(
                                      lang.isEnglish ? 'Sign Up' : "S'inscrire",
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Login redirect ────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => Center(
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1A1A1A),
                            ),
                            children: [
                              TextSpan(
                                text: lang.isEnglish
                                    ? 'Already have an account? '
                                    : 'Vous avez déjà un compte? ',
                              ),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).pop(),
                                  child: Text(
                                    lang.isEnglish ? 'Sign In' : 'Connexion',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF2A7D8F),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Terms & privacy ───────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => Center(
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: TextSpan(
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF888780),
                            ),
                            children: [
                              TextSpan(
                                text: lang.isEnglish
                                    ? 'By signing up you agree to our '
                                    : 'En vous inscrivant vous acceptez nos ',
                              ),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {
                                    /* TODO: Terms */
                                  },
                                  child: Text(
                                    lang.isEnglish
                                        ? 'Terms of Service'
                                        : "Conditions d'utilisation",
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2A7D8F),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const TextSpan(text: ' & '),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () {
                                    /* TODO: Privacy */
                                  },
                                  child: Text(
                                    lang.isEnglish
                                        ? 'Privacy Policy'
                                        : 'Politique de confidentialité',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF2A7D8F),
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showDuplicateEmailError(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.email_outlined, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Email address already exists. Please try with a different email address.',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFC0392B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  void _showVerificationSentDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.mark_email_unread_outlined, color: Color(0xFF2A7D8F)),
            SizedBox(width: 10),
            Text('Check your email'),
          ],
        ),
        content: Text(
          'We sent a verification link to ${_emailCtrl.text.trim()}.\n\n'
          'Please click the link to activate your account, '
          'then log in.',
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2A7D8F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // close dialog
              Navigator.of(context).pushReplacementNamed('/login');
              context.read<AuthCubit>().reset();
            },
            child: const Text(
              'Go to Login',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Password rules widget ──────────────────────────────────────────────────────
class _PasswordRules extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUppercase;
  final bool hasNumber;

  const _PasswordRules({
    required this.hasMinLength,
    required this.hasUppercase,
    required this.hasNumber,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FBF7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB2DFCF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF333330),
            ),
          ),
          const SizedBox(height: 4),
          _Rule(met: hasMinLength, label: 'At least 8 characters'),
          _Rule(met: hasUppercase, label: 'One uppercase letter (A–Z)'),
          _Rule(met: hasNumber, label: 'One number (0–9)'),
        ],
      ),
    );
  }
}

class _Rule extends StatelessWidget {
  final bool met;
  final String label;
  const _Rule({required this.met, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Icon(
            met ? Icons.check_circle_rounded : Icons.radio_button_unchecked,
            size: 14,
            color: met ? const Color(0xFF2A7D8F) : const Color(0xFFAAAAAA),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: met ? const Color(0xFF2A7D8F) : const Color(0xFF888780),
              fontWeight: met ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
