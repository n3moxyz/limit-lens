# Limit Lens

Limit Lens is a small native macOS menu-bar app for watching local AI coding
assistant limits from the desktop.

- Codex: reads live ChatGPT/Codex buckets with `codex app-server` and
  `account/rateLimits/read`.
- Claude: reads `claude auth status --json`, optional Claude Code statusline
  rate-limit data, and recent local Claude Code activity. Claude Code exposes
  5-hour and 7-day all-model subscription usage through the documented
  `rate_limits` statusline payload after the first Claude.ai response.

Run it from Codex or the shell with:

```sh
./script/build_and_run.sh
```

## Claude Live Usage

Claude Code only provides live subscription percentages to local tools through
statusline JSON. Install the bridge once:

```sh
./script/install_claude_statusline_bridge.sh
```

The installer backs up `~/.claude/settings.json`, preserves your existing
statusline command, and writes a small local cache at:

```text
~/Library/Application Support/LimitLens/claude-rate-limits.json
```

After installation, send one message in Claude Code. Limit Lens will show the
5-hour/current-session and 7-day all-model values from that cache. Claude's
separate Sonnet-only weekly bar is visible in Claude Settings > Usage, but it is
not present in the documented statusline payload today.

## Privacy

Limit Lens runs locally. It does not upload Claude Code transcript contents,
Codex account details, or local usage history to any Limit Lens service.

The app shells out to the locally installed `codex` and `claude` CLIs:

- Codex limit data comes from the local Codex app-server. That CLI may contact
  OpenAI as part of its normal signed-in behavior.
- Claude status data comes from `claude auth status --json`.
- Claude live usage comes from the optional statusline bridge cache. The bridge
  stores only model identity and `rate_limits` percentages/reset times, not
  transcript text.
- Claude local usage estimates are derived from metadata in local `.claude`
  JSONL history files, such as timestamps, message type, model name, and usage
  token counters.
- Claude Sonnet-only weekly usage is intentionally not guessed from local files
  because Claude does not currently expose that separate Settings bar through
  Claude Code statusline JSON.

## Project Status

This is an unofficial desktop utility. It is not affiliated with, endorsed by,
or sponsored by OpenAI, Anthropic, Codex, or Claude. Product names are used only
to identify compatible local tools and services.

## License

MIT License. See [LICENSE](LICENSE).
