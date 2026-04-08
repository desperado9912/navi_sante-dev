// Continously Listen For auth state changes and navigate accordingly.
// Handles: initial routing, token rotation, session expiry, sign-out.
//  # unauthenticated --> Login Page
//  # authenticated --> Home page

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/features/auth/cubit/auth_cubit.dart';
import 'package:navi_sante/features/auth/screens/login.dart';
import 'package:navi_sante/features/navigation_menu.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _listenToAuthEvents();
  }

  @override
  void dispose() {
    // Prevent memory leaks by canceling the listener
    _authSubscription?.cancel();
    super.dispose();
  }

  void _listenToAuthEvents() {
    _authSubscription = supa.Supabase.instance.client.auth.onAuthStateChange
        .listen(
          (data) {
            final event = data.event;

            switch (event) {
              case supa.AuthChangeEvent.signedIn:
                debugPrint('[AuthGate] User signed in.');
                break;
              case supa.AuthChangeEvent.tokenRefreshed:
                debugPrint('[AuthGate] Token rotated successfully.');
                break;
              case supa.AuthChangeEvent.signedOut:
                debugPrint('[AuthGate] User signed out — resetting state.');
                if (mounted) context.read<AuthCubit>().reset();
                break;
              case supa.AuthChangeEvent.userUpdated:
                debugPrint('[AuthGate] User record updated.');
                break;
              case supa.AuthChangeEvent.passwordRecovery:
                debugPrint('[AuthGate] Password recovery triggered.');
                break;
              default:
                break;
            }
          },
          onError: (error) {
            debugPrint('[AuthGate] Auth stream error: $error');
            if (mounted) context.read<AuthCubit>().reset();
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<supa.AuthState>(
      //Listen to auth state changes
      stream: supa.Supabase.instance.client.auth.onAuthStateChange.distinct(
        (prev, next) => (prev.session != null) == (next.session != null),
      ),

      //Build the right page based on auth state
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        //Check if there is an active session and navigate accordingly
        final session = snapshot.data?.session;

        if (session != null) {
          return NavigationMenu();
        } else {
          return LoginScreen();
        }
      },
    );
  }
}
