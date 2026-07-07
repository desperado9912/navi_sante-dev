import 'dart:convert';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/facility_model.dart';

/// Owns all Database network calls for facility data.
/// No business logic, no caching — just RPC calls and model parsing.
/// Errors (PostgrestException, AuthException) bubble up to the repository
/// which decides how to handle them based on cache availability.
/// Unlike [FacilityLocal], this class handles all network requests.

class FacilityRemote {
  final SupabaseClient _supabase;
  FacilityRemote(this._supabase);

  /// Fetches every facility in the database
  /// Called once per session; result is cached entirely in Hive.
  Future<List<FacilityModel>> getAllFacilities() async {
    final response = await _supabase.rpc('get_all_facilities');
    return (response as List<dynamic>)
        .map((row) => FacilityModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Searches facilities by [query] with optional filters.
  /// Null filter parameters are treated as "no filter" by the SQL Function
  Future<List<FacilityModel>> searchFacilities({
    required String query,
    String? typeFilter,
    String? cityFilter,
    String? serviceFilter,
    String? priceRangeFilter,
    double minRating = 0.0,
  }) async {
    final response = await _supabase.rpc(
      'search_facilities',
      params: {
        'query_text': query,
        'type_filter': typeFilter,
        'city_filter': cityFilter,
        'service_filter': serviceFilter,
        'price_range_filter': priceRangeFilter,
        'min_rating': minRating,
      },
    );
    return (response as List<dynamic>)
        .map((row) => FacilityModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// Fetches the full detail payload for a single facility.
  /// This RPC returns JSON (single object). Handles the three possible response
  Future<FacilityDetailModel?> getFacilityDetail(String facilityId) async {
    final response = await _supabase.rpc(
      'get_facility_detail',
      params: {'p_facility_id': facilityId},
    );

    if (response == null) return null;

    final Map<String, dynamic> data;
    if (response is String) {
      data = jsonDecode(response) as Map<String, dynamic>;
    } else {
      data = response as Map<String, dynamic>;
    }

    return FacilityDetailModel.fromJson(data);
  }

  // BOOKMARKS
  /// Fetches all bookmarked facilities for the authenticated user.
  Future<List<FacilityModel>> getUserBookmarks() async {
    final response = await _supabase.rpc('get_user_bookmarks');
    return (response as List<dynamic>)
        .map((row) => FacilityModel.fromJson(row as Map<String, dynamic>))
        .toList();
  }

  /// User Adds a bookmark. RLS enforces `user_id = auth.uid()`.
  Future<void> addBookmark(String facilityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    await _supabase.from('facility_bookmarks').insert({
      'user_id': userId,
      'facility_id': facilityId,
    });
  }

  /// Removes a bookmark. RLS enforces ownership.
  Future<void> removeBookmark(String facilityId) async {
    await _supabase
        .from('facility_bookmarks')
        .delete()
        .eq('facility_id', facilityId);
  }
}
