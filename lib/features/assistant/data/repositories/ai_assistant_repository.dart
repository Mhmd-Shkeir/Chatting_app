import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/translation_config.dart';
import '../models/assistant_message.dart';

class AiAssistantRepository {
  AiAssistantRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Sends the whole conversation so far to the same Gemini-backed
  /// Cloudflare Worker used for translation (see [geminiTranslateEndpoint]),
  /// and returns the assistant's reply text. The Worker tells this request
  /// apart from a translation request by its shape (`messages` array vs
  /// `text`/`targetLanguage`), so context (follow-up questions) is just
  /// "send the history every time" — the Worker itself is stateless.
  Future<String> sendMessage(List<AssistantMessage> history) async {
    final response = await _client
        .post(
          Uri.parse(geminiTranslateEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'messages': [
              for (final message in history)
                {
                  'role': message.role == AssistantRole.assistant ? 'assistant' : 'user',
                  'text': message.text,
                },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Assistant request failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['reply'] as String;
  }
}
