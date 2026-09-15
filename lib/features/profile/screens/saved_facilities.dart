import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
// import 'package:cached_network_image/cached_network_image.dart';
import 'package:navi_sante/core/performance/memory_leak_tracker.dart';
import 'package:navi_sante/core/utils/platform_adaptive_app_bar.dart';
import 'package:navi_sante/core/utils/language_cubit/language_cubit.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hospitals/controller/facility_bloc.dart';
import '../../hospitals/controller/facility_model.dart';
import '../../hospitals/widgets/facility_details_screen.dart';

class SavedFacilities extends StatefulWidget {
  const SavedFacilities({super.key});
  @override
  State<SavedFacilities> createState() => _SavedFacilitiesState();
}

class _SavedFacilitiesState extends State<SavedFacilities> {
  @override
  void initState() {
    super.initState();
    MemoryLeakTracker.logInit(this);

    final bloc = context.read<FacilityBloc>();
    if (!bloc.state.hasFacilities) {
      bloc.add(LoadFacilities());
    }
    bloc.add(LoadBookmarks());
  }

  @override
  void dispose() {
    MemoryLeakTracker.logDispose(this);
    super.dispose();
  }

  // UI BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      appBar: const PlatformAdaptiveAppBar(title: 'Saved Facilities'),
      body: BlocBuilder<FacilityBloc, FacilityState>(
        builder: (context, state) {
          if (state.isFacilitiesLoading && state.facilities.isEmpty) {
            return const Center(
              child: CircularProgressIndicator(color: Color(0xFF2A7D8F)),
            );
          }
          final saved = state.facilities
              .where((f) => state.isBookmarked(f.facilityId))
              .toList();

          if (saved.isEmpty) return const _EmptyState();

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            itemCount: saved.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final facility = saved[index];
              return SavedFacilityCard(
                facility: facility,
                onTap: () {
                  // Load details on card tap.
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
            },
          );
        },
      ),
    );
  }
}

// Empty state class. What to show if there are no bookmarks.
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
              CupertinoIcons.bookmark,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              context.tr('No saved facilities yet'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              context.tr(
                'Tap the bookmark icon on any hospital to save your favorite facilities here.',
              ),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }
}

// WIDGET SAVED FACILITY CARDS
class SavedFacilityCard extends StatelessWidget {
  final FacilityModel facility;
  final VoidCallback onTap;

  const SavedFacilityCard({
    super.key,
    required this.facility,
    required this.onTap,
  });

  String _typeLabel(BuildContext context) {
    final raw = facility.type.name;
    final capitalized = raw[0].toUpperCase() + raw.substring(1);
    return context.tr(capitalized);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Thumbnail(facility: facility),
            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    facility.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1A1A1A),
                      height: 1.25,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),
                  Text(
                    facility.address != null && facility.address!.isNotEmpty
                        ? '${_typeLabel(context)} • ${facility.address}'
                        : _typeLabel(context),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF5F6368)),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB300),
                        size: 16,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        facility.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),

                      if (facility.servicesList.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            facility.servicesList.join(', '),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: Color(0xFF5F6368),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),
            _RemoveBookmarkButton(facilityId: facility.facilityId),
          ],
        ),
      ),
    );
  }
}

// IMAGE THUMBNAIL / PLACEHOLDER
class _Thumbnail extends StatelessWidget {
  final FacilityModel facility;
  const _Thumbnail({required this.facility});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: 70,
        height: 70,
        child: _IconTile(type: facility.type),
        // facility.primaryImage != null
        //     ? CachedNetworkImage(
        //         imageUrl: facility.primaryImage!,
        //         fit: BoxFit.cover,
        //         placeholder: (_, _) => _IconTile(type: facility.type),
        //         errorWidget: (_, _, _) => _IconTile(type: facility.type),
        //       )
        //     : _IconTile(type: facility.type),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  final FacilityType type;
  const _IconTile({required this.type});

  IconData get _icon => switch (type) {
    FacilityType.hospital ||
    FacilityType.clinic => Icons.local_hospital_rounded,
    FacilityType.pharmacy => CupertinoIcons.capsule_fill,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFE8F0EF),
      child: Center(
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: const Color(0xFF2A7D8F),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(_icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _RemoveBookmarkButton extends StatefulWidget {
  final String facilityId;

  const _RemoveBookmarkButton({required this.facilityId});

  @override
  State<_RemoveBookmarkButton> createState() => _RemoveBookmarkButtonState();
}

class _RemoveBookmarkButtonState extends State<_RemoveBookmarkButton> {
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
    return IconButton(
      onPressed: _onPressed,
      icon: const Icon(
        Icons.bookmark_rounded,
        color: Color(0xFF2A7D8F),
        size: 22,
      ),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
