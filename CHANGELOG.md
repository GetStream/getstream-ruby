## [Unreleased]

### Added

- New error class hierarchy under `GetStreamRuby`:
    * `StreamError < StandardError`. Abstract base for every SDK-raised exception.
    * `ApiError < StreamError`. Raised on any HTTP 4xx/5xx, and on responses whose body cannot be parsed as the canonical `APIError` envelope. Exposes `status_code`, `code`, `message`, `exception_fields`, `unrecoverable`, `raw_response_body`, `more_info`, `details`. Previously only `message` survived.
    * `RateLimitError < ApiError`. Raised on HTTP 429. Adds `retry_after` (Float seconds, nil when the header is absent). Parses the `Retry-After` response header per RFC 7231 in both integer-seconds and HTTP-date forms. Past HTTP-dates clamp to 0.
    * `TransportError < StreamError`. Raised when no HTTP response is received (connection reset, timeout, TLS handshake failure, DNS failure). Exposes `error_type` from the enum `connection_reset`, `timeout`, `dns_failure`, `tls_handshake_failed`, `unknown`. Always raised inside the matching `rescue Faraday::Error` block, so `Exception#cause` is set to the underlying Faraday error.
    * `TaskError < StreamError`. Raised by `wait_for_task` when an async task finishes with `status="failed"`. Exposes `task_id`, `error_type`, `description`, `stack_trace`, `version`.
- New `Client#wait_for_task(task_id, poll_interval: 1, timeout: 60)` helper. Polls `/api/v2/tasks/:id` and: returns the task `result` payload when status reaches `completed`; raises `TaskError` when status reaches `failed`; raises `TransportError` with `error_type: "timeout"` when the deadline elapses.
- `Client#post` (and the multipart upload path) now deserialize the full canonical `APIError` envelope (`code`, `message`, `exception_fields`, `more_info`, `StatusCode`, `details`, `unrecoverable`, `duration`) and populate the new `ApiError` attributes.

### Changed

- The old `GetStreamRuby::APIError` constant remains as a deprecated alias for `GetStreamRuby::ApiError` for one minor cycle, slated for removal in v9.0. First access emits a one-time `Kernel.warn` deprecation notice.
- The old `GetStreamRuby::Error` constant is preserved as an alias for `StreamError`. Existing `rescue GetStreamRuby::Error` clauses continue to match.
- Pre-flight multipart validation (`file name must be provided`, `file not found`) now raises `ArgumentError` instead of the old `APIError`. These are caller-side programming errors and don't belong on the API-error surface.

### Webhook helpers

- Webhook handling spec helpers (CHA-2961): `UnknownEvent` class for forward-compat;
  `gunzip_payload`, `decode_sqs_payload`, `decode_sns_payload` primitives;
  `parse_event` (returns typed event or `UnknownEvent` for unrecognized discriminators);
  `verify_and_parse_webhook` HTTP composite; `parse_sqs` / `parse_sns`
  queue composites (no signature; backend emits no HMAC for queue messages today).
  Security for queue-delivered payloads is enforced via AWS IAM on the SQS/SNS
  subscription, not in-SDK.
- New `Stream::Webhook` module alias (preferred). `StreamChat::Webhook` retained as
  backward-compat alias for one minor-version cycle.
- New unified error class: `StreamChat::Webhook::InvalidWebhookError` covering signature
  mismatch, invalid JSON, missing/non-string `type` field, gzip decompression failure,
  invalid base64 in a queue body, and malformed SNS envelopes. Distinguish failure modes
  via the message substring or `cause` chain rather than the class.
- New instance methods on `GetStreamRuby::Client`: `verify_signature(body, signature)` and
  `verify_and_parse_webhook(body, signature)` that drop the `api_secret` parameter in favor
  of the client's stored secret. Dual API: module-level methods remain available.
- New instance methods on `GetStreamRuby::Client`: `parse_sqs(message_body)` and
  `parse_sns(notification_body)` (no signature; AWS IAM).
- Conformance fixture suite under `test/fixtures/webhooks/` (14 event-type buckets plus
  `_invalid/` negative cases).

### Fixed

- Auth tokens now backdate the JWT `iat` claim by `Client::AUTH_IAT_LEEWAY_SECONDS`
  (5s). `iat` is a whole-second value (RFC 7519 NumericDate) and the server applies
  minimal forward leeway, so stamping `iat = Time.now.to_i` caused a small fraction of
  requests to be rejected with `token used before issue at (iat)` (HTTP 401) whenever the
  caller's clock was even marginally ahead of the server and the second-truncation landed
  on a boundary. Backdating keeps the token safely behind the server clock. The legacy
  `stream-chat-ruby` client never sent `iat`, so upgrades from it newly exposed this.
