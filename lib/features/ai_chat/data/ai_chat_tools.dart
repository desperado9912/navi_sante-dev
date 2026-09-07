import 'dart:convert';
import '../../hospitals/controller/facility_model.dart';
import '../../hospitals/data/facility_repository.dart';
import '../../pharmacy/controller/medication_search.dart';
import '../../pharmacy/controller/pharmacy_model.dart';
import '../../pharmacy/data/medication_repository.dart';
import '../controller/ai_chat_models.dart';

/// On-device tools. The LLM never talks to Supabase.
///
/// Order: Hive / in-memory first. Only if there is no match do we call
/// existing repository methods (those may hit the DB). Timeouts are hard
/// so nothing spins forever.
class AiChatTools {
  AiChatTools({
    required this.facilities,
    required this.medicationRepo,
    required List<MedicationModel> medications,
    required this.lat,
    required this.lng,
    required this.bookmarkCount,
    required this.bookmarkNames,
    this.language = 'en',
  }) : medications = List<MedicationModel>.from(medications);

  final FacilityRepository facilities;
  final MedicationRepository medicationRepo;
  List<MedicationModel> medications;
  final double? lat;
  final double? lng;
  final int bookmarkCount;
  final List<String> bookmarkNames;
  final String language;

  static const MedicationSearchEngine _medSearch = MedicationSearchEngine();
  static const _toolTimeout = Duration(seconds: 10);

  final Map<String, FacilityModel> _facilityHits = {};
  final Map<String, MedicationModel> _medHits = {};

  FacilityModel? facilityById(String id) =>
      facilities.getFacilitySync(id) ?? _facilityHits[id];

  MedicationModel? medicationById(String id) {
    for (final m in medications) {
      if (m.medicationId == id) return m;
    }
    return _medHits[id];
  }

  void _rememberFacilities(Iterable<FacilityModel> rows) {
    for (final f in rows.take(3)) {
      _facilityHits[f.facilityId] = f;
    }
  }

  void _rememberMeds(Iterable<MedicationModel> rows) {
    for (final m in rows.take(3)) {
      _medHits[m.medicationId] = m;
    }
  }

  Future<Map<String, dynamic>> run(AiToolCall call) async {
    Map<String, dynamic> args = {};
    try {
      final decoded = jsonDecode(
        call.arguments.isEmpty ? '{}' : call.arguments,
      );
      if (decoded is Map) args = Map<String, dynamic>.from(decoded);
    } catch (_) {}

    switch (call.name) {
      case 'search_facilities':
        return _searchFacilities(args);
      case 'get_facility_detail':
        return _facilityDetail(args['facility_id']?.toString() ?? '');
      case 'search_medications':
        return _searchMedications(args);
      default:
        return {'error': 'Unknown tool'};
    }
  }

  List<FacilityModel> _nearbyPool() {
    return facilities.getHighlights(
      userLat: lat ?? 3.848,
      userLng: lng ?? 11.502,
      count: 80,
    );
  }

  /// Takes the first stream event (cache if present). Never waits for a
  /// background refresh — that was extra DB load.
  Future<void> _warmFacilityCache() async {
    if (_nearbyPool().isNotEmpty) return;
    try {
      await facilities.getAllFacilities().first.timeout(_toolTimeout);
    } catch (_) {}
  }

  Future<Map<String, dynamic>> _searchFacilities(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    final service = (args['service'] as String?)?.trim().toLowerCase() ?? '';
    final type = (args['type'] as String?)?.trim().toLowerCase() ?? '';

    await _warmFacilityCache();

    var cached = _filterCached(query: query, service: service, type: type);
    if (cached.isNotEmpty) {
      _rememberFacilities(cached);
      return {'results': cached.take(3).map(_slimFacility).toList()};
    }

    final needsRemote =
        query.length >= 3 || service.isNotEmpty || type.isNotEmpty;
    if (!needsRemote) {
      return {'results': <Map<String, dynamic>>[]};
    }

    try {
      var remote = await facilities
          .searchFacilities(
            query: query,
            typeFilter: (type == 'hospital' ||
                    type == 'clinic' ||
                    type == 'pharmacy')
                ? type
                : null,
            serviceFilter: service.isEmpty ? null : service,
          )
          .timeout(_toolTimeout);
      if (lat != null && lng != null) {
        remote = List<FacilityModel>.from(remote)
          ..sort(
            (a, b) =>
                a.distanceTo(lat!, lng!).compareTo(b.distanceTo(lat!, lng!)),
          );
      }
      final top = remote.take(3).toList();
      _rememberFacilities(top);
      return {'results': top.map(_slimFacility).toList()};
    } catch (_) {
      return {'results': <Map<String, dynamic>>[]};
    }
  }

