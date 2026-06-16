import 'dart:math';
import 'package:equatable/equatable.dart';

// All data models for the facilities live in this file.
// Three classes:
//   FacilityModel       → lightweight, used for map pins, cards, carousel
//   FacilityImage       → nested inside FacilityDetailModel
//   FacilityDetailModel → full data, used only on detail screen / expanded sheet


// ── Facility Type ────────────────────────────────────────────────────────────

/// Typed enum for the three facility categories stored in the DB.
/// Unknown values gracefully fall back to [hospital] instead of crashing.
enum FacilityType {
  hospital,
  clinic,
  pharmacy;

  static FacilityType fromString(String value) {
    return FacilityType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => FacilityType.hospital,
    );
  }
}

// ── Facility Model ───────────────────────────────────────────────────────────

/// Contains only the fields needed for map pins, grid cards, and the
/// highlights carousel. Tags and description are intentionally absent —
/// they live in [FacilityDetailModel] and are fetched on demand.
class FacilityModel extends Equatable {
  final String facilityId;
  final String name;
  final FacilityType type;
  final String? address;
  final String? phone;
  final String? workHours;
  final double rating;
  final String? priceRange;
  final double latitude;
  final double longitude;
  final String? primaryImage;
  final List<String> servicesList;

  const FacilityModel({
    required this.facilityId,
    required this.name,
    required this.type,
    this.address,
    this.phone,
    this.workHours,
    required this.rating,
    this.priceRange,
    required this.latitude,
    required this.longitude,
    this.primaryImage,
    required this.servicesList,
  });