- `event_class_for_type` now references `GetStream::Generated::Models::*Event`
  (was `StreamChat::*Event`, which raised `NameError` at runtime). `parse_event`
  resolves known event types correctly.

## [7.1.0] - 2026-MM-DD

### Added (CHA-2956 connection pooling)

- New runtime dependency: `faraday-net_http_persistent ~> 2.3` + `net-http-persistent ~> 4.0`. Default Faraday adapter switched from `Faraday.default_adapter` (plain `Net::HTTP`, no pool) to `:net_http_persistent` (pooled). Matches legacy `stream-chat-ruby`.
- New constructor kwargs on `GetStreamRuby.manual` / `Configuration`:
    * `max_conns_per_host:` default `5`
    * `idle_timeout:` default `55` (seconds)
    * `connect_timeout:` default `10` (seconds)
    * `request_timeout:` default `30` (seconds)
    * `http_client:` escape hatch (`Faraday::Connection`); when set, the 4 knobs above are ignored.
- Per-call `request_timeout:` kwarg on `Client#make_request` for one-off overrides without rebuilding the client.
- One INFO log on `Client.new` listing the effective pool config + escape-hatch flag.

### Changed

- Default adapter is now `:net_http_persistent`; long-lived processes hold up to 5 idle TCP connections per upstream host until they age out at 55s.
- The `Connection: keep-alive` request header is no longer emitted on the default path (`net_http_persistent` keeps connections alive natively). Still emitted when the user opts into a custom `faraday_adapter` with `connection_keep_alive: true`.

### Backwards compatibility

- The `timeout:` kwarg remains as an alias for `request_timeout:`.
- The `faraday_adapter` kwarg remains as an alternate escape hatch. When set, `pool_size`/`idle_timeout` are NOT applied (those are `net_http_persistent`-specific).

## [6.0.0] - 2026-04-17

### major^2 changes
- 

## [5.0.0] - 2026-03-31

### major^2 changes
- 

## [4.1.0] - 2026-03-20

### minor^2 changes
- 

## [4.0.1] - 2026-03-19

### patch^2 changes
- 

## [4.0.0] - 2026-03-12

### major^2 changes
- 

# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [3.0.0] - 2026-03-05

### Breaking Changes

- Type names across all products now follow the OpenAPI spec naming convention: response types are suffixed with `Response`, input types with `Request`. See [MIGRATION_v2_to_v3.md](./MIGRATION_v2_to_v3.md) for the complete rename mapping.
- `Event` (WebSocket envelope type) renamed to `WSEvent`. Base event type renamed from `BaseEvent` to `Event` (with field `type` instead of `T`).
- Event composition changed from monolithic `*Preset` embeds to modular `Has*` types.
- `Pager` renamed to `PagerResponse` and migrated from offset-based to cursor-based pagination (`next`/`prev` tokens).

### Added

- Full product coverage: Chat, Video, Moderation, and Feeds APIs are all supported in a single SDK.
- **Feeds**: activities, feeds, feed groups, follows, comments, reactions, collections, bookmarks, membership levels, feed views, and more.
- **Video**: calls, recordings, transcription, closed captions, SFU, call statistics, user feedback analytics, and more.
- **Moderation**: flags, review queue, moderation rules, config, appeals, moderation logs, and more.
- Push notification types, preferences, and templates.
- Webhook support: `WHEvent` envelope class for receiving webhook payloads, utility methods for decoding and verifying webhook signatures, and a full set of individual typed event classes for every event across all products (Chat, Video, Moderation, Feeds) usable as discriminated event types.
- Cursor-based pagination across all list endpoints.

## [2.1.0] - 2026-02-18

## [2.0.0] - 2026-02-02

## [1.1.1] - 2026-01-29

## [1.1.0] - 2026-01-26

## [1.0.1] - 2025-12-11

## [1.0.0] - 2025-12-11

## [0.1.12] - 2025-10-13

## [0.1.11] - 2025-10-13

## [0.1.10] - 2025-10-13

## [0.1.9] - 2025-10-13

## [0.1.8] - 2025-10-13

## [0.1.7] - 2025-10-13

## [0.1.6] - 2025-10-13

## [0.1.5] - 2025-10-10

## [0.1.4] - 2025-10-10

## [0.1.3] - 2025-10-10

## [0.1.2] - 2025-10-08

## [0.1.1] - 2025-10-08

## [0.1.0] - 2025-10-07
