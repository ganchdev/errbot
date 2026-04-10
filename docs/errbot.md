# Personal Exception Tracker — Product Spec + Implementation Plan

## Overview

Build a very small, self-hosted exception tracker for personal apps and low-traffic projects.

The goal is **not** to clone Sentry. The goal is to reuse Sentry client tooling in apps (`sentry-ruby`, Sentry JS, etc.), send exception events to a custom backend, store them simply, notify via Telegram, and provide a lightweight web UI for reviewing issues.

This system should be intentionally small, easy to understand, and cheap to run.

---

# Goals

## Primary goals

- Reuse Sentry SDKs in apps for exception capture and metadata enrichment
- Avoid self-hosting full Sentry
- Send exception data to a custom backend
- Notify the owner via Telegram
- Provide a basic web interface for reviewing and grouping errors
- Keep infrastructure simple enough to run on one VM

## Non-goals

- Full Sentry protocol compatibility
- Full APM, tracing, profiling, session replay, attachments, or release health
- Multi-tenant SaaS product
- High-scale ingestion pipeline
- Advanced grouping heuristics comparable to Sentry
- Real-time streaming architecture

---

# Core idea

Applications continue to use Sentry SDKs because they already provide:

- automatic exception capture
- stack trace extraction
- context gathering
- tags, breadcrumbs, environment, release
- framework integrations

Instead of sending events to Sentry, the SDK transport is redirected to a custom backend.

There are two possible approaches:

## Option A: Accept raw Sentry envelopes

The backend accepts Sentry-style envelopes and parses the event item.

### Pros
- More standard
- Easier to support multiple Sentry SDKs consistently

### Cons
- Slightly more backend complexity
- Need envelope parsing logic

## Option B: Use custom transports that transform data into a simplified JSON payload

Each SDK transport maps the Sentry event into a custom JSON shape before POSTing it to the backend.

### Pros
- Simplest backend
- Easier to debug
- Easier schema design

### Cons
- Need one mapping implementation per language/runtime

## Recommended approach

Start with a **hybrid of Option B and a very small subset of Option A**.

Reason:
- The intended use is small-scale and personal
- Simplicity is more important than protocol purity
- The backend should remain tiny
- Most value comes from the client-side capture, not server-side protocol compatibility
- A thin Sentry `store`/`envelope` parser makes it possible to point basic SDK DSNs at Errbot without committing to full Sentry protocol support

The Phase 1 implementation should continue to normalize everything into the same internal event shape before persistence.

---

# High-level architecture

## Components

### 1. Client apps
Apps use Sentry SDKs with a custom transport.

Examples:
- Rails app using `sentry-ruby`
- Node app using Sentry JS SDK
- Browser frontend using Sentry browser SDK if needed later

### 2. Collector web app
A small backend service that:
- receives exception payloads
- authenticates the sender
- normalizes data
- groups events into issues
- stores raw and normalized event data
- triggers Telegram notifications

### 3. Database
Use **SQLite** initially.

Why:
- traffic is low
- setup is trivial
- backup is simple
- operational cost is minimal

### 4. Notification worker
A lightweight background process or loop that sends Telegram alerts for newly created or reactivated issues.

### 5. Admin web UI
A simple internal interface for:
- viewing issues
- viewing individual events
- resolving or ignoring issues
- filtering by project/environment/release/status

---

# Deployment model

## Recommended v1 deployment

- One VM
- One Rails app (or equivalent web app)
- One SQLite database file
- One background worker process
- One reverse proxy (optional but recommended)
- HTTPS enabled

## Why this is sufficient

This project is intended for:
- personal apps
- low traffic
- low event volume
- minimal operational overhead

A queue broker, distributed workers, sharding, and multi-service architecture are unnecessary in v1.

---

# Functional requirements

## Ingestion

The system must allow applications to submit exception events over HTTP.

### Required behavior
- Accept POST requests from trusted apps
- Authenticate each request using a project-specific token
- Parse and validate incoming payloads
- Store raw payload
- Extract normalized fields
- Group into an issue
- Create a new event record
- Mark whether notification should be sent

## Grouping

The system must group similar exceptions into issues.

### Initial grouping strategy
Group by a fingerprint hash computed from:
- exception class/type
- top in-app stack frame filename
- top in-app function/method
- optionally line number

This should be simple and deterministic.

### Notes
This does not need to be perfect. It only needs to be useful enough for personal debugging.

## Notifications

The system must send Telegram messages for important issue events.

