import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:navi_sante/core/utils/navigation_menu.dart' show navBottomPadding;
import '../features/contribute/models/contribution_ticket.dart';
import '../features/contribute/widgets/contribution_detail_sheet.dart';
import '../features/contribute/Screens/suggest_facility.dart';
import '../features/contribute/Screens/update_facility.dart';
// import '../features/contribute/sub_screens/add_review.dart';
import '../features/contribute/Screens/add_photo.dart';
import '../features/contribute/viewmodel/contribute_bloc.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../features/hospitals/data/facility_repository.dart';

class ContributeScreen extends StatefulWidget {
  const ContributeScreen({super.key});

  @override
  State<ContributeScreen> createState() => _ContributeScreenState();
}

class _ContributeScreenState extends State<ContributeScreen> {
  // 0: All, 1: Pending, 2: Approved, 3: Rejected
  int _selectedFilter = 0;

  final ContributionBackendService _backendService =
      ContributionBackendService();
  bool _isLoadingTickets = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _backendService.subscribeToContributionUpdates(
      facilityRepository: context.read<FacilityRepository>(),
    );
  }

  @override
  void dispose() {
    _backendService.unsubscribeFromContributionUpdates();
    super.dispose();
  }

  Future<void> _loadTickets() async {
    setState(() => _isLoadingTickets = true);
    try {
      await _backendService.fetchUserContributions();
    } catch (e) {
      debugPrint('fetchUserContributions failed: $e');
    } finally {
      if (mounted) setState(() => _isLoadingTickets = false);
    }
  }

  String _deriveInitials(String source) {
    final trimmed = source.trim();
    if (trimmed.isEmpty) return '?';
    final name = trimmed.contains('@') ? trimmed.split('@').first : trimmed;
    final parts = name.split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  void _navigateToScreen(Widget screen) {
    Navigator.push(context, CupertinoPageRoute(builder: (context) => screen));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9F8),
      body: SafeArea(
        top: false,
        bottom: false,
        child: RefreshIndicator(
          color: const Color(0xFF2A7D8F),
          onRefresh: _loadTickets,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 10, 20, navBottomPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── 1. Profile Preview Box with Linear Gradient ───────────────
                _buildProfilePreviewBox(),
                const SizedBox(height: 24),

                // ── 2. Four Action Buttons ────────────────────────────────────
                _buildActionButtonsGrid(),
                const SizedBox(height: 28),

                // ── 3. Contributions Section (Tickets & State Machine) ─────────
                _buildContributionsSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 1. Profile Preview Box ──────────────────────────────────────────────────
  Widget _buildProfilePreviewBox() {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final user = Supabase.instance.client.auth.currentUser;
        final customName =
            (user?.userMetadata?['custom_display_name'] as String?) ?? '';
        final fullName = (user?.userMetadata?['full_name'] as String?) ?? '';
        final resolvedName = customName.isNotEmpty ? customName : fullName;
        final email = user?.email ?? '';
        final displayName = resolvedName.isNotEmpty
            ? resolvedName
            : (email.isNotEmpty ? email : 'Contributor');
        final initials = _deriveInitials(
          resolvedName.isNotEmpty
              ? resolvedName
              : (email.isNotEmpty ? email : 'C'),
        );

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0.72, 3.0], // Blue pushed lower down the linear path
              colors: [
                Color(0xFFF8F9F8), // Top: normal screen background
                Color(0xFFD8F6FF), // Bottom: secondary theme color
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2A7D8F).withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  // Avatar with initials fallback (compact 42x42)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A7D8F).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2A7D8F),
                        width: 1,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2A7D8F),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // User name & Simplified Contributor badge (no background)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        const Row(
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Level 1 Contributor',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF5F6368),
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(
                                  Icons.workspace_premium_outlined,
                                  size: 14,
                                  color: Color(0xFF2A7D8F),
                                ),
                              ],
                            ),
                            Spacer(),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.trending_up_rounded,
                                  size: 16,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  '+ 43%',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Simple MVP notice: "Contribute more to level up"
              const Row(
                children: [
                  Text(
                    'Contribute more to level up',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w300,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── 2. Four Action Buttons ──────────────────────────────────────────────────
  Widget _buildActionButtonsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Actions',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1A1A1A),
          ),
        ),
        const SizedBox(height: 8),
        //TODO: CHANGE ICON COLORS (iconBG)
        Row(
          children: [
            Expanded(
              child: _buildActionTile(
                title: 'Suggest facility',
                subtitle: 'Add new place',
                icon: Icons.add_location_alt_rounded,
                iconBg: const Color(0xFF2A7D8F),
                onTap: () => _navigateToScreen(const SuggestFacilityScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildActionTile(
                title: 'Update facility',
                subtitle: 'Edit info & hours',
                icon: Icons.edit_location_alt_rounded,
                iconBg: const Color(0xFF0284C7),
                onTap: () => _navigateToScreen(const UpdateFacilityScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            // Expanded(
            //   child: _buildActionTile(
            //     title: 'Add review',
            //     subtitle: 'Rate healthcare',
            //     icon: CupertinoIcons.chat_bubble_text,
            //     iconBg: const Color(0xFFF59E0B),
            //     onTap: () => _navigateToScreen(const AddReviewScreen()),
            //   ),
            // ),
            // const SizedBox(width: 12),
            Expanded(
              child: _buildActionTile(
                title: 'Add photo',
                subtitle: 'Upload photos',
                icon: Icons.add_a_photo_rounded,
                iconBg: const Color(0xFF10B981),
                onTap: () => _navigateToScreen(const AddPhotoScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconBg,
    required VoidCallback onTap,
  }) {
    return _PressableActionTile(
      title: title,
      subtitle: subtitle,
      icon: icon,
      iconBg: iconBg,
      onTap: onTap,
    );
  }

  // ── 3. Contributions Section (Tickets & State Machine) ──────────────────────
  Widget _buildContributionsSection() {
    return ValueListenableBuilder<List<ContributionTicket>>(
      valueListenable: ContributionTicketsStore.instance.ticketsNotifier,
      builder: (context, tickets, _) {
        final pendingCount = tickets
            .where((t) => t.status == ContributionStatus.pending)
            .length;
        final approvedCount = tickets
            .where((t) => t.status == ContributionStatus.approved)
            .length;
        final rejectedCount = tickets
            .where((t) => t.status == ContributionStatus.rejected)
            .length;

        final filteredTickets = tickets.where((ticket) {
          if (_selectedFilter == 1) {
            return ticket.status == ContributionStatus.pending;
          }
          if (_selectedFilter == 2) {
            return ticket.status == ContributionStatus.approved;
          }
          if (_selectedFilter == 3) {
            return ticket.status == ContributionStatus.rejected;
          }
          return true; // All
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Your Contributions',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                  ),
                ),
                Text(
                  '${tickets.length} total',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF5F6368),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Sorting Tabs
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab(
                    index: 0,
                    label: 'All',
                    count: tickets.length,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    index: 1,
                    label: 'Pending',
                    count: pendingCount,
                    activeColor: const Color(0xFF2A7D8F),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    index: 2,
                    label: 'Approved',
                    count: approvedCount,
                    activeColor: const Color(0xFF2A7D8F),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab(
                    index: 3,
                    label: 'Rejected',
                    count: rejectedCount,
                    activeColor: const Color(0xFF2A7D8F),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Tickets List
            if (filteredTickets.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Center(
                  child: _isLoadingTickets
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Color(0xFF2A7D8F),
                          ),
                        )
                      : const Text(
                          'No contributions found in this category.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF5F6368),
                          ),
                        ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filteredTickets.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final ticket = filteredTickets[index];
                  return _buildTicketCard(ticket);
                },
              ),
          ],
        );
      },
    );
  }

  Widget _buildFilterTab({
    required int index,
    required String label,
    required int count,
    Color activeColor = const Color(0xFF2A7D8F),
  }) {
    final isSelected = _selectedFilter == index;

    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? activeColor : const Color(0xFFE5E7EB),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.25)
                    : const Color(0xFFF2F4F7),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTicketCard(ContributionTicket ticket) {
    return _PressableTicketCard(
      ticket: ticket,
      onTap: () => ContributionDetailSheet.show(context, ticket),
    );
  }
}

/// Action tile with a visible pressed state (slight scale + shadow lift) —
/// kept intentionally plain (icon, title, one-line subtitle) so the grid
/// stays clean rather than busy.
class _PressableActionTile extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final VoidCallback onTap;

  const _PressableActionTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconBg,
    required this.onTap,
  });

  @override
  State<_PressableActionTile> createState() => _PressableActionTileState();
}

class _PressableActionTileState extends State<_PressableActionTile> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _isPressed
                  ? widget.iconBg.withValues(alpha: 0.4)
                  : const Color(0xFFEEF0F2),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.02 : 0.04),
                blurRadius: _isPressed ? 4 : 10,
                offset: Offset(0, _isPressed ? 1 : 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 40,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      widget.iconBg.withValues(alpha: 0.16),
                      widget.iconBg.withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: widget.iconBg, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF5F6368),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ticket card with a colored status accent bar, a pressed state, and a
/// clear "Edit & resubmit" affordance on rejected tickets — since tapping
/// one reopens the SAME ticket (see ContributionBackendService) rather than
/// creating a new one, the label makes that behavior obvious.
class _PressableTicketCard extends StatefulWidget {
  final ContributionTicket ticket;
  final VoidCallback onTap;

  const _PressableTicketCard({required this.ticket, required this.onTap});

  @override
  State<_PressableTicketCard> createState() => _PressableTicketCardState();
}

class _PressableTicketCardState extends State<_PressableTicketCard> {
  bool _isPressed = false;

  void _setPressed(bool value) {
    if (_isPressed != value) setState(() => _isPressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final ticket = widget.ticket;
    final isRejected = ticket.status == ContributionStatus.rejected;

    return GestureDetector(
      onTapDown: (_) => _setPressed(true),
      onTapCancel: () => _setPressed(false),
      onTapUp: (_) => _setPressed(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFEEF0F2)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isPressed ? 0.02 : 0.03),
                blurRadius: _isPressed ? 4 : 8,
                offset: Offset(0, _isPressed ? 1 : 2),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Status accent bar
                Container(
                  width: 4,
                  decoration: BoxDecoration(color: ticket.statusColor),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(13, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  ticket.typeIcon,
                                  size: 15,
                                  color: const Color(0xFF2A7D8F),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  ticket.typeLabel,
                                  style: const TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF2A7D8F),
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: ticket.statusBgColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                ticket.status.name.toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                  color: ticket.statusColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          ticket.facilityName,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1A1A1A),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          ticket.type == ContributionType.addPhoto
                              ? '${ticket.photoUrls.length} photos submitted for verification'
                              : '${ticket.data['City'] ?? ''} • ${ticket.data['Address'] ?? ''}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF5F6368),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (ticket.photoUrls.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 48,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              physics: const BouncingScrollPhysics(),
                              itemCount: ticket.photoUrls.length > 4
                                  ? 4
                                  : ticket.photoUrls.length,
                              separatorBuilder: (_, index) =>
                                  const SizedBox(width: 8),
                              itemBuilder: (context, i) {
                                final isLast =
                                    i == 3 && ticket.photoUrls.length > 4;
                                final url = ticket.photoUrls[i];
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Stack(
                                    children: [
                                      CachedNetworkImage(
                                        imageUrl: url,
                                        width: 48,
                                        height: 48,
                                        fit: BoxFit.cover,
                                        placeholder: (_, url) => Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFFF0F0F0),
                                          child: const Icon(
                                            CupertinoIcons.photo,
                                            size: 18,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                        errorWidget: (_, url, error) => Container(
                                          width: 48,
                                          height: 48,
                                          color: const Color(0xFFF0F0F0),
                                          child: const Icon(
                                            CupertinoIcons.photo,
                                            size: 18,
                                            color: Color(0xFF9CA3AF),
                                          ),
                                        ),
                                      ),
                                      if (isLast)
                                        Container(
                                          width: 48,
                                          height: 48,
                                          color: Colors.black.withValues(
                                            alpha: 0.55,
                                          ),
                                          alignment: Alignment.center,
                                          child: Text(
                                            '+${ticket.photoUrls.length - 3}',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ticket.dateText,
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9CA3AF),
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  isRejected
                                      ? 'Edit & resubmit'
                                      : 'View details',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isRejected
                                        ? const Color(0xFFD93025)
                                        : const Color(0xFF2A7D8F),
                                  ),
                                ),
                                const SizedBox(width: 3),
                                Icon(
                                  CupertinoIcons.chevron_right,
                                  size: 11,
                                  color: isRejected
                                      ? const Color(0xFFD93025)
                                      : const Color(0xFF2A7D8F),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
