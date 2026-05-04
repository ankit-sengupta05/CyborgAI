// lib/services/llm_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/models.dart';

class LLMService {
  final LLMConfig config;

  LLMService(this.config);

  // ── Core completion ──────────────────────────────────────────────────────────

  Future<String> complete(String prompt, {String? system, int maxTokens = 2000}) async {
    if (config.mode == 'local') {
      return _localComplete(prompt, system: system, maxTokens: maxTokens);
    } else {
      return _apiComplete(prompt, system: system, maxTokens: maxTokens);
    }
  }

  Stream<String> streamComplete(String prompt, {String? system, int maxTokens = 2000}) async* {
    final isCyborg = config.baseUrl.contains(':8765') || config.modelName == 'cyborg-llm';

    if (config.mode == 'local') {
      yield* _localStream(prompt, system: system, maxTokens: maxTokens);
    } else {
      yield* _apiStream(prompt, system: system, maxTokens: maxTokens);
    }
  }

  // ── OpenAI-compatible API (remote or Ollama/LMStudio) ───────────────────────

  Future<String> _apiComplete(String prompt, {String? system, int maxTokens = 2000}) async {
    final messages = [
      if (system != null) {'role': 'system', 'content': system},
      {'role': 'user', 'content': prompt},
    ];

    final isCyborg = config.baseUrl.contains(':8765') || config.modelName == 'cyborg-llm';
    final endpoint = isCyborg ? '${config.baseUrl}/chat/' : '${config.baseUrl}/chat/completions';

    final response = await http.post(
      Uri.parse(endpoint),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${config.apiKey}',
      },
      body: jsonEncode({
        'model': config.modelName,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': config.temperature,
      }),
    ).timeout(const Duration(seconds: 120));

    if (response.statusCode != 200) {
      throw Exception('API error ${response.statusCode}: ${response.body}');
    }

    final data = jsonDecode(response.body);
    // Support both OpenAI format and Cyborg native format
    if (data['choices'] != null && data['choices'] is List && data['choices'].isNotEmpty) {
      return data['choices'][0]['message']['content'] as String;
    } else if (data['message'] != null) {
      return data['message'] as String;
    }
    return response.body;
  }

  Stream<String> _apiStream(String prompt, {String? system, int maxTokens = 2000}) async* {
    final messages = [
      if (system != null) {'role': 'system', 'content': system},
      {'role': 'user', 'content': prompt},
    ];

    final isCyborg = config.baseUrl.contains(':8765') || config.modelName == 'cyborg-llm';
    final endpoint = isCyborg ? '${config.baseUrl}/chat/' : '${config.baseUrl}/chat/completions';
    final request = http.Request('POST', Uri.parse(endpoint));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${config.apiKey}';
    request.body = jsonEncode({
      'model': config.modelName,
      'messages': messages,
      'max_tokens': maxTokens,
      'temperature': config.temperature,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request).timeout(const Duration(seconds: 120));
      await for (final line in streamedResponse.stream.transform(utf8.decoder).transform(const LineSplitter())) {
        if (line.startsWith('data: ') && line != 'data: [DONE]') {
          try {
            final data = jsonDecode(line.substring(6));
            // Handle OpenAI format
            if (data['choices'] != null) {
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null && content is String && content.isNotEmpty) {
                yield content;
              }
            }
            // Handle Cyborg token format (if any, though Cyborg mainly uses WebSockets for streaming)
            else if (data['token'] != null) {
              yield data['token'] as String;
            }
          } catch (_) {}
        }
      }
    } finally {
      client.close();
    }
  }

  // ── Local GGUF via llama.cpp server or Ollama ─────────────────────────────────
  // Supports LM Studio (localhost:1234), Ollama (localhost:11434), llama.cpp server

  Future<String> _localComplete(String prompt, {String? system, int maxTokens = 2000}) async {
    // Try llama.cpp server first, then Ollama
    final endpoints = [
      '${config.localModelPath}/v1/chat/completions',  // llama.cpp server
      'http://localhost:1234/v1/chat/completions',     // LM Studio (default)
      'http://localhost:11434/v1/chat/completions',    // Ollama
    ];

    for (final endpoint in endpoints) {
      try {
        final messages = [
          if (system != null) {'role': 'system', 'content': system},
          {'role': 'user', 'content': prompt},
        ];
        final response = await http.post(
          Uri.parse(endpoint),
          headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer local'},
          body: jsonEncode({
            'model': config.modelName,
            'messages': messages,
            'max_tokens': maxTokens,
            'temperature': config.temperature,
          }),
        ).timeout(const Duration(seconds: 180));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'] as String;
        }
      } catch (_) {
        continue;
      }
    }
    throw Exception('No local LLM endpoint available. Please start llama.cpp server, Ollama, or LM Studio.');
  }

  Stream<String> _localStream(String prompt, {String? system, int maxTokens = 2000}) async* {
    // Try Ollama streaming
    try {
      final request = http.Request('POST', Uri.parse('http://localhost:1234/v1/chat/completions'));
      request.headers['Content-Type'] = 'application/json';
      request.headers['Authorization'] = 'Bearer local';
      final messages = [
        if (system != null) {'role': 'system', 'content': system},
        {'role': 'user', 'content': prompt},
      ];
      request.body = jsonEncode({
        'model': config.modelName,
        'messages': messages,
        'max_tokens': maxTokens,
        'temperature': config.temperature,
        'stream': true,
      });

      final client = http.Client();
      try {
        final response = await client.send(request).timeout(const Duration(seconds: 180));
        await for (final line in response.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('data: ') && line != 'data: [DONE]') {
            try {
              final data = jsonDecode(line.substring(6));
              final content = data['choices']?[0]?['delta']?['content'];
              if (content != null && content is String) yield content;
            } catch (_) {}
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      // Fall back to non-streaming
      final result = await _localComplete(prompt, system: system, maxTokens: maxTokens);
      yield result;
    }
  }

  // ── Structured outputs ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> completeJson(String prompt, {String? system}) async {
    final result = await complete(
      '$prompt\n\nRespond ONLY with valid JSON, no markdown, no explanation.',
      system: system,
    );
    // Strip possible ```json fences
    final clean = result.replaceAll(RegExp(r'```json\s*|```\s*'), '').trim();
    return jsonDecode(clean) as Map<String, dynamic>;
  }
}