### Notification rules for v1
Send a Telegram message when:
- a new issue is first created
- a resolved issue reappears
- an ignored issue is manually re-opened and then reappears

### Optional later rules
- send again after N hours of silence
- send when occurrence count crosses thresholds (10, 50, 100)
- send when a new release begins triggering the issue
- send when production is affected for the first time

## Web UI

The system must provide a private admin UI.

### Minimum views

#### Issues index
Show:
- title
- project
- environment
- status
- occurrence count
- first seen
- last seen
- latest release
- latest exception type

#### Issue detail
Show:
- issue summary
- grouped metadata
- latest event details
- event history
- raw JSON payload
- stack trace
- tags
- breadcrumbs if available

#### Events view
Optional separate list of recent events.

#### Status actions
Allow:
- resolve issue
- ignore issue
- re-open issue

---

# Non-functional requirements

## Simplicity
The system should be understandable by one developer and maintainable without significant ops overhead.

## Reliability
The system should prioritize storing the event first, then notifying later.

## Privacy
The system must avoid leaking sensitive request data into Telegram notifications.

## Extensibility
The system should allow future migration from SQLite to Postgres without major rewrites.

---

# Data model

## Projects

Represents an application/source sending exceptions.

### Fields
- `id`
- `name`
- `slug`
- `ingest_token`
- `default_environment` (optional)
- `created_at`
- `updated_at`

---

## Issues

Represents a grouped exception/problem.

### Fields
- `id`
- `project_id`
- `fingerprint_hash`
- `title`
- `culprit`
- `status` (`open`, `resolved`, `ignored`)
- `level`
- `platform`
- `first_seen_at`
- `last_seen_at`
- `occurrences_count`
- `last_release`
- `last_environment`
- `created_at`
- `updated_at`

### Notes
Add a unique constraint on:
- `project_id`
- `fingerprint_hash`

---

## Events

Represents an individual occurrence of an exception.

### Fields
- `id`
- `project_id`
- `issue_id`
- `event_uuid`
- `occurred_at`
- `environment`
- `release`
- `server_name`
- `transaction_name`
- `exception_type`
- `exception_message`
- `handled` (boolean, optional)
- `level`
- `raw_json`
- `notification_state` (`pending`, `sent`, `skipped`, `failed`)
- `notified_at` (optional)
- `created_at`

### Notes
`raw_json` stores the original normalized payload received from the client.

---

## EventTags

### Fields
- `id`
- `event_id`
- `key`
- `value`

---

## Optional: IssueStates history

Useful later if wanting auditability for resolve/ignore actions.

### Fields
- `id`
- `issue_id`
- `from_status`
- `to_status`
- `changed_by`
- `changed_at`

---

# Suggested normalized event payload

This is the payload the custom client transport should POST to the backend.

```json
{
  "auth": {
    "project_token": "project_secret_token"
  },
  "event": {
    "event_id": "uuid-or-sentry-event-id",
    "timestamp": "2026-04-05T10:15:00Z",
    "platform": "ruby",
    "level": "error",
    "environment": "production",
    "release": "2026.04.05.1",
    "server_name": "web-1",
    "transaction": "POST /payments",
    "tags": {
      "runtime": "ruby-3.3.0"
    },
    "user": {
      "id": "123"
    },
    "request": {
      "url": "https://example.com/payments",
      "method": "POST"
    },
    "exception": {
      "type": "NoMethodError",
      "value": "undefined method `id' for nil:NilClass",
      "stacktrace": {
        "frames": [
          {
            "filename": "app/services/payments/charge_customer.rb",
            "function": "call",
            "lineno": 42,
            "in_app": true
          }
        ]
      }
    },
    "breadcrumbs": [
      {
        "timestamp": "2026-04-05T10:14:58Z",
        "category": "sql.active_record",
        "message": "SELECT ..."
      }
    ],
    "contexts": {
      "runtime": {
        "name": "ruby",
        "version": "3.3.0"
      }
    },
    "extra": {
      "job_id": "abc123"
    }
  }
}
````

---

# Ingestion API spec

## Endpoints

Custom transport endpoint:

`POST /api/v1/events`

Thin Sentry-compatible endpoints:

`POST /api/:project_id/store`

`POST /api/:project_id/envelope`

## Authentication

Use a project-specific secret token.

### Recommendation

Use header:

* `Authorization: Bearer <project_token>`

Alternative:

* token embedded in JSON payload

Header-based auth is preferred.

