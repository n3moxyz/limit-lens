# Codex App-Server Source

Limit Lens reads Codex usage through the local Codex app-server JSON-RPC surface.

## Request Flow

The app starts `codex app-server`, sends `initialize`, `initialized`, `account/read`, and `account/rateLimits/read`, then parses line-delimited JSON-RPC responses.

`account/read` provides setup/account state. `account/rateLimits/read` provides rate-limit buckets.

## Parsed Fields

- `rateLimits` is the backward-compatible single-bucket response.
- `rateLimitsByLimitId` is the multi-bucket response.
- `limitId` becomes `LimitBucket.id`.
- `limitName` becomes the bucket title when present.
- `primary` and `secondary` become `LimitWindow` values.
- `usedPercent` is a percentage, not a fraction.
- `windowDurationMins` drives the visible label and pacing math.
- `resetsAt` is a Unix timestamp in seconds.
- `planType`, `credits`, and `rateLimitReachedType` are surfaced when available.

Limit Lens currently keeps the user-facing Codex bucket when `limitId == "codex"` is present.

## Failure Behavior

If a refresh fails after a previous good snapshot, the last good Codex data remains visible and the provider state becomes `Stale`. This keeps routing useful while making the failed refresh clear in the detail view diagnostics.

## Why This Source

This is more stable than reading `~/.codex/auth.json` and calling ChatGPT private HTTP endpoints directly. The app-server method is the integration surface documented for host apps, and it lets Codex own token refresh.
