import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class AccountInfo extends StatefulWidget {
  const AccountInfo({super.key});

  @override
  State<AccountInfo> createState() => _AccountInfoState();
}

class _AccountInfoState extends State<AccountInfo> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
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
    _nameController.dispose();
    super.dispose();
  }

  //Supabase update username function
  Future<bool> _updateUserName(String newName) async {
    final cleanName = newName.trim();

    setState(() => _isLoading = true);

    try {
      final user = supa.Supabase.instance.client.auth.currentUser;
      
      // Update auth metadata fields across layers
      await supa.Supabase.instance.client.auth.updateUser(
        supa.UserAttributes(data: {
          'full_name': cleanName,
          'name': cleanName,
          'custom_display_name': cleanName,
        }),
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

  //iOS cupertino style username edit sheet
  void _showCupertinoBottomSheet() {
    String? validationError;

    showCupertinoModalPopup(
      context: context,
      barrierDismissible: !_isLoading,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
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
                          final isValid = value.text.trim().isNotEmpty && RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.text) && validationError == null;
                          return _isLoading
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CupertinoActivityIndicator(),
                                )
                              : CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  onPressed: !isValid ? null : () async {
                                    final input = _nameController.text.trim();
                                    
                                    setSheetState(() {
                                      _isLoading = true;
                                    });

                                    final success = await _updateUserName(input);
                                    
                                    if (context.mounted) {
                                      setSheetState(() {
                                        _isLoading = false;
                                      });
                                      if (success) {
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (context) => CupertinoAlertDialog(
                                            title: const Text('Success'),
                                            content: const Text('Name updated successfully.'),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text('OK'),
                                                onPressed: () {
                                                  Navigator.pop(context); // close dialog
                                                  Navigator.pop(context); // close sheet
                                                },
                                              ),
                                            ],
                                          ),
                                        );
                                      } else {
                                        showCupertinoDialog(
                                          context: context,
                                          builder: (context) => CupertinoAlertDialog(
                                            title: const Text('Error'),
                                            content: const Text('Failed to update your name. Please try again.'),
                                            actions: [
                                              CupertinoDialogAction(
                                                child: const Text('OK'),
                                                onPressed: () => Navigator.pop(context),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  },
                                  child: Icon(
                                    CupertinoIcons.checkmark,
                                    color: isValid ? CupertinoColors.systemBlue : CupertinoColors.inactiveGray,
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
                      } else if (!RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(text)) {
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
                          final isValid = value.text.trim().isNotEmpty && RegExp(r"^[a-zA-Z\s\-']+$").hasMatch(value.text) && validationError == null;
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
                                    color: isValid ? const Color(0xFF2A7D8F) : Colors.grey,
                                    size: 26,
                                  ),
                                  onPressed: !isValid ? null : () async {
                                    final input = _nameController.text.trim();

                                    setSheetState(() {
                                      _isLoading = true;
                                    });

                                    final success = await _updateUserName(input);
                                    
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
                                            content: const Text('Name updated successfully.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () {
                                                  Navigator.pop(context); // close dialog
                                                  Navigator.pop(context); // close sheet
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
                                            content: const Text('Failed to update your name. Please try again.'),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.pop(context),
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<supa.AuthState>(
      stream: supa.Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final user = supa.Supabase.instance.client.auth.currentUser;
        final customName = user?.userMetadata?['custom_display_name'] as String?;
        final fullName = user?.userMetadata?['full_name'] as String?;
        final resolvedName = (customName != null && customName.isNotEmpty) ? customName : fullName;
        final displayName = (resolvedName != null && resolvedName.trim().isNotEmpty)
            ? resolvedName
            : 'Not set';
        final email = user?.email ?? 'Not set';
        final isEmailVerified = user?.emailConfirmedAt != null;
        final verificationStatus = isEmailVerified ? 'Verified' : 'Not verified';

        return Scaffold(
          appBar: const PlatformAdaptiveAppBar(title: 'Account Information'),
      backgroundColor: Color(0xFFF8F9F8),

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
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
                offset: Offset(0, 3),
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
                    child: Padding(
                      padding: EdgeInsets.only(right: 8.0),
                      child: Icon(
                        CupertinoIcons.pencil,
                        color: Color(0xFF2A7D8F),
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              //Email Address field row
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  verificationStatus,
                                  style: TextStyle(
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
              //           size: 20,
              //         ),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
      }
    );
  }
}
