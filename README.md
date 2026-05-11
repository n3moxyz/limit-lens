# Limit Lens

Limit Lens is a small native macOS menu-bar app for watching local AI coding
assistant limits from the desktop.

- Codex: reads live ChatGPT/Codex buckets with `codex app-server` and
  `account/rateLimits/read`.
- Claude: reads `claude auth status --json` and estimates recent Claude Code
  activity from local `.claude` JSONL history. Claude Code exposes account and
  subscription metadata, but not the same machine-readable live quota buckets as
  Codex; use interactive Claude Code `/status` or Claude Settings > Usage for
  exact remaining allocation.

Run it from Codex or the shell with:

```sh
./script/build_and_run.sh
```

## Privacy

Limit Lens runs locally. It does not upload Claude Code transcript contents,
Codex account details, or local usage history to any Limit Lens service.

The app shells out to the locally installed `codex` and `claude` CLIs:

- Codex limit data comes from the local Codex app-server. That CLI may contact
  OpenAI as part of its normal signed-in behavior.
- Claude status data comes from `claude auth status --json`.
- Claude local usage estimates are derived from metadata in local `.claude`
  JSONL history files, such as timestamps, message type, model name, and usage
  token counters.
- Claude exact remaining subscription usage is intentionally not guessed from
  local files because Claude usage is shared across Claude web, desktop, and
  Claude Code.

## Project Status

This is an unofficial desktop utility. It is not affiliated with, endorsed by,
or sponsored by OpenAI, Anthropic, Codex, or Claude. Product names are used only
to identify compatible local tools and services.

## License

MIT License. See [LICENSE](LICENSE).
