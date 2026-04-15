// Continously Listen For auth state changes and navigate accordingly.
// Handles: initial routing, token rotation, session expiry, sign-out.
//  # unauthenticated --> Login Page
//  # authenticated --> Home page (navigation_menu.dart)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
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
  StreamSubscription? _authSub;
  supa.Session? _currentSession = supa.Supabase.instance.client.auth.currentSession;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _listenToAuth();
  }

  void _listenToAuth() {
    // 1. Initial State Check: If we already have a session, stop loading immediately.
    if (_currentSession != null) {
      _handleSignInLogic(isInitialCheck: true);
    } else {
      _isLoading = false;
    }

    // 2. The Manager: Listen to the auth stream once. 
    // This logic only runs when an ACTUAL auth event occurs.
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;

      switch (event) {
        case supa.AuthChangeEvent.signedIn:
          debugPrint('[AuthGate] User signed in.');
          _handleSignInLogic();
          break;

        case supa.AuthChangeEvent.tokenRefreshed:
          debugPrint('[AuthGate] Token rotated successfully.');
          break;

        case supa.AuthChangeEvent.signedOut:
          debugPrint('[AuthGate] User signed out — resetting state.');
          // Use mounted check to safely access context across the async gap
          if (mounted) context.read<AuthCubit>().reset();
          
          // Clean up GetX controller
          if (Get.isRegistered<NavigationController>()) {
            Get.delete<NavigationController>(force: true);
          }
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

      // 3. The UI Update: Only triggers when the session status actually changes.
      if (mounted) {
        setState(() {
          _currentSession = session;
          _isLoading = false;
        });
      }
    });
  }

  /// Ensures a fresh login or app-start lands on the Home tab (index 0).
  void _handleSignInLogic({bool isInitialCheck = false}) {
    if (Get.isRegistered<NavigationController>()) {
      Get.put(NavigationController()).selectedIndex.value = 0;
    }
    if (isInitialCheck && mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    // 4. Memory Leak Prevention: Close the manual subscription.
    _authSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 5. The Painter: Only decides what to show based on local state.
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return (_currentSession != null) 
        ? const NavigationMenu() 
        : const LoginScreen();
  }
}







//   @override
//   Widget build(BuildContext context) {
//     return StreamBuilder<supa.AuthState>(
//       //Listen to auth state changes
//       stream: supa.Supabase.instance.client.auth.onAuthStateChange,

//       //Build the right page based on auth state
//       builder: (context, snapshot) {
//         if (snapshot.connectionState == ConnectionState.waiting &&
//             !snapshot.hasData) {
//           return const Scaffold(
//             body: Center(child: CircularProgressIndicator()),
//           );
//         }

//         // listen to Auth events
//         final event = snapshot.data?.event;
//         final session = snapshot.data?.session;

//         if (event != null) {
//           switch (event) {
//             case supa.AuthChangeEvent.signedIn:
//               debugPrint('[AuthGate] User signed in.');
//               // Reset nav index to Home on every fresh sign-in
//               if (Get.isRegistered<NavigationController>()) {
//                 Get.find<NavigationController>().selectedIndex.value = 0;
//               }
//               break;

//             case supa.AuthChangeEvent.tokenRefreshed:
//               debugPrint('[AuthGate] Token rotated successfully.');
//               break;

//             case supa.AuthChangeEvent.signedOut:
//               debugPrint('[AuthGate] User signed out — resetting state.');
//               // Reset cubit state 
//               context.read<AuthCubit>().reset();
//               // Clean up GetX controller so next login gets a fresh instance
//               if (Get.isRegistered<NavigationController>()) {
//                 Get.delete<NavigationController>(force: true);
//               }
//               break;

//             case supa.AuthChangeEvent.userUpdated:
//               debugPrint('[AuthGate] User record updated.');
//               break;

//             case supa.AuthChangeEvent.passwordRecovery:
//               debugPrint('[AuthGate] Password recovery triggered.');
//               break;

//             default:
//               break;
//           }
//         }

//         //Check if there is an active session and route accordingly
//         if (session != null) {
//           return const NavigationMenu();
//         } else {
//           return const LoginScreen();
//         }
//       },
//     );
//   }
// }
