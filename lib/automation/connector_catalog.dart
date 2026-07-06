import 'models/connector_def.dart';

/// Default local connector catalog.
/// Used as fallback / seed while the remote marketplace loads.
/// Includes official MCP (Model Context Protocol) connectors from
/// https://github.com/modelcontextprotocol/servers
class ConnectorCatalog {
  static final List<ConnectorDef> defaultConnectors = [
<<<<<<< HEAD
=======
    // --- TEST/CORE: Gemini ---
    ConnectorDef(
      id: "gemini_app",
      displayName: "Gemini",
      aliases: ["gemini", "google gemini"],
      category: ConnectorCategory.ai,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: "Google Gemini assistant and model connector.",
      availableActions: [
        ConnectorAction(
          name: "chat",
          description: "Send a prompt and receive a response.",
          params: {
            "prompt": ParamDef(type: "string", description: "User prompt"),
          },
        ),
      ],
      authStatus: AuthStatus.connected,
    ),

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
>>>>>>> 9aaa7ef (updated file strcture and model development)

    // ─── BUILT-IN ────────────────────────────────────────────────────────────

    ConnectorDef(
      id: 'zero_search',
      displayName: 'Zero Search',
      aliases: ['search', 'web', 'internet', 'google search', 'find out'],
      category: ConnectorCategory.utilities,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Search the web for real-time facts, prices, and news.',
      availableActions: [
        ConnectorAction(
          name: 'search_web',
          description: 'Search the internet for a query.',
          params: {'query': ParamDef(type: 'string', description: 'Search query')},
          requiresAuth: false,
        ),
      ],
      authStatus: AuthStatus.connected,
    ),

    // ─── OFFICIAL MCP CONNECTORS (Anthropic registry) ────────────────────────

    ConnectorDef(
      id: 'mcp_github',
      displayName: 'GitHub (MCP)',
      aliases: ['github', 'git hub', 'repo', 'pull request', 'issue', 'code'],
      category: ConnectorCategory.developer,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      description: 'Repository management, PRs, issues, and code search via MCP.',
      systemPromptExtension:
          'Use mcp_github for code repository tasks: creating/reading files, opening issues, '
          'reviewing PRs, searching code, or managing branches. Confirm before push/merge.',
      availableActions: [
        ConnectorAction(name: 'create_issue', description: 'Create a GitHub issue.',
            params: {'repo': ParamDef(type: 'string'), 'title': ParamDef(type: 'string'), 'body': ParamDef(type: 'string')}),
        ConnectorAction(name: 'list_prs', description: 'List open pull requests.',
            params: {'repo': ParamDef(type: 'string')}),
        ConnectorAction(name: 'search_code', description: 'Search code across repos.',
            params: {'query': ParamDef(type: 'string')}),
        ConnectorAction(name: 'get_file', description: 'Read a file from a repo.',
            params: {'repo': ParamDef(type: 'string'), 'path': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_slack',
      displayName: 'Slack (MCP)',
      aliases: ['slack', 'channel', 'workspace message'],
      category: ConnectorCategory.communication,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Send messages, read channels, and manage Slack workspaces via MCP.',
      systemPromptExtension:
          'Use mcp_slack to post messages or fetch recent channel messages. '
          'Confirm channel name with user before sending.',
      availableActions: [
        ConnectorAction(name: 'send_message', description: 'Post a message to a channel.',
            params: {'channel': ParamDef(type: 'string'), 'text': ParamDef(type: 'string')}),
        ConnectorAction(name: 'read_channel', description: 'Read recent channel messages.',
            params: {'channel': ParamDef(type: 'string'), 'limit': ParamDef(type: 'integer', required: false, defaultValue: 10)}),
        ConnectorAction(name: 'list_channels', description: 'List available channels.', params: {}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_notion',
      displayName: 'Notion (MCP)',
      aliases: ['notion', 'notes', 'wiki', 'database', 'page'],
      category: ConnectorCategory.productivity,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Read and write Notion pages and databases via MCP.',
      systemPromptExtension:
          'Use mcp_notion to create pages, search content, or update database entries. '
          'Search first to find page IDs before direct edits.',
      availableActions: [
        ConnectorAction(name: 'create_page', description: 'Create a Notion page.',
            params: {'title': ParamDef(type: 'string'), 'content': ParamDef(type: 'string'), 'parent_id': ParamDef(type: 'string', required: false)}),
        ConnectorAction(name: 'search', description: 'Search Notion workspace.',
            params: {'query': ParamDef(type: 'string')}),
        ConnectorAction(name: 'get_page', description: 'Get a page by ID.',
            params: {'page_id': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_stripe',
      displayName: 'Stripe (MCP)',
      aliases: ['stripe', 'payment', 'charge', 'invoice', 'subscription'],
      category: ConnectorCategory.finance,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      tosRisk: true,
      riskNote: 'Financial actions — always confirm amount and recipient before executing.',
      description: 'Manage Stripe payments, customers, and invoices via MCP.',
      systemPromptExtension:
          'Use mcp_stripe for payment queries only. Never initiate charges without explicit '
          'user confirmation. Always show amount and currency first.',
      availableActions: [
        ConnectorAction(name: 'get_customer', description: 'Look up a customer.',
            params: {'email': ParamDef(type: 'string')}),
        ConnectorAction(name: 'list_invoices', description: 'List invoices for a customer.',
            params: {'customer_id': ParamDef(type: 'string')}),
        ConnectorAction(name: 'create_payment_link', description: 'Create a payment link.',
            params: {'amount': ParamDef(type: 'integer'), 'currency': ParamDef(type: 'string'), 'description': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_postgres',
      displayName: 'PostgreSQL (MCP)',
      aliases: ['postgres', 'postgresql', 'database', 'sql', 'db'],
      category: ConnectorCategory.developer,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      description: 'Read-only SQL queries and schema inspection via MCP.',
      systemPromptExtension:
          'mcp_postgres is READ-ONLY. Only run SELECT queries. '
          'Never attempt INSERT, UPDATE, DELETE, or DROP. Show SQL to user first.',
      availableActions: [
        ConnectorAction(name: 'query', description: 'Run a read-only SQL query.',
            params: {'sql': ParamDef(type: 'string')}),
        ConnectorAction(name: 'list_tables', description: 'List all tables.', params: {}),
        ConnectorAction(name: 'describe_table', description: 'Describe a table schema.',
            params: {'table': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_google_drive',
      displayName: 'Google Drive (MCP)',
      aliases: ['google drive', 'drive', 'gdrive', 'docs', 'sheets', 'files'],
      category: ConnectorCategory.cloud,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Search, read, and manage Google Drive files via MCP.',
      availableActions: [
        ConnectorAction(name: 'search', description: 'Search for files.',
            params: {'query': ParamDef(type: 'string')}),
        ConnectorAction(name: 'read_file', description: 'Read a file content.',
            params: {'file_id': ParamDef(type: 'string')}),
        ConnectorAction(name: 'create_file', description: 'Create a new file.',
            params: {'name': ParamDef(type: 'string'), 'content': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_sentry',
      displayName: 'Sentry (MCP)',
      aliases: ['sentry', 'error tracking', 'bug report', 'crash log'],
      category: ConnectorCategory.developer,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      description: 'Query Sentry errors, issues, and project stats via MCP.',
      availableActions: [
        ConnectorAction(name: 'list_issues', description: 'List recent Sentry issues.',
            params: {'project': ParamDef(type: 'string')}),
        ConnectorAction(name: 'get_issue', description: 'Get details of an issue.',
            params: {'issue_id': ParamDef(type: 'string')}),
        ConnectorAction(name: 'resolve_issue', description: 'Mark issue as resolved.',
            params: {'issue_id': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_google_maps',
      displayName: 'Google Maps (MCP)',
      aliases: ['maps', 'directions', 'places', 'nearby', 'location'],
      category: ConnectorCategory.travel,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      description: 'Places search, directions, and geocoding via MCP.',
      availableActions: [
        ConnectorAction(name: 'search_places', description: 'Find places near a location.',
            params: {'query': ParamDef(type: 'string'), 'location': ParamDef(type: 'string', required: false)}),
        ConnectorAction(name: 'get_directions', description: 'Get directions.',
            params: {'origin': ParamDef(type: 'string'), 'destination': ParamDef(type: 'string')}),
        ConnectorAction(name: 'geocode', description: 'Convert address to coordinates.',
            params: {'address': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'mcp_filesystem',
      displayName: 'Filesystem (MCP)',
      aliases: ['filesystem', 'files', 'read file', 'write file', 'local file'],
      category: ConnectorCategory.utilities,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      description: 'Secure local file read/write with configurable access controls via MCP.',
      systemPromptExtension:
          'mcp_filesystem operates within allowed directories only. '
          'Always show path and content to user before writing.',
      availableActions: [
        ConnectorAction(name: 'read_file', description: 'Read a local file.',
            params: {'path': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'write_file', description: 'Write content to a file.',
            params: {'path': ParamDef(type: 'string'), 'content': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'list_dir', description: 'List files in a directory.',
            params: {'path': ParamDef(type: 'string')}, requiresAuth: false),
      ],
    ),

    ConnectorDef(
      id: 'mcp_fetch',
      displayName: 'Web Fetch (MCP)',
      aliases: ['fetch', 'scrape', 'web page', 'url content', 'read url'],
      category: ConnectorCategory.utilities,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      description: 'Fetch web page content, converted for LLM consumption via MCP.',
      availableActions: [
        ConnectorAction(name: 'fetch', description: 'Fetch a web page as text.',
            params: {'url': ParamDef(type: 'string')}, requiresAuth: false),
      ],
    ),

    ConnectorDef(
      id: 'mcp_memory',
      displayName: 'Memory (MCP)',
      aliases: ['memory', 'remember', 'knowledge graph', 'recall', 'store fact'],
      category: ConnectorCategory.ai,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      description: 'Persistent knowledge graph — store and recall facts across sessions.',
      systemPromptExtension:
          'Use mcp_memory to persist facts the user wants remembered. '
          'Confirm before storing personal data.',
      availableActions: [
        ConnectorAction(name: 'store', description: 'Store a fact.',
            params: {'key': ParamDef(type: 'string'), 'value': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'recall', description: 'Recall a stored fact.',
            params: {'key': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'search', description: 'Search knowledge graph.',
            params: {'query': ParamDef(type: 'string')}, requiresAuth: false),
      ],
    ),

    ConnectorDef(
      id: 'mcp_git',
      displayName: 'Git (MCP)',
      aliases: ['git', 'commit', 'branch', 'clone', 'diff'],
      category: ConnectorCategory.developer,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      description: 'Read, search, and manipulate local Git repositories via MCP.',
      availableActions: [
        ConnectorAction(name: 'log', description: 'Show commit history.',
            params: {'repo': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'diff', description: 'Show changes between commits.',
            params: {'repo': ParamDef(type: 'string'), 'from': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'status', description: 'Show working tree status.',
            params: {'repo': ParamDef(type: 'string')}, requiresAuth: false),
      ],
    ),

    ConnectorDef(
      id: 'mcp_puppeteer',
      displayName: 'Browser Automation (MCP)',
      aliases: ['puppeteer', 'browser', 'screenshot', 'web automation', 'headless'],
      category: ConnectorCategory.utilities,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      tosRisk: true,
      riskNote: 'Only automate pages the user explicitly requests. Never auto-enter credentials.',
      description: 'Browser automation — screenshots and web scraping via Puppeteer MCP.',
      availableActions: [
        ConnectorAction(name: 'screenshot', description: 'Take a screenshot of a URL.',
            params: {'url': ParamDef(type: 'string')}, requiresAuth: false),
        ConnectorAction(name: 'click', description: 'Click an element on a page.',
            params: {'url': ParamDef(type: 'string'), 'selector': ParamDef(type: 'string')}, requiresAuth: false),
      ],
    ),

    ConnectorDef(
      id: 'mcp_time',
      displayName: 'Time (MCP)',
      aliases: ['time', 'timezone', 'current time', 'clock', 'what time'],
      category: ConnectorCategory.utilities,
      type: ConnectorType.deepLinkOnly,
      feasibility: FeasibilityTier.selfServe,
      description: 'Current time and timezone conversion via MCP.',
      availableActions: [
        ConnectorAction(name: 'get_time', description: 'Get current time in a timezone.',
            params: {'timezone': ParamDef(type: 'string', required: false, defaultValue: 'UTC')}, requiresAuth: false),
        ConnectorAction(name: 'convert_time', description: 'Convert time between timezones.',
            params: {'time': ParamDef(type: 'string'), 'from_tz': ParamDef(type: 'string'), 'to_tz': ParamDef(type: 'string')}, requiresAuth: false),
      ],
      authStatus: AuthStatus.connected,
    ),

    ConnectorDef(
      id: 'mcp_linear',
      displayName: 'Linear (MCP)',
      aliases: ['linear', 'issue tracker', 'sprint', 'ticket', 'project management'],
      category: ConnectorCategory.productivity,
      type: ConnectorType.apiKey,
      feasibility: FeasibilityTier.selfServe,
      description: 'Manage Linear issues, projects, and cycles via MCP.',
      availableActions: [
        ConnectorAction(name: 'create_issue', description: 'Create a Linear issue.',
            params: {'title': ParamDef(type: 'string'), 'team': ParamDef(type: 'string')}),
        ConnectorAction(name: 'list_issues', description: 'List issues for a team.',
            params: {'team': ParamDef(type: 'string')}),
        ConnectorAction(name: 'update_issue', description: 'Update issue status.',
            params: {'issue_id': ParamDef(type: 'string'), 'state': ParamDef(type: 'string')}),
      ],
    ),

    // ─── EXISTING CONNECTORS ─────────────────────────────────────────────────

    ConnectorDef(
      id: 'canva',
      displayName: 'Canva',
      aliases: ['canva', 'design', 'graphic', 'image generator'],
      category: ConnectorCategory.design,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Create designs, graphics, and images.',
      availableActions: [
        ConnectorAction(name: 'create_design', description: 'Create a new design using a prompt.',
            params: {'prompt': ParamDef(type: 'string'), 'format': ParamDef(type: 'string', defaultValue: 'square')}),
        ConnectorAction(name: 'export_design', description: 'Export an existing design.',
            params: {'design_id': ParamDef(type: 'string')}, requiresPremium: true),
      ],
    ),

    ConnectorDef(
      id: 'gmail',
      displayName: 'Gmail',
      aliases: ['mail', 'email', 'google mail'],
      category: ConnectorCategory.communication,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.selfServe,
      description: 'Send and read emails.',
      availableActions: [
        ConnectorAction(name: 'send_email', description: 'Send an email.',
            params: {'to': ParamDef(type: 'string'), 'subject': ParamDef(type: 'string'), 'body': ParamDef(type: 'string')}),
        ConnectorAction(name: 'read_recent', description: 'Read recent emails.',
            params: {'count': ParamDef(type: 'integer', defaultValue: 5)}),
      ],
    ),

    ConnectorDef(
      id: 'swiggy',
      displayName: 'Swiggy',
      aliases: ['food', 'order food', 'instamart', 'dineout'],
      category: ConnectorCategory.foodDelivery,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.inviteGated,
      description: 'Order food and groceries.',
      availableActions: [
        ConnectorAction(name: 'search_restaurant', description: 'Find a restaurant.',
            params: {'query': ParamDef(type: 'string')}),
        ConnectorAction(name: 'order_item', description: 'Order a specific item.',
            params: {'restaurant_id': ParamDef(type: 'string'), 'item_name': ParamDef(type: 'string')}),
      ],
    ),

    ConnectorDef(
      id: 'whatsapp_personal',
      displayName: 'WhatsApp',
      aliases: ['whatsapp', 'wa', 'message'],
      category: ConnectorCategory.communication,
      type: ConnectorType.installedApp,
      feasibility: FeasibilityTier.accessibilityOnly,
      tosRisk: true,
      riskNote: 'Personal-account automation. Single, user-initiated actions only.',
      description: 'Send messages via WhatsApp accessibility automation.',
      availableActions: [
        ConnectorAction(name: 'send_message', description: 'Send a message to a contact.',
            params: {'contact': ParamDef(type: 'string'), 'message': ParamDef(type: 'string')}, requiresAuth: false),
      ],
      authStatus: AuthStatus.connected,
    ),

    ConnectorDef(
      id: 'zomato',
      displayName: 'Zomato',
      aliases: ['zomato', 'restaurant'],
      category: ConnectorCategory.foodDelivery,
      type: ConnectorType.apiOauth,
      feasibility: FeasibilityTier.partnershipOnly,
      description: 'Restaurant and food delivery (Partner access required).',
      availableActions: [],
    ),
  ];
}
