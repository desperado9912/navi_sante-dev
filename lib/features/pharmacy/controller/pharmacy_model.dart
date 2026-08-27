import 'package:equatable/equatable.dart';

// Holds the medication data NaviSante delivers to the Pharmacy screen and
// the Favourites screen. Mirrors facility_model.dart's shape: one light
// model carrying everything the UI needs — unlike facilities, medications
// don't need a separate "detail" model fetched on demand, since nothing
// here (description included) is expensive enough to justify a second
// network round-trip.

/// Unknown values gracefully fall back to a safe default instead of
/// crashing — same pattern as FacilityType.fromString.
enum MedicationForm {
  pill,
  liquid,
  injection,
  topical,
  other;

  static MedicationForm fromString(String value) {
    return MedicationForm.values.firstWhere(
      (form) => form.name == value,
      orElse: () => MedicationForm.pill,
    );
  }
}

enum DispensingClass {
  otc,
  rx;

  static DispensingClass fromString(String value) {
    return DispensingClass.values.firstWhere(
      (d) => d.name == value,
      orElse: () => DispensingClass.otc,
    );
  }
}

/// A single pharmacy that stocks a medication — enough to render a
/// tappable chip and hand straight to MapLauncher.openDirections().
class MedicationRetailer extends Equatable {
  final String facilityId;
  final String name;
  final double latitude;
  final double longitude;

  const MedicationRetailer({
    required this.facilityId,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  factory MedicationRetailer.fromJson(Map<String, dynamic> json) {
    return MedicationRetailer(
      facilityId: json['facility_id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() => {
    'facility_id': facilityId,
    'name': name,
    'latitude': latitude,
    'longitude': longitude,
  };

  @override
  List<Object?> get props => [facilityId, name, latitude, longitude];
}

class MedicationModel extends Equatable {
  final String medicationId;
  final String name;
  final List<String> brandNames;
  final List<String> dosages;
  final MedicationForm form;
  final DispensingClass dispensingClass;
  final int? priceMinCfa;
  final int? priceMaxCfa;
  final String? description;

  /// Non-null only for medications flagged as part of the default "common
  /// medications" view — lower rank shows first. Most medications will
  /// have this as null (only shown when the user actually searches).
  final int? defaultRank;

  final List<String> conditions;
  final List<MedicationRetailer> retailers;

  const MedicationModel({
    required this.medicationId,
    required this.name,
    required this.brandNames,
    required this.dosages,
    required this.form,
    required this.dispensingClass,
    this.priceMinCfa,
    this.priceMaxCfa,
    this.description,
    this.defaultRank,
    required this.conditions,
    required this.retailers,
  });

  /// Parses a single row from the get_all_medications() RPC.
  factory MedicationModel.fromJson(Map<String, dynamic> json) {
    return MedicationModel(
      medicationId: (json['medication_id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      brandNames: (json['brand_names'] as List<dynamic>? ?? [])
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['name'] ?? e['brand_name'] ?? '').toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList(),
      dosages: (json['dosages'] as List<dynamic>? ?? [])
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['dosage'] ?? e['name'] ?? '').toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList(),
      form: MedicationForm.fromString(json['form']?.toString() ?? ''),
      dispensingClass: DispensingClass.fromString(
        json['dispensing_class']?.toString() ?? '',
      ),
      priceMinCfa: (json['price_min_cfa'] as num?)?.toInt(),
      priceMaxCfa: (json['price_max_cfa'] as num?)?.toInt(),
      description: json['description'] as String?,
      defaultRank: (json['default_rank'] as num?)?.toInt(),
      conditions: (json['conditions'] as List<dynamic>? ?? [])
          .map((e) {
            if (e is String) return e;
            if (e is Map) {
              return (e['name'] ??
                      e['condition_name'] ??
                      e['condition'] ??
                      e['title'] ??
                      '')
                  .toString();
            }
            return e.toString();
          })
          .where((s) => s.isNotEmpty)
          .toList(),
      retailers: (json['retailers'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => MedicationRetailer.fromJson(e))
          .toList(),
    );
  }

  /// Serialises to JSON for Hive storage.
  Map<String, dynamic> toJson() => {
    'medication_id': medicationId,
    'name': name,
    'brand_names': brandNames,
    'dosages': dosages,
    'form': form.name,
    'dispensing_class': dispensingClass.name,
    'price_min_cfa': priceMinCfa,
    'price_max_cfa': priceMaxCfa,
    'description': description,
    'default_rank': defaultRank,
    'conditions': conditions,
    'retailers': retailers.map((r) => r.toJson()).toList(),
  };

  /// Human-readable price range, e.g. "500 – 1500 CFA" or "Price varies"
  /// when neither bound is known.
  String get priceRangeLabel {
    if (priceMinCfa == null && priceMaxCfa == null) return 'Price varies';
    if (priceMinCfa != null && priceMaxCfa != null) {
      if (priceMinCfa == priceMaxCfa) return '$priceMinCfa CFA';
      return '$priceMinCfa – $priceMaxCfa CFA';
    }
    return '${priceMinCfa ?? priceMaxCfa} CFA';
  }

  /// Auto-generated note shown in the expanded card — derived from
  /// [dispensingClass], never stored in the database.
  String get dispensingNote {
    return dispensingClass == DispensingClass.rx
        ? "Requires a doctor's prescription (Rx). Do not use without medical supervision."
        : 'Available over the counter (OTC). Follow the recommended dosage, and ask a pharmacist if unsure.';
  }

  @override
  List<Object?> get props => [
    medicationId,
    name,
    brandNames,
    dosages,
    form,
    dispensingClass,
    priceMinCfa,
    priceMaxCfa,
    description,
    defaultRank,
    conditions,
    retailers,
  ];
}
