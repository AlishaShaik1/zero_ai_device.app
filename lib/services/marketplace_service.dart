import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../automation/models/connector_def.dart';

/// Central service for the remote connector marketplace.
/// - Fetches connector catalog from Vercel with 5-min caching
/// - Tracks user connection states in Supabase (via Vercel API)
/// - Kicks off OAuth flows via a deep link
/// - Loads per-connector skill prompts for Gemma (one at a time)
/// - Executes connector actions via /api/execute
class MarketplaceService extends ChangeNotifier {
  static final MarketplaceService _instance = MarketplaceService._();
  static MarketplaceService get instance => _instance;
  MarketplaceService._();

  // ── Vercel marketplace URL ───────────────────────────────────────────────
  static const String _baseUrl = 'https://zero-connector-marketplace.vercel.app';
  // ────────────────────────────────────────────────────────────────────────

  // Per-device user ID — populated on first launch / login
  String _userId = 'local_user_v1';
  void setUserId(String id) { _userId = id; }

  List<ConnectorDef> _catalog = [];
  final Map<String, String> _authStates = {};   // connectorId → authStatus
  bool _isLoading = false;
  String? _error;

  // ── 5-minute catalog cache (avoids refetch on every tab switch) ──────────
  DateTime? _lastFetch;
  String? _lastQuery;
  String? _lastCategory;
  static const _cacheTtl = Duration(minutes: 5);

  // ── Gemma skill prompt cache (connectorId → prompt text) ─────────────────
  final Map<String, String> _skillCache = {};

  List<ConnectorDef> get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String authStatusFor(String connectorId) =>
      _authStates[connectorId] ?? 'notConnected';

  // ── LOAD CATALOG ──────────────────────────────────────────────────────────
  // Skips fetch if cache is fresh and params haven't changed.

