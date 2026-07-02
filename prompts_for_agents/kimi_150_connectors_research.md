# KIMI RESEARCH PROMPT — 150 Connectors for Zero Ring

Paste this entire prompt into Kimi or Cursor Agent. It will research and output the full connector JSON.

---

## YOUR TASK

You are an expert AI product engineer. Research 150 popular apps/services and output a valid JSON array of connector definitions for the Zero Ring AI assistant.

Zero Ring uses Gemma 4 E4B (a local on-device LLM) to call these connectors as tools. The `system_prompt_extension` field is CRITICAL — it must be laser-precise instructions that prevent Gemma from hallucinating endpoints, wrong parameters, or wrong behavior for that specific service.

## STRICT JSON SCHEMA (every item must match exactly):

```json
{
  "connector_id": "snake_case_unique_id",
  "display_name": "Human Readable Name",
  "aliases": ["alias1", "alias2"],
  "category": "one of: communication|social|productivity|design|entertainment|shopping|food_delivery|finance|travel|developer|ai|health|smart_home|news|education|utilities|photography|business|cloud|crm|marketing",
  "feasibility": "one of: selfServe|selfServeLimited|inviteGated|partnershipOnly|accessibilityOnly",
  "auth_type": "one of: oauth2|api_key|none",
  "oauth_provider": "google|github|slack|notion|canva|spotify|linear|null",
  "description": "One sentence: what Zero can do with this connector.",
  "tos_risk": false,
  "system_prompt_extension": "CRITICAL: Write 2-5 sentences of exact instructions Gemma must follow when calling THIS specific service. Include: (1) What it can and cannot do, (2) Which parameters are required vs optional, (3) What to say if the user asks for something not in available_actions, (4) Any rate limits or content policies to respect.",
  "available_actions": [
    {
      "name": "snake_case_action_name",
      "description": "What this action does in one sentence.",
      "params": {
        "param_name": {
          "type": "string|integer|boolean|array",
          "required": true,
          "description": "What this param is"
        }
      },
      "requires_premium": false
    }
  ],
  "icon_url": "https://logo.clearbit.com/website.com",
  "website": "https://developer.website.com"
}
```

## CATEGORY DISTRIBUTION (follow this exactly):

- Communication: 15 (Gmail, Outlook, Slack, Telegram, WhatsApp, Discord, Teams, Signal, Zoom, Twilio SMS, Intercom, Sendgrid, Mailchimp, Resend, Postmark)
- Social: 12 (Twitter/X, Instagram, LinkedIn, TikTok, Reddit, Pinterest, Mastodon, Threads, Bluesky, YouTube, Snapchat, BeReal)
- Productivity: 15 (Notion, Todoist, Trello, Asana, Linear, Jira, Monday, ClickUp, Airtable, Google Tasks, Reminders, Obsidian, Roam, Cron, Fantastical)
- Design: 8 (Canva, Figma, Adobe Express, Miro, Penpot, Excalidraw, Sketch, Framer)
- Developer: 10 (GitHub, GitLab, Bitbucket, Vercel, Netlify, Railway, Render, Supabase, PlanetScale, Neon)
- AI: 10 (ChatGPT, Claude, Gemini, Perplexity, Midjourney, Stable Diffusion, ElevenLabs, Suno, Kling, Runway)
- Entertainment: 8 (Spotify, YouTube Music, Apple Music, Netflix, Plex, Letterboxd, Goodreads, Steam)
- Shopping: 8 (Amazon, Flipkart, Meesho, Myntra, AJIO, Nykaa, Blinkit, Zepto)
- Food Delivery: 6 (Swiggy, Zomato, Uber Eats, DoorDash, Dunzo, ONDC)
- Finance: 10 (Razorpay, Stripe, PhonePe, Paytm, GPay, UPI, Splitwise, YNAB, Mint, Plaid)
- Travel: 8 (Uber, Ola, Rapido, MakeMyTrip, Ixigo, Airbnb, IRCTC, RedBus)
- Cloud Storage: 8 (Google Drive, Dropbox, OneDrive, Box, iCloud, S3, Backblaze, pCloud)
- Health: 8 (Google Fit, Apple Health, Fitbit, MyFitnessPal, Headspace, Calm, Strava, Cronometer)
- Smart Home: 6 (Google Home, Alexa, Home Assistant, Philips Hue, IFTTT, SmartThings)
- Utilities: 8 (Calendar, Maps, Weather (OpenWeather), News (NewsAPI), Wikipedia, WolframAlpha, QR Generator, Translator)

## RULES FOR SYSTEM_PROMPT_EXTENSION:

For each connector, the system_prompt_extension MUST:
1. Tell Gemma the exact name of valid actions. Example: "You may only call 'send_message' or 'read_messages'. Never call 'post' or 'create' as those are not valid for this connector."
2. State any content restrictions. Example: "Never generate bulk or spam messages. Always send one message per user request."
3. State what to do when auth is missing: "If the tool returns auth_error, output needs_auth and stop."
4. For search/retrieval: "Report ONLY what the tool result returns. Do NOT fill in prices, availability, or data from your training knowledge."
5. For actions involving user money (payments, purchases): "Always clarify the exact amount and recipient with the user BEFORE calling confirm_payment."

## FEASIBILITY GUIDE:
- `selfServe`: Has a free public developer portal with instant OAuth/API key (GitHub, Spotify, Canva, Notion, Slack, etc.)
- `selfServeLimited`: Free tier exists but rate-limited or feature-gated (OpenAI, ElevenLabs)
- `inviteGated`: Needs application/approval (Instagram Graph API, WhatsApp Business API)
- `partnershipOnly`: No public developer API exists (Zomato India, Swiggy India)
- `accessibilityOnly`: No API, Zero uses Android Accessibility Tree to automate (WhatsApp personal, any app with tos_risk: true)

## OUTPUT FORMAT:
Output ONLY a valid JSON array. No markdown, no explanation, no extra text. Start with `[` and end with `]`.
