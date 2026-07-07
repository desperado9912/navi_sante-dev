import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
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

const _tealColor = Color(0xFF00897B);
const _tealLight = Color(0xFF4DB6AC);

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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
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
        const SnackBar(content: Text('Unable to open the phone app.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
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
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
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
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
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
              label: const Text('GET DIRECTIONS'),
              style: FilledButton.styleFrom(
                backgroundColor: _tealLight,
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
                label: const Text('CALL'),
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

          // ── Tags (amenities/equipment) ───────────────────────────────────
          if (detail.tags.isNotEmpty) ...[
            const SizedBox(height: 20),
            ...detail.tags.map(
              (tag) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.circle, size: 6, color: Colors.grey),
                    const SizedBox(width: 10),
                    Text(tag, style: const TextStyle(fontSize: 14)),
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

class _BookmarkButton extends StatelessWidget {
  final String facilityId;
  const _BookmarkButton({required this.facilityId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FacilityBloc, FacilityState>(
      buildWhen: (previous, current) =>
          previous.bookmarkedIds != current.bookmarkedIds,
      builder: (context, state) {
        final isBookmarked = state.isBookmarked(facilityId);

        return IconButton(
          onPressed: () {
            context.read<FacilityBloc>().add(ToggleBookmark(facilityId));
          },
          icon: Icon(
            isBookmarked
                ? Icons.bookmark_rounded
                : Icons.bookmark_border_rounded,
            color: _tealColor,
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
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
