enum AuthStatus { connected, not_connected, expired }
enum ConnectorType { installed_app, api_oauth, deep_link_only }

class ConnectorDef {
  final String id;
  final List<String> displayNames;
  final ConnectorType type;
  final AuthStatus authStatus;
  final String? packageName;
  final List<String> availableActions;

  ConnectorDef({
    required this.id,
    required this.displayNames,
    required this.type,
    required this.authStatus,
    this.packageName,
    required this.availableActions,
  });
}

class ConnectorRegistry {
  final List<ConnectorDef> _registry = [
    ConnectorDef(
      id: "gemini_app",
      displayNames: ["gemini", "google gemini", "gemini app"],
      type: ConnectorType.installed_app,
      authStatus: AuthStatus.connected,
      packageName: "com.google.android.apps.bard",
      availableActions: ["create_image", "chat"]
    )
  ];

  Map<String, dynamic> gateCheck(String targetEntity) {
    // 1. Exact match lookup
    final match = _registry.cast<ConnectorDef?>().firstWhere(
      (c) => c!.displayNames.contains(targetEntity.toLowerCase()),
      orElse: () => null
    );

    if (match != null) {
      if (match.authStatus == AuthStatus.connected) {
        return {'status': 'proceed', 'connector': match};
      } else {
        return {'status': 'stop', 'message': '${match.id} isn\'t connected yet — want me to open setup?'};
      }
    }
    
    return {'status': 'stop', 'message': 'I don\'t have $targetEntity set up — is that an app I should know?'};
  }
}