  Future<void> loadCatalog({String? query, String? category, bool forceRefresh = false}) async {
    final now = DateTime.now();
    final cacheHit = !forceRefresh &&
        _lastFetch != null &&
        now.difference(_lastFetch!) < _cacheTtl &&
        _lastQuery == (query ?? '') &&
        _lastCategory == (category ?? '');

    if (cacheHit && _catalog.isNotEmpty) return; // serve from cache silently

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = <String, String>{
        'user_id': _userId,
        if (query != null && query.isNotEmpty) 'query': query,
        if (category != null) 'category': category,
      };
      final uri = Uri.parse('$_baseUrl/api/connectors')
          .replace(queryParameters: params);

      final res = await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

      // ✅ API returns { data: [...], total, limit, offset } — unwrap correctly
      final body = json.decode(res.body) as Map<String, dynamic>;
      final List<dynamic> data = body['data'] as List<dynamic>? ?? [];

      _catalog = data.map((j) => _parseConnector(j as Map<String, dynamic>)).toList();

      // Merge auth states into local map
      for (final j in data) {
        final m = j as Map<String, dynamic>;
        final id = m['connector_id'] as String;
        _authStates[id] = m['auth_status'] as String? ?? 'notConnected';
      }

      // Update cache stamp
      _lastFetch = now;
      _lastQuery = query ?? '';
      _lastCategory = category ?? '';
    } catch (e) {
      _error = 'Could not load connectors. Check your connection.';
      if (kDebugMode) debugPrint('MarketplaceService.loadCatalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── FETCH SINGLE CONNECTOR (full prompt for Gemma) ───────────────────────
  // Uses /api/connector/<id> endpoint for a detailed single-connector view.

  Future<ConnectorDef?> fetchConnector(String connectorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/connector/$connectorId')
          .replace(queryParameters: {'user_id': _userId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return _parseConnector(json.decode(res.body) as Map<String, dynamic>);
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.fetchConnector: $e');
      return null;
    }
  }

  // ── FETCH GEMMA SKILL PROMPT ─────────────────────────────────────────────
  // Loads a single focused skill prompt via /api/skill?id=<id>.
  // Cached in memory — Gemma only needs to load each skill once per session.

  Future<String?> fetchSkillPrompt(String connectorId) async {
    if (_skillCache.containsKey(connectorId)) return _skillCache[connectorId];
    try {
      final uri = Uri.parse('$_baseUrl/api/skill')
          .replace(queryParameters: {'id': connectorId, 'user_id': _userId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final body = json.decode(res.body) as Map<String, dynamic>;
      final prompt = body['skill_prompt'] as String?;
      if (prompt != null) _skillCache[connectorId] = prompt;
      return prompt;
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.fetchSkillPrompt[$connectorId]: $e');
      return null;
    }
  }

  // ── EXECUTE CONNECTOR ACTION ─────────────────────────────────────────────
  // Called by Gemma after deciding which connector + action to use.
  // Returns parsed result or throws a user-friendly error string.

  Future<Map<String, dynamic>> executeAction({
    required String connectorId,
    required String action,
    Map<String, dynamic> params = const {},
  }) async {
    final res = await http.post(
      Uri.parse('$_baseUrl/api/execute'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': _userId,
        'connector_id': connectorId,
        'action': action,
        'params': params,
      }),
    ).timeout(const Duration(seconds: 35));

    final body = json.decode(res.body) as Map<String, dynamic>;
    if (res.statusCode == 200 && body['success'] == true) return body['result'] as Map<String, dynamic>? ?? {};
    throw Exception(body['message'] ?? body['error'] ?? 'Execute failed (${res.statusCode})');
  }

  // ── OAUTH FLOW ───────────────────────────────────────────────────────────

  String buildOAuthStartUrl(String connectorId) =>
      '$_baseUrl/api/oauth/start?connector_id=$connectorId&user_id=$_userId';

  Future<void> onOAuthSuccess(String connectorId) async {
    _authStates[connectorId] = 'connected';
    _skillCache.remove(connectorId); // invalidate so prompt is re-fetched with READY status
    notifyListeners();
  }

  // ── DISCONNECT ───────────────────────────────────────────────────────────

  Future<void> disconnect(String connectorId) async {
    try {
      await http.delete(
        Uri.parse('$_baseUrl/api/user-connections')
            .replace(queryParameters: {'connector_id': connectorId, 'user_id': _userId}),
        headers: {'Content-Type': 'application/json'},
      );
      _authStates[connectorId] = 'notConnected';
      _skillCache.remove(connectorId);
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.disconnect: $e');
    }
  }

  // ── PARSE ────────────────────────────────────────────────────────────────

  ConnectorDef _parseConnector(Map<String, dynamic> j) {
    // auth_flow field: 'oauth2_pkce' | 'apiKey' | 'none'
    final authFlowStr = j['auth_flow'] as String? ?? 'oauth2_pkce';
    final ConnectorType type;
    if (authFlowStr == 'apiKey') {
      type = ConnectorType.apiKey;
    } else if (authFlowStr == 'none') {
      type = ConnectorType.deepLinkOnly;
    } else {
      type = ConnectorType.apiOauth;
    }

    final feasStr = j['feasibility'] as String? ?? 'selfServe';
    final feasibility = FeasibilityTier.values.firstWhere(
      (e) => e.name == feasStr,
      orElse: () => FeasibilityTier.selfServe,
    );
    final catStr = j['category'] as String? ?? 'utilities';
    final category = ConnectorCategory.values.firstWhere(
      (e) => e.name == catStr,
      orElse: () => ConnectorCategory.utilities,
    );
    final authStatusStr = j['auth_status'] as String? ?? 'notConnected';
    final authStatus = AuthStatus.values.firstWhere(
      (e) => e.name == authStatusStr,
      orElse: () => AuthStatus.notConnected,
    );

    final rawActions = j['available_actions'] as List<dynamic>? ?? [];
    final actions = rawActions.map((a) {
      final am = a as Map<String, dynamic>;
      // Actions from marketplace have 'parameters' list, not 'params' map
      final paramsList = am['parameters'] as List<dynamic>? ?? [];
      final paramsMap = <String, ParamDef>{};
      for (final p in paramsList) {
        final pm = p as Map<String, dynamic>;
        final name = pm['name'] as String? ?? '';
        if (name.isNotEmpty) {
          paramsMap[name] = ParamDef(
            type: pm['type'] as String? ?? 'string',
            required: pm['required'] as bool? ?? true,
            description: pm['description'] as String?,
          );
        }
      }
      return ConnectorAction(
        name: am['name'] as String,
        description: am['description'] as String? ?? '',
        params: paramsMap,
      );
    }).toList();

    return ConnectorDef(
      id: j['connector_id'] as String,
      displayName: j['display_name'] as String,
      aliases: List<String>.from(j['aliases'] ?? []),
      category: category,
      type: type,
      feasibility: feasibility,
      description: j['description'] as String? ?? '',
      systemPromptExtension: j['system_prompt_extension'] as String?,
      iconAsset: j['icon_url'] as String?,
      tosRisk: j['tos_risk'] as bool? ?? false,
      authStatus: authStatus,
      availableActions: actions,
    );
  }
}
