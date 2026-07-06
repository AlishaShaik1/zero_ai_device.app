import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/constants.dart';
import '../models/search_result.dart';

/// Singleton service that handles web search
/// via the Zero Search Gateway (hosted on Render).
///
/// SEARCH FLOW:
///   [search(query)] → POST /search with X-API-Key from AppConfig
///   → returns List<SearchResult>
///   → Caller formats answer as short TTS string + sends to ring OLED.
class SearchGatewayService {
  SearchGatewayService._();

  // ─── Singleton ────────────────────────────────────────────────────────────
  static final SearchGatewayService instance = SearchGatewayService._();

  // ─── Config ───────────────────────────────────────────────────────────────
  static const Duration _timeout = Duration(seconds: 8);
  static const String _searchPath = '/search';

  // ─── Public API ───────────────────────────────────────────────────────────

  /// Call once at app start
  Future<void> init() async {
    debugPrint('SearchGateway: init() done using configured API key.');
  }

  /// Fetch search results for [query] from the gateway.
  /// Returns an empty list on any error or timeout — never throws.
  Future<List<SearchResult>> search(String query) async {
    try {
      final uri = Uri.parse('${AppConfig.searchGatewayUrl}$_searchPath');
      final response = await http.post(
        uri,
        headers: {
          'X-API-Key': AppConfig.searchGatewayApiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'q': query}),
      ).timeout(_timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] as List<dynamic>? ?? [];
        return results
            .whereType<Map<String, dynamic>>()
            .map((r) => SearchResult.fromJson(r))
            .toList();
      } else {
        debugPrint('SearchGateway: search HTTP ${response.statusCode}');
        return [];
      }
    } catch (e) {
      debugPrint('SearchGateway: search() error — $e');
      return [];
    }
  }
}
