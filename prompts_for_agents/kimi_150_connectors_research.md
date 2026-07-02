# KIMI RESEARCH PROMPT — Zero Ring 150 Connector Definitions

## WHAT YOU ARE BUILDING

You are researching connectors for **Zero Ring** — an offline-first AI assistant app that runs Gemma 4 E4B (a very small, 4-billion parameter quantized model) on an Android phone. 

The connector system works **exactly like Claude's MCP (Model Context Protocol)**:
- The user signs in with **their own account** (not the developer's API key) via OAuth 2.1 with PKCE
- The server stores the **user's access token** (scoped, short-lived, revocable) in Supabase
- When Gemma plans a tool call, the backend makes the API call **using the user's own token**
- The user has full control — they can revoke at any time
- **Zero Ring never uses or exposes the developer's API credentials to users**

## WHY THIS MATTERS FOR YOUR RESEARCH

For each connector you research, you must determine:
1. Does it have a **public OAuth 2.0 developer program** that allows third-party apps to act on users' behalf? (Self-serve)
2. Or does it require a **business partnership** to get API access? (Not viable for now)
3. Or does it have **no API at all** — only Android screen automation? (Accessibility-only)

**ONLY include connectors where users can realistically sign in with their OWN account and Zero Ring can act on their behalf.** Do NOT include connectors where the developer has to manually obtain an API key and share it.

---

## GEMMA 4 E4B CONSTRAINTS — CRITICAL

Gemma 4 E4B is very small (4B parameters, quantized). Its tool-calling accuracy depends entirely on the `system_prompt_extension`. You must design each extension to:

1. **Be extremely short and precise** — under 120 words. Gemma loses focus on long prompts.
2. **List the EXACT function names** Gemma is allowed to call, nothing else.
3. **State the EXACT required parameters** with their types. Gemma must not guess parameter names.
4. **Include one "stop rule"** — what Gemma must output if auth fails or the action is not in the list.
5. **Include one "grounding rule"** — for data-retrieval actions, Gemma must only report what the API actually returned, never fill in from its training data.

---

## OUTPUT SCHEMA (strict — every field required)

```json
{
  "connector_id": "snake_case_unique_id",
  "display_name": "Human Name",
  "aliases": ["alias1", "alias2", "how user might mention it in conversation"],
  "category": "communication|social|productivity|design|entertainment|shopping|food_delivery|finance|travel|developer|ai|health|smart_home|news|education|utilities|photography|business|cloud|crm|marketing",
  "feasibility": "selfServe|accessibilityOnly|partnershipOnly",
  "auth_flow": "oauth2_pkce|none",
  "oauth_authorization_url": "https://exact-url-from-developer-docs/authorize",
  "oauth_token_url": "https://exact-url-from-developer-docs/token",
  "oauth_scopes": ["minimum required scopes only"],
  "oauth_provider_name": "google|github|slack|notion|spotify|canva|linear|custom",
  "developer_portal": "https://exact-developer-portal-url",
  "description": "One sentence: what can Zero do for the user with this connector.",
  "tos_risk": false,
  "tos_note": "Only if tos_risk is true — what the risk is",
  "system_prompt_extension": "Under 120 words. Exact function names allowed. Exact required params. One stop rule. One grounding rule. No fluff.",
  "available_actions": [
    {
      "name": "exact_function_name",
      "description": "One sentence.",
      "http_method": "GET|POST|PUT|DELETE",
      "endpoint_template": "https://api.service.com/v1/endpoint/{param}",
      "params": {
        "param_name": {
          "type": "string|integer|boolean",
          "required": true,
          "description": "What it is",
          "source": "user_input|user_context|api_response"
        }
      }
    }
  ],
  "icon_url": "https://logo.clearbit.com/service.com",
  "notes": "Any important notes about rate limits, free tier limits, or special setup"
}
```

---

## CONNECTOR LIST TO RESEARCH (150 total)

Research each one. For connectors marked *(no public API)*, set `feasibility: "partnershipOnly"` and leave `available_actions` empty. For *(screen only)*, set `feasibility: "accessibilityOnly"` and `auth_flow: "none"`.

### Communication (15)
Gmail, Microsoft Outlook, Slack, Discord, Telegram Bot API, Zoom, Microsoft Teams, Twilio (SMS), SendGrid, Mailchimp, Resend, Linear (notifications), Intercom, Zendesk, PagerDuty

### Social Media (10)
Twitter/X (v2 API), LinkedIn, Reddit, Pinterest, Mastodon, Bluesky, YouTube Data API, GitHub Social, Dev.to, Hashnode  
*(Instagram, TikTok, Snapchat, BeReal = partnershipOnly — no public OAuth for 3rd party actions)*

### Productivity (15)
Notion, Todoist, Trello, Asana, Linear, Jira, Monday.com, ClickUp, Airtable, Google Tasks, Google Calendar, Obsidian (local vault via REST plugin), Cron, Calendly, Doist

### Design (6)
Canva, Figma, Adobe Express (Creative Cloud API), Miro, Penpot (self-hosted), Framer  
*(Sketch = desktop only, partnershipOnly)*

### Developer Tools (10)
GitHub, GitLab, Bitbucket, Vercel, Netlify, Railway, Render, Supabase Management API, PlanetScale, Cloudflare

### AI Services (8)
OpenAI (ChatGPT API — user's own key), Anthropic (Claude API — user's own key), Google Gemini API (user's own key), ElevenLabs, Stable Diffusion (via Automatic1111 local), Perplexity, Suno AI, Replicate

### Entertainment (6)
Spotify, YouTube Music (YouTube Data API), Last.fm, Plex, Letterboxd *(no API, accessibilityOnly)*, Goodreads *(no API, accessibilityOnly)*

### Shopping (8)
Amazon (Product Advertising API — requires partner application, partnershipOnly), Flipkart (partnershipOnly), Meesho (partnershipOnly), Myntra (partnershipOnly), Nykaa (partnershipOnly), Blinkit (partnershipOnly), Zepto (partnershipOnly), Shopify (selfServe — user's own store)

### Food Delivery (6)
Swiggy (partnershipOnly), Zomato (partnershipOnly), Uber Eats (partnershipOnly), DoorDash (Developer platform — selfServe for ordering), Dunzo (partnershipOnly), ONDC (open network — selfServe for registered apps)

### Finance (8)
Stripe (user's own account), Razorpay (user's own account), PhonePe (partnershipOnly), Paytm (partnershipOnly), Splitwise (selfServe OAuth), YNAB (selfServe OAuth), Plaid (selfServe for user's bank connections), Wise

### Travel (6)
Uber (selfServe — Uber Developer Platform), Ola (partnershipOnly), Rapido (partnershipOnly), Airbnb (partnershipOnly), Google Maps Platform (selfServe — user's own API key), IRCTC (partnershipOnly)

### Cloud Storage (6)
Google Drive, Dropbox, OneDrive (Microsoft Graph API), Box, AWS S3 (user's own account), Cloudflare R2

### Health & Fitness (5)
Google Fit (via Fitness API), Fitbit, Strava, MyFitnessPal *(partnershipOnly)*, Cronometer *(partnershipOnly)*

### Smart Home (5)
Google Home (Smart Device Management API), Philips Hue, Home Assistant (REST API — local), IFTTT Webhooks, SmartThings

### Utilities (6)
OpenWeatherMap, NewsAPI, Wikipedia (free API), WolframAlpha, DeepL (translation), Twilio (WhatsApp Business API via Twilio — user's own number)

---

## RESEARCH INSTRUCTIONS FOR KIMI

For EACH connector in the list:

1. **Search the developer portal** — find the exact OAuth 2.0 authorization URL, token URL, and minimum required scopes.
2. **Read the API docs** — find the 3-5 most useful actions for an AI assistant (send message, create task, read data, etc.). Get the exact endpoint URL template.
3. **Check rate limits and free tier** — note in the `notes` field.
4. **Write the system_prompt_extension** — follow Gemma 4 E4B constraints above. Include: exact allowed function names, required params, stop rule, grounding rule. Under 120 words.
5. **Verify OAuth availability** — if a service requires a business contract or has no public developer program, set `partnershipOnly`. Be honest — do NOT invent OAuth flows that don't exist.

## OUTPUT FORMAT

Output ONLY a valid JSON array starting with `[` and ending with `]`. No markdown fences, no explanation text. Every item must match the schema exactly. Validate that your JSON is parseable before outputting.
