# CURSOR AGENT PROMPT — Build Zero Ring MCP-Style Connector Backend

## WHAT YOU ARE BUILDING

A **production-ready Vercel + Supabase backend** that acts as an MCP (Model Context Protocol) server for the Zero Ring AI assistant app.

The architecture mirrors exactly how Claude's MCP connectors work:
- Each user authenticates with **their own account** on each service (Gmail, Notion, GitHub, etc.) via OAuth 2.1 + PKCE
- Your server stores and refreshes **the user's token** — not a shared developer token
- When the Flutter app calls a connector action (e.g. "send Gmail"), your server uses **the user's personal access token** to call Gmail's API
- Zero Ring never shares developer API credentials with users — every action is authenticated as the individual user

---

## PROJECT STRUCTURE

Create a new Node.js project at the path you're working in:

```
zero-connector-marketplace/
├── api/
│   ├── connectors.js           # GET  - catalog with user auth states merged
│   ├── connector/[id].js       # GET  - single connector + full system_prompt_extension
│   ├── user-connections.js     # GET/DELETE - user's connected apps
│   ├── execute.js              # POST - execute a connector action using user's token
│   └── oauth/
│       ├── start.js            # GET  - initiate OAuth 2.1 + PKCE flow
│       └── callback.js         # GET  - receive code, exchange for token, save to Supabase
├── admin/
│   └── index.html             # Admin UI to manage connector catalog
├── lib/
│   ├── supabase.js            # Supabase admin client
│   ├── token-store.js         # Encrypt/decrypt + refresh user tokens
│   └── oauth-providers.js     # OAuth config for each supported provider
├── .env.example
├── package.json
└── vercel.json
```

---

## SUPABASE SCHEMA

Run this SQL in Supabase SQL Editor:

```sql
-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- Connector catalog (managed by admin, read by all)
CREATE TABLE connectors (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  connector_id TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  aliases TEXT[] DEFAULT '{}',
  category TEXT NOT NULL,
  feasibility TEXT NOT NULL DEFAULT 'selfServe',
  auth_flow TEXT NOT NULL DEFAULT 'oauth2_pkce',
  oauth_provider_name TEXT,
  oauth_authorization_url TEXT,
  oauth_token_url TEXT,
  oauth_scopes TEXT[] DEFAULT '{}',
  description TEXT NOT NULL,
  system_prompt_extension TEXT,
  available_actions JSONB DEFAULT '[]',
  tos_risk BOOLEAN DEFAULT false,
  tos_note TEXT,
  icon_url TEXT,
  developer_portal TEXT,
  notes TEXT,
  is_active BOOLEAN DEFAULT true,
  sort_order INTEGER DEFAULT 100,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Search index
CREATE INDEX connectors_fts_idx ON connectors 
  USING GIN (to_tsvector('english', display_name || ' ' || COALESCE(description, '') || ' ' || array_to_string(aliases, ' ')));

-- Per-user connection state (one row per user per connector)
CREATE TABLE user_connections (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id TEXT NOT NULL,
  connector_id TEXT NOT NULL REFERENCES connectors(connector_id) ON DELETE CASCADE,
  auth_status TEXT NOT NULL DEFAULT 'notConnected', -- notConnected | connected | expired | error
  -- Tokens encrypted at rest using pgcrypto
  access_token_encrypted TEXT,
  refresh_token_encrypted TEXT,
  token_expires_at TIMESTAMPTZ,
  scopes TEXT[] DEFAULT '{}',
  provider_user_id TEXT,    -- The user's ID on the external service (for logging)
  provider_email TEXT,      -- The user's email on the external service
  connected_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(user_id, connector_id)
);

-- RLS: anyone can read connectors, only authenticated calls can write user_connections
ALTER TABLE connectors ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_connections ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Public read active connectors" ON connectors FOR SELECT USING (is_active = true);
CREATE POLICY "Service role full access connectors" ON connectors FOR ALL USING (true);
CREATE POLICY "Service role full access connections" ON user_connections FOR ALL USING (true);

-- Auto-update updated_at
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = NOW(); RETURN NEW; END; $$ LANGUAGE plpgsql;
CREATE TRIGGER update_connectors_updated_at BEFORE UPDATE ON connectors FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER update_connections_updated_at BEFORE UPDATE ON user_connections FOR EACH ROW EXECUTE FUNCTION update_updated_at();
```

