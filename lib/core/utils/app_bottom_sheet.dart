import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'language_cubit/language_cubit.dart';

/// A reusable bottom sheet widget that encapsulates the core visual styling and behavior.
/// This acts as a single source of truth for the bottom sheet containers in the app.
class AppBottomSheet extends StatelessWidget {
  /// The content to show inside the bottom sheet.
  final Widget child;

  /// Optional title. If provided, a header row with the title and a close button will be displayed.
  final String? title;

  /// Whether to show the drag handle at the top. Defaults to true.
  final bool showDragHandle;

  /// Whether to show a close button in the header. Only applicable if [title] is not null.
  final bool showCloseButton;

  /// Optional maximum height fraction of the screen height (e.g. 0.6 for 60%).
  final double? maxHeightFraction;

  /// Custom padding for the content area.
  final EdgeInsetsGeometry? padding;

  const AppBottomSheet({
    super.key,
    required this.child,
    this.title,
    this.showDragHandle = true,
    this.showCloseButton = true,
    this.maxHeightFraction,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = child;

    // Build the header if a title is provided.
    if (title != null) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Padding(
            padding: const EdgeInsets.only(left: 30, right: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    context.tr(title!),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
                if (showCloseButton)
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 35,
                      height: 35,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        CupertinoIcons.xmark,
                        size: 16,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (padding != null)
            Padding(padding: padding!, child: child)
          else
            child,
        ],
      );
    } else {
      if (padding != null) {
        content = Padding(padding: padding!, child: content);
      }
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      constraints: maxHeightFraction != null
          ? BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * maxHeightFraction!,
            )
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showDragHandle) ...[
            // Drag Handle
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFE0E0E0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Flexible(child: content),
        ],
      ),
    );
  }
}
