import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../controller/ai_chat_models.dart';

class AiChatApi {
  AiChatApi({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 30),
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 30),
            ),
          );

  final Dio _dio;

  String get _base {
    final raw = dotenv.env['AI_GATEWAY_URL']?.trim() ?? '';
    return raw.endsWith('/') ? raw.substring(0, raw.length - 1) : raw;
  }

  bool get _validBase {
    final uri = Uri.tryParse(_base);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }

  Future<AiGatewayResponse> send({
    required String conversationId,
    required String message,
    required List<ChatMessage> history,
    required double? lat,
    required double? lng,
    required int bookmarkCount,
    required List<String> bookmarkNames,
    String language = 'en',
    List<Map<String, dynamic>>? toolResults,
  }) async {
    if (!_validBase) {
      debugPrint('[Navi AI] AI_GATEWAY_URL missing or invalid in .env');
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          'Navi AI is unavailable right now. Please try again later.',
          'Navi AI est indisponible pour le moment. Réessayez plus tard.',
        ),
      );
    }

    final userId = Supabase.instance.client.auth.currentUser?.id;
    final recent = history
        .where((m) => !m.isError && m.text.isNotEmpty)
        .toList()
        .reversed
        .take(6)
        .toList()
        .reversed
        .map(
          (m) => {
            'role': m.role.name,
            'content': m.text.length > 400 ? m.text.substring(0, 400) : m.text,
          },
        )
        .toList();

    final payload = <String, dynamic>{
      'conversation_id': conversationId,
      'message': message.length > 1200 ? message.substring(0, 1200) : message,
      'history': recent,
      'context': {
        'lat': lat,
        'lng': lng,
        'country': 'Cameroon',
        'language': language,
        'bookmark_count': bookmarkCount,
        'bookmark_names': bookmarkNames.take(6).toList(),
      },
    };
    if (toolResults != null) payload['tool_results'] = toolResults;

    try {
      final headers = <String, String>{
            'Content-Type': 'application/json',
            'X-Gateway-Secret': dotenv.env['AI_GATEWAY_SECRET'] ?? '',
          };
          if (userId != null) headers['X-User-Id'] = userId;
      final response = await _dio.post<dynamic>(
        '$_base/v1/chat',
        data: payload,
        options: Options(headers: headers),
      );
      return _parse(response.data, language);
    } on DioException catch (e) {
      return _fromDio(e, language);
    }
  }

  AiGatewayResponse _fromDio(DioException e, String language) {
    final code = e.response?.statusCode;
    if (code == 401) {
      debugPrint('[Navi AI] gateway secret mismatch');
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          'Navi AI is unavailable right now. Please try again later.',
          'Navi AI est indisponible pour le moment. Réessayez plus tard.',
        ),
      );
    }
    if (code == 429) {
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          'Too many requests. Try again in a minute.',
          'Trop de demandes. Réessayez dans une minute.',
        ),
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          'That took too long. Please try a shorter question.',
          'La réponse a pris trop de temps. Essayez une question plus courte.',
        ),
      );
    }
    return AiGatewayResponse(
      ok: false,
      error: _copy(
        language,
        "Couldn't reach Navi AI. Check your connection and try again.",
        'Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.',
      ),
    );
  }

  AiGatewayResponse _parse(dynamic data, String language) {
    if (data is Map<String, dynamic>) return AiGatewayResponse.fromJson(data);
    if (data is Map) {
      return AiGatewayResponse.fromJson(Map<String, dynamic>.from(data));
    }
    return AiGatewayResponse(
      ok: false,
      error: _copy(
        language,
        "Couldn't reach Navi AI. Check your connection and try again.",
        'Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.',
      ),
    );
  }

  String _copy(String language, String en, String fr) =>
      language == 'fr' ? fr : en;
}
