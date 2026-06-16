import 'package:flutter_bloc/flutter_bloc.dart';
import '../data/facility_repository.dart';

// Tracks the last 05 viewed facilities.
// Shown as horizontal scrollable chips on the Hospitals screen under
// search bar as "Recent History" with a "Clear all" button.
//
// Recents stored in Hive only
// STATE: List<String> of facility_id values (most recent first, max 10).
// The hospitals screen uses these IDs to look up names from the FacilityBloc
// state (already cached) — no extra network calls.

class RecentlyViewedCubit extends Cubit<List<String>> {
  static const int _maxItems = 5; // max recents chips shown on the UI

  final FacilityRepository _repository;

  // INIT
  // Opens the Hive box and loads saved IDs into state.
  RecentlyViewedCubit({required FacilityRepository repository})
    : _repository = repository,
      super([]);

  // LOAD
  // Reads persisted IDs from Hive and emits them.
  void load() {
    emit(_repository.getRecentlyViewed().take(_maxItems).toList());
  }

  // ADD
  // Adds a facility_id to the front of the list (most recent = first).
  Future<void> add(String facilityId) async {
    final updated = [
      facilityId,
      ...state.where((id) => id != facilityId),
    ].take(_maxItems).toList();
    emit(updated);
    await _repository.saveRecentlyViewed(facilityId);
  }

  // CLEAR ALL
  // Triggered by the "Clear all" button.
  Future<void> clearAll() async {
    emit([]);
    await _repository.clearRecentlyViewed();
  }
}
