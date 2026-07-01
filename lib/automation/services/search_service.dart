import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Connects to the deployed Zero Search Gateway.
/// Qwen outputs {"type": "search", "query": "..."} when it needs facts,
/// and this service executes that search.
class SearchService {
  static const String _gatewayUrl = 'https://search-server-theta.vercel.app';
  static const String _apiKey = 'zerotech1234';

  /// Search the gateway and return a concise answer.
  /// Returns null on failure (caller should say "couldn't find that").
  Future<SearchResult?> search(String query) async {
    try {
      final response = await http.post(
        Uri.parse('$_gatewayUrl/search'),
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': _apiKey,
        },
        body: json.encode({'q': query}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) {
        if (kDebugMode) debugPrint('Search failed: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      return SearchResult(
        answer: data['answer'] as String? ?? '',
        confidence: (data['answer_confidence'] as num?)?.toDouble() ?? 0.0,
        provider: data['provider_used'] as String? ?? 'unknown',
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Search error: $e');
      return null;
    }
  }
}

class SearchResult {
  final String answer;
  final double confidence;
  final String provider;

  const SearchResult({
    required this.answer,
    required this.confidence,
    required this.provider,
  });
}