---

## ENV VARIABLES (.env.example)

```bash
# Supabase
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Token encryption secret (32 chars minimum)
TOKEN_ENCRYPTION_KEY=your-32-char-random-secret

# JWT for OAuth state verification (32 chars minimum)
JWT_SECRET=your-32-char-random-jwt-secret

# Your Vercel deployment URL (for OAuth redirect)
APP_URL=https://zero-connector-marketplace.vercel.app

# Flutter app deep link (for post-OAuth redirect back to app)
APP_DEEP_LINK_BASE=zeroapp://oauth-callback

# Admin UI access key
ADMIN_API_KEY=your-admin-key

# OAuth App credentials (register ONE app per service on YOUR developer account)
# Users sign in with THEIR account — you just register the "app" once
GOOGLE_CLIENT_ID=
GOOGLE_CLIENT_SECRET=

GITHUB_CLIENT_ID=
GITHUB_CLIENT_SECRET=

SLACK_CLIENT_ID=
SLACK_CLIENT_SECRET=

NOTION_CLIENT_ID=
NOTION_CLIENT_SECRET=

SPOTIFY_CLIENT_ID=
SPOTIFY_CLIENT_SECRET=

CANVA_CLIENT_ID=
CANVA_CLIENT_SECRET=

DISCORD_CLIENT_ID=
DISCORD_CLIENT_SECRET=

DROPBOX_CLIENT_ID=
DROPBOX_CLIENT_SECRET=

ZOOM_CLIENT_ID=
ZOOM_CLIENT_SECRET=

TRELLO_CLIENT_ID=
TRELLO_CLIENT_SECRET=

LINEAR_CLIENT_ID=
LINEAR_CLIENT_SECRET=

FIGMA_CLIENT_ID=
FIGMA_CLIENT_SECRET=

STRIPE_CLIENT_ID=
STRIPE_CLIENT_SECRET=

AIRTABLE_CLIENT_ID=
AIRTABLE_CLIENT_SECRET=
```

---

## lib/oauth-providers.js

Create this file that maps each `oauth_provider_name` to its OAuth config:

```javascript
// Each entry: what scopes to request, how to build the authorization URL,
// how to exchange the code for tokens, how to get the user's profile.
export const OAUTH_PROVIDERS = {
  google: {
    authUrl: 'https://accounts.google.com/o/oauth2/v2/auth',
    tokenUrl: 'https://oauth2.googleapis.com/token',
    profileUrl: 'https://www.googleapis.com/oauth2/v3/userinfo',
    clientId: process.env.GOOGLE_CLIENT_ID,
    clientSecret: process.env.GOOGLE_CLIENT_SECRET,
    // Scopes vary by connector (gmail vs drive vs calendar)
    // Passed dynamically from connector definition
  },
  github: {
    authUrl: 'https://github.com/login/oauth/authorize',
    tokenUrl: 'https://github.com/login/oauth/access_token',
    profileUrl: 'https://api.github.com/user',
    clientId: process.env.GITHUB_CLIENT_ID,
    clientSecret: process.env.GITHUB_CLIENT_SECRET,
  },
  slack: {
    authUrl: 'https://slack.com/oauth/v2/authorize',
    tokenUrl: 'https://slack.com/api/oauth.v2.access',
    profileUrl: 'https://slack.com/api/users.identity',
    clientId: process.env.SLACK_CLIENT_ID,
    clientSecret: process.env.SLACK_CLIENT_SECRET,
  },
  notion: {
    authUrl: 'https://api.notion.com/v1/oauth/authorize',
    tokenUrl: 'https://api.notion.com/v1/oauth/token',
    profileUrl: null, // returned in token response
    clientId: process.env.NOTION_CLIENT_ID,
    clientSecret: process.env.NOTION_CLIENT_SECRET,
  },
  spotify: {
    authUrl: 'https://accounts.spotify.com/authorize',
    tokenUrl: 'https://accounts.spotify.com/api/token',
    profileUrl: 'https://api.spotify.com/v1/me',
    clientId: process.env.SPOTIFY_CLIENT_ID,
    clientSecret: process.env.SPOTIFY_CLIENT_SECRET,
  },
  // Add remaining providers following same pattern
};
```

