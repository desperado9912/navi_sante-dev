import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../core/utils/language_cubit/language_cubit.dart';
import '../features/home/viewmodel/map_cubit.dart';
import '../features/hospitals/viewmodels/facility_bloc.dart';
import '../features/hospitals/data/facility_repository.dart';
import '../features/pharmacy/viewmodels/pharmacy_bloc.dart';
import '../features/pharmacy/data/medication_repository.dart';
import '../features/ai_chat/viewmodel/ai_chat_bloc.dart';
import '../features/ai_chat/models/ai_chat_api.dart';
import '../features/ai_chat/models/ai_chat_local.dart';
import '../features/ai_chat/models/ai_chat_tools.dart';
import '../features/ai_chat/widgets/ai_chat_style.dart';
import '../features/ai_chat/widgets/chat_composer.dart';
import '../features/ai_chat/widgets/chat_empty_state.dart';
import '../features/ai_chat/widgets/chat_history_sheet.dart';
import '../features/ai_chat/widgets/chat_message_bubble.dart';
import '../features/ai_chat/widgets/navi_ai_app_bar.dart';

class AIChatPage extends StatelessWidget {
  const AIChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AiChatBloc(
        api: AiChatApi(),
        local: AiChatLocal(),
        tools: () {
          final map = context.read<MapCubit>().state;
          final fac = context.read<FacilityBloc>().state;
          final pharm = context.read<PharmacyBloc>().state;
          final loc = map.userLocation ?? map.center;
          var lang = 'en';
          try {
            if (!context.read<LanguageCubit>().state.isEnglish) lang = 'fr';
          } catch (_) {}
          return AiChatTools(
            facilities: context.read<FacilityRepository>(),
            medicationRepo: context.read<MedicationRepository>(),
            medications: pharm.medications,
            lat: loc.latitude,
            lng: loc.longitude,
            bookmarkCount: fac.bookmarkedIds.length,
            bookmarkNames: fac.savedFacilities
                .take(6)
                .map((f) => f.name)
                .toList(),
            language: lang,
          );
        },
      )..add(AiChatStarted()),
      child: const _AiChatView(),
    );
  }
}

class _AiChatView extends StatefulWidget {
  const _AiChatView();

  @override
  State<_AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<_AiChatView> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    final pharmacy = context.read<PharmacyBloc>();
    if (pharmacy.state.medications.isEmpty) {
      pharmacy.add(LoadMedications());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _send([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;
    _controller.clear();
    _focus.unfocus();
    context.read<AiChatBloc>().add(AiChatSendMessage(text));
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kNaviChatBg,
      appBar: NaviAiAppBar(onHistoryTap: () => showChatHistorySheet(context)),
      body: Column(
        children: [
          Expanded(
            child: BlocConsumer<AiChatBloc, AiChatState>(
              listenWhen: (prev, curr) =>
                  prev.messages.length != curr.messages.length ||
                  prev.sendingId != curr.sendingId,
              listener: (_, _) => _scrollToEnd(),
              builder: (context, state) {
                final messages = state.messages;
                final showTyping =
                    state.sending && state.activeId == state.sendingId;
                if (messages.isEmpty && !showTyping) {
                  return ChatEmptyState(onSuggestion: _send);
                }
                return ListView.builder(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  itemCount: messages.length + (showTyping ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= messages.length) {
                      return const ChatTypingDots();
                    }
                    return ChatMessageBubble(
                      message: messages[index],
                      showRetry:
                          messages[index].isError &&
                          index == messages.length - 1 &&
                          !state.sending,
                    );
                  },
                );
              },
            ),
          ),
          BlocBuilder<AiChatBloc, AiChatState>(
            buildWhen: (prev, curr) => prev.sendingId != curr.sendingId,
            builder: (context, state) {
              return ChatComposer(
                controller: _controller,
                focus: _focus,
                enabled: !state.sending,
                onSend: _send,
              );
            },
          ),
        ],
      ),
    );
  }
}
