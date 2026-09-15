import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:navi_sante/features/ai_chat/screens/ai_chat.dart';
import '../controller/map_cubit.dart';
import 'map_info_sheet.dart';

/// A sleek, glassmorphic column of map controls (zoom in, zoom out, center/locate, info etc.).
class MapControls extends StatelessWidget {
  const MapControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
      buildWhen: (prev, curr) =>
          (prev is MapLoadingState) != (curr is MapLoadingState),
      builder: (context, state) {
        final mapCubit = context.read<MapCubit>();
        final bool isLoading = state is MapLoadingState;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Zoom In Button
            _GlassmorphicButton(
              icon: CupertinoIcons.add,
              tooltip: 'Zoom In',
              onTap: isLoading ? null : mapCubit.zoomIn,
            ),
            const SizedBox(height: 10),

            // Zoom Out Button
            _GlassmorphicButton(
              icon: CupertinoIcons.minus,
              tooltip: 'Zoom Out',
              onTap: isLoading ? null : mapCubit.zoomOut,
            ),
            const SizedBox(height: 10),

            // Locate Me Button — always tappable, uses instant last-known position
            _GlassmorphicButton(
              icon: CupertinoIcons.location_fill,
              iconColor: CupertinoColors.systemBlue,
              tooltip: '',
              isLoading: false,
              onTap: () => mapCubit.locateUser(requestPermission: true),
            ),
            const SizedBox(height: 10),

            //Info button
            _GlassmorphicButton(
              icon: CupertinoIcons.info_circle,
              tooltip: 'map info',
              onTap: () => _showMapInfoSheet(context),
            ),
            const SizedBox(height: 40),

            // AI Chat Button
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AIChatButton(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const AIChatPage(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 4),
                const Text(
                  'Navi AI',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

void _showMapInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: kCupertinoModalBarrierColor,
    isScrollControlled: true,
    enableDrag: true,
    sheetAnimationStyle: AnimationStyle(
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 200),
    ),
    builder: (_) => const MapInfoSheet(),
  );
}

/// A highly polished, custom glassmorphic button with built-in micro-animations on tap.
class _GlassmorphicButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final Color iconColor;
  final bool isLoading;

  const _GlassmorphicButton({
    required this.icon,
    required this.onTap,
    required this.tooltip,
    this.iconColor = const Color(0xFF1A1A1A),
    this.isLoading = false,
  });

  @override
  State<_GlassmorphicButton> createState() => _GlassmorphicButtonState();
}

class _GlassmorphicButtonState extends State<_GlassmorphicButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.onTap != null) {
      _animationController.forward();
    }
  }

  void _handleTapUp(TapUpDetails details) {
    if (widget.onTap != null) {
      _animationController.reverse();
    }
  }

  void _handleTapCancel() {
    if (widget.onTap != null) {
      _animationController.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEnabled = widget.onTap != null;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Tooltip(
          message: widget.tooltip,
          child: Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 16,
                  spreadRadius: 0,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Material(
                  color: Colors.white.withValues(alpha: 0.78),
                  child: InkWell(
                    onTapDown: _handleTapDown,
                    onTapUp: _handleTapUp,
                    onTapCancel: _handleTapCancel,
                    onTap: widget.onTap,
                    child: Center(
                      child: Icon(
                        widget.icon,
                        size: 22,
                        color: widget.iconColor,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AIChatButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AIChatButton({required this.onTap});

  @override
  State<_AIChatButton> createState() => _AIChatButtonState();
}

class _AIChatButtonState extends State<_AIChatButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Tooltip(
        message: 'AI Chat',
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF2A7D8F),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                spreadRadius: 2,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTapDown: (_) => _animationController.forward(),
              onTapUp: (_) => _animationController.reverse(),
              onTapCancel: () => _animationController.reverse(),
              onTap: widget.onTap,
              child: Center(
                child: ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFF2B035),
                      Color(0xFFC9DEE3), // Light cyan gradient
                    ],
                  ).createShader(bounds),
                  child: const FaIcon(
                    FontAwesomeIcons
                        .hexagonNodes, //or 'openai' or 'robot' or 'gemini'
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
