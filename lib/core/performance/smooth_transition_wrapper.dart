import 'package:flutter/material.dart';

/// A utility widget that delays rendering heavy or complex UI subtrees
/// until the page transition (e.g. slide/fade) is fully complete.
class SmoothTransitionWrapper extends StatefulWidget {
  final Widget child;
  final Widget? placeholder;

  const SmoothTransitionWrapper({
    super.key,
    required this.child,
    this.placeholder,
  });

  @override
  State<SmoothTransitionWrapper> createState() => _SmoothTransitionWrapperState();
}

class _SmoothTransitionWrapperState extends State<SmoothTransitionWrapper> {
  bool _shouldRender = false;
  Animation<double>? _routeAnimation;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_routeAnimation == null) {
      final modalRoute = ModalRoute.of(context);
      final animation = modalRoute?.animation;
      if (animation != null) {
        _routeAnimation = animation;
        if (animation.isCompleted) {
          _shouldRender = true;
        } else {
          animation.addStatusListener(_onRouteAnimationStatusChange);
        }
      } else {
        // No modal route found, render immediately
        _shouldRender = true;
      }
    }
  }

  void _onRouteAnimationStatusChange(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChange);
      if (mounted) {
        setState(() {
          _shouldRender = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _routeAnimation?.removeStatusListener(_onRouteAnimationStatusChange);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_shouldRender) {
      return RepaintBoundary(
        child: widget.child,
      );
    }
    return widget.placeholder ??
        const Scaffold(
          backgroundColor: Color(0xFFF8F9F8),
          body: Center(
            child: CircularProgressIndicator(
              color: Color(0xFF2A7D8F),
            ),
          ),
        );
  }
}
