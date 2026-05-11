#!/bin/sh
set -eu

claude_dir="${HOME}/.claude"
settings_file="${CLAUDE_SETTINGS_FILE:-${claude_dir}/settings.json}"
backup_dir="${claude_dir}/backups"
bridge_file="${claude_dir}/limit-lens-statusline-bridge.sh"
original_command_file="${claude_dir}/limit-lens-statusline-original-command"

mkdir -p "$claude_dir" "$backup_dir"

if [ ! -f "$settings_file" ]; then
  printf '{}\n' > "$settings_file"
fi

existing_command=$(/usr/bin/ruby -rjson -e '
path = ARGV.fetch(0)
settings = JSON.parse(File.read(path))
command = settings.dig("statusLine", "command")
puts command if command && !command.empty?
' "$settings_file" 2>/dev/null || true)

case "$existing_command" in
  *limit-lens-statusline-bridge.sh*)
    ;;
  *)
    printf '%s\n' "$existing_command" > "$original_command_file"
    ;;
esac

cat > "$bridge_file" <<'BRIDGE'
#!/bin/sh

input=$(cat)
cache_dir="${HOME}/Library/Application Support/LimitLens"
cache_file="${cache_dir}/claude-rate-limits.json"
original_command_file="${HOME}/.claude/limit-lens-statusline-original-command"

mkdir -p "$cache_dir"

printf '%s' "$input" | /usr/bin/ruby -rjson -e '
cache_file = ARGV.fetch(0)
payload = JSON.parse(STDIN.read)
cache = {
  "source" => "claude-code-statusline",
  "captured_at" => Time.now.to_i,
  "model" => {
    "id" => payload.dig("model", "id"),
    "display_name" => payload.dig("model", "display_name")
  },
  "rate_limits" => payload["rate_limits"]
}
tmp = "#{cache_file}.#{$$}"
File.write(tmp, JSON.generate(cache) + "\n")
File.rename(tmp, cache_file)
' "$cache_file" 2>/dev/null

if [ -r "$original_command_file" ]; then
  original_command=$(cat "$original_command_file")
  case "$original_command" in
    ""|*limit-lens-statusline-bridge.sh*)
      ;;
    *)
      printf '%s' "$input" | /bin/sh -c "$original_command"
      exit 0
      ;;
  esac
fi

printf '%s' "$input" | /usr/bin/ruby -rjson -e '
payload = JSON.parse(STDIN.read)
puts payload.dig("model", "display_name") || "Claude"
' 2>/dev/null || printf 'Claude\n'
BRIDGE

chmod 700 "$bridge_file"

timestamp=$(date +%Y%m%d-%H%M%S)
cp "$settings_file" "${backup_dir}/settings.limit-lens.${timestamp}.json"

/usr/bin/ruby -rjson -e '
path = ARGV.fetch(0)
bridge = ARGV.fetch(1)
settings = JSON.parse(File.read(path))
settings["statusLine"] = {
  "type" => "command",
  "command" => bridge
}
File.write(path, JSON.pretty_generate(settings) + "\n")
' "$settings_file" '/bin/sh "$HOME/.claude/limit-lens-statusline-bridge.sh"'

printf 'Installed Limit Lens Claude statusline bridge.\n'
printf 'Cache: %s\n' "${HOME}/Library/Application Support/LimitLens/claude-rate-limits.json"
