import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/auth_cubit.dart';
import '../cubit/language_cubit.dart';
import '../widgets/auth_text_field.dart';
import '../widgets/language_picker.dart';
import 'signup.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  // ── Validators: Validates user Inputs───────────────────────────────
  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email address is required';
    }
    final emailRegex = RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$');
    if (!emailRegex.hasMatch(value.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  void _onLogin() {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate() || _isSubmitting) return;
    setState(() => _isSubmitting = true);

    context.read<AuthCubit>().login(
      email: _emailCtrl.text.trim().toLowerCase(),
      password: _passwordCtrl.text,
    );
    _passwordCtrl.clear();

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) setState(() => _isSubmitting = false);
    });
  }

  void _onForgotPassword() {
    final email = _emailCtrl.text.trim();
    showDialog<void>(
      context: context,
      builder: (ctx) => _ForgotPasswordDialog(prefillEmail: email),
    );
  }

  //-- Login page UI------------------------------------------
  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) {
          Navigator.of(context).pushReplacementNamed('/home');
        }
        if (state is AuthEmailNotVerified) {
          _showEmailVerificationMessage(context);
        }
        if (state is AuthError) {
          _showErrorSnackbar(context, state.message);
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

                    // ── Top bar: logo + language picker ───────────
                    _TopBar(),
                    const SizedBox(height: 25),

                    // ── Welcome heading ───────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lang.isEnglish ? 'Welcome Back' : 'Bon Retour',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            lang.isEnglish
                                ? 'Please login to your account'
                                : 'Connectez-vous à votre compte',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF5F6368),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // ── Email field ───────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => AuthTextField(
                        controller: _emailCtrl,
                        label: lang.isEnglish
                            ? 'Enter Email Address'
                            : 'Adresse e-mail',
                        hint: 'john@example.com',
                        prefixIcon: CupertinoIcons.mail,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        validator: _validateEmail,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Password field ────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => AuthTextField(
                        controller: _passwordCtrl,
                        label: lang.isEnglish
                            ? 'Enter Password'
                            : 'Mot de passe',
                        hint: '••••••••',
                        prefixIcon: CupertinoIcons.lock,
                        isPassword: true,
                        obscureText: _obscurePassword,
                        onToggleObscure: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        textInputAction: TextInputAction.done,
                        onEditingComplete: _onLogin,
                        validator: _validatePassword,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // ── Forgot password ───────────────────────────
                    Align(
                      alignment: Alignment.centerRight,
                      child: BlocBuilder<LanguageCubit, LanguageState>(
                        builder: (context, lang) => GestureDetector(
                          onTap: _onForgotPassword,
                          child: Text(
                            lang.isEnglish
                                ? 'Forgot password?'
                                : 'Mot de passe oublié?',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1A1A1A),
                              decoration: TextDecoration.underline,
                              decorationColor: Color(0xFF1A1A1A),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Login button ──────────────────────────────
                    BlocBuilder<AuthCubit, AuthState>(
                      builder: (context, state) {
                        final isLoading = state is AuthLoading;
                        return BlocBuilder<LanguageCubit, LanguageState>(
                          builder: (context, lang) => SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _onLogin,
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
                                      lang.isEnglish ? 'Login' : 'Connexion',
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

                    // ── Sign up redirect ──────────────────────────
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
                                    ? 'New on NaviSanté? '
                                    : 'Nouveau sur NaviSanté? ',
                              ),
                              WidgetSpan(
                                child: GestureDetector(
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => BlocProvider.value(
                                        value: context.read<AuthCubit>(),
                                        child: BlocProvider.value(
                                          value: context.read<LanguageCubit>(),
                                          child: const SignupScreen(),
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    lang.isEnglish ? 'Sign up' : "S'inscrire",
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
                    const SizedBox(height: 30),

                    // ── Divider ───────────────────────────────────
                    BlocBuilder<LanguageCubit, LanguageState>(
                      builder: (context, lang) => Row(
                        children: [
                          const Expanded(
                            child: Divider(color: Color(0xFFCCCCCC)),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              lang.isEnglish
                                  ? 'Or Continue With'
                                  : 'Ou continuer avec',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF5F6368),
                              ),
                            ),
                          ),
                          const Expanded(
                            child: Divider(color: Color(0xFFCCCCCC)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Social buttons ───────────────────
                    Row(
                      children: [
                        Expanded(
                          child: _SocialButton(
                            label: 'Google',
                            icon: SvgPicture.asset(
                              'assets/google_logo.svg',
                              height: 20,
                              width: 20,
                            ),
                            onTap: () {
                              /* TODO: Google auth */
                              // => context.read<AuthCubit>().signInWithGoogle(),
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _SocialButton(
                            label: 'Apple',
                            icon: const FaIcon(
                              FontAwesomeIcons.apple,
                              size: 22,
                              color: Color(0xFF1A1A1A),
                            ),
                            onTap: () {
                              /* TODO: Apple auth */
                            },
                          ),
                        ),
                      ],
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

  // ── Dialogs ────────────────────────────────────────────────────
  void _showEmailVerificationMessage(BuildContext context) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(
                    Icons.mark_email_unread_outlined,
                    color: Colors.white,
                    size: 20,
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Verification Email Sent',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Please verify your email before attempting login. Check your inbox for the verification link.',
                style: TextStyle(fontSize: 13, color: Colors.white),
              ),
            ],
          ),

          //verification link sent message
          backgroundColor: const Color(0xFFF39C12),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.read<AuthCubit>().reset();
            },
          ),
        ),
      );
  }

  void _showErrorSnackbar(BuildContext context, String message) {
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
                child: Text(message, style: const TextStyle(fontSize: 14)),
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
}

// ── Internal sub-widgets ───────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Logo || Logo text
        const Text(
          'NaviSanté',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2A7D8F),
          ),
        ),
        const LanguagePicker(),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final String label;
  final Widget icon;
  final VoidCallback onTap;

  const _SocialButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 14),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          icon,
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),
        ],
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  final String prefillEmail;
  const _ForgotPasswordDialog({required this.prefillEmail});

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _ctrl;
  bool _sent = false;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.prefillEmail);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthSuccess) setState(() => _sent = true);
        if (state is AuthError) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: const Color(0xFFC0392B),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(_sent ? 'Email Sent' : 'Reset Password'),
        content: _sent
            ? const Text(
                'If this email is registered, you will receive '
                'a password reset link shortly. '
                'Please follow the steps in the link to reset your password, '
                'then try to login again',
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter your email address and we will send '
                    'you a reset link.',
                    style: TextStyle(fontSize: 14, color: Color(0xFF666660)),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      hintText: 'your@email.com',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(
                          color: Color(0xFF2A7D8F),
                          width: 1.8,
                        ),
                      ),
                      prefixIcon: const Icon(Icons.mail_outline_rounded),
                    ),
                  ),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.read<AuthCubit>().reset();
            },
            child: Text(
              _sent ? 'Done' : 'Cancel',
              style: const TextStyle(color: Color(0xFF666660)),
            ),
          ),
          if (!_sent)
            BlocBuilder<AuthCubit, AuthState>(
              builder: (context, state) => TextButton(
                onPressed: state is AuthLoading
                    ? null
                    : () => context.read<AuthCubit>().sendPasswordReset(
                        email: _ctrl.text,
                      ),
                child: state is AuthLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF2A7D8F),
                        ),
                      )
                    : const Text(
                        'Send',
                        style: TextStyle(
                          color: Color(0xFF2A7D8F),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
        ],
      ),
    );
  }
}