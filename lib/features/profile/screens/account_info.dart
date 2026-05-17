import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;


class AccountInfo extends StatelessWidget {
  const AccountInfo({super.key});

// Future<void> _updateFullName() async {
//   final user = supabase.auth.currentUser;
//   if (user != null) {
//     try {
//       // Option A: Update stored metadata (persistent)
//       await supabase.auth.updateUser(
//         UserAttributes(
//           data: {
//             'full_name': _nameController.text.trim(),
//           },
//         ),
//       );

//       // Option B: Update custom_display_name (if you use that for UI)
//       await supabase.auth.updateUser(
//         UserAttributes(
//           data: {
//             'custom_display_name': _nameController.text.trim(),
//           },
//         ),
//       );

//       setState(() { /* refresh UI */ });
//     } catch (e) {
//       debugPrint('Error updating profile: $e');
//     }
//   }
// }

  @override
  Widget build(BuildContext context) {
    final user = supa.Supabase.instance.client.auth.currentUser;
    final fullName = user?.userMetadata?['full_name'] as String?;
    final displayName = (fullName != null && fullName.trim().isNotEmpty)
        ? fullName
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
                    onTap: () => {},
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
}
