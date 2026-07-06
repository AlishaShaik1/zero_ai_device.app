import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'connector_catalog.dart';
import 'models/connector_def.dart';

/// Thin wrapper around the marketplace API for Gemma's gate-check logic.
/// For full catalog UI use MarketplaceService instead.
class ConnectorRegistry {
<<<<<<< HEAD
  static const String _marketplaceUrl =
      'https://zero-connector-marketplace.vercel.app/api/connectors';

  List<ConnectorDef> _registry = [];
  bool get isEmpty => _registry.isEmpty;
  int get count => _registry.length;
=======
  final String _marketplaceUrl = 'https://your-vercel-marketplace.vercel.app/api/connectors';
  List<ConnectorDef> _registry;

  ConnectorRegistry({bool seedLocalCatalog = true})
      : _registry = seedLocalCatalog
            ? List<ConnectorDef>.from(ConnectorCatalog.defaultConnectors)
            : [];
>>>>>>> 9aaa7ef (updated file strcture and model development)

  /// Fetch and cache the connector catalog.
  /// The server returns { data: [...], total, limit, offset }.
  Future<void> loadMarketplace({String? userId}) async {
    try {
      final uri = Uri.parse(_marketplaceUrl).replace(
        queryParameters: <String, String>{
          if (userId != null) 'user_id': userId,
          'limit': '200',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        if (kDebugMode) print('[ConnectorRegistry] HTTP ${response.statusCode}');
        return;
      }

      // ✅ Unwrap the { data: [...] } envelope from the API
      final decoded = json.decode(response.body) as Map<String, dynamic>;
      final List<dynamic> data = decoded['data'] as List<dynamic>? ?? [];

      _registry = data.map((j) {
        final m = j as Map<String, dynamic>;
        final id = m['connector_id'] as String;
        final displayName = m['display_name'] as String;
        final aliases = List<String>.from(m['aliases'] ?? []);

        // auth_flow → ConnectorType
        final authFlow = m['auth_flow'] as String? ?? 'oauth2_pkce';
        final ConnectorType type;
        if (authFlow == 'apiKey') {
          type = ConnectorType.apiKey;
        } else if (authFlow == 'none') {
          type = ConnectorType.deepLinkOnly;
        } else {
          type = ConnectorType.apiOauth;
        }

        final feasStr = m['feasibility'] as String? ?? 'selfServe';
        final feasibility = FeasibilityTier.values.firstWhere(
          (e) => e.name == feasStr,
          orElse: () => FeasibilityTier.selfServe,
        );

        final catStr = m['category'] as String? ?? 'utilities';
        final category = ConnectorCategory.values.firstWhere(
          (e) => e.name == catStr,
          orElse: () => ConnectorCategory.utilities,
        );

        final authStatusStr = m['auth_status'] as String? ?? 'notConnected';
        final authStatus = AuthStatus.values.firstWhere(
          (e) => e.name == authStatusStr,
          orElse: () => AuthStatus.notConnected,
        );

        // Parse actions list from marketplace format
        final rawActions = m['available_actions'] as List<dynamic>? ?? [];
        final actions = rawActions.map((a) {
          final am = a as Map<String, dynamic>;
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
<<<<<<< HEAD

        return ConnectorDef(
          id: id,
          displayName: displayName,
          aliases: aliases,
          category: category,
          type: type,
          feasibility: feasibility,
          description: m['description'] as String? ?? '',
          systemPromptExtension: m['system_prompt_extension'] as String?,
          tosRisk: m['tos_risk'] as bool? ?? false,
          authStatus: authStatus,
          availableActions: actions,
        );
      }).toList();

      if (kDebugMode) {
        print('[ConnectorRegistry] Loaded ${_registry.length} connectors.');
      }
    } catch (e) {
      if (kDebugMode) print('[ConnectorRegistry] loadMarketplace error: $e');
=======
        if (kDebugMode) print("Loaded ${_registry.length} connectors from marketplace.");
      }
    } catch (e) {
      if (kDebugMode) print("Failed to load marketplace: $e");
      // Keep local default catalog if network fails.
>>>>>>> 9aaa7ef (updated file strcture and model development)
    }
  }

  // Check if an app exists in the loaded registry
  Map<String, dynamic> gateCheck(String targetEntity) {
    if (_registry.isEmpty) {
      return {'status': 'stop', 'message': 'Connector registry not loaded.'};
    }

    final searchTarget = targetEntity.toLowerCase();
    
    // 1. Exact or Alias match lookup
    final match = _registry.cast<ConnectorDef?>().firstWhere(
      (c) => c!.allNames.contains(searchTarget),
      orElse: () => null
    );

    if (match != null) {
      if (match.authStatus == AuthStatus.connected) {
        return {'status': 'proceed', 'connector': match};
      } else {
        return {'status': 'stop', 'message': '${match.displayName} isn\'t connected yet — want me to open setup?'};
      }
    }
    
    return {'status': 'stop', 'message': 'I don\'t have $targetEntity set up — is that an app I should know?'};
  }
}
