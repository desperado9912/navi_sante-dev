import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';
import '../../pharmacy/controller/pharmacy_bloc.dart';
import '../../pharmacy/widgets/medication_card.dart';

class FavouriteProducts extends StatefulWidget {
  const FavouriteProducts({super.key});

  @override
  State<FavouriteProducts> createState() => _FavouriteProductsState();
}

class _FavouriteProductsState extends State<FavouriteProducts> {
  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);

    // Trigger load if not loaded yet — droppable() on PharmacyBloc means
    // this is a safe no-op if the Pharmacy screen already loaded these
    // this session, not a duplicate network call.
    context.read<PharmacyBloc>().add(LoadMedications());
    context.read<PharmacyBloc>().add(LoadFavourites());
  }

  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const PlatformAdaptiveAppBar(title: 'Favourite Products'),
      backgroundColor: const Color(0xFFF8F9F8),
      body: BlocBuilder<PharmacyBloc, PharmacyState>(
        // Only rebuild when medication data or favourites change — not on
        // unrelated search/filter events from the Pharmacy tab.
        buildWhen: (prev, curr) =>
            prev.medications != curr.medications ||
            prev.medicationsStatus != curr.medicationsStatus ||
            prev.favouriteIds != curr.favouriteIds,
        builder: (context, state) {
          if (state.isMedicationsLoading && state.medications.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
            );
          }

          final favourites = state.medications
              .where((m) => state.isFavourited(m.medicationId))
              .toList();

          if (favourites.isEmpty) return const _EmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: favourites.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final medication = favourites[index];
              return MedicationCard(
                key: ValueKey(medication.medicationId),
                medication: medication,
                isFavourited: true,
                onToggleFavourite: () => context.read<PharmacyBloc>().add(
                  ToggleFavourite(medication.medicationId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// Empty state class. What to show if there are no favourites.
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              CupertinoIcons.heart,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.t('No favourite medications yet', 'Aucun favoris pour le moment'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr('Tap the heart icon on any medication to save it here.'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: Color(0xFF5F6368)),
            ),
          ],
        ),
      ),
    );
  }
}