import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/contribution_ticket.dart';

/// Backend service for the Contributors module.
///
/// Wraps every Supabase call for facility suggestions:
/// - Submits new tickets via the `submit_facility_suggestion` RPC.
/// - Uploads photos to the `facility-photos` Storage bucket first, so the
///   ticket only ever stores public URLs (never local file paths).
/// - Resubmits an edited, previously-rejected ticket onto the SAME row via
///   `resubmit_facility_suggestion` — no new ticket is ever created for the
///   same request, so the UI never shows stacked/duplicate tickets.
/// - Fetches the current user's tickets and keeps [ContributionTicketsStore]
///   in sync in real time (admin approvals/rejections show up instantly,
///   with zero manual refresh, because Supabase Realtime pushes the row
///   change straight to this subscription).
///
/// Admin review has no dedicated dashboard by design — see the SQL
/// migration's `pending_facility_suggestions` view and
/// `admin_approve_suggestion` / `admin_reject_suggestion` functions, run
/// directly from the Supabase SQL editor.
class ContributionBackendService {
  final SupabaseClient _client;
  static const String _photosBucket = 'facility-photos';

  RealtimeChannel? _channel;

  ContributionBackendService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  String get _requireUserId {
    final id = _client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('User must be authenticated to contribute.');
    }
    return id;
  }

  // ────────────────────────────────────────────────────────────────────────
  // SUBMIT / RESUBMIT
  // ────────────────────────────────────────────────────────────────────────

  /// Submits a facility suggestion. If [ticketId] is given (edit-and-resubmit
  /// flow), this always resubmits onto that exact ticket — regardless of
  /// whether the user changed the name/city while editing. Otherwise, if the
  /// user has a previously **rejected** ticket matching this facility name +
  /// city, that ticket is resubmitted automatically; failing that, a new
  /// ticket is created. Either way, a reject → edit → resubmit cycle never
  /// creates a second ticket for the same request.
  ///
  /// [localPhotoPaths] may mix already-hosted URLs (kept as-is) and local
  /// device file paths (uploaded to Storage here, then replaced with their
  /// public URL).
  Future<ContributionTicket> submitFacilitySuggestion({
    String? ticketId,
    required String facilityName,
    required String facilityType,
    required String city,
    required String address,
    required String phone,
    String? description,
    required String workDays,
    required double latitude,
    required double longitude,
    required String priceRange,
    required double rating,
    required List<String> services,
    required List<String> infrastructure,
    required List<String> localPhotoPaths,
  }) async {
    final userId = _requireUserId;

    final photoUrls = await _uploadPhotos(userId, localPhotoPaths);

    final resolvedTicketId = ticketId ??
        await _findRejectedTicket(
          userId: userId,
          facilityName: facilityName,
          city: city,
        );

    final dynamic response;
    if (resolvedTicketId != null) {
      response = await _client.rpc('resubmit_facility_suggestion', params: {
        'p_ticket_id': resolvedTicketId,
        'p_facility_name': facilityName,
        'p_facility_type': facilityType.toLowerCase(),
        'p_city': city,
        'p_address': address,
        'p_phone': phone,
        'p_description': description,
        'p_work_days': workDays,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_price_range': priceRange.toLowerCase(),
        'p_rating': rating,
        'p_services': services,
        'p_infrastructure': infrastructure,
        'p_photo_urls': photoUrls,
      });
    } else {
      response = await _client.rpc('submit_facility_suggestion', params: {
        'p_facility_name': facilityName,
        'p_facility_type': facilityType.toLowerCase(),
        'p_city': city,
        'p_address': address,
        'p_phone': phone,
        'p_description': description,
        'p_work_days': workDays,
        'p_latitude': latitude,
        'p_longitude': longitude,
        'p_price_range': priceRange.toLowerCase(),
        'p_rating': rating,
        'p_services': services,
        'p_infrastructure': infrastructure,
        'p_photo_urls': photoUrls,
      });
    }

    final row = _coerceRow(response);
    final ticket = _ticketFromRow(row);
    ContributionTicketsStore.instance.upsertTicket(ticket);
    return ticket;
  }

  /// Looks for the user's own rejected ticket matching this facility
  /// name + city (case-insensitive), so resubmission reuses the same row.
  Future<String?> _findRejectedTicket({
    required String userId,
    required String facilityName,
    required String city,
  }) async {
    final rows = await _client
        .from('facility_suggestions')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'rejected')
        .ilike('facility_name', facilityName.trim())
        .ilike('city', city.trim())
        .limit(1);
    if ((rows as List).isEmpty) return null;
    return rows.first['id'] as String;
  }

  /// Uploads every local file path to Storage under the user's own folder
  /// (required by the bucket's RLS policy) and returns the final list of
  /// public URLs, preserving order and passing already-hosted URLs through.
  Future<List<String>> _uploadPhotos(
    String userId,
    List<String> localPhotoPaths,
  ) async {
    final urls = <String>[];
    for (final path in localPhotoPaths) {
      if (path.startsWith('http://') || path.startsWith('https://')) {
        urls.add(path);
        continue;
      }
      final file = File(path);
      final extension = path.split('.').last.toLowerCase();
      final fileName = '${DateTime.now().microsecondsSinceEpoch}.$extension';
      final storagePath = '$userId/$fileName';
      try {
        await _client.storage.from(_photosBucket).upload(
              storagePath,
              file,
              fileOptions: const FileOptions(upsert: false),
            );
        urls.add(_client.storage.from(_photosBucket).getPublicUrl(storagePath));
      } catch (e) {
        debugPrint('Photo upload failed for $path: $e');
        // Skip the failed photo rather than failing the whole submission.
      }
    }
    return urls;
  }

  // ────────────────────────────────────────────────────────────────────────
  // FETCH + REALTIME
  // ────────────────────────────────────────────────────────────────────────

  /// Fetches all of the current user's contribution tickets and populates
  /// [ContributionTicketsStore]. Call once when the Contribute screen opens.
  Future<List<ContributionTicket>> fetchUserContributions() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      ContributionTicketsStore.instance.clear();
      return const [];
    }

    final rows = await _client
        .from('facility_suggestions')
        .select(
          'id, status, created_at, rejection_reason, facility_name, facility_type, '
          'city, address, phone, description, work_days, price_range, rating, '
          'services, infrastructure, photo_urls, coordinates',
        )
        .eq('user_id', userId)
        .order('created_at', ascending: false);

    final tickets = (rows as List)
        .map((row) => _ticketFromRow(Map<String, dynamic>.from(row as Map)))
        .toList();
    ContributionTicketsStore.instance.replaceAll(tickets);
    return tickets;
  }

  /// Subscribes to realtime changes on the user's own tickets so an admin
  /// approval/rejection (run from the SQL editor) reflects in the app
  /// instantly, with no polling or manual refresh.
  void subscribeToContributionUpdates() {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return;

    unsubscribeFromContributionUpdates();
    _channel = _client
        .channel('facility_suggestions:$userId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'facility_suggestions',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: userId,
          ),
          callback: (payload) {
            if (payload.eventType == PostgresChangeEvent.delete) return;
            final ticket = _ticketFromRow(payload.newRecord);
            ContributionTicketsStore.instance.upsertTicket(ticket);
          },
        )
        .subscribe();
  }

  void unsubscribeFromContributionUpdates() {
    final channel = _channel;
    if (channel != null) {
      _client.removeChannel(channel);
      _channel = null;
    }
  }

  Map<String, dynamic> _coerceRow(dynamic response) {
    if (response is List && response.isNotEmpty) {
      return Map<String, dynamic>.from(response.first as Map);
    } else if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    throw StateError('Unexpected RPC response format: $response');
  }

  ContributionTicket _ticketFromRow(Map<String, dynamic> row) =>
      ContributionTicket.fromSupabase(row);
}