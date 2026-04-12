# Errbot — Simplified Implementation Plan

A minimal self-hosted exception tracker using Sentry SDKs → custom backend → SQLite + Telegram alerts.

---

## Stack

- **Backend**: Rails 8 with SQLite
- **Auth**: Google OAuth via OmniAuth (pre-authorized emails only)
- **Alerts**: Telegram Bot API
- **UI**: Server-rendered HTML

---

## Completed

- [x] Basic project structure
- [x] DB Schema
- [x] Authentication system
- [x] Authentication page + Dashboard

---

## Tasks

### Phase 1 — Core Collector

- [x] Create `POST /api/v1/events` endpoint
- [x] Authenticate project via `Authorization: Bearer <token>`
- [x] Parse and validate JSON payload
- [x] Implement fingerprint hashing (exception type + top in-app frame + function + lineno)
- [x] Create/find Issue based on fingerprint
- [x] Create Event record with raw JSON
- [x] Add Project model with ingest_token
- [x] Reject non-exception events (transactions)
- [x] Add thin Sentry-compatible ingest routes for SDK `store` and `envelope` requests
- [x] Normalize custom and Sentry exception payloads through shared ingestion services

### Phase 2 — Telegram Alerts

- [x] Create Telegram bot integration
- [x] Run BotUser migration
- [x] Create `/bot/verify` page (OAuth required)
- [x] Implement bot `/start` handler → ask for email
- [x] Implement email lookup in bot → send verification link
- [x] Implement code verification in bot → generate token
- [x] Build notification worker (background loop)
- [x] Send alert on new issue first occurrence
- [x] Send alert when resolved issue reappears
- [x] Handle failed notifications with retry
- [~] Add token to Authorization header for bot API requests (won't do for current polling-based bot setup)

### Phase 3 — Web UI

#### Design

- Need Light and Dark mode
- Accent color: something like #FF3300
- Background color: Light mode - white, Dark mode -gray
- Font: System
- Rounded borders

#### Implementation

- Use TailsindCSS
- Use ViewComponents
- Avoid using Rails view application helpers

#### Decisions

- Dashboard (`/`) is the main issues list page
- Issue pages are available to all signed-in authorized users
- Admin-only pages: Authorized Users CRUD and Projects CRUD
- Style the auth sign-in page (`/auth`)
- Style the bot verification page (`/bot/verify`)
- Keep Issue detail page (`/issues/:id`) basic for now: show title, status, project, occurrences, timestamps, environment/release, and issue actions
- Environment filter uses `issues.last_environment`
- Projects admin manages basic fields only: `name`, `slug`, `default_environment`; show `ingest_token` as read-only, with no rotation in Phase 3

#### Tasks

- [x] Style the auth sign-in page (`/auth/new`)
- [x] Style the bot verification page (`/bot/verify`)
- [x] Build Authorized Users CRUD pages for admin users only
- [x] Build Projects CRUD pages for admin users only
- [x] Build Dashboard index page which lists all issues (similar to what Issues index page `/issues` would look like)
- [x] Build Issue detail page (`/issues/:id`)
- [x] Add filters: project, status, environment
- [x] Add actions: resolve, ignore, re-open

### Phase 4 — Hardening

- [ ] Scrub sensitive data (cookies, auth headers, secrets)
- [ ] Add basic pagination
- [ ] Add SQLite backup script

---

## Data Model

| Table | Key Fields |
|-------|------------|
| projects | id, name, slug, ingest_token |
| issues | id, project_id, fingerprint_hash, title, status, occurrences_count, first_seen_at, last_seen_at |
| events | id, project_id, issue_id, event_uuid, exception_type, raw_json, notification_state |
| event_tags | id, event_id, key, value |
| users | id, email_address, name, admin |
| authorized_users | id, email_address, user_id |
| bot_users | id, authorized_user_id, code, api_token, chat_id, expires_at, linked_at |

---

## Telegram Bot Auth Flow

**Goal**: Secure the Telegram bot so only authorized users can interact with it.

**Flow**:

1. User visits bot chat → hits `/start`
2. Bot asks: "Enter your email address"
3. User enters email → bot checks `authorized_users` table
4. If email found → bot sends link to `/bot/verify` (requires Google OAuth login)
5. User clicks link, logs in via Google with the same authorized email, sees 6-digit verification code
6. User pastes code in bot → bot verifies code
7. On success → bot generates `SecureRandom.alphanumeric(32)` token, confirms "Linked!"

**Security**:
- Bot ignores messages from users not in `authorized_users`
- Verification codes expire after 10 minutes
- Linked bot API requests are authenticated via `Authorization: Bearer <token>` header
- Tokens can be revoked/rotated per user in admin UI

## Phase 1 Ingestion API

Errbot supports two Phase 1 ingestion modes:

1. A small custom JSON API for simple clients and custom transports.
2. A narrow Sentry-compatible API for clients that can point a DSN at Errbot.

This is not full Sentry protocol compatibility. Phase 1 only extracts exception event items and rejects transactions or other non-exception payloads.

### Custom JSON Endpoint

**POST `/api/v1/events`**

```
Authorization: Bearer <project_token>
Content-Type: application/json

{
  "event": {
    "event_id": "uuid",
    "timestamp": "2026-04-05T10:15:00Z",
    "platform": "ruby",
    "level": "error",
    "environment": "production",
    "release": "2026.04.05.1",
    "exception": {
      "type": "NoMethodError",
      "value": "undefined method `id' for nil:NilClass",
      "stacktrace": {
        "frames": [
          { "filename": "app/services/payments.rb", "function": "call", "lineno": 42, "in_app": true }
        ]
      }
    },
    "tags": { "runtime": "ruby-3.3.0" }
  }
}
```

**Response**: `201 Created` → `{ "ok": true, "issue_id": 123, "event_id": "..." }`

### Sentry-Compatible Endpoints

These endpoints exist so Sentry SDKs can send basic exception events to Errbot:

- `POST /api/:project_id/store`
- `POST /api/:project_id/envelope`

Authentication uses the project `ingest_token` as the Sentry public key:

- `X-Sentry-Auth: Sentry sentry_version=7, sentry_key=<project_token>`
- or `?sentry_key=<project_token>`

The `:project_id` path segment can be the Errbot project id or slug. For a DSN-like setup, use the `ingest_token` as the public key and the project slug/id as the DSN project id.

Accepted Sentry shapes:

- Store payloads with `exception.values`
- Envelope payloads containing an item with `"type": "event"` or `"type": "error"`

Unsupported Phase 1 shapes:

- transactions
- attachments
- profiles
- replays
- release health/session items

---

## Grouping Algorithm

1. Get exception type
2. Find first stack frame where `in_app == true`
3. Join: `type|filename|function|lineno`
4. SHA256 hash → fingerprint_hash
5. If there is no in-app frame, fall back to hashing the exception type only

---

## Constraints

- **Only exception events accepted** — transactions (performance events without exceptions) are rejected with `400 Bad Request`
- **Not full Sentry** — Phase 1 only parses the basic event data needed for grouping, storage, and later Telegram alerts
