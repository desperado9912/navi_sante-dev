import 'dart:convert';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../hospitals/data/facility_model.dart';
import '../../pharmacy/data/pharmacy_model.dart';
import '../models/ai_chat_api.dart';
import '../models/ai_chat_local.dart';
import '../models/ai_chat_tools.dart';
import '../models/ai_chat_models.dart';

abstract class AiChatEvent {}

class AiChatStarted extends AiChatEvent {}

class AiChatNewConversation extends AiChatEvent {}

class AiChatOpenConversation extends AiChatEvent {
  final String id;
  AiChatOpenConversation(this.id);
}

class AiChatDeleteConversation extends AiChatEvent {
  final String id;
  AiChatDeleteConversation(this.id);
}

class AiChatSendMessage extends AiChatEvent {
  final String text;
  AiChatSendMessage(this.text);
}

class AiChatRetryLast extends AiChatEvent {}

class AiChatState extends Equatable {
  final List<ChatConversation> conversations;
  final String? activeId;
  final String? sendingId;
  final String? errorMessage;

  const AiChatState({
    this.conversations = const [],
    this.activeId,
    this.sendingId,
    this.errorMessage,
  });

  bool get sending => sendingId != null;

  ChatConversation? get active {
    if (activeId == null) return null;
    for (final c in conversations) {
      if (c.id == activeId) return c;
    }
    return null;
  }

  List<ChatMessage> get messages => active?.messages ?? const [];

  AiChatState copyWith({
    List<ChatConversation>? conversations,
    Object? activeId = _unset,
    Object? sendingId = _unset,
    Object? errorMessage = _unset,
  }) {
    return AiChatState(
      conversations: conversations ?? this.conversations,
      activeId: identical(activeId, _unset)
          ? this.activeId
          : activeId as String?,
      sendingId: identical(sendingId, _unset)
          ? this.sendingId
          : sendingId as String?,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
    );
  }

  @override
  List<Object?> get props => [conversations, activeId, sendingId, errorMessage];
}

const Object _unset = Object();

class AiChatBloc extends Bloc<AiChatEvent, AiChatState> {
  AiChatBloc({
    required AiChatApi api,
    required AiChatLocal local,
    required AiChatTools Function() tools,
  }) : _api = api,
       _local = local,
       _tools = tools,
       super(const AiChatState()) {
    on<AiChatStarted>(_onStarted);
    on<AiChatNewConversation>(_onNew);
    on<AiChatOpenConversation>(_onOpen);
    on<AiChatDeleteConversation>(_onDelete);
    on<AiChatSendMessage>(_onSend, transformer: droppable());
    on<AiChatRetryLast>(_onRetry, transformer: droppable());
  }

  final AiChatApi _api;
  final AiChatLocal _local;
  final AiChatTools Function() _tools;

  String _id() => DateTime.now().microsecondsSinceEpoch.toString();

  String _titleFrom(String text) {
    final t = text.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (t.isEmpty) return 'New chat';
    return t.length > 42 ? '${t.substring(0, 42)}…' : t;
  }

  Future<void> _onStarted(
    AiChatStarted event,
    Emitter<AiChatState> emit,
  ) async {
    emit(state.copyWith(conversations: _local.loadAll(), activeId: null));
  }

  Future<void> _onNew(
    AiChatNewConversation event,
    Emitter<AiChatState> emit,
  ) async {
    emit(state.copyWith(activeId: null, errorMessage: null));
  }

  Future<void> _onOpen(
    AiChatOpenConversation event,
    Emitter<AiChatState> emit,
  ) async {
    emit(state.copyWith(activeId: event.id, errorMessage: null));
  }

  Future<void> _onDelete(
    AiChatDeleteConversation event,
    Emitter<AiChatState> emit,
  ) async {
    final next = state.conversations.where((c) => c.id != event.id).toList();
    await _local.saveAll(next);
    if (emit.isDone) return;
    emit(
      state.copyWith(
        conversations: next,
        activeId: state.activeId == event.id ? null : state.activeId,
      ),
    );
  }

