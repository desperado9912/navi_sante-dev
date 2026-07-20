// Continously Listen For auth state changes and navigate accordingly.
// Handles operations & state changes that are to occur during auth login & signout.
// Handles: initial routing, token rotation, session expiry, sign-out.
//  # unauthenticated --> Login Page
//  # authenticated --> Home page (navigation_menu.dart)
//  # Token rotation --> Update token and continue

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get/get.dart';
import 'package:navi_sante/features/auth/cubit/auth_cubit.dart';
import 'package:navi_sante/features/auth/screens/login.dart';
import 'package:navi_sante/core/utils/navigation_menu.dart';
import 'package:navi_sante/features/hospitals/controller/facility_bloc.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription? _authSub;
  supa.Session? _currentSession =
      supa.Supabase.instance.client.auth.currentSession;
  bool _isLoading = true;
  bool _splashRemoved = false;

  @override
  void initState() {
    super.initState();
    _listenToAuth();
  }

  // Listen to state changes for init and then dismiss splash after first fram paint
  void _removeSplash() {
    if (_splashRemoved) return;
    _splashRemoved = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  void _listenToAuth() {
    // 1. Initial State Check: If we already have a session, stop loading immediately.
    if (_currentSession != null) {
      _handleSignInLogic(isInitialCheck: true);
    } else {
      _isLoading = false;
      _removeSplash();
    }

    // 2. The Manager: Listen to the auth stream once.
    // This logic only runs when an ACTUAL auth event occurs.
    _authSub = supa.Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) {
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
          if (mounted) {
            context.read<AuthCubit>().reset();
            context.read<FacilityBloc>().add(ClearBookmarks());
          }

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
        _removeSplash();
      }
    });
  }

  /// Ensures a fresh login or app-start lands on the Home tab (index 0).
  /// Ensures facility data and bookmarks are loaded on login .
  void _handleSignInLogic({bool isInitialCheck = false}) {
    if (Get.isRegistered<NavigationController>()) {
      Get.put(NavigationController()).selectedIndex.value = 0;
    }
    if (isInitialCheck && mounted) {
      setState(() => _isLoading = false);
    }

    context.read<FacilityBloc>().add(LoadFacilities());
    context.read<FacilityBloc>().add(LoadRecentlyViewed());
    context.read<FacilityBloc>().add(LoadBookmarks());

    if (isInitialCheck) _removeSplash();
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return (_currentSession != null)
        ? const NavigationMenu()
        : const LoginScreen();
  }
}
