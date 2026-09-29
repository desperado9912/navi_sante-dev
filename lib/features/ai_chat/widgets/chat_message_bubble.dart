import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hospitals/viewmodels/facility_bloc.dart';
import '../../hospitals/data/facility_model.dart';
import '../../hospitals/widgets/facility_details_screen.dart';
import '../../hospitals/widgets/facility_grid_cards.dart';
import '../../pharmacy/viewmodels/pharmacy_bloc.dart';
import '../../pharmacy/data/pharmacy_model.dart';
import '../../pharmacy/widgets/medication_card.dart';
import '../viewmodel/ai_chat_bloc.dart';
import '../models/ai_chat_models.dart';
import 'ai_chat_style.dart';

class ChatMessageBubble extends StatelessWidget {
  const ChatMessageBubble({
    super.key,
    required this.message,
    this.showRetry = false,
  });

  final ChatMessage message;
  final bool showRetry;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment:
            isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Align(
            alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.78,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isUser
                      ? kNaviTeal
                      : message.isError
                      ? const Color(0xFFFFE8E8)
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isUser ? 18 : 6),
                    bottomRight: Radius.circular(isUser ? 6 : 18),
                  ),
                  boxShadow: isUser
                      ? const []
                      : [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                ),
                child: Text(
                  message.text,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.4,
                    color: isUser
                        ? Colors.white
                        : message.isError
                        ? const Color(0xFFB71C1C)
                        : const Color(0xFF1A1A1A),
                  ),
                ),
              ),
            ),
          ),
          if (showRetry)
            TextButton(
              onPressed: () =>
                  context.read<AiChatBloc>().add(AiChatRetryLast()),
              child: Text(t(context, 'Retry', 'Réessayer')),
            ),
          if (!isUser) ...[
            _FacilityResults(facilities: message.facilities),
            _MedicationResults(medications: message.medications),
          ],
        ],
      ),
    );
  }
}

class ChatTypingDots extends StatefulWidget {
  const ChatTypingDots({super.key});

  @override
  State<ChatTypingDots> createState() => _ChatTypingDotsState();
}

class _ChatTypingDotsState extends State<ChatTypingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10, right: 64),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final t = (_c.value + i * 0.2) % 1.0;
                final dy = (t < 0.5 ? t : 1 - t) * -6;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: Transform.translate(
                    offset: Offset(0, dy),
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: kNaviTeal,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

class _FacilityResults extends StatelessWidget {
  const _FacilityResults({required this.facilities});

  final List<FacilityModel> facilities;

  @override
  Widget build(BuildContext context) {
    if (facilities.isEmpty) return const SizedBox.shrink();
    final screenWidth = MediaQuery.sizeOf(context).width;
    final double childAspectRatio = screenWidth < 360
        ? 0.58
        : screenWidth < 390
            ? 0.60
            : 0.62;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: childAspectRatio,
        children: [
          for (final facility in facilities.take(3))
            FacilityGridCard(
              facility: facility,
              onDetailsTap: () {
                context.read<FacilityBloc>().add(
                  LoadFacilityDetail(facility.facilityId),
                );
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        FacilityDetailScreen(facilityId: facility.facilityId),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _MedicationResults extends StatelessWidget {
  const _MedicationResults({required this.medications});

  final List<MedicationModel> medications;

  @override
  Widget build(BuildContext context) {
    if (medications.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Column(
        children: [
          for (final medication in medications.take(3)) ...[
            BlocSelector<PharmacyBloc, PharmacyState, bool>(
              selector: (state) => state.isFavourited(medication.medicationId),
              builder: (context, isFavourited) {
                return MedicationCard(
                  key: ValueKey(medication.medicationId),
                  medication: medication,
                  isFavourited: isFavourited,
                  onToggleFavourite: () => context.read<PharmacyBloc>().add(
                    ToggleFavourite(medication.medicationId),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
