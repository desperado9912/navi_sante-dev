import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'ai_chat_style.dart';

class ChatEmptyState extends StatelessWidget {
  const ChatEmptyState({super.key, required this.onSuggestion});

  final ValueChanged<String> onSuggestion;

  @override
  Widget build(BuildContext context) {
    final fr = isFrench(context);
    final chips = fr
        ? const [
            'Hôpitaux à proximité',
            'Infos paracétamol',
            "Qu'est-ce que le paludisme ?",
          ]
        : const [
            'Find nearby hospitals',
            'Paracetamol info',
            'What is malaria?',
          ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: const BoxDecoration(
                color: kNaviTeal,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.hexagonNodes,
                  color: Colors.white,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'NaviSanté Assistant',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              fr
                  ? 'Questions sur les médicaments, les hôpitaux\nprès de vous, ou la santé en général.'
                  : 'Ask about medications, nearby hospitals,\nor general health questions.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Color(0xFF5F6368),
              ),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final label in chips)
                  ActionChip(
                    label: Text(label),
                    labelStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: kNaviTeal,
                    ),
                    backgroundColor: Colors.white,
                    side: const BorderSide(color: kNaviTeal),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () => onSuggestion(label),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
