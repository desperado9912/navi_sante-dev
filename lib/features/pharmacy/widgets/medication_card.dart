import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:latlong2/latlong.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';
import '../../home/viewmodel/map_cubit.dart';
import '../../hospitals/widgets/facility_details_screen.dart';
import '../viewmodels/pharmacy_bloc.dart';
import '../data/pharmacy_model.dart';

/// Clean Cupertino-styled expandable medication list tile.
///
/// Collapsed list view displays:
/// - Medication name
/// - Dosage
/// - Dispensing class (OTC / RX badge)
/// - Bookmark button
/// - Chevron pointing to expand/collapse
///
/// Expanded dropdown displays:
/// - Brand names (inline chips)
/// - Price range label
/// - Conditions treated
/// - Closest 2 retailers (sorted by proximity; tapping opens FacilityDetailScreen)
/// - Description & dispensing note
class MedicationCard extends StatefulWidget {
  final MedicationModel medication;
  final bool isFavourited;
  final VoidCallback onToggleFavourite;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.isFavourited,
    required this.onToggleFavourite,
  });

  @override
  State<MedicationCard> createState() => _MedicationCardState();
}

class _MedicationCardState extends State<MedicationCard> {
  bool _expanded = false;

  static const int _maxRetailersShown = 2;

  IconData get _formIcon => switch (widget.medication.form) {
    MedicationForm.pill => CupertinoIcons.capsule_fill,
    MedicationForm.liquid => Icons.water_drop_rounded,
    MedicationForm.injection => Icons.vaccines_rounded,
    MedicationForm.topical => Icons.healing_rounded,
    MedicationForm.other => Icons.medical_services_rounded,
  };

  List<MedicationRetailer> _getClosestRetailers(
    BuildContext context,
    List<MedicationRetailer> retailers,
  ) {
    if (retailers.isEmpty) return const [];
    final userLoc = context.select<MapCubit, LatLng?>(
      (cubit) => cubit.state.userLocation,
    );
    if (userLoc == null) {
      return retailers.take(_maxRetailersShown).toList();
    }

    const distanceCalc = Distance();
    final sorted = List<MedicationRetailer>.from(retailers)
      ..sort((a, b) {
        final distA = distanceCalc.as(
          LengthUnit.Meter,
          userLoc,
          LatLng(a.latitude, a.longitude),
        );
        final distB = distanceCalc.as(
          LengthUnit.Meter,
          userLoc,
          LatLng(b.latitude, b.longitude),
        );
        return distA.compareTo(distB);
      });
    return sorted.take(_maxRetailersShown).toList();
  }

  @override
  Widget build(BuildContext context) {
    final MedicationModel m = widget.medication;
    final bool isRx = m.dispensingClass == DispensingClass.rx;
    final closestRetailers = _getClosestRetailers(context, m.retailers);

    return Container(
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFEBEBEB),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cupertino-styled list tile row
          CupertinoListTile(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            leadingSize: 38,
            leading: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFD8F6FF).withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _formIcon,
                color: const Color(0xFF2A7D8F),
                size: 20,
              ),
            ),
            title: Text(
              m.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A1A1A),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: m.dosages.isNotEmpty
                ? Text(
                    m.dosages.join(' / '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                : null,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _DispensingBadge(isRx: isRx),
                const SizedBox(width: 8),
                BlocSelector<PharmacyBloc, PharmacyState, bool>(
                  selector: (state) =>
                      state.isFavourited(widget.medication.medicationId),
                  builder: (context, isFav) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onToggleFavourite,
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Icon(
                          isFav
                              ? CupertinoIcons.heart_fill
                              : CupertinoIcons.heart,
                          color: isFav
                              ? CupertinoColors.systemRed
                              : const Color(0xFF9CA3AF),
                          size: 20,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 4),
                Icon(
                  _expanded
                      ? CupertinoIcons.chevron_up
                      : CupertinoIcons.chevron_down,
                  color: const Color(0xFF9CA3AF),
                  size: 18,
                ),
              ],
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),

          // Dropdown expansion details
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            firstCurve: Curves.easeInOut,
            secondCurve: Curves.easeInOut,
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1, thickness: 0.6, color: Color(0xFFF0F0F0)),
                  const SizedBox(height: 10),

                  // Brand names
                  if (m.brandNames.isNotEmpty) ...[
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: m.brandNames
                          .map((b) => _InlineChip(text: b))
                          .toList(),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Price range
                  Row(
                    children: [
                      const Icon(
                        CupertinoIcons.tag,
                        size: 14,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        context.tr(m.priceRangeLabel),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Conditions treated
                  if (m.conditions.isNotEmpty) ...[
                    Text(
                      '${context.tr('Treats: ')}${m.conditions.join(', ')}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF5F6368),
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Retailers (closest 2)
                  if (m.retailers.isNotEmpty) ...[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        ...closestRetailers.map(
                          (r) => _RetailerChip(retailer: r),
                        ),
                        if (m.retailers.length > _maxRetailersShown)
                          Text(
                            '+${m.retailers.length - _maxRetailersShown} ${context.tr('more')}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Description
                  if (m.description != null && m.description!.isNotEmpty) ...[
                    Text(
                      m.description!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: Color(0xFF374151),
                      ),
                    ),
                    const SizedBox(height: 6),
                  ],

                  // Dispensing note
                  Text(
                    context.tr(m.dispensingNote),
                    style: const TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DispensingBadge extends StatelessWidget {
  final bool isRx;
  const _DispensingBadge({required this.isRx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: isRx ? const Color(0xFFFFE1E1) : const Color(0xFFDCF7E3),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isRx ? 'RX' : 'OTC',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: isRx ? const Color(0xFFC62828) : const Color(0xFF2E7D32),
        ),
      ),
    );
  }
}

class _InlineChip extends StatelessWidget {
  final String text;
  const _InlineChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EEF3).withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: Color(0xFF2A7D8F),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Tapping a retailer opens the facility detail screen first
/// so the user can inspect facility details before getting directions.
class _RetailerChip extends StatelessWidget {
  final MedicationRetailer retailer;
  const _RetailerChip({required this.retailer});

  void _openDetail(BuildContext context) {
    Navigator.push(
      context,
      CupertinoPageRoute(
        builder: (_) => FacilityDetailScreen(facilityId: retailer.facilityId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              CupertinoIcons.building_2_fill,
              size: 13,
              color: Color(0xFF2A7D8F),
            ),
            const SizedBox(width: 4),
            Text(
              retailer.name,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Color(0xFF2A7D8F),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
