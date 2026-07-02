/// Feasibility tier — determines what the UI shows and what the gate allows.
/// Directly from connector feasibility doc §1.
enum FeasibilityTier {
  /// Tier A: Public dev portal, OAuth or API key, instant approval
  selfServe,
  /// Tier B: Works standalone but some features need user's own paid plan
  selfServeLimited,
  /// Tier C: Exists but requires application/approval before credentials
  inviteGated,
  /// Tier D: No individual-developer path exists
  partnershipOnly,
  /// Tier E: No official API; accessibility-automation only
  accessibilityOnly,
}

enum AuthStatus { connected, notConnected, expired }

enum ConnectorType {
  /// Installed Android app — Level 2 accessibility or deep link
  installedApp,
  /// API with OAuth 2.0 flow — Level 3 connector
  apiOauth,
  /// API with user-provided API key — Level 3 connector
  apiKey,
  /// Deep link only — limited to opening the app at a specific screen
  deepLinkOnly,
}

/// The category a connector belongs to — used for marketplace UI grouping.
enum ConnectorCategory {
  communication,
  social,
  productivity,
  design,
  entertainment,
  shopping,
  foodDelivery,
  finance,
  travel,
  developer,
  ai,
  health,
  smartHome,
  news,
  education,
  utilities,
  photography,
  business,
  cloud,
  crm,
  marketing,
  custom,
}

/// Full connector definition — every field from core architecture §3
/// plus feasibility tier from connector feasibility doc §3.
class ConnectorDef {
  final String id;
  final String displayName;
  final List<String> aliases;
  final ConnectorCategory category;
  final ConnectorType type;
  final FeasibilityTier feasibility;
  final bool tosRisk;
  final String? riskNote;
  final String? packageName;
  final String? oauthProvider;
  final List<String> requiredScopes;
  final List<ConnectorAction> availableActions;
  final String? iconAsset;
  final String description;
  final String? systemPromptExtension;
  final bool isPremium;

  /// Runtime state — mutable, stored per-user in local DB
  AuthStatus authStatus;
  DateTime? lastVerified;
  String? oauthTokenRef;

  ConnectorDef({
    required this.id,
    required this.displayName,
    required this.aliases,
    required this.category,
    required this.type,
    required this.feasibility,
    this.tosRisk = false,
    this.riskNote,
    this.packageName,
    this.oauthProvider,
    this.requiredScopes = const [],
    required this.availableActions,
    this.iconAsset,
    required this.description,
    this.systemPromptExtension,
    this.isPremium = false,
    this.authStatus = AuthStatus.notConnected,
    this.lastVerified,
    this.oauthTokenRef,
  });

  /// All name variants for fuzzy + exact lookup
  List<String> get allNames => [
    displayName.toLowerCase(),
    ...aliases.map((a) => a.toLowerCase()),
  ];

  Map<String, dynamic> toJson() => {
    'connector_id': id,
    'display_name': displayName,
    'category': category.name,
    'type': type.name,
    'feasibility': feasibility.name,
    'tos_risk': tosRisk,
    'auth_status': authStatus.name,
    if (systemPromptExtension != null) 'system_prompt_extension': systemPromptExtension,
    'available_actions': availableActions.map((a) => a.name).toList(),
  };
}

/// A single action a connector can perform.
class ConnectorAction {
  final String name;
  final String description;
  final Map<String, ParamDef> params;
  final bool requiresAuth;
  final bool requiresPremium;

  const ConnectorAction({
    required this.name,
    required this.description,
    this.params = const {},
    this.requiresAuth = true,
    this.requiresPremium = false,
  });
}

/// Parameter definition for a connector action.
class ParamDef {
  final String type;
  final bool required;
  final String? description;
  final dynamic defaultValue;

  const ParamDef({
    required this.type,
    this.required = true,
    this.description,
    this.defaultValue,
  });
}
