import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';
import 'package:navi_sante/features/hospitals/controller/facility_bloc.dart';
import 'package:navi_sante/features/hospitals/widgets/facility_details_image_carousel.dart';
import 'package:url_launcher/url_launcher.dart';
import '../controller/facility_model.dart';
import '../../home/maps/map_launcher.dart';

// lib/features/hospitals/screens/facility_detail_screen.dart
//
// Full detail view: image carousel, name, rating, bookmark, services,
// description, contact info, directions/call buttons, tags.
//
// facilityId is passed via route arguments. This screen always dispatches
// its own LoadFacilityDetail — it does not assume the caller already did,
// so it works correctly from any entry point (grid card, map pin, deep link).

const _tealColor = Color(0xFF2A7D8F);

class FacilityDetailScreen extends StatefulWidget {
  final String facilityId;
  const FacilityDetailScreen({super.key, required this.facilityId});

  @override
  State<FacilityDetailScreen> createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Only re-fetch if the currently loaded detail isn't this facility —
    // avoids a redundant network call and loading flicker when the caller
    // already triggered the load (e.g. hospitals_screen.dart).
    final current = context.read<FacilityBloc>().state.currentDetail;
    if (current?.facilityId != widget.facilityId) {
      _loadDetail();
    }
  }

  void _loadDetail() {
    context.read<FacilityBloc>().add(LoadFacilityDetail(widget.facilityId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: PlatformAdaptiveAppBar(
        backgroundColor: const Color(0xFFF8F9F8),
        title: ('Details'),
      ),
      body: BlocBuilder<FacilityBloc, FacilityState>(
        buildWhen: (prev, curr) =>
            prev.detailStatus != curr.detailStatus ||
            prev.currentDetail != curr.currentDetail ||
            prev.errorMessage != curr.errorMessage,
        builder: (context, state) {
          // Error takes priority — covers "not found" and network failures.
          if (state.detailStatus == FacilityStatus.error) {
            return _ErrorView(
              message: state.errorMessage ?? 'Something went wrong.',
              onRetry: _loadDetail,
            );
          }

          final detail = state.currentDetail;

          // Still loading, or the loaded detail belongs to a different
          // facility (e.g. user tapped through from another screen quickly).
          if (detail == null || detail.facilityId != widget.facilityId) {
            return const Center(
              child: CircularProgressIndicator(color: _tealColor),
            );
          }

          return _DetailContent(detail: detail);
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final FacilityDetailModel detail;
  const _DetailContent({required this.detail});

  Future<void> _openDirections(BuildContext context) async {
    try {
      await MapLauncher.openDirections(
        latitude: detail.latitude,
        longitude: detail.longitude,
        facilityName: detail.name,
      );
    } on MapLaunchException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppTranslations.tr(e.message, context))),
      );
    }
  }

  Future<void> _call(BuildContext context, String phone) async {
    // Strip everything except digits and a leading '+' before building the URI.
    final sanitized = phone.replaceAll(RegExp(r'[^\d+]'), '');
    final uri = Uri(scheme: 'tel', path: sanitized);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.tr('Unable to open the phone app.'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image carousel ──────────────────────────────────────────────
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: SizedBox(
              height: 220,
              child: DetailImageCarousel(
                images: detail.images,
                fallbackType: detail.type,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ── Name + rating + bookmark ────────────────────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  detail.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ),
              _BookmarkButton(facilityId: detail.facilityId),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: Color(0xFFFFB300),
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                detail.rating.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color(0xFF1A1A1A),
                ),
              ),
            ],
          ),

          // ── Service chips ────────────────────────────────────────────────
          if (detail.services.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: detail.services
                  .map(
                    (name) => Chip(
                      label: Text(name, style: const TextStyle(fontSize: 12)),
                      backgroundColor: Colors.grey[200],
                      side: BorderSide.none,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  )
                  .toList(),
            ),
          ],

          // ── Description ──────────────────────────────────────────────────
          if (detail.description != null && detail.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              detail.description!,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF5F6368),
                height: 1.5,
              ),
            ),
          ],

          // ── Contact card ─────────────────────────────────────────────────
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                if (detail.phone != null)
                  _ContactRow(icon: Icons.phone_rounded, label: detail.phone!),
                if (detail.address != null)
                  _ContactRow(
                    icon: Icons.location_on_rounded,
                    label: detail.address!,
                  ),
                if (detail.workHours != null)
                  _ContactRow(
                    icon: Icons.access_time_rounded,
                    label: detail.workHours!,
                  ),
              ],
            ),
          ),

          // ── Action buttons ────────────────────────────────────────────────
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () => _openDirections(context),
              icon: const Icon(Icons.directions_rounded),
              label: Text(context.tr('GET DIRECTIONS')),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF2A7D8F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (detail.phone != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _call(context, detail.phone!),
                icon: const Icon(Icons.call_rounded),
                label: Text(context.tr('CALL')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _tealColor,
                  side: const BorderSide(color: _tealColor),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],

          // Specilists Section
          if (detail.specialists.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.person_3,
                  size: 20,
                  color: _tealColor,
                ),
                const SizedBox(width: 8),
                Text(
                  context.t("Specialists", "Spécialistes"),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: detail.specialists.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, index) =>
                    _SpecialistCard(specialist: detail.specialists[index]),
              ),
            ),
          ],

          // Tags (amenities/equipment)
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(
                  Icons.apartment_rounded,
                  size: 20,
                  color: _tealColor,
                ),
                const SizedBox(width: 8),
                Text(
                  context.tr('Infrastructure'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...detail.tags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 8, color: Color(0xFF5F6368)),
                    const SizedBox(width: 10),
                    Text(
                      tag,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _BookmarkButton extends StatefulWidget {
  final String facilityId;
  const _BookmarkButton({required this.facilityId});

  @override
  State<_BookmarkButton> createState() => _BookmarkButtonState();
}

class _BookmarkButtonState extends State<_BookmarkButton> {
  bool _cooldown = false;

  void _onPressed() {
    if (_cooldown) return;
    setState(() => _cooldown = true);
    context.read<FacilityBloc>().add(ToggleBookmark(widget.facilityId));
    Future<void>.delayed(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _cooldown = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FacilityBloc, FacilityState, bool>(
      selector: (state) => state.isBookmarked(widget.facilityId),
      builder: (context, isBookmarked) {
        return IconButton(
          onPressed: _onPressed,
          icon: Icon(
            isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: isBookmarked ? _tealColor : const Color(0xFF5F6368),
          ),
        );
      },
    );
  }
}

class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: _tealColor),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

class _SpecialistCard extends StatelessWidget {
  final FacilitySpecialist specialist;
  const _SpecialistCard({required this.specialist});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 108,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 84,
            width: double.infinity,
            child: specialist.photoUrl != null
                ? CachedNetworkImage(
                    imageUrl: specialist.photoUrl!,
                    fit: BoxFit.cover,
                    memCacheWidth: 220,
                    placeholder: (_, _) => const _SpecialistAvatarPlaceholder(),
                    errorWidget: (_, _, _) =>
                        const _SpecialistAvatarPlaceholder(),
                  )
                : const _SpecialistAvatarPlaceholder(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        specialist.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      if (specialist.specialty != null) ...[
                        const SizedBox(height: 1),
                        Text(
                          specialist.specialty!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                      ],
                    ],
                  ),
                  _AvailabilityBadge(isAvailable: specialist.isAvailable),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpecialistAvatarPlaceholder extends StatelessWidget {
  const _SpecialistAvatarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      // TODO: CHANGE / HARMONISE COLOR
      color: Colors.grey[200],
      child: Icon(Icons.person_rounded, color: Colors.grey[400], size: 32),
    );
  }
}

class _AvailabilityBadge extends StatelessWidget {
  final bool isAvailable;
  const _AvailabilityBadge({required this.isAvailable});

  @override
  Widget build(BuildContext context) {
    // TODO: CHANGE / HARMONISE COLOR
    final color = isAvailable
        ? const Color(0xFF2E7D32)
        : const Color(0xFF9E9E9E);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            context.tr(isAvailable ? 'Available' : 'Unavailable'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 40,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: _tealColor),
              child: Text(context.tr('Retry')),
            ),
          ],
        ),
      ),
    );
  }
}
