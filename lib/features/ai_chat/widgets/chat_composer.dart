import 'package:flutter/material.dart';
import 'ai_chat_style.dart';

class ChatComposer extends StatelessWidget {
  const ChatComposer({
    super.key,
    required this.controller,
    required this.focus,
    required this.enabled,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 4, 6, 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  enabled: enabled,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 2000,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) {
                    if (enabled) onSend();
                  },
                  decoration: InputDecoration(
                    hintText: t(
                      context,
                      'Ask NaviSanté...',
                      'Demandez à NaviSanté...',
                    ),
                    hintStyle: const TextStyle(
                      color: Color(0xFF9AA0A6),
                      fontSize: 15,
                    ),
                    border: InputBorder.none,
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: enabled ? kNaviTeal : kNaviTeal.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: enabled ? onSend : null,
                  child: const SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.arrow_upward_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