  List<FacilityModel> _filterCached({
    required String query,
    required String service,
    required String type,
  }) {
    List<FacilityModel> pool;
    var filterQuery = false;
    if (query.isNotEmpty) {
      final named = facilities.searchCachedFacilities(query);
      if (named.isNotEmpty) {
        pool = named;
      } else {
        pool = _nearbyPool();
        filterQuery = true;
      }
    } else {
      pool = _nearbyPool();
    }

    if (lat != null && lng != null) {
      pool = List<FacilityModel>.from(pool)
        ..sort(
          (a, b) => a.distanceTo(lat!, lng!).compareTo(b.distanceTo(lat!, lng!)),
        );
    }

    Iterable<FacilityModel> it = pool;
    if (type == 'hospital' || type == 'clinic' || type == 'pharmacy') {
      it = it.where((f) => f.type.name == type);
    }
    if (service.isNotEmpty) {
      it = it.where(
        (f) => f.servicesList.any((s) => s.toLowerCase().contains(service)),
      );
    }
    if (filterQuery && query.isNotEmpty) {
      final needle = query.toLowerCase();
      it = it.where(
        (f) =>
            f.name.toLowerCase().contains(needle) ||
            (f.address?.toLowerCase().contains(needle) ?? false) ||
            f.servicesList.any((s) => s.toLowerCase().contains(needle)),
      );
    }
    return it.take(3).toList();
  }

  Future<Map<String, dynamic>> _facilityDetail(String id) async {
    if (id.isEmpty) return {'error': 'Facility not found'};
    final cached = facilityById(id);
    if (cached != null) return _slimFacility(cached);
    try {
      final detail = await facilities.getFacilityDetail(id).timeout(_toolTimeout);
      if (detail == null) return {'error': 'Facility not found'};
      final desc = detail.description;
      return {
        'facility_id': detail.facilityId,
        'name': detail.name,
        'type': detail.type.name,
        'rating': detail.rating,
        'address': detail.address,
        'phone': detail.phone,
        'work_hours': detail.workHours,
        'services': detail.services.take(4).toList(),
        if (desc != null && desc.isNotEmpty)
          'description': desc.length > 220 ? desc.substring(0, 220) : desc,
      };
    } catch (_) {
      return {'error': 'Facility not found'};
    }
  }

  Future<Map<String, dynamic>> _searchMedications(
    Map<String, dynamic> args,
  ) async {
    final query = (args['query'] as String?)?.trim() ?? '';
    final condition = (args['condition'] as String?)?.trim() ?? '';
    final needle = [query, condition].where((s) => s.isNotEmpty).join(' ');
    if (needle.isEmpty) return {'results': <Map<String, dynamic>>[]};

    if (medications.isEmpty) {
      try {
        medications = await medicationRepo.fetchMedicationsDirect().timeout(
          _toolTimeout,
        );
      } catch (_) {}
    }
    if (medications.isEmpty) return {'results': <Map<String, dynamic>>[]};

    final matches = _medSearch.search(medications, needle).matches.take(3);
    _rememberMeds(matches);
    return {
      'results': matches.map((m) {
        return {
          'medication_id': m.medicationId,
          'name': m.name,
          'brands': m.brandNames.take(3).toList(),
          'form': m.form.name,
          'class': m.dispensingClass.name,
          'price': m.priceRangeLabel,
          'conditions': m.conditions.take(3).toList(),
          'retailers': m.retailers.take(2).map((r) => r.name).toList(),
        };
      }).toList(),
    };
  }

  Map<String, dynamic> _slimFacility(FacilityModel f) {
    return {
      'facility_id': f.facilityId,
      'name': f.name,
      'type': f.type.name,
      'rating': f.rating,
      if (lat != null && lng != null) 'distance': f.formatDistance(lat!, lng!),
      'address': f.address,
      'services': f.servicesList.take(3).toList(),
    };
  }
}
