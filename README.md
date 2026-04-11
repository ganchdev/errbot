# Errbot

Errbot is a small Rails exception tracker for personal and low-traffic apps. It stores exception events in SQLite, groups them into issues, and is intended to send Telegram alerts in the next phase.

## Phase 1 Collector

The collector currently accepts exception events through:

- `POST /api/v1/events` with `Authorization: Bearer <project_token>`
- `POST /api/:project_id/store` with `sentry_key=<project_token>`
- `POST /api/:project_id/envelope` with `sentry_key=<project_token>`

The Sentry-compatible endpoints are intentionally narrow. They parse basic exception events from Sentry `store` and `envelope` requests, then normalize them into the same internal event shape as the custom JSON endpoint. Transactions, attachments, profiling, replay, and release health payloads are out of scope for Phase 1.

## Development

Run the test suite:

```sh
bin/rails test
```

Run the app locally:

```sh
bin/dev
```

Run the Telegram bot poller locally:

```sh
bin/telegram
```

The poller uses long polling against the Telegram Bot API and expects `TELEGRAM_BOT_TOKEN` in your environment. For this first Phase 2 step it only responds to `/start`, which gives us a simple end-to-end check that the integration is working before we add account-linking and alert delivery.

See [docs/errbot-simplified.md](docs/errbot-simplified.md) for the active implementation plan and [docs/errbot.md](docs/errbot.md) for the larger product spec.