---

## api/oauth/start.js

```javascript
import crypto from 'crypto';
import jwt from 'jsonwebtoken';
import { supabase } from '../../lib/supabase.js';
import { OAUTH_PROVIDERS } from '../../lib/oauth-providers.js';

export default async function handler(req, res) {
  const { connector_id, user_id } = req.query;
  if (!connector_id || !user_id) return res.status(400).json({ error: 'Missing params' });

  // 1. Load connector from Supabase to get scopes + provider
  const { data: connector } = await supabase
    .from('connectors')
    .select('oauth_provider_name, oauth_scopes, oauth_authorization_url')
    .eq('connector_id', connector_id)
    .single();

  if (!connector) return res.status(404).json({ error: 'Connector not found' });

  const provider = OAUTH_PROVIDERS[connector.oauth_provider_name];
  if (!provider) return res.status(400).json({ error: 'Unsupported OAuth provider' });

  // 2. Generate PKCE code_verifier and code_challenge (OAuth 2.1 requirement)
  const codeVerifier = crypto.randomBytes(32).toString('base64url');
  const codeChallenge = crypto.createHash('sha256').update(codeVerifier).digest('base64url');

  // 3. Create signed state JWT (encodes: user_id, connector_id, code_verifier)
  // State prevents CSRF. code_verifier is stored server-side temporarily.
  const state = jwt.sign(
    { user_id, connector_id, code_verifier, ts: Date.now() },
    process.env.JWT_SECRET,
    { expiresIn: '10m' }
  );

  // 4. Build authorization URL
  const authUrl = new URL(connector.oauth_authorization_url || provider.authUrl);
  authUrl.searchParams.set('client_id', provider.clientId);
  authUrl.searchParams.set('redirect_uri', `${process.env.APP_URL}/api/oauth/callback`);
  authUrl.searchParams.set('response_type', 'code');
  authUrl.searchParams.set('scope', (connector.oauth_scopes || []).join(' '));
  authUrl.searchParams.set('state', state);
  authUrl.searchParams.set('code_challenge', codeChallenge);
  authUrl.searchParams.set('code_challenge_method', 'S256');
  authUrl.searchParams.set('access_type', 'offline'); // request refresh token (Google)
  authUrl.searchParams.set('prompt', 'consent'); // always show consent (ensures refresh token)

  res.redirect(authUrl.toString());
}
```

---

## api/oauth/callback.js

