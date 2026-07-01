import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'models/connector_def.dart';

class ConnectorRegistry {
  final String _marketplaceUrl = 'https://your-vercel-marketplace.vercel.app/api/connectors';
  List<ConnectorDef> _registry = [];

  // Fetch the latest catalog from the remote marketplace (e.g. Vercel)
  Future<void> loadMarketplace() async {
    try {
      final response = await http.get(Uri.parse(_marketplaceUrl));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        _registry = data.map((json) {
          // Parse basic fields
          final id = json['connector_id'] as String;
          final displayName = json['display_name'] as String;
          final aliases = List<String>.from(json['aliases'] ?? []);
          
          // Parse enums safely
          final typeStr = json['type'] as String? ?? 'apiOauth';
          final type = ConnectorType.values.firstWhere(
            (e) => e.name == typeStr, 
            orElse: () => ConnectorType.apiOauth
          );

          final authStatusStr = json['auth_status'] as String? ?? 'notConnected';
          final authStatus = AuthStatus.values.firstWhere(
            (e) => e.name == authStatusStr, 
            orElse: () => AuthStatus.notConnected
          );

          return ConnectorDef(
            id: id,
            displayName: displayName,
            aliases: aliases,
            category: ConnectorCategory.utilities, // simplify for example
            type: type,
            feasibility: FeasibilityTier.selfServe, // simplify for example
            description: json['description'] ?? '',
            authStatus: authStatus,
            availableActions: [], // parse actions here in a real app
          );
        }).toList();
        if (kDebugMode) print("Loaded \${_registry.length} connectors from marketplace.");
      }
    } catch (e) {
      if (kDebugMode) print("Failed to load marketplace: \$e");
      // Fallback to local cache if network fails
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
        return {'status': 'stop', 'message': '\${match.displayName} isn\'t connected yet — want me to open setup?'};
      }
    }
    
    return {'status': 'stop', 'message': 'I don\'t have \$targetEntity set up — is that an app I should know?'};
  }
}
