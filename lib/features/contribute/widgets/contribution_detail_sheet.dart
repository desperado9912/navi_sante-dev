import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/contribution_ticket.dart';
import '../Screens/suggest_facility.dart';
import '../Screens/add_photo.dart';
import '../Screens/update_facility.dart';

class ContributionDetailSheet extends StatelessWidget {
  final ContributionTicket ticket;

  const ContributionDetailSheet({super.key, required this.ticket});

  static void show(BuildContext context, ContributionTicket ticket) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ContributionDetailSheet(ticket: ticket),
    );
  }

  void _navigateToEdit(BuildContext context) {
    // Close the bottom sheet first
    Navigator.pop(context);

    Widget screen;
    switch (ticket.type) {
      case ContributionType.addPhoto:
        screen = AddPhotoScreen(editingTicket: ticket);
        break;
      case ContributionType.updateFacility:
        screen = UpdateFacilityScreen(editingTicket: ticket);
        break;
      case ContributionType.suggestFacility:
      case ContributionType.addReview:
        screen = SuggestFacilityScreen(editingTicket: ticket);
        break;
    }

    Navigator.push(
      context,
      CupertinoPageRoute(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isRejected = ticket.status == ContributionStatus.rejected;

    return Container(
      height: mediaQuery.size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4.5,
            decoration: BoxDecoration(
              color: const Color(0xFFD0D5DD),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ticket.id,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF5F6368),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        ticket.facilityName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // Scrollable details
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // State Machine Status Banner
                  _buildStatusBanner(),
                  const SizedBox(height: 20),

                  // Ticket Type & Timestamp
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2A7D8F).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(ticket.typeIcon, size: 14, color: const Color(0xFF2A7D8F)),
                            const SizedBox(width: 5),
                            Text(
                              ticket.typeLabel,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF2A7D8F),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        ticket.dateText,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF5F6368)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Specific View for Add Photo tickets
                  if (ticket.type == ContributionType.addPhoto) ...[
                    const Text(
                      'Photos added pending reviewal',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                        childAspectRatio: 1.2,
                      ),
                      itemCount: ticket.photoUrls.length,
                      itemBuilder: (context, i) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl: ticket.photoUrls[i],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    ),
                  ] else ...[
                    // Key-Value details of the suggested/edited facility
                    const Text(
                      'Suggested Information',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF9FAFB),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Column(
                        children: [
                          ...ticket.data.entries.map((entry) {
                            if (entry.value is List) {
                              final list = entry.value as List;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF5F6368),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 6,
                                      runSpacing: 6,
                                      children: list.map((item) {
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF2A7D8F)
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Text(
                                            item.toString(),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF2A7D8F),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(
                                    width: 100,
                                    child: Text(
                                      entry.key,
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Color(0xFF5F6368),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value.toString(),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),

                    if (ticket.photoUrls.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      const Text(
                        'Attached Photos',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        height: 84,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: ticket.photoUrls.length,
                          separatorBuilder: (_, _) => const SizedBox(width: 8),
                          itemBuilder: (ctx, i) => ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: ticket.photoUrls[i],
                              width: 84,
                              height: 84,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],

                  // Edit & Resubmit button for rejected tickets
                  if (isRejected) ...[
                    const SizedBox(height: 28),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _navigateToEdit(context),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit & Resubmit'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFD93025),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    IconData icon;
    Color fgColor;
    Color bgColor;
    Color borderColor;
    String title;
    String message;

    switch (ticket.status) {
      case ContributionStatus.approved:
        icon = Icons.check_circle_outline_rounded;
        fgColor = const Color(0xFF1E8E3E);
        bgColor = const Color(0xFFE6F4EA);
        borderColor = const Color(0xFFB7E1CD);
        title = 'Approved';
        message = 'Your edit has been approved and is now visible to all users.';
        break;
      case ContributionStatus.pending:
        icon = Icons.hourglass_top_rounded;
        fgColor = const Color(0xFFD97706);
        bgColor = const Color(0xFFFEF3C7);
        borderColor = const Color(0xFFFDE68A);
        title = 'Pending Review';
        message = 'Your edits are being reviewed for accuracy.';
        break;
      case ContributionStatus.rejected:
        icon = Icons.cancel_outlined;
        fgColor = const Color(0xFFD93025);
        bgColor = const Color(0xFFFCE8E6);
        borderColor = const Color(0xFFF9AB9F);
        title = 'Rejected';
        message =
            'Your edits have been rejected for the following reasons:\n• ${ticket.rejectionReason ?? "Information could not be verified."}';
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: fgColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: fgColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: fgColor.withValues(alpha: 0.9),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
