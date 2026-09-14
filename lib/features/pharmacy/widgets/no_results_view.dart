import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';

/// Shown when MedicationSearchEngine finds nothing for the current
/// query — the graceful end state your search flow explicitly asked
/// for, so a dead-end search never just leaves a blank screen.
class NoResultsView extends StatelessWidget {
  final String query;
  const NoResultsView({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_rounded, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              context.isFrench
                  ? 'Aucun médicament trouvé pour "$query"'
                  : 'No medications found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Try a different name, brand, or symptom — e.g. "headache" or "malaria".',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}