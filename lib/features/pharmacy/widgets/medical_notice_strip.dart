import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// Permanent, compact notice strip — sits below the quick filters and
/// above the results list, so it's always visible without scrolling and
/// never competes with the bottom nav bar for space.
class MedicalNoticeStrip extends StatelessWidget {
  const MedicalNoticeStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFD8F6FF).withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(
            CupertinoIcons.info_circle_fill,
            color: Color(0xFF2A7D8F),
            size: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Certain medications require medical supervision. Please always consult a healthcare professional before use.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[700],
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }
}
