import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';
import '../controller/facility_bloc.dart';
import '../controller/facility_model.dart';
import '../data/facility_repository.dart';
import '../widgets/facility_details_screen.dart';
import '../widgets/facility_grid_cards.dart';
import '../widgets/search_filters_bar.dart';
import 'package:navi_sante/core/utils/navigation_menu.dart'
    show navBottomPadding;

// =============================================================================
// hospitals.dart
// lib/features/hospitals/screens/hospitals.dart
//
// The Hospitals tab. Matches the "Find Sanctuary" mockup:
//   1. Header title + subtitle
//   2. Search bar (debounced 500ms)
//   3. Recent History chips (from FacilityBloc.recentlyViewedIds, with "Clear all")
//   4. Filter bar (Health Condition / City / Price Rating + Search button)
//   5. Section header ("Top Rated Nearby" or "Search Results")
//   6. 2-column GridView of facility cards
//
// DATA SOURCING:
//   - Default browse mode: state.facilities (already cached from Sprint 3/4,
//     loaded once on app start) — filtered to exclude pharmacies (this tab
//     is Hospitals only; Pharmacy has its own tab) and sorted by rating.
//   - Search/filter mode: state.searchResults (always fetched fresh from
//     Supabase — search is never cached, per Sprint 3 design).
//
// Pharmacy exclusion is done HERE in Dart, not in the SQL function, because
// it is specific to this screen's purpose — the map and search RPC remain
// general-purpose and unaware of which tab is calling them.
// =============================================================================

class Hospitals extends StatefulWidget {
  const Hospitals({super.key});

  @override
  State<Hospitals> createState() => _HospitalsState();
}

// HEADER TITLE + SUBTITLE
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr('Find health facilities around you'),
            style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
          ),
        ],
      ),
    );
  }
}

// SEARCH FIELD BAR
class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: context.tr('hospitals, clinics or pharmacies'),
        prefixIcon: const Icon(Icons.search_rounded, size: 22),
        // Clear (X) button only shows once there's text to clear.
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) {
            if (value.text.isEmpty) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFF5F6368),
              ),
              onPressed: onClear,
            );
          },
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// RECENT HISTORY CHIPS SECTION
// Shows up to 5 chips of recently viewed facility names.
// Resolved from FacilityBloc state — recentlyViewedIds holds IDs,
// names are looked up from the cached facilities list.
class _RecentHistorySection extends StatelessWidget {
  const _RecentHistorySection();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FacilityBloc, FacilityState>(
      buildWhen: (prev, curr) =>
          prev.recentlyViewedIds != curr.recentlyViewedIds ||
          prev.facilities != curr.facilities,
      builder: (context, state) {
        if (state.recentlyViewedIds.isEmpty) return const SizedBox.shrink();

        // Resolve names using O(1) map lookup; skip any ID not in cache.
        final entries = state.recentlyViewedIds
            .map((id) => state.facilityById(id))
            .whereType<FacilityModel>()
            .toList();

        if (entries.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    context.tr('Recent History'),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A)),
                  ),
                  GestureDetector(
                    onTap: () =>
                        context.read<FacilityBloc>().add(ClearRecentlyViewed()),
                    child: Text(
                      context.t('Clear all', 'Tout effacer'),
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF2A7D8F),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: entries.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final facility = entries[index];
                    return Chip(
                      avatar: const Icon(Icons.history_rounded, size: 14),
                      label: Text(
                        facility.name,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A)),
                      ),
                      backgroundColor: Colors.white,
                      side: BorderSide(color: Colors.grey[300]!),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// HOSPITALS SCREEN STATE & SEARCH FILTER BAR
// Stateful body of the Hospitals screen
class _HospitalsState extends State<Hospitals> {
  final _searchController = TextEditingController();
  Timer? _debounceSearchTimer;

  String? _serviceFilter;
  String? _cityFilter;
  String? _priceRangeFilter;

  List<String> _serviceOptions = [];

  @override
  void initState() {
    super.initState();
    final bloc = context.read<FacilityBloc>();
    if (!bloc.state.hasFacilities) {
      bloc.add(LoadFacilities());
    }
    bloc.add(LoadRecentlyViewed());
    // Derive service options from cached facilities after the first frame
    // so the Bloc has time to emit cached data on cold start.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServices());
  }

