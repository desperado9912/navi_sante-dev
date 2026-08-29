import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum ConnectivityBannerStatus {
  hidden,
  offline,
  restored,
}

class ConnectivityBannerState {
  const ConnectivityBannerState({
    required this.status,
    this.dismissed = false,
  });

  final ConnectivityBannerStatus status;
  final bool dismissed;

  bool get isVisible => status != ConnectivityBannerStatus.hidden;

  ConnectivityBannerState copyWith({
    ConnectivityBannerStatus? status,
    bool? dismissed,
  }) {
    return ConnectivityBannerState(
      status: status ?? this.status,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Global connectivity listener used only for the app-level connectivity banner.
///
/// This service intentionally does NOT handle API requests, timeouts, cache
/// lookups, Supabase errors, or feature-specific network states.
class ConnectivityService {
  ConnectivityService._();

  static final ConnectivityService instance = ConnectivityService._();

  final Connectivity _connectivity = Connectivity();

  final ValueNotifier<ConnectivityBannerState> state =
      ValueNotifier<ConnectivityBannerState>(
    const ConnectivityBannerState(
      status: ConnectivityBannerStatus.hidden,
    ),
  );

  StreamSubscription<List<ConnectivityResult>>? _subscription;

  bool _started = false;
  bool _hasKnownConnectivityState = false;
  bool _isOffline = false;

  /// Starts the listener once.
  ///
  /// Safe to call multiple times.
  Future<void> start() async {
    if (_started) return;

    _started = true;

    // Subscribe before the initial check so a connectivity change cannot be
    // missed while checkConnectivity() is running.
    _subscription = _connectivity.onConnectivityChanged.listen(
      _handleConnectivityChange,
      onError: (_) {
        // Do not turn listener errors into a UI error. The feature-level
        // request handling remains responsible for actual network failures.
      },
    );

    await _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();

      final offline = !_hasUsableConnectivity(result);

      // Initial state is silent: if the app starts offline, show the offline
      // banner, but never show "connection restored" on initial launch.
      _isOffline = offline;
      _hasKnownConnectivityState = true;

      if (offline) {
        state.value = const ConnectivityBannerState(
          status: ConnectivityBannerStatus.offline,
          dismissed: false,
        );
      } else {
        state.value = const ConnectivityBannerState(
          status: ConnectivityBannerStatus.hidden,
        );
      }
    } on PlatformException {
      // If the platform check fails, do not manufacture an offline state.
      // Existing API timeout/error handling remains untouched.
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> result) {
    final offline = !_hasUsableConnectivity(result);

    // Ignore duplicate states. This is especially useful on iOS where
    // NWPathMonitor can briefly emit transitional values.
    if (_hasKnownConnectivityState && offline == _isOffline) {
      return;
    }

    final wasOffline = _isOffline;

    _isOffline = offline;
    _hasKnownConnectivityState = true;

    if (offline) {
      state.value = const ConnectivityBannerState(
        status: ConnectivityBannerStatus.offline,
        dismissed: false,
      );
      return;
    }

    // Only show "restored" when we actually transitioned from offline to
    // connected. Never show it on the first successful connectivity check.
    if (wasOffline) {
      state.value = const ConnectivityBannerState(
        status: ConnectivityBannerStatus.restored,
        dismissed: false,
      );
    } else {
      state.value = const ConnectivityBannerState(
        status: ConnectivityBannerStatus.hidden,
      );
    }
  }

  bool _hasUsableConnectivity(List<ConnectivityResult> result) {
    return result.any(
      (type) => type != ConnectivityResult.none,
    );
  }

  /// Dismisses only the currently displayed offline banner.
  ///
  /// This does not change connectivity state and does not prevent a future
  /// offline/online transition from producing another notification.
  void dismissOfflineBanner() {
    if (state.value.status != ConnectivityBannerStatus.offline) return;

    state.value = state.value.copyWith(
      dismissed: true,
    );
  }

  /// Called by the UI when it resumes from the background.
  ///
  /// This is intentionally only a connectivity re-check; it does not make
  /// any application API request.
  Future<void> refresh() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _handleConnectivityChange(result);
    } on PlatformException {
      // Ignore and let feature-level request handling deal with real
      // network failures.
    }
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _started = false;
  }
}
