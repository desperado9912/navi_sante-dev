import 'package:flutter/foundation.dart';

/// Placeholder controller for profile statistics and health score.
/// Health score logic will be implemented in a future sprint.
/// Currently exposes static placeholder values for UI scaffolding.
///
/// Replace [loadHealthScore] implementation when the scoring feature is built.
class ProfileController extends ChangeNotifier {
  double _healthScore      = 84.0;
  double _healthScoreTrend = 4.3;
  bool   _isTrendPositive  = true;

  double get healthScore       => _healthScore;
  double get healthScoreTrend  => _healthScoreTrend;
  bool   get isTrendPositive   => _isTrendPositive;

  /// Placeholder — fetches health score from Supabase when implemented.
  Future<void> loadHealthScore() async {
    // TODO: replace with real Supabase fetch when scoring feature is built
    notifyListeners();
  }
}