# Claude Statusline Source

Limit Lens reads Claude usage from three local sources:

- `claude auth status --json` for sign-in and subscription setup state.
- The optional Limit Lens statusline bridge cache for live subscription percentages.
- Local Claude Code JSONL history for activity-only signals such as prompts and tokens.

## Statusline Bridge

Claude Code exposes live subscription usage in the documented statusline payload after a Claude.ai response. The bridge installed by `script/install_claude_statusline_bridge.sh` preserves any existing statusline command, writes only rate-limit metadata to:

```text
~/Library/Application Support/LimitLens/claude-rate-limits.json
```

The cache stores:

- capture time
- model id/display name
- `rate_limits.five_hour`
- `rate_limits.seven_day`

It does not store transcript text.

## Freshness

Windows with reset times in the past are ignored. If the cache has no fresh limit windows, the setup UI asks the user to send one Claude Code message and refresh.

## Known Gap

Claude’s separate Settings-only Sonnet weekly bar is not exposed in the statusline payload. Limit Lens shows that window as not reported instead of guessing from local files.
