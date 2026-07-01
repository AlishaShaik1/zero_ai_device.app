import 'models/connector_def.dart';

class ConnectorCatalog {
  static final List<ConnectorDef> defaultConnectors = [
    // --- SEARCH GATEWAY ---
    ConnectorDef(
      id: "zero_search",
      displayName: "Zero Search",
      aliases: ["search", "web", "internet", "google search", "find out"],
      category: ConnectorCategory.utilities,
      type: ConnectorType.apiOauth, // Or apiKey
      feasibility: FeasibilityTier.selfServe,
      description: "Search the web for real-time facts, prices, and news using the Zero Search Gateway.",
      availableActions: [
        ConnectorAction(
          name: "search_web",
          description: "Search the internet for a query.",
          params: {
            "query": ParamDef(type: "string", description: "The search query"),
          },
          requiresAuth: false, // Assuming the app uses its internal key
        ),
      ],
      authStatus: AuthStatus.connected, // Implicitly connected
    ),

    // --- TIER A: Canva ---
    ConnectorDef(
      id: "canva",
      displayName: "Canva",
      aliases: ["canva", "design", "graphic", "image generator"],
      category: ConnectorCategory.design,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: "Create designs, graphics, and images.",
      availableActions: [
        ConnectorAction(
          name: "create_design",
          description: "Create a new design using a prompt.",
          params: {
            "prompt": ParamDef(type: "string", description: "What to design"),
            "format": ParamDef(type: "string", defaultValue: "square"),
          },
        ),
        ConnectorAction(
          name: "export_design",
          description: "Export an existing design to an image.",
          params: {
            "design_id": ParamDef(type: "string"),
          },
          requiresPremium: true,
        ),
      ],
    ),

    // --- TIER A: Gmail ---
    ConnectorDef(
      id: "gmail",
      displayName: "Gmail",
      aliases: ["mail", "email", "google mail"],
      category: ConnectorCategory.communication,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: "Send and read emails.",
      availableActions: [
        ConnectorAction(
          name: "send_email",
          description: "Send an email.",
          params: {
            "to": ParamDef(type: "string"),
            "subject": ParamDef(type: "string"),
            "body": ParamDef(type: "string"),
          },
        ),
        ConnectorAction(
          name: "read_recent",
          description: "Read recent emails.",
          params: {
            "count": ParamDef(type: "integer", defaultValue: 5),
          },
        ),
      ],
    ),

    // --- TIER C: Swiggy ---
    ConnectorDef(
      id: "swiggy",
      displayName: "Swiggy",
      aliases: ["food", "order food", "instamart", "dineout"],
      category: ConnectorCategory.foodDelivery,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.inviteGated,
      description: "Order food and groceries.",
      availableActions: [
        ConnectorAction(
          name: "search_restaurant",
          description: "Find a restaurant.",
          params: {"query": ParamDef(type: "string")},
        ),
        ConnectorAction(
          name: "order_item",
          description: "Order a specific item from a restaurant.",
          params: {
            "restaurant_id": ParamDef(type: "string"),
            "item_name": ParamDef(type: "string"),
          },
        ),
      ],
    ),

    // --- TIER E: WhatsApp (Personal) ---
    ConnectorDef(
      id: "whatsapp_personal",
      displayName: "WhatsApp",
      aliases: ["whatsapp", "wa", "message mary"],
      category: ConnectorCategory.communication,
      type: ConnectorType.installedApp,
      feasibility: FeasibilityTier.accessibilityOnly,
      tosRisk: true,
      riskNote: "Personal-account automation; keep to single-message, user-initiated actions only. Never batch or schedule sends.",
      description: "Send messages via WhatsApp accessibility UI automation.",
      availableActions: [
        ConnectorAction(
          name: "send_message",
          description: "Send a message to a contact.",
          params: {
            "contact": ParamDef(type: "string"),
            "message": ParamDef(type: "string"),
          },
          requiresAuth: false, // Managed by OS/accessibility
        ),
      ],
      authStatus: AuthStatus.connected, // Typically just installed
    ),

    // --- TIER D: Zomato (Partnership Only) ---
    ConnectorDef(
      id: "zomato",
      displayName: "Zomato",
      aliases: ["zomato", "restaurant price"],
      category: ConnectorCategory.foodDelivery,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.partnershipOnly,
      description: "Restaurant and food delivery (Partner access required).",
      availableActions: [],
    ),
  ];
}
