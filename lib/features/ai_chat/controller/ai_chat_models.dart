import 'package:equatable/equatable.dart';
import '../../hospitals/controller/facility_model.dart';
import '../../pharmacy/controller/pharmacy_model.dart';

enum ChatRole { user, assistant }

class ChatMessage extends Equatable {
  final String id;
  final ChatRole role;
  final String text;
  final int createdAt;
  final List<FacilityModel> facilities;
  final List<MedicationModel> medications;
  final bool isError;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.createdAt,
    this.facilities = const [],
    this.medications = const [],
    this.isError = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'text': text,
    'created_at': createdAt,
    'facilities': facilities.map((f) => f.toJson()).toList(),
    'medications': medications.map((m) => m.toJson()).toList(),
    'is_error': isError,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      role: (json['role'] as String) == 'user'
          ? ChatRole.user
          : ChatRole.assistant,
      text: json['text'] as String? ?? '',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      facilities: _maps(json['facilities']).map(FacilityModel.fromJson).toList(),
      medications: _maps(
        json['medications'],
      ).map(MedicationModel.fromJson).toList(),
      isError: json['is_error'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [
    id,
    role,
    text,
    createdAt,
    facilities,
    medications,
    isError,
  ];
}

class ChatConversation extends Equatable {
  final String id;
  final String title;
  final int createdAt;
  final int updatedAt;
  final List<ChatMessage> messages;

  const ChatConversation({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    this.messages = const [],
  });

  ChatConversation copyWith({
    String? title,
    int? updatedAt,
    List<ChatMessage>? messages,
  }) {
    return ChatConversation(
      id: id,
      title: title ?? this.title,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      messages: messages ?? this.messages,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'created_at': createdAt,
    'updated_at': updatedAt,
    'messages': messages.map((m) => m.toJson()).toList(),
  };

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'New chat',
      createdAt: (json['created_at'] as num?)?.toInt() ?? 0,
      updatedAt: (json['updated_at'] as num?)?.toInt() ?? 0,
      messages: _maps(json['messages']).map(ChatMessage.fromJson).toList(),
    );
  }

  @override
  List<Object?> get props => [id, title, createdAt, updatedAt, messages];
}

class AiToolCall {
  final String id;
  final String name;
  final String arguments;

  const AiToolCall({
    required this.id,
    required this.name,
    required this.arguments,
  });

  factory AiToolCall.fromJson(Map<String, dynamic> json) {
    return AiToolCall(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      arguments: json['arguments'] as String? ?? '{}',
    );
  }
}

class AiGatewayResponse {
  final bool ok;
  final String text;
  final List<String> facilityIds;
  final List<String> medicationIds;
  final List<AiToolCall>? toolCalls;
  final String? error;

  const AiGatewayResponse({
    required this.ok,
    this.text = '',
    this.facilityIds = const [],
    this.medicationIds = const [],
    this.toolCalls,
    this.error,
  });

  factory AiGatewayResponse.fromJson(Map<String, dynamic> json) {
    final rawCalls = json['tool_calls'];
    return AiGatewayResponse(
      ok: json['ok'] as bool? ?? false,
      text: json['text'] as String? ?? '',
      facilityIds: (json['facility_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      medicationIds: (json['medication_ids'] as List<dynamic>? ?? [])
          .map((e) => e.toString())
          .toList(),
      toolCalls: rawCalls is List
          ? _maps(rawCalls).map(AiToolCall.fromJson).toList()
          : null,
      error: json['error'] as String?,
    );
  }
}

List<Map<String, dynamic>> _maps(dynamic raw) {
  if (raw is! List) return const [];
  return raw
      .whereType<Map>()
      .map((e) => Map<String, dynamic>.from(e))
      .toList();
}
