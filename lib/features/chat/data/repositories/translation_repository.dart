import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../../core/config/translation_config.dart';

class TranslationRepository {
  TranslationRepository({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  /// Translates [text] to the language identified by [targetLanguageCode]
  /// (e.g. 'ar', 'fr') via the Gemini-backed Cloudflare Worker. The Worker
  /// auto-detects the source language, so nothing about the original
  /// message's language needs to be known or stored.
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
  }) async {
    final response = await _client
        .post(
          Uri.parse(geminiTranslateEndpoint),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'text': text,
            'targetLanguage': targetLanguageCode,
          }),
        )
        .timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw Exception(
        'Translation failed (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['translatedText'] as String;
  }
}