```javascript
import jwt from 'jsonwebtoken';
import { supabase } from '../../lib/supabase.js';
import { OAUTH_PROVIDERS } from '../../lib/oauth-providers.js';
import { encryptToken } from '../../lib/token-store.js';

export default async function handler(req, res) {
  const { code, state, error } = req.query;

  if (error) {
    return res.redirect(`${process.env.APP_DEEP_LINK_BASE}?status=error&reason=${error}`);
  }

  // 1. Verify and decode state JWT
  let decoded;
  try {
    decoded = jwt.verify(state, process.env.JWT_SECRET);
  } catch {
    return res.redirect(`${process.env.APP_DEEP_LINK_BASE}?status=error&reason=invalid_state`);
  }
  const { user_id, connector_id, code_verifier } = decoded;

  // 2. Load connector + provider config
  const { data: connector } = await supabase
    .from('connectors')
    .select('oauth_provider_name, oauth_token_url, oauth_scopes')
    .eq('connector_id', connector_id)
    .single();

  const provider = OAUTH_PROVIDERS[connector.oauth_provider_name];

  // 3. Exchange authorization code for tokens (back-channel, with PKCE verifier)
  const tokenRes = await fetch(connector.oauth_token_url || provider.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': 'application/json' },
    body: new URLSearchParams({
      grant_type: 'authorization_code',
      code,
      redirect_uri: `${process.env.APP_URL}/api/oauth/callback`,
      client_id: provider.clientId,
      client_secret: provider.clientSecret,
      code_verifier, // PKCE verifier — no client secret needed for public clients
    }),
  });
  const tokens = await tokenRes.json();

  if (!tokens.access_token) {
    return res.redirect(`${process.env.APP_DEEP_LINK_BASE}?status=error&connector_id=${connector_id}&reason=token_exchange_failed`);
  }

  // 4. Get user's profile from the external service
  let providerEmail = null, providerUserId = null;
  if (provider.profileUrl) {
    const profileRes = await fetch(provider.profileUrl, {
      headers: { Authorization: `Bearer ${tokens.access_token}` },
    });
    const profile = await profileRes.json();
    providerEmail = profile.email || profile.emailAddress || null;
    providerUserId = profile.id || profile.sub || profile.login || null;
  }

  // 5. Encrypt tokens and upsert to Supabase
  const expiresAt = tokens.expires_in
    ? new Date(Date.now() + tokens.expires_in * 1000).toISOString()
    : null;

  await supabase.from('user_connections').upsert({
    user_id,
    connector_id,
    auth_status: 'connected',
    access_token_encrypted: encryptToken(tokens.access_token),
    refresh_token_encrypted: tokens.refresh_token ? encryptToken(tokens.refresh_token) : null,
    token_expires_at: expiresAt,
    scopes: connector.oauth_scopes || [],
    provider_user_id: providerUserId,
    provider_email: providerEmail,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'user_id,connector_id' });

  // 6. Redirect back to the Flutter app via deep link
  res.redirect(`${process.env.APP_DEEP_LINK_BASE}?status=success&connector_id=${connector_id}`);
}
```

---

## api/execute.js (THE KEY ENDPOINT)

This is what Gemma calls after planning a connector action. It uses the user's own token.

```javascript
import { supabase } from '../lib/supabase.js';
import { decryptToken, refreshTokenIfNeeded } from '../lib/token-store.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).end();

  const { user_id, connector_id, action, params } = req.body;
  if (!user_id || !connector_id || !action) {
    return res.status(400).json({ error: 'Missing required fields' });
  }

  // 1. Load connector definition (to validate action is allowed)
  const { data: connector } = await supabase
    .from('connectors')
    .select('available_actions, feasibility')
    .eq('connector_id', connector_id)
    .single();

  if (!connector) return res.status(404).json({ error: 'Connector not found' });

  // 2. Gate check — action must be in the connector's defined list
  const allowedActions = connector.available_actions.map(a => a.name);
  if (!allowedActions.includes(action)) {
    return res.status(403).json({ 
      error: 'action_not_allowed',
      message: `Action '${action}' is not registered for connector '${connector_id}'. Allowed: ${allowedActions.join(', ')}`
    });
  }

  // 3. Load user's token
  const { data: connection } = await supabase
    .from('user_connections')
    .select('*')
    .eq('user_id', user_id)
    .eq('connector_id', connector_id)
    .single();

  if (!connection || connection.auth_status !== 'connected') {
    return res.status(401).json({ error: 'needs_auth', connector_id });
  }

  // 4. Decrypt + refresh token if expired
  const accessToken = await refreshTokenIfNeeded(connection, connector_id);
  if (!accessToken) {
    return res.status(401).json({ error: 'token_refresh_failed', connector_id });
  }

  // 5. Find the action definition and execute it
  const actionDef = connector.available_actions.find(a => a.name === action);
  
  try {
    // Build the request URL (replace path params)
    let url = actionDef.endpoint_template;
    Object.entries(params || {}).forEach(([key, value]) => {
      url = url.replace(`{${key}}`, encodeURIComponent(value));
    });

    // Remove path params from body/query params
    const pathParamKeys = (url.match(/\{([^}]+)\}/g) || []).map(m => m.slice(1, -1));
    const bodyParams = Object.fromEntries(
      Object.entries(params || {}).filter(([k]) => !pathParamKeys.includes(k))
    );

    const response = await fetch(url, {
      method: actionDef.http_method || 'POST',
      headers: {
        'Authorization': `Bearer ${accessToken}`,
        'Content-Type': 'application/json',
      },
      body: ['POST', 'PUT', 'PATCH'].includes(actionDef.http_method)
        ? JSON.stringify(bodyParams)
        : undefined,
    });

    const result = await response.json();

    if (!response.ok) {
      return res.status(response.status).json({ 
        error: 'api_error', 
        status: response.status,
        result 
      });
    }

    return res.status(200).json({ success: true, result });
  } catch (err) {
    return res.status(500).json({ error: 'execution_failed', message: err.message });
  }
}
```