  /// Parses the raw Map returned by the Supabase RPC.
  /// Column names match the `RETURNS TABLE` definition in `03_functions.sql`.
  factory FacilityModel.fromJson(Map<String, dynamic> json) {
    return FacilityModel(
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      type: FacilityType.fromString(json['type'] as String),
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      workHours: json['work_hours'] as String?,
      rating: (json['rating'] as num).toDouble(),
      priceRange: json['price_range'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      primaryImage: json['primary_image'] as String?,
      servicesList: (json['services_list'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  /// Serialises to JSON for Hive storage. Must round-trip with [fromJson].
  Map<String, dynamic> toJson() => {
        'facility_id': facilityId,
        'name': name,
        'type': type.name,
        'address': address,
        'phone': phone,
        'work_hours': workHours,
        'rating': rating,
        'price_range': priceRange,
        'latitude': latitude,
        'longitude': longitude,
        'primary_image': primaryImage,
        'services_list': servicesList,
      };

  /// Creates a copy with selected fields replaced.
  /// Used by BLoC layer for filter mutations and bookmark toggling.
  FacilityModel copyWith({
    String? facilityId,
    String? name,
    FacilityType? type,
    String? address,
    String? phone,
    String? workHours,
    double? rating,
    String? priceRange,
    double? latitude,
    double? longitude,
    String? primaryImage,
    List<String>? servicesList,
  }) {
    return FacilityModel(
      facilityId: facilityId ?? this.facilityId,
      name: name ?? this.name,
      type: type ?? this.type,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      workHours: workHours ?? this.workHours,
      rating: rating ?? this.rating,
      priceRange: priceRange ?? this.priceRange,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      primaryImage: primaryImage ?? this.primaryImage,
      servicesList: servicesList ?? this.servicesList,
    );
  }


  // ── Distance Utilities ───────────────────────────────────────────────────

  /// Haversine distance in metres from this facility to the user's position.
  /// Used by [FacilityRepository.getHighlights] for client-side proximity sort.

  double _toRadians(double degrees) => degrees * pi / 180;
  double distanceTo(double userLat, double userLng) {
    const earthRadius = 6371000.0; // metres
    final dLat = _toRadians(userLat - latitude);
    final dLng = _toRadians(userLng - longitude);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(latitude)) *
            cos(_toRadians(userLat)) *
            sin(dLng / 2) *
            sin(dLng / 2);
    return earthRadius * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  /// Human-readable distance string: `"350m"` below 1 km, `"2.4km"` above.
  String formatDistance(double userLat, double userLng) {
    final metres = distanceTo(userLat, userLng);
    if (metres < 1000) return '${metres.toStringAsFixed(0)}m';
    return '${(metres / 1000).toStringAsFixed(1)}km';
  }

  @override
  List<Object?> get props => [
        facilityId,
        name,
        type,
        address,
        phone,
        workHours,
        rating,
        priceRange,
        latitude,
        longitude,
        primaryImage,
        servicesList,
      ];
}

// ── Facility Image ───────────────────────────────────────────────────────────

/// A single image belonging to a facility.
/// Used inside [FacilityDetailModel] for the detail-screen image carousel.
class FacilityImage extends Equatable {
  final String id;
  final String url;
  final bool isPrimary;
  final int displayOrder;

  const FacilityImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    required this.displayOrder,
  });

  factory FacilityImage.fromJson(Map<String, dynamic> json) {
    return FacilityImage(
      id: json['id'] as String,
      url: json['url'] as String,
      isPrimary: json['is_primary'] as bool,
      displayOrder: (json['display_order'] as num).toInt(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'url': url,
        'is_primary': isPrimary,
        'display_order': displayOrder,
      };

  @override
  List<Object?> get props => [id, url, isPrimary, displayOrder];
}


// ── Facility Detail Model ────────────────────────────────────────────────────

/// Full model returned by `get_facility_detail()` RPC.
///
/// Includes description, tags, and all images — fields that the lightweight
/// [FacilityModel] intentionally omits. Fetched on demand when the user taps
/// a facility, then cached in Hive by `facility_id`.
class FacilityDetailModel extends Equatable {
  final String facilityId;
  final String name;
  final FacilityType type;
  final String? description;
  final String? city;
  final String? address;
  final String? phone;
  final String? workHours;
  final double rating;
  final String? priceRange;
  final double latitude;
  final double longitude;
  final List<FacilityImage> images;
  final List<String> services;
  final List<String> tags;

  const FacilityDetailModel({
    required this.facilityId,
    required this.name,
    required this.type,
    this.description,
    this.city,
    this.address,
    this.phone,
    this.workHours,
    required this.rating,
    this.priceRange,
    required this.latitude,
    required this.longitude,
    required this.images,
    required this.services,
    required this.tags,
  });

  /// Parses the JSON object returned by `get_facility_detail()` RPC.
  /// Images are sorted by [displayOrder] after parsing to guarantee
  /// correct carousel sequence regardless of DB insertion order.
  factory FacilityDetailModel.fromJson(Map<String, dynamic> json) {
    final rawImages = (json['images'] as List<dynamic>? ?? [])
        .map((e) => FacilityImage.fromJson(e as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return FacilityDetailModel(
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      type: FacilityType.fromString(json['type'] as String),
      description: json['description'] as String?,
      city: json['city'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      workHours: json['work_hours'] as String?,
      rating: (json['rating'] as num).toDouble(),
      priceRange: json['price_range'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      images: rawImages,
      services: (json['services'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
      tags: (json['tags'] as List<dynamic>? ?? [])
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'facility_id': facilityId,
        'name': name,
        'type': type.name,
        'description': description,
        'city': city,
        'address': address,
        'phone': phone,
        'work_hours': workHours,
        'rating': rating,
        'price_range': priceRange,
        'latitude': latitude,
        'longitude': longitude,
        'images': images.map((e) => e.toJson()).toList(),
        'services': services,
        'tags': tags,
      };

  /// Returns the primary image URL, falling back to the first image, or null.
  String? get primaryImageUrl {
    try {
      return images.firstWhere((img) => img.isPrimary).url;
    } catch (_) {
      return images.isNotEmpty ? images.first.url : null;
    }
  }

  @override
  List<Object?> get props => [
        facilityId,
        name,
        type,
        description,
        city,
        address,
        phone,
        workHours,
        rating,
        priceRange,
        latitude,
        longitude,
        images,
        services,
        tags,
      ];
}