For the Sentry-compatible endpoints, use the project `ingest_token` as the Sentry key:

* `X-Sentry-Auth: Sentry sentry_version=7, sentry_key=<project_token>`
* or `?sentry_key=<project_token>`

The `:project_id` path segment can be the Errbot project id or slug.

## Request content type

Custom and Sentry store requests use:

`application/json`

Sentry envelope requests use:

`application/x-sentry-envelope`

## Response

### Success

`201 Created`

```json
{
  "ok": true,
  "issue_id": 123,
  "event_id": "..."
}
```

### Unauthorized

`401 Unauthorized`

### Invalid payload

`400 Bad Request`

Returned when the payload is malformed, contains no exception data, or contains an unsupported Sentry item such as a transaction.

---

# Grouping algorithm v1

## Inputs

* exception type
* top in-app frame filename
* top in-app frame function
* optional line number

## Algorithm

1. Get `exception.type`
2. Find first stack frame where `in_app == true`
3. Use:

   * exception type
   * filename
   * function
   * line number (optional)
4. Join into a string
5. Hash string using SHA256
6. Store as `fingerprint_hash`

## Example source string

```text
NoMethodError|app/services/payments/charge_customer.rb|call|42
```

## Notes

If no in-app frame exists, fall back to:

* first available frame
* or exception type + exception message prefix

---

# Telegram notification spec

## Purpose

Telegram is the primary alerting channel for the owner.

## Bot behavior

* Send concise alerts
* Include enough information to decide urgency
* Include link to issue page
* Avoid dumping full payloads

## Message template

```text
🚨 {project} / {environment}
{exception_type}: {exception_message}

Where: {culprit}
Count: {occurrences_count}
First seen: {first_seen_at}
Last seen: {last_seen_at}
Release: {release}

{issue_url}
```

## Notification safety rules

Never include:

* cookies
* authorization headers
* full request params
* secrets/tokens
* session data
* raw PII unless explicitly allowed

---

# Auth spec

## Overview

Use Google OAuth via OmniAuth for admin login. Only pre-authorized users can access the system.

## Data model

### Users

Represents an authenticated user who can access the admin UI.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| email_address | string | Unique, from Google |
| name | string | Full name from Google |
| first_name | string | First name |
| last_name | string | Last name |
| image | string | Profile image URL |
| admin | boolean | Can manage projects and authorized users |
| created_at | datetime | |
| updated_at | datetime | |

### AuthorizedUsers

Whitelist of emails allowed to log in. Admin adds emails here before users can authenticate.

| Field | Type | Description |
|-------|------|-------------|
| id | integer | Primary key |
| email_address | string | Email to authorize |
| user_id | integer | FK to Users (filled after first login) |
| created_at | datetime | |
| updated_at | datetime | |

### Indexes

- `index_authorized_users_on_user_id`

## Auth flow

1. Admin adds an email to `authorized_users`
2. User visits `/auth/google`
3. OmniAuth redirects to Google
4. After Google auth, callback at `/auth/google/callback`
5. Controller checks if email is in `authorized_users`
6. If authorized: find or create `User`, start session, redirect to dashboard
7. If not authorized: redirect with error

## OmniAuth configuration

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_APP_SECRET"],
           scope: "email, profile"
end
OmniAuth.config.full_host = ENV["APP_HOST"]
```

## Auth controller

Single controller handles all auth operations:

```ruby
class AuthController < ApplicationController
  layout "auth"

  allow_unauthenticated_access only: [:new, :callback]
  rate_limit to: 10, within: 3.minutes, only: :new, with: :redirect_on_rate_limit

  before_action :redirect_if_authenticated, only: [:new, :callback]

  def callback
    auth_data = request.env["omniauth.auth"]["info"]
    auth_user = AuthorizedUser.find_by(email_address: auth_data["email"])

    unless auth_user
      redirect_to auth_path, alert: "Not authorized"
      return
    end

    user = find_or_create_user(auth_data, auth_user)
    start_new_session_for(user)
    redirect_to after_authentication_url
  end

  def destroy
    terminate_session
    redirect_to auth_path, notice: "Logged out"
  end

  private

  def find_or_create_user(auth_data, auth_user)
    user = User.find_or_initialize_by(email_address: auth_data["email"]) do |u|
      u.name = auth_data["name"]
      u.first_name = auth_data["first_name"]
      u.last_name = auth_data["last_name"]
      u.image = auth_data["image"]
    end

    if user.new_record?
      user.save!
      auth_user.update(user: user)
    end

    user
  end
