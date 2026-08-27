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
        children: [
          const Icon(Icons.info_rounded, color: Color(0xFF2A7D8F), size: 15),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              'Always consult a doctor or pharmacist before taking medication.',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey[800],
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}