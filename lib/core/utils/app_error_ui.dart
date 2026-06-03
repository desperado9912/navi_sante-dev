// Centralized UI feedback utility for consistent error/warning/info/success
// presentation across the entire app.
//
// Usage:
// ''dart
// AppFeedback.show(context, type: FeedbackType.error, message: 'Incorrect email or password.');
// AppFeedback.show(context, type: FeedbackType.warning, message: '...', title: 'Warning');
// ''

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

// ── Feedback categories ──────────────────────────────────────────────
enum FeedbackType { error, warning, info, success }

class AppFeedback {
  AppFeedback._();

  // Color palette
  static const _errorColor = Color(0xFFC0392B);
  static const _warningColor = Color(0xFFE67E22);
  static const _infoColor = Color(0xFF2A7D8F);
  static const _successColor = Color(0xFF2A7D8F);

  static Color _colorFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.error:
        return _errorColor;
      case FeedbackType.warning:
        return _warningColor;
      case FeedbackType.info:
        return _infoColor;
      case FeedbackType.success:
        return _successColor;
    }
  }

  static IconData _iconFor(FeedbackType type) {
    switch (type) {
      case FeedbackType.error:
        return Icons.error_outline_rounded;
      case FeedbackType.warning:
        return Icons.warning_amber_rounded;
      case FeedbackType.info:
        return Icons.info_outline_rounded;
      case FeedbackType.success:
        return Icons.check_circle_outline_rounded;
    }
  }

  /// Shows a floating SnackBar with icon, message, and optional [title].
  static void show(
    BuildContext context, {
    required FeedbackType type,
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    final color = _colorFor(type);
    final icon = _iconFor(type);

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: title != null
                ? CrossAxisAlignment.start
                : CrossAxisAlignment.center,
            children: [
              Icon(icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: title != null
                    ? Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            message,
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        message,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
              ),
            ],
          ),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
          duration: duration,
          action: action,
        ),
      );
  }

  // ── Platform-adaptive error dialog ───────────────────────────────
  /// Shows a platform-adaptive dialog for critical errors that need acknowledgment.
  static void showErrorDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    if (isIOS) {
      showCupertinoDialog(
        context: context,
        builder: (ctx) => CupertinoAlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            CupertinoDialogAction(
              child: const Text('OK'),
              onPressed: () => Navigator.pop(ctx),
            ),
          ],
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(title),
          content: Text(
            message,
            style: const TextStyle(fontSize: 14, color: Color(0xFF5F6368)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'OK',
                style: TextStyle(
                  color: Color(0xFF2A7D8F),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  // ── Inline error widget for bottom sheets ────────────────────────
  /// Returns a styled inline error container for use inside bottom sheets.
  /// Returns an empty SizedBox when [error] is null.
  static Widget inlineError(String? error) {
    if (error == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _errorColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _errorColor.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: _errorColor,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: _errorColor,
                fontSize: 13,
                fontWeight: FontWeight.w500,
                decoration: TextDecoration.none,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
