import 'package:flutter/material.dart';

/// A custom, high-performance replacement for Flutter's [IndexedStack] that
/// smoothly transitions between its children using a cross-fade animation.
///
/// Keeps all children alive in memory (preserving scroll positions, forms, and controller states)
/// while utilizing [TickerMode] to freeze tickers (cursors, animation controllers, scroll events)
/// on non-active pages to minimize CPU cycles and conserve battery life.
class FadeIndexedStack extends StatefulWidget {
  final int index;
  final List<Widget> children;
  final Duration duration;

  const FadeIndexedStack({
    super.key,
    required this.index,
    required this.children,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  State<FadeIndexedStack> createState() => _FadeIndexedStackState();
}

class _FadeIndexedStackState extends State<FadeIndexedStack>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.children.length,
      (i) => AnimationController(
        vsync: this,
        duration: widget.duration,
        value: i == widget.index ? 1.0 : 0.0,
      ),
    );

    _animations = _controllers.map((c) {
      return CurvedAnimation(parent: c, curve: Curves.easeInOut);
    }).toList();
  }

  @override
  void didUpdateWidget(FadeIndexedStack oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.index != widget.index) {
      _controllers[oldWidget.index].reverse();
      _controllers[widget.index].forward();
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: List.generate(widget.children.length, (i) {
        return FadeTransition(
          opacity: _animations[i],
          child: IgnorePointer(
            ignoring: i != widget.index,
            child: TickerMode(
              enabled: i == widget.index || _controllers[i].isAnimating,
              child: widget.children[i],
            ),
          ),
        );
      }),
    );
  }
}
