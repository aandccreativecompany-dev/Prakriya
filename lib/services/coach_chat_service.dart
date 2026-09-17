import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// One turn to send to the coach-chat proxy — deliberately not the full
/// [CoachMessage] model (no `date`), so this file doesn't need to import
/// models.dart just to describe an HTTP request body.
typedef CoachTurn = ({String role, String content});

/// Talks to the `coach-chat` Netlify Function that fronts the Anthropic API
/// — never calls api.anthropic.com directly, since an API key shipped
/// inside the app could be extracted from the APK. See
/// netlify/functions/coach-chat.js in the website repo for the server side
/// and SETUP_COACH_CHAT.md for one-time setup.
///
/// Dependency-free (plain `dart:io`/`dart:convert`, same choice
/// update_checker.dart made) — one JSON POST doesn't need a whole `http`
/// package pulled in.
class CoachChatService {
  CoachChatService._();
  static final CoachChatService instance = CoachChatService._();

  static const _endpoint =
      'https://aandccreativeventures.netlify.app/.netlify/functions/coach-chat';

  /// Sends the conversation so far (already trimmed to a reasonable window
  /// by the caller) and returns the coach's reply text. Throws on any
  /// network/server failure — the caller (Store.sendCoachMessage) turns
  /// that into a friendly in-app message rather than letting it propagate.
  Future<String> send(List<CoachTurn> messages) async {
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 15);
      final request = await client.postUrl(Uri.parse(_endpoint));
      request.headers.set('content-type', 'application/json');
      request.add(utf8.encode(jsonEncode({
        'messages': [
          for (final m in messages) {'role': m.role, 'content': m.content},
        ],
      })));
      final response = await request.close().timeout(const Duration(seconds: 25));
      final body = await response.transform(utf8.decoder).join();

      if (response.statusCode != 200) {
        throw Exception('coach-chat request failed: ${response.statusCode} $body');
      }
      final decoded = jsonDecode(body);
      final reply = decoded is Map<String, dynamic> ? decoded['reply'] : null;
      if (reply is! String || reply.trim().isEmpty) {
        throw Exception('coach-chat returned an empty reply');
      }
      return reply.trim();
    } finally {
      client?.close(force: true);
    }
  }
}
