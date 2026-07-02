import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../automation/models/connector_def.dart';

/// Central service for everything related to the remote connector marketplace.
/// - Fetches connector catalog from Vercel
/// - Tracks user connection states in Supabase (via Vercel API)
/// - Kicks off OAuth flows via a deep link
/// - Returns per-connector system prompt extension when Gemma loads a tool
class MarketplaceService extends ChangeNotifier {
  static final MarketplaceService _instance = MarketplaceService._();
  static MarketplaceService get instance => _instance;
  MarketplaceService._();

  // ── Replace with your Vercel URL once deployed ──────────────────────────
  static const String _baseUrl = 'https://zero-connector-marketplace.vercel.app';
  // ────────────────────────────────────────────────────────────────────────

  // Unique per-device user ID — replace with proper auth later
  String _userId = 'local_user_v1';

  List<ConnectorDef> _catalog = [];
  final Map<String, String> _authStates = {}; // connectorId → authStatus
  bool _isLoading = false;
  String? _error;

  List<ConnectorDef> get catalog => _catalog;
  bool get isLoading => _isLoading;
  String? get error => _error;

  String authStatusFor(String connectorId) =>
      _authStates[connectorId] ?? 'notConnected';

  // ── LOAD CATALOG ────────────────────────────────────────────────────────

  Future<void> loadCatalog({String? query, String? category}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final params = {
        'user_id': _userId,
        if (query != null && query.isNotEmpty) 'query': query,
        if (category != null) 'category': category,
      };
      final uri = Uri.parse('$_baseUrl/api/connectors')
          .replace(queryParameters: params);

      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) throw Exception('Server error ${res.statusCode}');

      final List<dynamic> data = json.decode(res.body);
      _catalog = data.map((j) => _parseConnector(j)).toList();

      // Merge auth states
      for (final j in data) {
        final id = j['connector_id'] as String;
        _authStates[id] = j['auth_status'] as String? ?? 'notConnected';
      }
    } catch (e) {
      _error = 'Could not load connectors. Check your connection.';
      if (kDebugMode) debugPrint('MarketplaceService.loadCatalog: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ── FETCH SINGLE CONNECTOR (with full system prompt for Gemma) ──────────

  Future<ConnectorDef?> fetchConnector(String connectorId) async {
    try {
      final uri = Uri.parse('$_baseUrl/api/connector/$connectorId')
          .replace(queryParameters: {'user_id': _userId});
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      return _parseConnector(json.decode(res.body));
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.fetchConnector: $e');
      return null;
    }
  }

  // ── START OAUTH FLOW ────────────────────────────────────────────────────
  // Returns the URL to open in a webview/browser.
  // The server will redirect back to zeroapp://oauth-success?connector_id=X

  String buildOAuthStartUrl(String connectorId) {
    return '$_baseUrl/api/oauth/start'
        '?connector_id=$connectorId&user_id=$_userId';
  }

  // Called by the app's deep link handler when OAuth completes.
  Future<void> onOAuthSuccess(String connectorId) async {
    _authStates[connectorId] = 'connected';
    notifyListeners();
  }

  // ── DISCONNECT ──────────────────────────────────────────────────────────

  Future<void> disconnect(String connectorId) async {
    try {
      await http.post(
        Uri.parse('$_baseUrl/api/user-connections'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': _userId,
          'connector_id': connectorId,
          'auth_status': 'disconnected',
        }),
      );
      _authStates[connectorId] = 'notConnected';
      notifyListeners();
    } catch (e) {
      if (kDebugMode) debugPrint('MarketplaceService.disconnect: $e');
    }
  }

  // ── PARSE ───────────────────────────────────────────────────────────────

  ConnectorDef _parseConnector(Map<String, dynamic> j) {
    final typeStr = j['auth_type'] as String? ?? 'apiOauth';
    final type = ConnectorType.values.firstWhere(
      (e) => e.name == typeStr || e.name == 'apiOauth',
      orElse: () => ConnectorType.apiOauth,
    );
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
      final paramsRaw = (a['params'] as Map<String, dynamic>?) ?? {};
      return ConnectorAction(
        name: a['name'] as String,
        description: a['description'] as String? ?? '',
        params: paramsRaw.map((key, val) => MapEntry(
          key,
          ParamDef(
            type: val['type'] as String? ?? 'string',
            required: val['required'] as bool? ?? true,
            description: val['description'] as String?,
          ),
        )),
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