  @override
  void dispose() {
    _debounceSearchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // Extracts unique service names from cached facilities for the filter dropdown.
  // Sync call — reads from Hive cache. Empty on true first launch until
  // facilities finish loading; the BlocListener below handles that case.
  void _loadServices() {
    try {
      final options = context.read<FacilityRepository>().getServiceOptions();
      if (mounted) setState(() => _serviceOptions = options);
    } catch (_) {}
  }

  // Debounced search — fires after the user stops typing.
  void _onSearchChanged(String query) {
    _debounceSearchTimer?.cancel();
    _debounceSearchTimer = Timer(const Duration(milliseconds: 400), () {
      _dispatchSearch(query);
    });
  }

  void _dispatchSearch(String query) {
    final trimmed = query.trim();
    final hasFilters =
        _serviceFilter != null ||
        _cityFilter != null ||
        _priceRangeFilter != null;
    if (trimmed.isEmpty && !hasFilters) {
      context.read<FacilityBloc>().add(ClearSearch());
      return;
    }
    context.read<FacilityBloc>().add(
      SearchFacilities(
        query: trimmed,
        serviceFilter: _serviceFilter,
        cityFilter: _cityFilter,
        priceRangeFilter: _priceRangeFilter,
      ),
    );
  }

  // Called by FacilityFilterBar when the user taps "Search".
  // Combines whatever is currently typed with the new filter selections.
  void _onFilterApply({String? service, String? city, String? priceRange}) {
    setState(() {
      _serviceFilter = service;
      _cityFilter = city;
      _priceRangeFilter = priceRange;
    });
    _dispatchSearch(_searchController.text.trim());
  }

  void _onClearSearch() {
    _debounceSearchTimer?.cancel();
    _searchController.clear();
    setState(() {
      _serviceFilter = null;
      _cityFilter = null;
      _priceRangeFilter = null;
    });
    context.read<FacilityBloc>().add(ClearSearch());
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFFF8F9F8),
      child: SafeArea(
        bottom: false,
        // BlocListener refreshes service options when facilities finish loading.
        // Covers the cold-start case where Hive is empty during initState.
        child: BlocListener<FacilityBloc, FacilityState>(
          listenWhen: (prev, curr) =>
              prev.facilitiesStatus != curr.facilitiesStatus &&
              curr.facilitiesStatus == FacilityStatus.loaded,
          listener: (context, state) => _loadServices(),
          child: CustomScrollView(
            slivers: [
              // ── Header ──────────────────────────────────────────────────
              const SliverToBoxAdapter(child: _ScreenHeader()),

              // ── Search bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: _SearchField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    onClear: _onClearSearch,
                  ),
                ),
              ),

              // ── Recent History ──────────────────────────────────────────
              const SliverToBoxAdapter(child: _RecentHistorySection()),

              // ── Filter bar ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                  child: FacilityFilterBar(
                    serviceOptions: _serviceOptions,
                    onApply: _onFilterApply,
                  ),
                ),
              ),

              // ── Section header + grid ───────────────────────────────────
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              const _ResultsGrid(),
              const SliverToBoxAdapter(
                child: SizedBox(height: navBottomPadding),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// FACILITY GRID / SEARCH RESULTS
// Main body of the hospitals screen.
// Switches between browse mode (state.facilities) and search mode
// (state.searchResults) based on state.isSearchActive.
// Pharmacy facilities are excluded — this is the Hospitals tab only.
class _ResultsGrid extends StatelessWidget {
  const _ResultsGrid();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FacilityBloc, FacilityState>(
      buildWhen: (prev, curr) =>
          prev.searchStatus != curr.searchStatus ||
          prev.searchResults != curr.searchResults ||
          prev.facilities != curr.facilities ||
          prev.facilitiesStatus != curr.facilitiesStatus,
      builder: (context, state) {
        final isSearching = state.isSearchActive;

        // ── Loading state ──────────────────────────────────────────────────
        final loading = isSearching
            ? state.isSearchLoading
            : state.isFacilitiesLoading;
        if (loading) {
          return const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: EdgeInsets.only(top: 40),
                child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
              ),
            ),
          );
        }

        // ── Source list: search results or pre-computed browse list ─────
        // Browse mode uses hospitalBrowseList (pre-filtered, pre-sorted, pre-capped)
        // to avoid filter+sort on every BlocBuilder rebuild.
        final List<FacilityModel> displayList;
        if (isSearching) {
          displayList = state.searchResults
              .where((f) => f.type != FacilityType.pharmacy)
              .toList();
        } else {
          displayList = state.hospitalBrowseList;
        }

        // ── Empty state ─────────────────────────────────────────────────────
        if (displayList.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text(
                  isSearching
                      ? context.tr('No results found')
                      : context.tr('No facilities available'),
                  style: const TextStyle(color: Color(0xFF5F6368)),
                ),
              ),
            ),
          );
        }

        // ── Section title + grid ────────────────────────────────────────────
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverMainAxisGroup(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    isSearching
                        ? '${context.tr('Search Results')} (${displayList.length})'
                        : context.tr('Top Rated Nearby'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ),
              ),
              SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 12,
                  childAspectRatio: 0.62,
                ),
                delegate: SliverChildBuilderDelegate((context, index) {
                  final facility = displayList[index];
                  return FacilityGridCard(
                    facility: facility,
                    onDetailsTap: () {
                      context.read<FacilityBloc>().add(
                        LoadFacilityDetail(facility.facilityId),
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => FacilityDetailScreen(
                            facilityId: facility.facilityId,
                          ),
                        ),
                      );
                    },
                  );
                }, childCount: displayList.length),
              ),
            ],
          ),
        );
      },
    );
  }
}