---

## lib/token-store.js

```javascript
import crypto from 'crypto';
import { supabase } from './supabase.js';
import { OAUTH_PROVIDERS } from './oauth-providers.js';

const ALGORITHM = 'aes-256-gcm';
const KEY = Buffer.from(process.env.TOKEN_ENCRYPTION_KEY, 'utf-8').slice(0, 32);

export function encryptToken(token) {
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv(ALGORITHM, KEY, iv);
  const encrypted = Buffer.concat([cipher.update(token, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `${iv.toString('hex')}:${tag.toString('hex')}:${encrypted.toString('hex')}`;
}

export function decryptToken(encrypted) {
  const [ivHex, tagHex, dataHex] = encrypted.split(':');
  const decipher = crypto.createDecipheriv(ALGORITHM, KEY, Buffer.from(ivHex, 'hex'));
  decipher.setAuthTag(Buffer.from(tagHex, 'hex'));
  return decipher.update(Buffer.from(dataHex, 'hex'), 'binary', 'utf8') + decipher.final('utf8');
}

export async function refreshTokenIfNeeded(connection, connectorId) {
  const accessToken = decryptToken(connection.access_token_encrypted);
  
  // If token doesn't expire or not expired yet, return as-is
  if (!connection.token_expires_at) return accessToken;
  const expiresAt = new Date(connection.token_expires_at);
  if (expiresAt > new Date(Date.now() + 60_000)) return accessToken; // 1min buffer

  // Token is expired — try to refresh
  if (!connection.refresh_token_encrypted) return null;
  const refreshToken = decryptToken(connection.refresh_token_encrypted);

  const { data: connector } = await supabase
    .from('connectors')
    .select('oauth_provider_name, oauth_token_url')
    .eq('connector_id', connectorId)
    .single();
  
  const provider = OAUTH_PROVIDERS[connector.oauth_provider_name];

  const res = await fetch(connector.oauth_token_url || provider.tokenUrl, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'refresh_token',
      refresh_token: refreshToken,
      client_id: provider.clientId,
      client_secret: provider.clientSecret,
    }),
  });

  const tokens = await res.json();
  if (!tokens.access_token) return null;

  const newExpiry = tokens.expires_in
    ? new Date(Date.now() + tokens.expires_in * 1000).toISOString()
    : null;

  await supabase.from('user_connections').update({
    access_token_encrypted: encryptToken(tokens.access_token),
    refresh_token_encrypted: tokens.refresh_token
      ? encryptToken(tokens.refresh_token)
      : connection.refresh_token_encrypted,
    token_expires_at: newExpiry,
    updated_at: new Date().toISOString(),
  }).eq('id', connection.id);

  return tokens.access_token;
}
```

---

