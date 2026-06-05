import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/features/home/screens/ai_chat.dart';
import '../controller/map_cubit.dart';

/// A sleek, glassmorphic column of map controls (zoom in, zoom out, center/locate).
class MapControls extends StatelessWidget {
  const MapControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MapCubit, MapState>(
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

            // Locate Me Button
            _GlassmorphicButton(
              icon: CupertinoIcons.location_fill,
              iconColor: CupertinoColors.systemBlue,
              tooltip: '',
              isLoading: false,
              onTap: () {
                mapCubit.locateUser(requestPermission: true);
              },
            ),
            const SizedBox(height: 10),

            //Info button
            _GlassmorphicButton(
              icon: CupertinoIcons.info_circle,
              tooltip: 'map info',
              onTap: () {
                // TODO: ADD INFO BOTTOM SHEET
              },
            ),
            const SizedBox(height: 40),

            //ai chat button
            _GlassmorphicButton(
              icon: CupertinoIcons.chat_bubble,
              iconColor: const Color(0xFF2A7D8F),
              tooltip: 'AI Chat',
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const AIChatPage()),
                );
              },
            ),
          ],
        );
      },
    );
  }
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
    this.iconColor = Colors.black,
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
