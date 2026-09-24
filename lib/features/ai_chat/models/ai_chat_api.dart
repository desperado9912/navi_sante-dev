import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'ai_chat_models.dart';

class AiChatApi {
  AiChatApi({Dio? dio}) : _dio = dio ?? _createDio();


  /// Shared client so TLS / keep-alive survive across chat opens.
  static final AiChatApi shared = AiChatApi();

  final Dio _dio;
  DateTime? _lastWarm;
  Future<void>? _inFlightWarm;

  static Dio _createDio() {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 26),
        persistentConnection: true,
        followRedirects: true,
        validateStatus: (code) => code != null && code < 600,
      ),
    );
    final adapter = dio.httpClientAdapter;
    if (adapter is IOHttpClientAdapter) {
      adapter.createHttpClient = () {
        final client = HttpClient();
        client.idleTimeout = const Duration(seconds: 8);
        return client;
      };
    }
    return dio;
  }

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

  Map<String, String> _headers() {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Gateway-Secret': dotenv.env['AI_GATEWAY_SECRET'] ?? '',
    };
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) headers['X-User-Id'] = userId;
    return headers;
  }

  /// Hits GET /health so Render is awake before the first chat token.
  Future<void> warmup({bool force = false}) {
    if (!_validBase) return Future.value();
    final now = DateTime.now();
    if (!force &&
        _lastWarm != null &&
        now.difference(_lastWarm!) < const Duration(minutes: 3)) {
      return Future.value();
    }
    return _inFlightWarm ??= _warmupOnce();
  }

  Future<void> _warmupOnce() async {
    try {
      await _dio.get<dynamic>(
        '$_base/health',
        options: Options(
          headers: _headers(),
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );
      _lastWarm = DateTime.now();
    } catch (e) {
      debugPrint('[Navi AI] warmup: $e');
    } finally {
      _inFlightWarm = null;
    }
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

    DioException? last;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (attempt > 0) {
          // A background timer already re-warms the gateway every few
          // minutes, so the instance is almost never actually cold here.
          // Forcing another /health round trip before every retry used to
          // add several extra seconds on top of the retry itself — a short
          // backoff is enough.
          await Future<void>.delayed(const Duration(milliseconds: 300));
        }
        final response = await _dio.post<dynamic>(
          '$_base/v1/chat',
          data: payload,
          options: Options(headers: _headers()),
        );
        final code = response.statusCode ?? 0;
        if (code == 401 || code == 429 || code == 503) {
          return _fromDio(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            language,
          );
        }
        if (code >= 500) {
          if (attempt == 0) continue;
          return _fromDio(
            DioException(
              requestOptions: response.requestOptions,
              response: response,
              type: DioExceptionType.badResponse,
            ),
            language,
          );
        }
        return _parse(response.data, language);
      } on DioException catch (e) {
        last = e;
        final parsed = _gatewayBody(e, language);
        if (parsed != null) return parsed;
        if (!_shouldRetry(e) || attempt == 1) {
          return _fromDio(e, language);
        }
      }
    }
    return _fromDio(last, language);
  }
 
  bool _shouldRetry(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403 || code == 429) return false;
    if (e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return false;
    }
    if (code != null && code >= 500) return true;
    return e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown;
  }

  AiGatewayResponse? _gatewayBody(DioException e, String language) {
    final data = e.response?.data;
    if (data == null) return null;
    if (data is Map) {
      final parsed = AiGatewayResponse.fromJson(Map<String, dynamic>.from(data));
      if (parsed.error != null || parsed.text.isNotEmpty || parsed.ok) {
        return parsed;
      }
    }
    return null;
  }

  AiGatewayResponse _fromDio(DioException? e, String language) {
    if (e == null) {
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          "Couldn't reach Navi AI. Check your connection and try again.",
          'Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.',
        ),
      );
    }
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
    if (code == 503) {
      return AiGatewayResponse(
        ok: false,
        error: _copy(
          language,
          'Navi AI is unavailable right now. Please try again later.',
          'Navi AI est indisponible pour le moment. Réessayez plus tard.',
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
