import 'package:flutter/material.dart';
import '../widgets/postgis_utils.dart';

enum ContributionStatus {
  pending,
  approved,
  rejected;

  static ContributionStatus fromString(String value) {
    final normalized = value.toLowerCase().trim();
    return ContributionStatus.values.firstWhere(
      (s) => s.name.toLowerCase() == normalized,
      orElse: () => ContributionStatus.pending,
    );
  }
}

enum ContributionType {
  suggestFacility,
  updateFacility,
  addReview,
  addPhoto;

  static ContributionType fromString(String? value) {
    switch (value?.trim().toLowerCase()) {
      case 'update_facility':
      case 'updatefacility':
        return ContributionType.updateFacility;
      case 'add_photo':
      case 'addphoto':
        return ContributionType.addPhoto;
      case 'add_review':
      case 'addreview':
        return ContributionType.addReview;
      default:
        return ContributionType.suggestFacility;
    }
  }

  String get wireName {
    switch (this) {
      case ContributionType.suggestFacility:
        return 'suggest_facility';
      case ContributionType.updateFacility:
        return 'update_facility';
      case ContributionType.addReview:
        return 'add_review';
      case ContributionType.addPhoto:
        return 'add_photo';
    }
  }
}

/// Keeps the current suggestion RPC compatible while allowing the same ticket
/// row to describe update and photo workflows until the database adds a
/// dedicated contribution-type column.
class ContributionMetadata {
  static const String marker = '[NAVISANTE_CONTRIBUTION]';

  static String encode({
    required ContributionType type,
    required String facilityId,
    String? description,
  }) {
    final body = description?.trim() ?? '';
    return '$marker type=${type.wireName};facility_id=$facilityId\n$body';
  }

  static ContributionMetadata? parse(String? raw) {
    if (raw == null || !raw.startsWith(marker)) return null;
    final newline = raw.indexOf('\n');
    final header = newline == -1 ? raw : raw.substring(0, newline);
    final typeMatch = RegExp(r'type=([^;]+)').firstMatch(header);
    final facilityMatch = RegExp(r'facility_id=([^;\s]+)').firstMatch(header);
    if (typeMatch == null || facilityMatch == null) return null;
    return ContributionMetadata._(
      type: ContributionType.fromString(typeMatch.group(1)),
      facilityId: facilityMatch.group(1)!,
      description: newline == -1 ? null : raw.substring(newline + 1).trim(),
    );
  }

  final ContributionType type;
  final String facilityId;
  final String? description;

  ContributionMetadata._({
    required this.type,
    required this.facilityId,
    required this.description,
  });
}

class ContributionTicket {
  final String id;
  final ContributionType type;
  final String facilityName;
  final String dateText;
  final ContributionStatus status;
  final String? rejectionReason;
  final Map<String, dynamic> data;
  final List<String> photoUrls;
  final String? targetFacilityId;

  // Raw fields kept alongside `data` (which only holds display strings) so
  // the suggest-facility form can pre-fill itself exactly when a rejected
  // ticket is reopened for editing — see SuggestFacilityScreen(editingTicket:).
  final String? facilityType;
  final String? city;
  final String? address;
  final String? phone;
  final String? description;
  final String? workDays;
  final String? priceRange;
  final double? rating;
  final double? latitude;
  final double? longitude;
  final List<String> services;
  final List<String> infrastructure;

  const ContributionTicket({
    required this.id,
    required this.type,
    required this.facilityName,
    required this.dateText,
    required this.status,
    this.rejectionReason,
    this.data = const {},
    this.photoUrls = const [],
    this.targetFacilityId,
    this.facilityType,
    this.city,
    this.address,
    this.phone,
    this.description,
    this.workDays,
    this.priceRange,
    this.rating,
    this.latitude,
    this.longitude,
    this.services = const [],
    this.infrastructure = const [],
  });

