import 'package:supabase_flutter/supabase_flutter.dart';
import 'pharmacy_model.dart';

/// Owns all network calls for medication data. No caching, no retry
/// logic, no single-flight guarding — that all lives in
/// MedicationRepository. This class exists purely so the repository
/// never imports supabase_flutter directly, same separation as
/// FacilityRemote.
///
/// Every method here is a plain, single network call. Do not add
/// looping, polling, or automatic retries in this file — that
/// responsibility belongs entirely to the repository's guarded fetch,
/// so there is exactly one place in the codebase that decides when a
/// medication network call is allowed to happen.
class MedicationRemote {
  final SupabaseClient _supabase;
  MedicationRemote(this._supabase);

  /// Fetches every active medication, with conditions and retailers
  /// aggregated server-side in a single round trip.
  Future<List<MedicationModel>> getAllMedications() async {
    final response = await _supabase.rpc('get_all_medications');
    return (response as List<dynamic>)
        .map((row) => MedicationModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// The curated set of condition chips to show before/alongside recent
  /// searches (Malaria, Fever, Headache, ...). A plain table read, not
  /// an RPC — matches how FacilityRemote.getUserBookmarks() does a
  /// simple select rather than a function call for a simple lookup.
  Future<List<String>> getQuickFilterConditions() async {
    final response = await _supabase
        .from('condition')
        .select('name')
        .eq('is_quick_filter', true)
        .order('display_order');
    return (response as List<dynamic>)
        .map((row) => row['name'] as String)
        .toList();
  }

  // FAVOURITES
  Future<Set<String>> getUserFavourites() async {
    final response = await _supabase
        .from('medication_favourites')
        .select('medication_id');
    return (response as List<dynamic>)
        .map((row) => row['medication_id'] as String)
        .toSet();
  }

  Future<void> addFavourite(String medicationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    await _supabase.from('medication_favourites').upsert(
      {'user_id': userId, 'medication_id': medicationId},
      onConflict: 'user_id,medication_id',
      ignoreDuplicates: true,
    );
  }

  Future<void> removeFavourite(String medicationId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    await _supabase
        .from('medication_favourites')
        .delete()
        .eq('medication_id', medicationId)
        .eq('user_id', userId);
  }
}