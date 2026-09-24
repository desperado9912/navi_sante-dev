import 'package:flutter/material.dart';

/// Small "Contributor" pill shown on a facility's detail screen — ONLY to
/// the user who actually contributed to that facility (never to the
/// general public). Privacy is enforced server-side by RLS on
/// `facility_contributors`, not by this widget — this is purely display.
///
/// Usage: wrap in a FutureBuilder driven by
/// `FacilityRepository.isCurrentUserContributor(facilityId)` and only
/// build this widget when that resolves to `true`.
///
/// ```dart
/// FutureBuilder<bool>(
///   future: context.read<FacilityRepository>().isCurrentUserContributor(facility.facilityId),
///   builder: (context, snapshot) {
///     if (snapshot.data != true) return const SizedBox.shrink();
///     return const ContributorBadge();
///   },
/// )
/// ```
class ContributorBadge extends StatelessWidget {
  const ContributorBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A7D8F), Color(0xFF1E5F6E)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2A7D8F).withValues(alpha: 0.25),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.workspace_premium_outlined, size: 14, color: Colors.white),
          SizedBox(width: 5),
          Text(
            'Contributor',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}