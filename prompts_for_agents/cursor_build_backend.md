# CURSOR AGENT PROMPT — Build Zero Ring Connector Marketplace Backend

Paste this into Cursor Composer (Agent mode). It will build the entire Vercel + Supabase backend.

---

## CONTEXT

I am building Zero Ring — an AI assistant Flutter app. I need you to build a production-ready Vercel backend called `zero-connector-marketplace` that:

1. Stores 150+ app connector definitions in Supabase (PostgreSQL)
2. Stores each user's OAuth connection state in Supabase
3. Handles OAuth 2.0 flows for services like Google, Slack, Notion, Canva, GitHub, Spotify
4. Exposes REST API endpoints the Flutter app calls to browse, connect, and use connectors
5. Has a minimal admin web UI (single HTML page) to add/edit/delete connectors and their system prompts

## PROJECT STRUCTURE TO CREATE:

```
zero-connector-marketplace/
├── api/
│   ├── connectors.js         # GET /api/connectors?query=&category=
│   ├── connector/[id].js     # GET /api/connector/:id (single connector with full system prompt)
│   ├── user-connections.js   # GET/POST /api/user-connections
│   ├── oauth/
│   │   ├── start.js          # GET /api/oauth/start?connector_id=&user_id=
│   │   └── callback.js       # GET /api/oauth/callback?code=&state=
├── admin/
│   └── index.html            # Simple web UI to manage connectors
├── lib/
│   └── supabase.js           # Supabase client singleton
├── package.json
├── vercel.json
└── .env.example
```

## SUPABASE SCHEMA (create these tables):

### Table: `connectors`
```sql
CREATE TABLE connectors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  connector_id TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  aliases TEXT[] DEFAULT '{}',
  category TEXT NOT NULL,
  feasibility TEXT NOT NULL DEFAULT 'selfServe',
  auth_type TEXT NOT NULL DEFAULT 'oauth2',
  oauth_provider TEXT,
  description TEXT NOT NULL,
  system_prompt_extension TEXT,
  tos_risk BOOLEAN DEFAULT false,
  available_actions JSONB DEFAULT '[]',
  icon_url TEXT,
  website TEXT,
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Full text search index
CREATE INDEX connectors_search_idx ON connectors USING GIN (
  to_tsvector('english', display_name || ' ' || COALESCE(description, ''))
);

ALTER TABLE connectors ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Public read active connectors" ON connectors FOR SELECT USING (is_active = true);
```

### Table: `user_connections`
```sql
CREATE TABLE user_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL,
  connector_id TEXT NOT NULL REFERENCES connectors(connector_id),
  auth_status TEXT NOT NULL DEFAULT 'notConnected',
  access_token TEXT,
  refresh_token TEXT,
  token_expires_at TIMESTAMPTZ,
  scopes TEXT[],
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, connector_id)
);

ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own connections" ON user_connections FOR SELECT USING (true);
CREATE POLICY "Users write own connections" ON user_connections FOR ALL USING (true);
```

## API ENDPOINTS TO BUILD:

### GET /api/connectors
- Query params: `query` (search string), `category` (filter), `user_id` (to merge connection status)
- Returns: Array of connectors. If user_id provided, each connector includes `auth_status` from user_connections table.
- Use Supabase full-text search if query provided.
- Add Cache-Control: s-maxage=60 header

### GET /api/connector/[id]
- Returns single connector with FULL system_prompt_extension (not returned in list endpoint to save bandwidth)
- Also returns user's auth_status if user_id query param provided

### GET /api/oauth/start
- Params: `connector_id`, `user_id`
- Looks up connector's oauth_provider
- Generates a `state` JWT (encode: {connector_id, user_id, timestamp})
- Redirects to the correct OAuth provider's authorization URL
- Supported providers: google, slack, notion, canva, github, spotify, linear
- Each provider needs its own client_id from env vars

### GET /api/oauth/callback
- Params: `code`, `state`
- Decodes state JWT to get connector_id and user_id
- Exchanges code for access_token using the provider's token endpoint
- Saves to user_connections table: access_token (encrypted), refresh_token, scopes
- Redirects to: `zeroapp://oauth-success?connector_id=X` (deep link back to Flutter app)

### GET /api/user-connections
- Params: `user_id`
- Returns all connector_id's the user has connected with their auth_status

### POST /api/user-connections
- Body: `{user_id, connector_id, auth_status: 'disconnected'}`
- Used by Flutter app when user taps "Disconnect"

## OAUTH PROVIDERS CONFIG (in .env):
```
# Google (for Gmail, Google Drive, Google Calendar, Google Fit)
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

# GitHub
GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

# Slack
SLACK_CLIENT_ID=
SLACK_CLIENT_SECRET=

# Notion
NOTION_CLIENT_ID=
NOTION_CLIENT_SECRET=

# Canva
CANVA_CLIENT_ID=
CANVA_CLIENT_SECRET=

# Spotify
SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=

# Supabase
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=

# JWT secret for state token
JWT_SECRET=

# App deep link base
APP_DEEP_LINK=zeroapp://oauth-success
```

## ADMIN UI (admin/index.html):
Build a clean, minimal single-page HTML (no frameworks, vanilla JS + fetch) that:
- Lists all connectors in a table
- Has a search box
- Each row has Edit and Delete buttons
- Clicking Edit opens a modal with all fields editable, especially `system_prompt_extension` (large textarea)
- Has an "Add New Connector" button that opens the same modal empty
- All actions call /api/connectors with admin API key in header
- Add a "Test Prompt" button per connector that shows what Gemma will see

## IMPORTANT NOTES:
- Use `jsonwebtoken` for state JWT signing
- Use `@supabase/supabase-js` v2 for all database calls
- Use native `fetch` for OAuth token exchange (no axios)
- Vercel free tier: serverless functions, no background jobs
- All token storage in Supabase must be encrypted at rest (use pgcrypto or just store as-is since Supabase encrypts storage)
- `vercel.json` should configure routes so `/admin` serves the HTML file
- Add CORS headers to all API routes for the Flutter app

## AFTER BUILDING:
Run `vercel deploy` and give me the deployed URL. I will paste it into my Flutter app.