  Future<void> _onSend(
    AiChatSendMessage event,
    Emitter<AiChatState> emit,
  ) async {
    final text = event.text.trim();
    if (text.isEmpty || state.sending) return;

    var convId = state.activeId;
    var conversations = List<ChatConversation>.from(state.conversations);
    if (convId == null) {
      convId = _id();
      conversations.insert(
        0,
        ChatConversation(
          id: convId,
          title: _titleFrom(text),
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    final userMsg = ChatMessage(
      id: _id(),
      role: ChatRole.user,
      text: text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    conversations = _append(conversations, convId, userMsg, titleIfEmpty: text);
    emit(
      state.copyWith(
        conversations: conversations,
        activeId: convId,
        sendingId: convId,
        errorMessage: null,
      ),
    );
    await _local.saveAll(conversations);
    if (emit.isDone) return;

    final history = conversations
        .firstWhere((c) => c.id == convId)
        .messages
        .where((m) => m.id != userMsg.id)
        .toList();
    await _complete(emit, convId, text, history);
  }

  Future<void> _onRetry(
    AiChatRetryLast event,
    Emitter<AiChatState> emit,
  ) async {
    if (state.sending || state.activeId == null) return;
    final convId = state.activeId!;
    var conversations = List<ChatConversation>.from(state.conversations);
    final conv = conversations.firstWhere((c) => c.id == convId);
    var msgs = List<ChatMessage>.from(conv.messages);
    while (msgs.isNotEmpty && msgs.last.isError) {
      msgs.removeLast();
    }
    ChatMessage? lastUser;
    for (final m in msgs.reversed) {
      if (m.role == ChatRole.user) {
        lastUser = m;
        break;
      }
    }
    if (lastUser == null) return;

    conversations = conversations
        .map((c) => c.id == convId ? c.copyWith(messages: msgs) : c)
        .toList();
    emit(
      state.copyWith(
        conversations: conversations,
        sendingId: convId,
        errorMessage: null,
      ),
    );
    await _local.saveAll(conversations);
    if (emit.isDone) return;

    final history = msgs.where((m) => m.id != lastUser!.id).toList();
    await _complete(emit, convId, lastUser.text, history);
  }

  Future<void> _complete(
    Emitter<AiChatState> emit,
    String convId,
    String text,
    List<ChatMessage> history,
  ) async {
    final tools = _tools();
    final lang = tools.language;
    try {
      var response = await _api.send(
        conversationId: convId,
        message: text,
        history: history,
        lat: tools.lat,
        lng: tools.lng,
        bookmarkCount: tools.bookmarkCount,
        bookmarkNames: tools.bookmarkNames,
        language: lang,
      );

      var rounds = 0;
      while (response.ok &&
          response.toolCalls != null &&
          response.toolCalls!.isNotEmpty &&
          rounds < 2) {
        final results = <Map<String, dynamic>>[];
        for (final call in response.toolCalls!.take(2)) {
          final content = await tools.run(call);
          results.add({
            'tool_call_id': call.id,
            'name': call.name,
            'arguments': call.arguments,
            'content': jsonEncode(content),
          });
        }
        rounds += 1;
        response = await _api.send(
          conversationId: convId,
          message: text,
          history: history,
          lat: tools.lat,
          lng: tools.lng,
          bookmarkCount: tools.bookmarkCount,
          bookmarkNames: tools.bookmarkNames,
          language: lang,
          toolResults: results,
        );
      }

      if (emit.isDone) return;

      final fallback = lang == 'fr'
          ? 'Je peux vous aider avec les établissements NaviSanté, les médicaments et des questions de santé générales.'
          : 'I can help with NaviSanté facilities, medications, and general health questions.';
      final errFallback = lang == 'fr'
          ? 'Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.'
          : "Couldn't reach Navi AI. Check your connection and try again.";

      final assistant = ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: response.ok
            ? (response.text.isEmpty ? fallback : response.text)
            : (response.error ?? errFallback),
        createdAt: DateTime.now().millisecondsSinceEpoch,
        facilities: _resolveFacilities(tools, response.facilityIds),
        medications: _resolveMedications(tools, response.medicationIds),
        isError: !response.ok,
      );
      final conversations = _append(state.conversations, convId, assistant);
      emit(state.copyWith(conversations: conversations, sendingId: null));
      await _local.saveAll(conversations);
    } catch (_) {
      if (emit.isDone) return;
      final err = ChatMessage(
        id: _id(),
        role: ChatRole.assistant,
        text: lang == 'fr'
            ? 'Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.'
            : "Couldn't reach Navi AI. Check your connection and try again.",
        createdAt: DateTime.now().millisecondsSinceEpoch,
        isError: true,
      );
      final conversations = _append(state.conversations, convId, err);
      emit(state.copyWith(conversations: conversations, sendingId: null));
      await _local.saveAll(conversations);
    }
  }

  List<FacilityModel> _resolveFacilities(AiChatTools tools, List<String> ids) {
    final out = <FacilityModel>[];
    for (final id in ids.take(3)) {
      final f = tools.facilityById(id);
      if (f != null) out.add(f);
    }
    return out;
  }

  List<MedicationModel> _resolveMedications(
    AiChatTools tools,
    List<String> ids,
  ) {
    final out = <MedicationModel>[];
    for (final id in ids.take(3)) {
      final m = tools.medicationById(id);
      if (m != null) out.add(m);
    }
    return out;
  }

  List<ChatConversation> _append(
    List<ChatConversation> source,
    String convId,
    ChatMessage message, {
    String? titleIfEmpty,
  }) {
    return source.map((c) {
      if (c.id != convId) return c;
      final title = (c.messages.isEmpty && titleIfEmpty != null)
          ? _titleFrom(titleIfEmpty)
          : c.title;
      return c.copyWith(
        title: title,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        messages: [...c.messages, message],
      );
    }).toList();
  }
}
