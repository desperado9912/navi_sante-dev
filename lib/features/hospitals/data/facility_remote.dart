import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'facility_model.dart';

/// Owns all Database network calls for facility data.
/// No business logic, no caching — just RPC calls and model parsing.
/// Errors (PostgrestException, AuthException) bubble up to the repository
/// which decides how to handle them based on cache availability.
/// Unlike [FacilityLocal], this class handles all network requests.

class FacilityRemote {
  final SupabaseClient _supabase;
  FacilityRemote(this._supabase);

  SupabaseClient get supabase => _supabase;

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
  Future<Set<String>> getUserBookmarks() async {
    final response = await _supabase
        .from('facility_bookmarks')
        .select('facility_id');
    return (response as List<dynamic>)
        .map((row) => row['facility_id'] as String)
        .toSet();
  }

  /// User Adds a bookmark. RLS enforces ownership.
  /// Optimistic flow and safe revert on network failure
  Future<void> addBookmark(String facilityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    await _supabase
        .from('facility_bookmarks')
        .upsert(
          {'user_id': userId, 'facility_id': facilityId},
          onConflict: 'user_id,facility_id',
          ignoreDuplicates: true,
        );
  }

  /// Removes a bookmark. RLS enforces ownership.
  Future<void> removeBookmark(String facilityId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) throw Exception('User not authenticated');
    await _supabase
        .from('facility_bookmarks')
        .delete()
        .eq('facility_id', facilityId)
        .eq('user_id', userId);
  }

  // SERVICES & TAGS CATALOG
  /// Returns every known service name, alphabetically sorted.
  Future<List<String>> getServicesCatalog() async {
    final response = await _supabase
        .from('services')
        .select('name')
        .order('name', ascending: true);
    return (response as List<dynamic>)
        .map((row) => row['name'] as String)
        .toList();
  }

  /// Returns every known tag (used as "infrastructure") name, sorted.
  Future<List<String>> getTagsCatalog() async {
    final response = await _supabase
        .from('tags')
        .select('name')
        .order('name', ascending: true);
    return (response as List<dynamic>)
        .map((row) => row['name'] as String)
        .toList();
  }

  // CONTRIBUTOR BADGE
  /// Displays if the current user is a credited contributor for this facility
  Future<bool> isCurrentUserContributor(String facilityId) async {
    try {
      final response = await _supabase.rpc(
        'is_facility_contributor',
        params: {'p_facility_id': facilityId},
      );
      return response == true;
    } catch (e) {
      debugPrint('isCurrentUserContributor failed for $facilityId: $e');
      return false;
    }
  }
}
