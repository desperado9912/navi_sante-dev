import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:navi_sante/core/utils/language_cubit/app_translations.dart';
import '../../home/maps/map_launcher.dart';
import '../controller/pharmacy_model.dart';

/// Compact medication card matching the Pharmacy screen mockup, trimmed
/// down per your "too big, keep it simple and compact" note: no boxed
/// grid cells, no full-width button — brand names and retailers are
/// inline chips, price is plain text, and expand/collapse is a small
/// chevron icon rather than a full-width "View Details" button.
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

  static const int _maxConditionsShown = 4;
  static const int _maxRetailersShown = 3;

  IconData get _formIcon => switch (widget.medication.form) {
    MedicationForm.pill => CupertinoIcons.capsule_fill,
    MedicationForm.liquid => Icons.water_drop_rounded,
    MedicationForm.injection => Icons.vaccines_rounded,
    MedicationForm.topical => Icons.healing_rounded,
    MedicationForm.other => Icons.medical_services_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final MedicationModel m = widget.medication;
    final bool isRx = m.dispensingClass == DispensingClass.rx;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFD8F6FF).withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  _formIcon,
                  color: const Color(0xFF2A7D8F),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (m.dosages.isNotEmpty)
                      Text(
                        m.dosages.join(' / '),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              _DispensingBadge(isRx: isRx),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: widget.onToggleFavourite,
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(
                    widget.isFavourited
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: widget.isFavourited
                        ? const Color(0xFFE53935)
                        : Colors.grey[400],
                    size: 22,
                  ),
                ),
              ),
            ],
          ),

          if (m.brandNames.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: m.brandNames.map((b) => _InlineChip(text: b)).toList(),
            ),
          ],

          const SizedBox(height: 6),
          Text(
            context.tr(m.priceRangeLabel),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1A1A1A),
            ),
          ),

          if (m.conditions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              '${context.tr('Treats: ')}${_capped(m.conditions, _maxConditionsShown)}',
              style: TextStyle(fontSize: 11.5, color: Colors.grey[600]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],

          if (m.retailers.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 10,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ...m.retailers
                    .take(_maxRetailersShown)
                    .map((r) => _RetailerChip(retailer: r)),
                if (m.retailers.length > _maxRetailersShown)
                  Text(
                    '+${m.retailers.length - _maxRetailersShown} ${context.tr('more')}',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500]),
                  ),
              ],
            ),
          ],

          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            alignment: Alignment.topCenter,
            child: !_expanded
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (m.description != null && m.description!.isNotEmpty)
                          Text(
                            m.description!,
                            style: const TextStyle(fontSize: 12.5, height: 1.4),
                          ),
                        const SizedBox(height: 6),
                        Text(
                          context.tr(m.dispensingNote),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontStyle: FontStyle.italic,
                            color: Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.only(top: 8, bottom: 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    _expanded
                        ? CupertinoIcons.chevron_up
                        : CupertinoIcons.chevron_down,
                    color: const Color(0xFF2A7D8F),
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _capped(List<String> items, int max) {
    if (items.length <= max) return items.join(', ');
    return '${items.take(max).join(', ')} +${items.length - max}';
  }
}

class _DispensingBadge extends StatelessWidget {
  final bool isRx;
  const _DispensingBadge({required this.isRx});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isRx ? const Color(0xFFFFE1E1) : const Color(0xFFDCF7E3),
        borderRadius: BorderRadius.circular(8),
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

// Medication brand names chip
class _InlineChip extends StatelessWidget {
  final String text;
  const _InlineChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFD7EEF3).withValues(alpha: 0.4),
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

/// Tapping a retailer opens native Maps (Google/Apple/Waze, whichever
/// the user has set as preferred) centered on that pharmacy — reuses
/// MapLauncher.openDirections() as-is, no in-app map tab hand-off.
class _RetailerChip extends StatelessWidget {
  final MedicationRetailer retailer;
  const _RetailerChip({required this.retailer});

  Future<void> _open(BuildContext context) async {
    try {
      await MapLauncher.openDirections(
        latitude: retailer.latitude,
        longitude: retailer.longitude,
        facilityName: retailer.name,
      );
    } on MapLaunchException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.tr(e.message))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _open(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 16,
            color: Color(0xFF2A7D8F),
          ),
          const SizedBox(width: 3),
          Text(
            retailer.name,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF2A7D8F),
              decoration: TextDecoration.underline,
            ),
          ),
        ],
      ),
    );
  }
}
