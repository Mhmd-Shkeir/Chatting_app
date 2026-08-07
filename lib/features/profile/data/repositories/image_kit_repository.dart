import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../../../core/config/imagekit_config.dart';

class ImageKitRepository {
  ImageKitRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Uploads [file] to ImageKit and returns the resulting CDN URL.
  ///
  /// ImageKit requires a signature/token/expire triple generated with the
  /// account's private key for every client-side upload — there's no
  /// unsigned mode like Cloudinary's. [imageKitAuthEndpoint] (a small
  /// Cloudflare Worker holding that private key, never this app) is asked
  /// for a fresh one before every upload, since each is only valid for a
  /// short window and meant to be used once.
  ///
  /// [fileName] defaults to a generic timestamped name (profile pictures);
  /// callers with a more specific naming need (e.g. chat images, keyed to
  /// their conversation) can override it instead of relying on the
  /// original, often-generic device filename.
  Future<String> uploadImage(File file, {String? fileName}) async {
    final authResponse =
        await _client.get(Uri.parse(imageKitAuthEndpoint)).timeout(const Duration(seconds: 15));
    if (authResponse.statusCode != 200) {
      throw Exception('Could not authenticate upload (${authResponse.statusCode})');
    }
    final auth = jsonDecode(authResponse.body) as Map<String, dynamic>;

    final uploadUri = Uri.parse('https://upload.imagekit.io/api/v1/files/upload');
    final request = http.MultipartRequest('POST', uploadUri)
      ..fields['publicKey'] = imageKitPublicKey
      ..fields['signature'] = auth['signature'] as String
      ..fields['expire'] = auth['expire'].toString()
      ..fields['token'] = auth['token'] as String
      ..fields['fileName'] = fileName ?? 'lumina_${DateTime.now().millisecondsSinceEpoch}.jpg'
      ..files.add(await http.MultipartFile.fromPath('file', file.path));

    final streamedResponse = await _client.send(request).timeout(const Duration(seconds: 30));
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode != 200) {
      throw Exception('Image upload failed (${response.statusCode}): ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    return data['url'] as String;
  }
}
