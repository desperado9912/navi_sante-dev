import 'dart:async';
import 'package:flutter/material.dart';
import 'connectivity_service.dart';
import 'package:flutter/cupertino.dart';
import '../language_cubit/language_cubit.dart';

/// Small, non-blocking connectivity banner UI.
///
/// This widget only reports device connectivity state. It intentionally does
/// not handle search errors, API errors, timeouts, Supabase errors, or cache
/// behavior.
class ConnectivityBanner extends StatefulWidget {
  const ConnectivityBanner({
    super.key,
    this.themeColor = const Color(0xFF2A7D8F),
  });

  final Color themeColor;

  @override
  State<ConnectivityBanner> createState() => _ConnectivityBannerState();
}

class _ConnectivityBannerState extends State<ConnectivityBanner>
    with WidgetsBindingObserver, TickerProviderStateMixin {
  final ConnectivityService _service = ConnectivityService.instance;

  Timer? _restoreTimer;
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);
    _service.start();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, -1.0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _service.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _restoreTimer?.cancel();
    _animationController.dispose();
    super.dispose();
  }

  void _dismissOfflineBanner() {
    _service.dismissOfflineBanner();
  }

  void _scheduleRestoreDismissal() {
    _restoreTimer?.cancel();

    _restoreTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;

      final current = _service.state.value;

      if (current.status == ConnectivityBannerStatus.restored) {
        _service.state.value = const ConnectivityBannerState(
          status: ConnectivityBannerStatus.hidden,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ConnectivityBannerState>(
      valueListenable: _service.state,
      builder: (context, bannerState, _) {
        // Handle animation based on visibility changes
        if (bannerState.isVisible) {
          if (_animationController.status == AnimationStatus.dismissed ||
              _animationController.status == AnimationStatus.reverse) {
            _animationController.forward();
          }
        } else {
          if (_animationController.status == AnimationStatus.completed ||
              _animationController.status == AnimationStatus.forward) {
            _animationController.reverse();
          }
        }

        if (!bannerState.isVisible) {
          _restoreTimer?.cancel();
          return const SizedBox.shrink();
        }

        if (bannerState.status == ConnectivityBannerStatus.restored) {
          _scheduleRestoreDismissal();
        } else {
          _restoreTimer?.cancel();
        }

        // A manually dismissed offline banner stays dismissed until the
        // connectivity state changes again.
        if (bannerState.status == ConnectivityBannerStatus.offline &&
            bannerState.dismissed) {
          return const SizedBox.shrink();
        }

        final isRestored =
            bannerState.status == ConnectivityBannerStatus.restored;

        final backgroundColor = isRestored
            ? widget.themeColor
            : const Color(0xFFEF3F5F);

        final icon = isRestored
            ? CupertinoIcons.check_mark_circled_solid
            : Icons.wifi_off_rounded;

        final text = isRestored
            ? context.t('Internet connection restored', 'Connexion internet rétablie')
            : context.t('No internet connection', 'Pas de connexion internet');

        return SafeArea(
          bottom: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 12, left: 24, right: 24),
              child: SlideTransition(
                position: _slideAnimation,
                child: Dismissible(
                  key: ValueKey(
                    '${bannerState.status.name}-${bannerState.dismissed}',
                  ),
                  direction: DismissDirection.up,
                  onDismissed: (_) {
                    _animationController.reverse();
                    if (!isRestored) {
                      _dismissOfflineBanner();
                    } else {
                      _service.state.value = const ConnectivityBannerState(
                        status: ConnectivityBannerStatus.hidden,
                      );
                    }
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: Semantics(
                      liveRegion: true,
                      label: text,
                      child: Container(
                        constraints: const BoxConstraints(
                          minHeight: 38,
                          maxWidth: 350,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: backgroundColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 12,
                              offset: Offset(0, 4),
                              color: Color(0x22000000),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 20, color: Colors.white),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                text,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  height: 1.15,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
