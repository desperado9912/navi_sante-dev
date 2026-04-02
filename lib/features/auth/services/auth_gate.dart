// Continously Listen For auth state changes.

//# unauthenticated --> Login Page
//# authenticated --> Home page

import 'package:flutter/material.dart';
import 'package:navi_sante/features/auth/screens/login.dart';
import 'package:navi_sante/features/home/home_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      //Listen to auth state changes
      stream: Supabase.instance.client.auth.onAuthStateChange,
      
      //Build the right page based on auth state
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
      //Check if there is an active session and navigate accordingly
        final session = Supabase.instance.client.auth.currentSession;

        if (session != null) {
          return HomeScreen();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