## admin/index.html

Build a clean single-page admin UI with:
- No framework — vanilla HTML + CSS + JS only
- Table listing all connectors with search
- Each row: Edit button (opens modal), Delete button, Toggle Active button
- Edit modal: all fields editable, large textarea for `system_prompt_extension`, JSON editor for `available_actions`
- Add New Connector button
- All calls to `/api/connectors` with `X-Admin-Key: your-admin-key` header in Authorization

---

## api/connectors.js

```javascript
import { supabase } from '../lib/supabase.js';

export default async function handler(req, res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Cache-Control', 's-maxage=30, stale-while-revalidate=120');

  const { query, category, user_id } = req.query;

  // Admin write operations
  if (req.method === 'POST' || req.method === 'PUT' || req.method === 'DELETE') {
    if (req.headers['x-admin-key'] !== process.env.ADMIN_API_KEY) {
      return res.status(403).json({ error: 'Unauthorized' });
    }
    // Handle CRUD for admin...
  }

  // Build catalog query
  let dbQuery = supabase
    .from('connectors')
    .select('connector_id, display_name, aliases, category, feasibility, auth_flow, description, tos_risk, icon_url, is_active, sort_order')
    .eq('is_active', true)
    .order('sort_order', { ascending: true });

  if (category) dbQuery = dbQuery.eq('category', category);

  if (query) {
    dbQuery = dbQuery.textSearch('display_name', query, { 
      type: 'websearch', 
      config: 'english' 
    });
  }

  const { data: connectors, error } = await dbQuery;
  if (error) return res.status(500).json({ error: error.message });

  // Merge user auth states if user_id provided
  if (user_id && connectors?.length) {
    const { data: connections } = await supabase
      .from('user_connections')
      .select('connector_id, auth_status, provider_email')
      .eq('user_id', user_id)
      .in('connector_id', connectors.map(c => c.connector_id));

    const connectionMap = {};
    (connections || []).forEach(c => { connectionMap[c.connector_id] = c; });

    return res.status(200).json(connectors.map(c => ({
      ...c,
      auth_status: connectionMap[c.connector_id]?.auth_status || 'notConnected',
      provider_email: connectionMap[c.connector_id]?.provider_email || null,
    })));
  }

  return res.status(200).json(connectors || []);
}
```

---

## vercel.json

```json
{
  "rewrites": [
    { "source": "/admin", "destination": "/admin/index.html" },
    { "source": "/admin/", "destination": "/admin/index.html" }
  ],
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Access-Control-Allow-Origin", "value": "*" },
        { "key": "Access-Control-Allow-Methods", "value": "GET, POST, PUT, DELETE, OPTIONS" },
        { "key": "Access-Control-Allow-Headers", "value": "Content-Type, Authorization, X-Admin-Key" }
      ]
    }
  ]
}
```

---

## package.json

```json
{
  "name": "zero-connector-marketplace",
  "version": "1.0.0",
  "type": "module",
  "dependencies": {
    "@supabase/supabase-js": "^2.39.3",
    "jsonwebtoken": "^9.0.2"
  }
}
```

---

## AFTER BUILDING AND DEPLOYING

1. Run `vercel deploy` (or `vercel --prod`)
2. Set all environment variables in the Vercel dashboard
3. Give me the deployed URL (e.g. `https://zero-connector-marketplace.vercel.app`)
4. Register OAuth apps on each developer portal:
   - Google: console.cloud.google.com → Credentials → OAuth 2.0 Client ID
     - Redirect URI: `https://your-vercel-url/api/oauth/callback`
   - GitHub: github.com/settings/applications/new
   - Slack: api.slack.com/apps → Create New App
   - Notion: notion.so/my-integrations → New Integration (OAuth)
   - Spotify: developer.spotify.com/dashboard → Create App
   - And so on for each provider
5. Add the client_id and client_secret for each to Vercel environment variables
6. The Flutter app will use the deployed URL — one line change in `marketplace_service.dart`
