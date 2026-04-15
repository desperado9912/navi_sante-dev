import 'package:flutter/material.dart';
import 'package:navi_sante/features/shared/widgets/platform_adaptive_app_bar.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class AccountInfo extends StatelessWidget {
  const AccountInfo({super.key});

  @override
  Widget build(BuildContext context) {
    final user = supa.Supabase.instance.client.auth.currentUser;

    final fullName = user?.userMetadata?['full_name'] ?? 'Not set';
    final country = user?.userMetadata?['country'] ?? 'Not set';
    final isEmailVerified = user?.emailConfirmedAt != null;

    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Account Information'),
      backgroundColor: Color(0xFFF8F9F8),
      

      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
        child: Column(
          children: [
            const SizedBox(height: 24),
            Center(),

            const SizedBox(height: 32),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
