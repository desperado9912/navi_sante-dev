import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'ai_chat_models.dart';

const String _boxName = 'ai_chat_conversations';
const String _allKey = 'all';
const int _maxConversations = 30;
const int _maxMessages = 40;

class AiChatLocal {
  static Future<void> init() async {
    await Hive.openBox<String>(_boxName);
  }

  List<ChatConversation> loadAll() {
    try {
      final encoded = Hive.box<String>(_boxName).get(_allKey);
      if (encoded == null) return [];
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => ChatConversation.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveAll(List<ChatConversation> conversations) async {
    try {
      final trimmed = conversations.take(_maxConversations).map((c) {
        if (c.messages.length <= _maxMessages) return c;
        return c.copyWith(
          messages: c.messages.sublist(c.messages.length - _maxMessages),
        );
      }).toList();
      await Hive.box<String>(_boxName).put(
        _allKey,
        jsonEncode(trimmed.map((c) => c.toJson()).toList()),
      );
    } catch (_) {}
  }
}
