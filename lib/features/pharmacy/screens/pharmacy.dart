import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';
import 'package:navi_sante/core/utils/navigation_menu.dart'
    show navBottomPadding;
import '../controller/pharmacy_bloc.dart';
import '../controller/pharmacy_model.dart';
import '../widgets/medical_notice_strip.dart';
import '../widgets/medication_card.dart';
import '../widgets/medication_search_bar.dart';
import '../widgets/no_results_view.dart';
import '../widgets/quick_filter_chips.dart';

// =============================================================================
//
// The Medications tab.
//
// DATA FLOW:
//   initState → LoadMedications → cache-then-network (one guarded fetch)
//   typing → 400ms debounce → SearchMedications → in-memory search (zero network)
//   chip tap → SearchMedications immediately (explicit user intent, no debounce)
//   clear → ClearMedicationSearch (local only, zero network)
//
// BUILD OPTIMISATION:
//   Two separate BlocBuilders with targeted buildWhen — the header section
//   (quick filters) only rebuilds when filters/recents change; the results
//   section only rebuilds when the medication list, search results, or
//   status change. A favourites-only change (heart toggle) does NOT rebuild
//   the entire screen — it only triggers the results section where the
//   affected MedicationCard lives.
// =============================================================================

class PharmacyScreen extends StatefulWidget {
  const PharmacyScreen({super.key});

  @override
  State<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends State<PharmacyScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;

  // 400ms — a little more generous than the map search's 220ms. Given
  // the recent disk I/O incident, the extra margin here costs nothing
  // (search itself is local/instant either way) and further reduces how
  // often a mid-typing query could ever reach the network fallback path.
  static const Duration _debounceDelay = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);
    MemoryLeakTracker.logInit(_controller);

    // Safe to dispatch even if already loaded — droppable() on the bloc
    // means a load already in progress simply absorbs this dispatch.
    context.read<PharmacyBloc>().add(LoadMedications());
    context.read<PharmacyBloc>().add(LoadFavourites());
  }

  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    MemoryLeakTracker.logDispose(_controller);
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ── Search callbacks ──────────────────────────────────────────────────

  void _onQueryChanged(String raw) {
    _debounce?.cancel();
    _debounce = Timer(_debounceDelay, () {
      if (!mounted) return;
      final PharmacyBloc bloc = context.read<PharmacyBloc>();
      final String trimmed = raw.trim();
      if (trimmed.isEmpty) {
        bloc.add(ClearMedicationSearch());
      } else {
        bloc.add(SearchMedications(trimmed));
      }
    });
  }

  /// Chip taps are explicit user intent — bypass debounce.
  void _onChipTap(String term) {
    _debounce?.cancel();
    _controller.text = term;
    _controller.selection = TextSelection.collapsed(offset: term.length);
    context.read<PharmacyBloc>().add(SearchMedications(term));
  }

  void _onClearSearch() {
    _debounce?.cancel();
    _controller.clear();
    context.read<PharmacyBloc>().add(ClearMedicationSearch());
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // No Scaffold — NavigationMenu already provides one with the
    // PlatformAdaptiveAppBar and SafeArea for this tab.
    return ColoredBox(
      color: const Color(0xFFF8F9F8),
      child: BlocBuilder<PharmacyBloc, PharmacyState>(
        buildWhen: (prev, curr) =>
            prev.medications != curr.medications ||
            prev.medicationsStatus != curr.medicationsStatus ||
            prev.activeQuery != curr.activeQuery ||
            prev.searchResults != curr.searchResults ||
            prev.commonQuickFilters != curr.commonQuickFilters ||
            prev.recentSearches != curr.recentSearches ||
            prev.favouriteIds != curr.favouriteIds,
        builder: (context, state) {
          return CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              // ── Header: subtitle + search bar + quick filters + notice ──
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      MedicationSearchBar(
                        controller: _controller,
                        onChanged: _onQueryChanged,
                        onClear: _onClearSearch,
                      ),

                      // Quick filters
                      if (state.mergedQuickFilters.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: QuickFilterChips(
                            filters: state.mergedQuickFilters,
                            activeFilter: state.activeQuery,
                            canClear: state.recentSearches.isNotEmpty,
                            onTap: _onChipTap,
                            onClear: () => context.read<PharmacyBloc>().add(
                              ClearRecentSearches(),
                            ),
                          ),
                        ),

                      const SizedBox(height: 12),

                      // Medical notice label
                      const MedicalNoticeStrip(),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),

              // ── Results section ─────────────────────────────────────────
              ..._buildResultsSlivers(context, state),
            ],
          );
        },
      ),
    );
  }

  // ── Results slivers ─────────────────────────────────────────────────

  List<Widget> _buildResultsSlivers(BuildContext context, PharmacyState state) {
    // 1. Loading — only show spinner when there's truly nothing cached.
    if (state.isMedicationsLoading && state.medications.isEmpty) {
      return const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
          ),
        ),
      ];
    }

    // 2. Error — only shown when no cached data is available.
    if (state.medicationsStatus == MedicationStatus.error &&
        state.medications.isEmpty) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorRetryView(
            message: state.errorMessage ?? 'Unable to load medications.',
            onRetry: () => context.read<PharmacyBloc>().add(LoadMedications()),
          ),
        ),
      ];
    }

    // 3. Search performed but no results.
    if (state.hasNoResults) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: NoResultsView(query: state.activeQuery),
        ),
      ];
    }

    // 4. Normal display — search results or default medications.
    final bool searching = state.isSearching;
    final List<MedicationModel> displayList = searching
        ? state.searchResults
        : state.defaultMedications;

    if (displayList.isEmpty) {
      return const [SliverToBoxAdapter(child: SizedBox.shrink())];
    }

    final String headerLabel = searching
        ? (context.isFrench
            ? '${displayList.length} résultat${displayList.length == 1 ? '' : 's'} trouvé${displayList.length == 1 ? '' : 's'}'
            : 'Found ${displayList.length} result${displayList.length == 1 ? '' : 's'}')
        : context.tr('Common medications');

    // Medicatiosn cards Area
    return [
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
          child: Text(
            headerLabel,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, navBottomPadding),
        sliver: SliverList.separated(
          itemCount: displayList.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final MedicationModel medication = displayList[index];
            return MedicationCard(
              key: ValueKey(medication.medicationId),
              medication: medication,
              isFavourited: state.isFavourited(medication.medicationId),
              onToggleFavourite: () => context.read<PharmacyBloc>().add(
                ToggleFavourite(medication.medicationId),
              ),
            );
          },
        ),
      ),
    ];
  }
}

// ── Error + retry ──────────────────────────────────────────────────────

// TODO: Convert to Network connection Error state reusable widget for Facility, Medications and AI chat screens.
class _ErrorRetryView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorRetryView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 44, color: Colors.grey[400]),
            const SizedBox(height: 14),
            Text(
              context.tr(message),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: Colors.grey[700]),
            ),
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2A7D8F),
                side: const BorderSide(color: Color(0xFF2A7D8F)),
              ),
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