end
```

## Routes

```ruby
get  "/auth",          to: "auth#new",      as: :auth
get  "/auth/google",  to: "auth#new"
get  "/auth/google/callback", to: "auth#callback"
delete "/logout",     to: "auth#destroy",  as: :logout
```

## Admin-only actions

Only users with `admin: true` can:
- Create/edit/delete projects
- Add/remove authorized users
- Resolve/ignore issues

Non-admin users can:
- View issues and events
- Re-open resolved issues

---

# Web UI spec

## Pages

### Issues list

Columns:

* status
* project
* title
* occurrences
* first seen
* last seen
* environment
* release

### Issue detail

Sections:

* summary
* stack trace
* recent events
* raw event JSON
* tags
* breadcrumbs
* action buttons

### Filters

* project
* status
* environment
* release
* date range

---

# Privacy and security requirements

## Ingestion auth

Every project must have a secret ingest token.

## Transport security

Use HTTPS in production.

## Data scrubbing

Scrub or remove:

* `Authorization` header
* cookies
* passwords
* tokens
* secrets
* session IDs

## Telegram scrubbing

Telegram messages must contain only a safe summary.

## UI security

All admin UI routes require authentication via Google OAuth. See Auth spec above.

---

# Operational design

## Database choice

### v1: SQLite

Use SQLite initially.

### Why

* simplest deployment
* zero extra service dependency
* enough for low write volume
* easy backup and restore

### When to switch to Postgres

Switch only if:

* concurrent writes become a problem
* event volume grows significantly
* search/filtering becomes more complex
* future analytics require better SQL features

## Queue choice

### v1

No external queue broker.

### Recommended processing model

* store event synchronously
* mark notification as pending
* background worker polls pending notifications
* send Telegram
* mark result

### Why

This is enough for low traffic and avoids Redis/RabbitMQ/Kafka complexity.

---

# Failure handling

## Event ingestion failure

If event validation fails:

* log failure
* return 422
* do not store incomplete data unless using a dead-letter table later

## Notification failure

If Telegram fails:

* keep event stored
* mark `notification_state = failed`
* retry later with backoff

## DB failure

Return 500 and log error.

---

# Suggested implementation stack

## Recommended stack

* Rails app
* SQLite
* background job loop or worker process
* Telegram Bot API
* simple server-rendered HTML UI

## Why Rails

* fast to build
* easy admin UI
* good fit if main apps are already Rails
* easy SQLite support

---

# Client integration design

## Ruby / Rails

Use `sentry-ruby` with a custom transport.

### Responsibilities of custom transport

* receive event from Sentry SDK
* transform to normalized JSON payload
* POST to backend endpoint
* include project token

### Keep using Sentry SDK features

* `capture_exception`
* automatic Rails integration
* context enrichment
* breadcrumbs
* release/environment tagging

## JavaScript / Node

Later implement a similar transport or custom event processor if needed.

---

# Minimal milestone plan

## Phase 1 — Core collector

Build the backend that can:

* authenticate project
* receive JSON payload
* validate payload
* compute fingerprint
* create/find issue
* create event
* store raw JSON

### Deliverables

* DB schema
* projects/issues/events models
* `POST /api/v1/events`
* issue grouping logic

## Phase 2 — Telegram alerts

Add notification pipeline.

### Deliverables

* Telegram bot integration
* notification worker
* first-seen issue alerts
* retry handling

## Phase 3 — Basic web UI

Build a minimal internal dashboard.

### Deliverables

* issues index
* issue detail page
* event history
* resolve/ignore actions

## Phase 4 — Hardening

Add production safety and quality improvements.

### Deliverables

* request/header scrubbing
* better fingerprinting
* filter/search UI
* basic pagination
* basic tests
* backups for SQLite

## Phase 5 — Optional improvements

Only add if real use demands it.

### Possible additions

* Postgres migration
* issue comments
* rate limiting
* release tracking
* recurring notification thresholds
* email alerts
* saved filters
* source maps or better JS handling
* broader Sentry envelope support

---

# Concrete implementation plan

## Step 1: Create Rails app

Create a Rails app dedicated to exception tracking.

### Requirements

* server-rendered app
* SQLite
* Google OAuth via OmniAuth
* API endpoint namespace

### Auth setup

* Add `gem "omniauth-google-oauth2"` and `gem "omniauth-rails_csrf_token"`
* Configure OmniAuth middleware
* Create `users` and `authorized_users` tables
* Create `AuthController` with callback and destroy actions
* Add auth routes
* Protect all non-API routes with authentication

## Step 2: Create schema

Add tables:

* `users` - authenticated users with admin flag
* `authorized_users` - email whitelist
* `projects`
* `issues`
* `events`
* `event_tags`

## Step 3: Implement ingestion endpoint

Build `POST /api/v1/events`.

### Responsibilities

* authenticate project token
* parse JSON
* validate minimum required fields
* normalize event
* scrub sensitive fields
* persist event and issue in one transaction

Also expose the narrow Sentry-compatible routes:

* `POST /api/:project_id/store`
* `POST /api/:project_id/envelope`

These routes should only parse exception events and then hand the normalized payload to the same ingestion service as the custom endpoint.

## Step 4: Implement grouping service

Create a service object:

* extracts top frame
* computes fingerprint hash
* creates or updates issue

## Step 5: Implement notification state machine

For each ingested event:

* determine whether Telegram should be sent
* mark notification state

## Step 6: Implement Telegram worker

Build a worker that:

* fetches pending notifications
* sends Telegram message
* updates notification status

## Step 7: Build admin UI

Pages:

* `/issues`
* `/issues/:id`

Actions:

* resolve
* ignore
* re-open

## Step 8: Build Ruby client transport

Create a small library or internal module for Rails apps that:

* hooks into Sentry transport
* maps event to normalized JSON
* posts to backend with auth token

## Step 9: Add observability for the tracker itself

Add:

* application logs
* request logs
* notification failure logs
* optional health endpoint

## Step 10: Add backup and retention

For SQLite:

* nightly backup
* optional retention rules for old events
* optional event pruning while keeping issue aggregates

---

# Validation rules

## Required fields in incoming payload

At minimum:

* event ID
* timestamp
* platform
* exception type or equivalent error title

## Nice-to-have fields

* environment
* release
* stack trace
* tags
* request URL/method
* breadcrumbs

## Rejection rules

Reject if:

* auth missing
* payload malformed
* no useful exception data present

---

# Retention policy

## v1

Keep everything unless disk usage becomes a concern.

## Optional later policy

* keep issues forever
* keep raw events for 90–180 days
* prune breadcrumbs/extra data older than retention target
* keep counts and timestamps even after raw event deletion

---

# Risks and tradeoffs

## Risk: custom transport per language

This is manageable if most apps are Rails first.

## Risk: grouping quality

Initial grouping will be imperfect, but acceptable for personal use.

## Risk: SQLite limits

Fine for low traffic. Revisit only when real problems appear.

## Risk: Telegram noise

Mitigate with first-seen-only alerts initially.

## Risk: sensitive data leakage

Must implement scrubbing before storage and before notification.

---

# Recommendation summary

Build a **small Rails app on one VM with SQLite**.

Use **Sentry SDKs in apps**, but replace the delivery transport so exceptions go to the custom backend.

Store:

* normalized issue/event data
* raw JSON payloads

Do **not** add:

* Kafka
* Redis queues
* RabbitMQ
* Postgres
* microservices
* full Sentry protocol compatibility

unless actual usage later proves the need.

This project should start as a **personal Sentry-lite**, not a Sentry clone.

---

# Suggested first deliverable

A working v1 should support:

* Google OAuth login for admin
* authorized_users table for email whitelist
* one project/app sending exceptions
* custom Ruby transport
* event ingestion endpoint
* issue grouping
* SQLite persistence
* Telegram alert on new issue
* issue list page
* issue detail page
* resolve/ignore actions

That is enough to be immediately useful.

---

# Suggested prompt for an implementation LLM

Build a Rails application called `error_tracker` implementing the spec above.

Requirements:

* use Rails with SQLite
* build models for User, AuthorizedUser, Project, Issue, Event, and EventTag
* use Google OAuth via OmniAuth for admin authentication
* only pre-authorized emails (in authorized_users table) can log in
* create `POST /api/v1/events`
* authenticate with bearer token mapped to Project
* store normalized event data and raw JSON
* group events into issues using fingerprint hash from exception type + top in-app frame
* add a Telegram notification worker for new issues
* create simple HTML pages for issues index and issue detail
* add actions to resolve, ignore, and re-open issues
* keep implementation simple and server-rendered
* do not add Redis, Kafka, RabbitMQ, or Postgres
* prefer plain Rails patterns and service objects
* optimize for readability and low operational complexity
