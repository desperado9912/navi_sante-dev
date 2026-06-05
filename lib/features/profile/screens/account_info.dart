import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:navi_sante/features/profile/controllers/security_controller.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/app_error_ui.dart';
import 'package:navi_sante/core/utils/app_error_mapper.dart';

class AccountInfo extends StatefulWidget {
  const AccountInfo({super.key});

  @override
  State<AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  final TextEditingController _nameController = TextEditingController();
  final SecurityController _securityController = SecurityController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);
    MemoryLeakTracker.logInit(_nameController);
    MemoryLeakTracker.logInit(_securityController);
    final initialName = supa
        .Supabase
        .instance
        .client
        .auth
        .currentUser
        ?.userMetadata?['full_name'];
    _nameController.text = initialName ?? '';
  }

  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    MemoryLeakTracker.logDispose(_nameController);
    MemoryLeakTracker.logDispose(_securityController);
    _nameController.dispose();
    _securityController.dispose();
    super.dispose();
  }

  //----------------------------------------
  //SUPABASE FUNCTIONS
  //----------------------------------------

  //Supabase update username function
  Future<bool> _updateUserName(String newName) async {
    final cleanName = newName.trim();

    setState(() => _isLoading = true);

    try {
      final user = supa.Supabase.instance.client.auth.currentUser;

      // Update auth metadata fields across layers
      await supa.Supabase.instance.client.auth.updateUser(
        supa.UserAttributes(
          data: {
            'full_name': cleanName,
            'name': cleanName,
            'custom_display_name': cleanName,
          },
        ),
      );

      // Attempt to update public.users table if it exists (fail silently if not configured)
      if (user != null) {
        try {
          await supa.Supabase.instance.client
              .from('users')
              .update({
                'full_name': cleanName,
                'name': cleanName,
                'custom_display_name': cleanName,
              })
              .eq('id', user.id);
        } catch (_) {
          // Ignore if table doesn't exist or RLS denies it
        }
      }

      return true;
    } catch (error) {
      return false;
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  // Platform adaptive 'account delete' confirmation dialogue
  void _confirmDeleteAccount() {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    if (isAndroid) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action is permanent and cannot be undone. All your personal data, saved facilities, and settings will be permanently erased. Are you sure you want to proceed?',
            style: TextStyle(color: Color(0xFF5F6368), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: CupertinoColors.activeBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _performDeleteAccount();
              },
              child: const Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFC0392B),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: const Text('Delete Account'),
          content: const Text(
            'This action is permanent and cannot be undone. All your personal data, saved facilities, and settings will be permanently erased. Are you sure you want to proceed?',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.pop(ctx),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Delete'),
              onPressed: () {
                Navigator.pop(ctx);
                _performDeleteAccount();
              },
            ),
          ],
        ),
      );
    }
  }

  // Executes secure user deletion process and update app state
  Future<void> _performDeleteAccount() async {
    // Show non-dismissible loading overlay to prevent interaction
    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black26,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(
          child: CircularProgressIndicator(color: Color(0xFFC0392B)),
        ),
      ),
    );

    final navigator = Navigator.of(context, rootNavigator: true);

    try {
      await _securityController.deleteAccount();
      // AuthGate automatically redirects to /login after token and session are wiped
      // Pop all pushed screens (including this one and the loader) to reveal the root LoginScreen
      navigator.popUntil((route) => route.isFirst);
    } catch (e) {
      navigator.pop();
      final errorMsg = AppErrorMapper.mapDeleteAccountError(e);

      if (mounted) {
        AppFeedback.showErrorDialog(
          context,
          title: 'Error',
          message: errorMsg,
        );
      }
    }
  }

  // Platform adaptive username edit sheet entry point/launcher
  void _openEditSheet(String currentName) {
    _nameController.text = currentName == 'Not set' ? '' : currentName;

    final isAndroid = Theme.of(context).platform == TargetPlatform.android;

    if (isAndroid) {
      _showMaterialBottomSheet();
    } else {
      _showCupertinoBottomSheet();
    }
  }

  //----------------------------------------
  //UI PAGES
  //----------------------------------------

  //iOS cupertino style username edit sheet
  void _showCupertinoBottomSheet() {
    String? validationError;

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return _SwipeDismissibleSheet(
              canDismiss: !_isLoading,
              child: Container(
                height: 300 + MediaQuery.of(context).viewInsets.bottom,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      // ── Drag handle ──────────────────────────────────────
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Action Header Configuration Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        CupertinoButton(
                          padding: EdgeInsets.zero,
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.pop(context),
                          child: const Icon(
                            CupertinoIcons.xmark,
                            color: CupertinoColors.label,
                            size: 24,
                          ),
                        ),
                        const Text(
                          'Edit Name',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 17,
                            color: Colors.black,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _nameController,
                          builder: (context, value, child) {
                            final isValid =
                                value.text.trim().isNotEmpty &&
                                RegExp(
                                  r"^[a-zA-Z\s\-']+$",
                                ).hasMatch(value.text) &&
                                validationError == null;
                            return _isLoading
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CupertinoActivityIndicator(),
                                  )
                                : CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: !isValid
                                        ? null
                                        : () async {
                                            final input = _nameController.text
                                                .trim();

                                            setSheetState(() {
                                              _isLoading = true;
                                            });

                                            final success =
                                                await _updateUserName(input);

                                            if (context.mounted) {
                                              setSheetState(() {
                                                _isLoading = false;
                                              });
                                              if (success) {
                                                showCupertinoDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      CupertinoAlertDialog(
                                                        title: const Text(
                                                          'Success',
                                                        ),
                                                        content: const Text(
                                                          'Name updated successfully.',
                                                        ),
                                                        actions: [
                                                          CupertinoDialogAction(
                                                            child: const Text(
                                                              'OK',
                                                            ),
                                                            onPressed: () {
                                                              Navigator.pop(
                                                                context,
                                                              ); // close dialog
                                                              Navigator.pop(
                                                                context,
                                                              ); // close sheet
                                                            },
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              } else {
                                                showCupertinoDialog(
                                                  context: context,
                                                  builder: (context) =>
                                                      CupertinoAlertDialog(
                                                        title: const Text(
                                                          'Error',
                                                        ),
                                                        content: const Text(
                                                          'Failed to update your name. Please try again.',
                                                        ),
                                                        actions: [
                                                          CupertinoDialogAction(
                                                            child: const Text(
                                                              'OK',
                                                            ),
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              }
                                            }
                                          },
                                    child: Icon(
                                      CupertinoIcons.checkmark,
                                      color: isValid
                                          ? CupertinoColors.systemBlue
                                          : CupertinoColors.inactiveGray,
                                      size: 24,
                                    ),
                                  );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    CupertinoTextField(
                      controller: _nameController,
                      autofocus: true,
                      maxLength: 30, // Hardware enforced constraint max length
                      inputFormatters: [LengthLimitingTextInputFormatter(30)],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: CupertinoColors.extraLightBackgroundGray,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: validationError != null
                              ? CupertinoColors.destructiveRed
                              : Colors.transparent,
                          width: 1,
                        ),
                      ),
                      placeholder: "Enter full name",
                      enabled: !_isLoading,
                      onChanged: (text) {
                        String? error;
                        if (text.trim().isEmpty) {
                          error = null;
                        } else if (!RegExp(
                          r"^[a-zA-Z\s\-']+$",
                        ).hasMatch(text)) {
                          error = "Special characters are not allowed";
                        }

                        if (validationError != error) {
                          setSheetState(() => validationError = error);
                        }
                      },
                    ),
                    if (validationError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        validationError!,
                        style: const TextStyle(
                          color: CupertinoColors.destructiveRed,
                          fontSize: 12,
                          decoration: TextDecoration.none,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  //Android Material style username edit sheet
  void _showMaterialBottomSheet() {
    String? validationError; // Tracks dynamic error state inside sheet context

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !_isLoading,
      enableDrag: !_isLoading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Drag handle ──────────────────────────────────────
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.red,
                          size: 26,
                        ),
                        onPressed: _isLoading
                            ? null
                            : () => Navigator.pop(context),
                      ),
                      const Text(
                        'Edit Name',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _nameController,
                        builder: (context, value, child) {
                          final isValid =
                              value.text.trim().isNotEmpty &&
                              RegExp(
                                r"^[a-zA-Z\s\-']+$",
                              ).hasMatch(value.text) &&
                              validationError == null;
                          return _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Color(0xFF2A7D8F),
                                  ),
                                )
                              : IconButton(
                                  icon: Icon(
                                    Icons.check,
                                    color: isValid
                                        ? const Color(0xFF2A7D8F)
                                        : Colors.grey,
                                    size: 26,
                                  ),
                                  onPressed: !isValid
                                      ? null
                                      : () async {
                                          final input = _nameController.text
                                              .trim();

                                          setSheetState(() {
                                            _isLoading = true;
                                          });

                                          final success = await _updateUserName(
                                            input,
                                          );

                                          if (context.mounted) {
                                            setSheetState(() {
                                              _isLoading = false;
                                            });
                                            if (success) {
                                              showDialog(
                                                context: context,
                                                barrierDismissible: false,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Success'),
                                                  content: const Text(
                                                    'Name updated successfully.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () {
                                                        Navigator.pop(
                                                          context,
                                                        ); // close dialog
                                                        Navigator.pop(
                                                          context,
                                                        ); // close sheet
                                                      },
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            } else {
                                              showDialog(
                                                context: context,
                                                builder: (context) => AlertDialog(
                                                  title: const Text('Error'),
                                                  content: const Text(
                                                    'Failed to update your name. Please try again.',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed: () =>
                                                          Navigator.pop(
                                                            context,
                                                          ),
                                                      child: const Text('OK'),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          }
                                        },
                                );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    autofocus: true,
                    maxLength:
                        30, // Shows standard material character counter badge
                    inputFormatters: [LengthLimitingTextInputFormatter(30)],
                    decoration: InputDecoration(
                      hintText: "Enter full name",
                      errorText:
                          validationError, // Built-in Material error handler
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(
                          color: Color(0xFF2A7D8F),
                          width: 2,
                        ),
                      ),
                    ),
                    enabled: !_isLoading,
                    onChanged: (text) {
                      String? error;
                      if (text.trim().isEmpty) {
                        error = null;
                      } else if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(text)) {
                        error = "Special characters are not allowed";
                      }

                      if (validationError != error) {
                        setSheetState(() => validationError = error);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // Launcher for platform adaptive password update bottom sheets
  void _openPasswordSheet(bool hasPassword) {
    final isAndroid = Theme.of(context).platform == TargetPlatform.android;
    if (isAndroid) {
      _showMaterialPasswordSheet(hasPassword);
    } else {
      _showCupertinoPasswordSheet(hasPassword);
    }
  }

  // Renders the Change/Create Password security tile
  Widget _buildPasswordTile(bool hasPassword) {
    return GestureDetector(
      onTap: () => _openPasswordSheet(hasPassword),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE4E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F1F1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                CupertinoIcons.lock,
                color: Color(0xFF1A1A1A),
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Change Password',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ),
            const Icon(
              CupertinoIcons.chevron_right,
              size: 18,
              color: Color(0xFF5F6368),
            ),
          ],
        ),
      ),
    );
  }

  // iOS Cupertino style password update bottom sheet
  void _showCupertinoPasswordSheet(bool hasPassword) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSheetLoading = false;
    String? sheetError;

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: !isSheetLoading,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final newPassword = newPasswordController.text;
            final confirmPassword = confirmPasswordController.text;

            final isLengthOk = newPassword.length >= 8;
            final hasUppercase = newPassword.contains(RegExp(r'[A-Z]'));
            final hasNumber = newPassword.contains(RegExp(r'[0-9]'));
            final passwordsMatch =
                newPassword == confirmPassword && newPassword.isNotEmpty;

            final isFormValid =
                (hasPassword
                    ? currentPasswordController.text.isNotEmpty
                    : true) &&
                isLengthOk &&
                hasUppercase &&
                hasNumber &&
                passwordsMatch;

            return _SwipeDismissibleSheet(
              canDismiss: !isSheetLoading,
              child: Container(
                height: 520 + MediaQuery.of(context).viewInsets.bottom,
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 + MediaQuery.of(context).viewInsets.bottom,
                ),
                decoration: const BoxDecoration(
                  color: CupertinoColors.systemBackground,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Drag handle ──────────────────────────────────────
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 20),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0E0E0),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          CupertinoButton(
                            padding: EdgeInsets.zero,
                            onPressed: isSheetLoading
                                ? null
                                : () => Navigator.pop(context),
                            child: const Icon(
                              CupertinoIcons.xmark,
                              color: CupertinoColors.label,
                              size: 24,
                            ),
                          ),
                          Text(
                            hasPassword ? 'Change Password' : 'Create Password',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                              color: Colors.black,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          isSheetLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CupertinoActivityIndicator(),
                                )
                              : CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: !isFormValid
                                      ? null
                                      : () async {
                                          setSheetState(() {
                                            isSheetLoading = true;
                                            sheetError = null;
                                          });

                                          try {
                                            if (hasPassword) {
                                              await _securityController
                                                  .updatePassword(
                                                    currentPassword:
                                                        currentPasswordController
                                                            .text,
                                                    newPassword:
                                                        newPasswordController
                                                            .text,
                                                  );
                                            } else {
                                              await _securityController
                                                  .linkPassword(
                                                    newPassword:
                                                        newPasswordController
                                                            .text,
                                                  );
                                            }

                                            if (mounted && context.mounted) {
                                              Navigator.pop(
                                                context,
                                              ); // close sheet
                                              showCupertinoDialog(
                                                context: this.context,
                                                builder: (ctx) => CupertinoAlertDialog(
                                                  title: const Text('Success'),
                                                  content: Text(
                                                    hasPassword
                                                        ? 'Your password has been changed successfully.'
                                                        : 'Password created successfully! You can now log in with your email and password.',
                                                  ),
                                                  actions: [
                                                    CupertinoDialogAction(
                                                      child: const Text('OK'),
                                                      onPressed: () =>
                                                          Navigator.pop(ctx),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }
                                          } catch (error) {
                                            setSheetState(() {
                                              isSheetLoading = false;
                                              sheetError = AppErrorMapper
                                                  .mapPasswordError(error);
                                            });
                                          }
                                        },
                                  child: Icon(
                                    CupertinoIcons.checkmark,
                                    color: isFormValid
                                        ? CupertinoColors.systemBlue
                                        : CupertinoColors.inactiveGray,
                                    size: 24,
                                  ),
                                ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      if (!hasPassword) ...[
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeBlue.withValues(
                              alpha: 0.1,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Setting a password allows you to log in with your email in the future.',
                            style: const TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.activeBlue,
                              decoration: TextDecoration.none,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      if (hasPassword) ...[
                        const Text(
                          'Current Password',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.label,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        CupertinoTextField(
                          controller: currentPasswordController,
                          obscureText: obscureCurrent,
                          placeholder: "Enter current password",
                          enabled: !isSheetLoading,
                          decoration: BoxDecoration(
                            color: CupertinoColors.extraLightBackgroundGray,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                          suffix: CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Icon(
                              obscureCurrent
                                  ? CupertinoIcons.eye_slash
                                  : CupertinoIcons.eye,
                              color: CupertinoColors.secondaryLabel,
                              size: 20,
                            ),
                            onPressed: () {
                              setSheetState(
                                () => obscureCurrent = !obscureCurrent,
                              );
                            },
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Text(
                        'New Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: newPasswordController,
                        obscureText: obscureNew,
                        placeholder: "Enter new password",
                        enabled: !isSheetLoading,
                        decoration: BoxDecoration(
                          color: CupertinoColors.extraLightBackgroundGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        suffix: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(
                            obscureNew
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            color: CupertinoColors.secondaryLabel,
                            size: 20,
                          ),
                          onPressed: () {
                            setSheetState(() => obscureNew = !obscureNew);
                          },
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Confirm Password',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.label,
                          decoration: TextDecoration.none,
                        ),
                      ),
                      const SizedBox(height: 8),
                      CupertinoTextField(
                        controller: confirmPasswordController,
                        obscureText: obscureConfirm,
                        placeholder: "Confirm new password",
                        enabled: !isSheetLoading,
                        decoration: BoxDecoration(
                          color: CupertinoColors.extraLightBackgroundGray,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 14,
                        ),
                        suffix: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Icon(
                            obscureConfirm
                                ? CupertinoIcons.eye_slash
                                : CupertinoIcons.eye,
                            color: CupertinoColors.secondaryLabel,
                            size: 20,
                          ),
                          onPressed: () {
                            setSheetState(
                              () => obscureConfirm = !obscureConfirm,
                            );
                          },
                        ),
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 24),

                      // Validation checklist
                      _buildValidationRule('At least 8 characters', isLengthOk),
                      const SizedBox(height: 8),
                      _buildValidationRule(
                        'At least one uppercase letter (A-Z)',
                        hasUppercase,
                      ),
                      const SizedBox(height: 8),
                      _buildValidationRule(
                        'At least one number (0-9)',
                        hasNumber,
                      ),
                      const SizedBox(height: 8),
                      _buildValidationRule('Passwords match', passwordsMatch),

                      if (sheetError != null) ...[
                        const SizedBox(height: 16),
                        AppFeedback.inlineError(sheetError),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Android Material style password update bottom sheet
  void _showMaterialPasswordSheet(bool hasPassword) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    bool obscureCurrent = true;
    bool obscureNew = true;
    bool obscureConfirm = true;
    bool isSheetLoading = false;
    String? sheetError;

    final currentUser = supa.Supabase.instance.client.auth.currentUser;
    final email = currentUser?.email ?? '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: !isSheetLoading,
      enableDrag: !isSheetLoading,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final newPassword = newPasswordController.text;
            final confirmPassword = confirmPasswordController.text;

            final isLengthOk = newPassword.length >= 8;
            final hasUppercase = newPassword.contains(RegExp(r'[A-Z]'));
            final hasNumber = newPassword.contains(RegExp(r'[0-9]'));
            final passwordsMatch =
                newPassword == confirmPassword && newPassword.isNotEmpty;

            final isFormValid =
                (hasPassword
                    ? currentPasswordController.text.isNotEmpty
                    : true) &&
                isLengthOk &&
                hasUppercase &&
                hasNumber &&
                passwordsMatch;

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                16,
                24,
                24 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Drag handle ──────────────────────────────────────
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    // Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.close,
                            color: Colors.red,
                            size: 26,
                          ),
                          onPressed: isSheetLoading
                              ? null
                              : () => Navigator.pop(context),
                        ),
                        Text(
                          hasPassword ? 'Change Password' : 'Create Password',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        isSheetLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(0xFF2A7D8F),
                                ),
                              )
                            : IconButton(
                                icon: Icon(
                                  Icons.check,
                                  color: isFormValid
                                      ? const Color(0xFF2A7D8F)
                                      : Colors.grey,
                                  size: 26,
                                ),
                                onPressed: !isFormValid
                                    ? null
                                    : () async {
                                        setSheetState(() {
                                          isSheetLoading = true;
                                          sheetError = null;
                                        });

                                        try {
                                          if (hasPassword) {
                                            await _securityController
                                                .updatePassword(
                                                  currentPassword:
                                                      currentPasswordController
                                                          .text,
                                                  newPassword:
                                                      newPasswordController
                                                          .text,
                                                );
                                          } else {
                                            await _securityController
                                                .linkPassword(
                                                  newPassword:
                                                      newPasswordController
                                                          .text,
                                                );
                                          }

                                          if (mounted && context.mounted) {
                                            Navigator.pop(
                                              context,
                                            ); // close sheet
                                            showDialog(
                                              context: this.context,
                                              builder: (ctx) => AlertDialog(
                                                title: const Text('Success'),
                                                content: Text(
                                                  hasPassword
                                                      ? 'Your password has been changed successfully.'
                                                      : 'Password created successfully! You can now log in with your email and password.',
                                                ),
                                                actions: [
                                                  TextButton(
                                                    child: const Text('OK'),
                                                    onPressed: () =>
                                                        Navigator.pop(ctx),
                                                  ),
                                                ],
                                              ),
                                            );
                                          }
                                        } catch (error) {
                                          setSheetState(() {
                                            isSheetLoading = false;
                                            sheetError = AppErrorMapper
                                                .mapPasswordError(error);
                                          });
                                        }
                                      },
                              ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (!hasPassword) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Text(
                          'You signed in via social login. Setting a password allows you to log in with your email ($email) in the future.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    if (hasPassword) ...[
                      TextField(
                        controller: currentPasswordController,
                        obscureText: obscureCurrent,
                        decoration: InputDecoration(
                          labelText: 'Current Password',
                          labelStyle: const TextStyle(color: Color(0xFF2A7D8F)),
                          focusedBorder: const UnderlineInputBorder(
                            borderSide: BorderSide(
                              color: Color(0xFF2A7D8F),
                              width: 2,
                            ),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              obscureCurrent
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setSheetState(
                                () => obscureCurrent = !obscureCurrent,
                              );
                            },
                          ),
                        ),
                        enabled: !isSheetLoading,
                        onChanged: (_) => setSheetState(() {}),
                      ),
                      const SizedBox(height: 16),
                    ],

                    TextField(
                      controller: newPasswordController,
                      obscureText: obscureNew,
                      decoration: InputDecoration(
                        labelText: 'New Password',
                        labelStyle: const TextStyle(color: Color(0xFF2A7D8F)),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF2A7D8F),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureNew
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setSheetState(() => obscureNew = !obscureNew);
                          },
                        ),
                      ),
                      enabled: !isSheetLoading,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 16),

                    TextField(
                      controller: confirmPasswordController,
                      obscureText: obscureConfirm,
                      decoration: InputDecoration(
                        labelText: 'Confirm New Password',
                        labelStyle: const TextStyle(color: Color(0xFF2A7D8F)),
                        focusedBorder: const UnderlineInputBorder(
                          borderSide: BorderSide(
                            color: Color(0xFF2A7D8F),
                            width: 2,
                          ),
                        ),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureConfirm
                                ? Icons.visibility_off
                                : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () {
                            setSheetState(
                              () => obscureConfirm = !obscureConfirm,
                            );
                          },
                        ),
                      ),
                      enabled: !isSheetLoading,
                      onChanged: (_) => setSheetState(() {}),
                    ),
                    const SizedBox(height: 24),

                    // Validation checklist
                    _buildValidationRule('At least 8 characters', isLengthOk),
                    const SizedBox(height: 8),
                    _buildValidationRule(
                      'At least one uppercase letter (A-Z)',
                      hasUppercase,
                    ),
                    const SizedBox(height: 8),
                    _buildValidationRule(
                      'At least one number (0-9)',
                      hasNumber,
                    ),
                    const SizedBox(height: 8),
                    _buildValidationRule('Passwords match', passwordsMatch),

                    if (sheetError != null) ...[
                      const SizedBox(height: 16),
                      AppFeedback.inlineError(sheetError),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Atomic dynamic password rule checklist element generator
  Widget _buildValidationRule(String text, bool isMet) {
    return Row(
      children: [
        Icon(
          isMet ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
          color: isMet ? const Color(0xFF2A7D8F) : Colors.grey,
          size: 16,
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            color: isMet ? const Color(0xFF2A7D8F) : const Color(0xFF888780),
            decoration: TextDecoration.none,
            fontWeight: FontWeight.normal,
          ),
        ),
      ],
    );
  }

  // Delete Account button
  bool _isDeletePressed = false;
  Widget _buildDeleteAccountButton() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _isDeletePressed = true),
          onTapUp: (_) => setState(() => _isDeletePressed = false),
          onTapCancel: () => setState(() => _isDeletePressed = false),
          onTap: _confirmDeleteAccount,
          behavior: HitTestBehavior
              .opaque, // Ensures exact bounding box hit detection
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 100),
            opacity: _isDeletePressed
                ? 0.7
                : 1.0, // Fades only the content on press
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(CupertinoIcons.trash, size: 20, color: Color(0xFFC0392B)),
                SizedBox(width: 10),
                Text(
                  'Delete Account',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFFC0392B),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  //User account info box
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<supa.AuthState>(
      stream: supa.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = supa.Supabase.instance.client.auth.currentUser;
        final customName =
            user?.userMetadata?['custom_display_name'] as String?;
        final fullName = user?.userMetadata?['full_name'] as String?;
        final resolvedName = (customName != null && customName.isNotEmpty)
            ? customName
            : fullName;
        final displayName =
            (resolvedName != null && resolvedName.trim().isNotEmpty)
            ? resolvedName
            : 'Not set';
        final email = user?.email ?? 'Not set';
        final isEmailVerified = user?.emailConfirmedAt != null;
        final verificationStatus = isEmailVerified
            ? 'Verified'
            : 'Not verified';

        return Scaffold(
          appBar: const PlatformAdaptiveAppBar(title: 'Account Information'),
          backgroundColor: const Color(0xFFF8F9F8),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Column(
              children: [
                // Primary User Details Container
                RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFFE4E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Fullname Field Row with edit button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Full name',
                                    style: TextStyle(
                                      color: Color(0xFF1A1A1A),
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    style: const TextStyle(
                                      color: Colors.black,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            GestureDetector(
                              onTap: () => _openEditSheet(displayName),
                              child: const Padding(
                                padding: EdgeInsets.only(right: 8.0),
                                child: Icon(
                                  CupertinoIcons.pencil_circle,
                                  color: Color(0xFF2A7D8F),
                                  size: 28,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // Email Address field row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        'Email address',
                                        style: TextStyle(
                                          color: Color(0xFF1A1A1A),
                                          fontSize: 14,
                                        ),
                                      ),
                                      if (isEmailVerified) ...[
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE8F8F0),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            verificationStatus,
                                            style: const TextStyle(
                                              color: Colors.green,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),

                                  const SizedBox(height: 4),

                                  Text(
                                    email,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 14),

                        // //Phone number field row
                        // Row(
                        //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        //   crossAxisAlignment: CrossAxisAlignment.start,
                        //   children: [
                        //     Expanded(
                        //       child: Column(
                        //         crossAxisAlignment: CrossAxisAlignment.start,
                        //         children: [
                        //           const Text(
                        //             'Phone number',
                        //             style: TextStyle(
                        //               color: Color(0xFF1A1A1A),
                        //               fontSize: 14,
                        //             ),
                        //           ),

                        //           const SizedBox(height: 4),
                        //           Text(
                        //             '+237 123 45 67 89',
                        //             style: const TextStyle(
                        //               color: Colors.black,
                        //               fontSize: 16,
                        //               fontWeight: FontWeight.bold,
                        //             ),
                        //           ),
                        //         ],
                        //       ),
                        //     ),

                        //     GestureDetector(
                        //       onTap: () => {},
                        //       child: Padding(
                        //         padding: EdgeInsets.only(right: 8.0),
                        //         child: Icon(
                        //           CupertinoIcons.pencil,
                        //           color: Color(0xFF2A7D8F),
                        //           size: 24,
                        //         ),
                        //       ),
                        //     ),
                        //   ],
                        // ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Password Update dynamic tile
                ListenableBuilder(
                  listenable: _securityController,
                  builder: (context, child) {
                    final hasPassword = _securityController.checkHasPassword();
                    return _buildPasswordTile(hasPassword);
                  },
                ),

                const SizedBox(height: 60),

                // Delete Account outlined button
                _buildDeleteAccountButton(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// Interactive swipe-to-dismiss wrapper for Cupertino-style bottom sheets.
class _SwipeDismissibleSheet extends StatefulWidget {
  final Widget child;
  final bool canDismiss;

  const _SwipeDismissibleSheet({required this.child, this.canDismiss = true});

  @override
  State<_SwipeDismissibleSheet> createState() => _SwipeDismissibleSheetState();
}

class _SwipeDismissibleSheetState extends State<_SwipeDismissibleSheet>
    with SingleTickerProviderStateMixin {
  double _dragOffset = 0;
  double _animStart = 0;
  double _animTarget = 0;
  late final AnimationController _animController;
  bool _isDismissing = false;

  static const _dismissThreshold = 100.0;
  static const _dismissVelocity = 700.0;

  @override
  void initState() {
    super.initState();
    _animController =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 250),
        )..addListener(() {
          final curved = Curves.easeOut.transform(_animController.value);
          setState(() {
            _dragOffset = _animStart + (_animTarget - _animStart) * curved;
          });
        });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.canDismiss || _isDismissing) return;
    setState(() {
      // Only allow dragging downward (clamp at 0)
      _dragOffset = (_dragOffset + (details.primaryDelta ?? 0)).clamp(
        0.0,
        double.infinity,
      );
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.canDismiss || _isDismissing) return;

    final velocity = details.primaryVelocity ?? 0;

    if (_dragOffset > _dismissThreshold || velocity > _dismissVelocity) {
      _isDismissing = true;
      _animStart = _dragOffset;
      _animTarget = MediaQuery.of(context).size.height;
      _animController
        ..reset()
        ..duration = const Duration(milliseconds: 200)
        ..forward().then((_) {
          if (mounted) Navigator.of(context).pop();
        });
    } else {
      _animStart = _dragOffset;
      _animTarget = 0;
      _animController
        ..reset()
        ..duration = const Duration(milliseconds: 250)
        ..forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onVerticalDragUpdate: _onDragUpdate,
      onVerticalDragEnd: _onDragEnd,
      child: Transform.translate(
        offset: Offset(0, _dragOffset),
        child: widget.child,
      ),
    );
  }
}