  /// Builds a ticket from a `facility_suggestions` row (RPC result, a
  /// realtime payload, or a plain `select *` — same column names either way).
  factory ContributionTicket.fromSupabase(Map<String, dynamic> json) {
    final servicesList = (json['services'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final infraList = (json['infrastructure'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final photos = (json['photo_urls'] as List<dynamic>? ?? [])
        .whereType<String>()
        .toList();
    final createdAt =
        DateTime.tryParse(json['created_at'] as String? ?? '') ??
            DateTime.now();

    double? lat = (json['latitude'] as num?)?.toDouble();
    double? lng = (json['longitude'] as num?)?.toDouble();
    if (lat == null && lng == null && json['coordinates'] != null) {
      final rawCoords = json['coordinates'];
      if (rawCoords is String) {
        final parsed = PostGisUtils.parseEwkbHex(rawCoords);
        if (parsed != null) {
          lat = parsed.latitude;
          lng = parsed.longitude;
        }
      } else if (rawCoords is Map) {
        final coordsList = rawCoords['coordinates'] as List<dynamic>?;
        if (coordsList != null && coordsList.length >= 2) {
          lng = (coordsList[0] as num).toDouble();
          lat = (coordsList[1] as num).toDouble();
        }
      }
    }

    final metadata = ContributionMetadata.parse(json['description'] as String?);
    final displayDescription = metadata?.description ?? json['description'] as String?;

    return ContributionTicket(
      id: json['id'] as String,
      type: metadata?.type ??
          ContributionType.fromString(json['contribution_type'] as String?),
      facilityName: json['facility_name'] as String? ?? 'Unnamed facility',
      dateText: _formatRelativeDate(createdAt),
      status: ContributionStatus.fromString(json['status'] as String? ?? 'pending'),
      rejectionReason: json['rejection_reason'] as String?,
      data: {
        'Type': _capitalize(json['facility_type'] as String? ?? ''),
        'City': json['city'] as String? ?? '',
        'Address': json['address'] as String? ?? '',
        'Phone': json['phone'] as String? ?? '',
        if (displayDescription?.isNotEmpty ?? false)
          'Description': displayDescription,
        'Work Days': json['work_days'] as String? ?? '',
        if (lat != null && lng != null)
          'Coordinates':
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
        'Price Range': _capitalize(json['price_range'] as String? ?? ''),
        'Rating': json['rating'] as num? ?? 0,
        if (servicesList.isNotEmpty) 'Services': servicesList,
        if (infraList.isNotEmpty) 'Infrastructure': infraList,
      },
      photoUrls: photos,
      targetFacilityId: metadata?.facilityId ??
          json['created_facility_id'] as String? ??
          json['target_facility_id'] as String?,
      facilityType: _capitalize(json['facility_type'] as String? ?? ''),
      city: json['city'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      description: displayDescription,
      workDays: json['work_days'] as String?,
      priceRange: _capitalize(json['price_range'] as String? ?? ''),
      rating: (json['rating'] as num?)?.toDouble(),
      latitude: lat,
      longitude: lng,
      services: servicesList,
      infrastructure: infraList,
    );
  }

  static String _capitalize(String value) =>
      value.isEmpty ? value : '${value[0].toUpperCase()}${value.substring(1)}';

  static String _formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final local = date.toLocal();
    final isToday = now.year == local.year &&
        now.month == local.month &&
        now.day == local.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday = yesterday.year == local.year &&
        yesterday.month == local.month &&
        yesterday.day == local.day;
    final time =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (isToday) return 'Today, $time';
    if (isYesterday) return 'Yesterday, $time';
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  String get typeLabel {
    switch (type) {
      case ContributionType.suggestFacility:
        return 'Suggest facility';
      case ContributionType.updateFacility:
        return 'Update facility';
      case ContributionType.addReview:
        return 'Add review';
      case ContributionType.addPhoto:
        return 'Add photo';
    }
  }

  IconData get typeIcon {
    switch (type) {
      case ContributionType.suggestFacility:
        return Icons.add_business_rounded;
      case ContributionType.updateFacility:
        return Icons.edit_location_alt_rounded;
      case ContributionType.addReview:
        return Icons.rate_review_rounded;
      case ContributionType.addPhoto:
        return Icons.add_a_photo_rounded;
    }
  }

  String get statusMessage {
    switch (status) {
      case ContributionStatus.approved:
        return 'Your edit has been approved and is now visible to all users.';
      case ContributionStatus.pending:
        return 'Your edits are being reviewed for accuracy.';
      case ContributionStatus.rejected:
        return 'Your edits have been rejected for the following reasons: ${rejectionReason ?? "Information could not be verified."}';
    }
  }

  Color get statusColor {
    switch (status) {
      case ContributionStatus.approved:
        return const Color(0xFF1E8E3E);
      case ContributionStatus.pending:
        return const Color(0xFFD97706);
      case ContributionStatus.rejected:
        return const Color(0xFFD93025);
    }
  }

  Color get statusBgColor {
    switch (status) {
      case ContributionStatus.approved:
        return const Color(0xFFE6F4EA);
      case ContributionStatus.pending:
        return const Color(0xFFFEF3C7);
      case ContributionStatus.rejected:
        return const Color(0xFFFCE8E6);
    }
  }
}

/// Reactive, in-memory mirror of the user's `facility_suggestions` rows.
/// Owned/populated by [ContributionBackendService] (fetch + realtime) —
/// screens only ever read [ticketsNotifier] or call [upsertTicket].
class ContributionTicketsStore {
  ContributionTicketsStore._();
  static final ContributionTicketsStore instance = ContributionTicketsStore._();

  final ValueNotifier<List<ContributionTicket>> ticketsNotifier =
      ValueNotifier<List<ContributionTicket>>(const []);

  /// Replaces the whole list — used after the initial fetch from Supabase.
  void replaceAll(List<ContributionTicket> tickets) {
    final sorted = List<ContributionTicket>.from(tickets)
      ..sort((a, b) => b.id.compareTo(a.id));
    ticketsNotifier.value = sorted;
  }

  /// Inserts a new ticket, or updates it in place if a ticket with the same
  /// [ContributionTicket.id] already exists — this is what keeps a
  /// rejected-then-resubmitted ticket as a single row instead of stacking
  /// duplicates, and is also what realtime status updates call.
  void upsertTicket(ContributionTicket ticket) {
    final current = List<ContributionTicket>.from(ticketsNotifier.value);
    final index = current.indexWhere((t) => t.id == ticket.id);
    if (index == -1) {
      current.insert(0, ticket);
    } else {
      current[index] = ticket;
    }
    ticketsNotifier.value = current;
  }

  void clear() => ticketsNotifier.value = const [];
}
