# lib/merge-settings.sh — deep-merge two Claude Code settings.json files.
# Usage (sourced): merge_settings <common.json> <lang.json> <target.json> <dry:0|1>
# Concatenates arrays under .hooks.PreToolUse / PostToolUse / UserPromptSubmit.
# Validates the result with `jq empty`. Atomic write on success.

merge_settings() {
  local common="$1" lang="$2" target="$3" dry="$4"

  [[ -f "$common" ]] || { log_error "missing common settings: $common"; return 5; }
  [[ -f "$lang"   ]] || { log_error "missing lang settings: $lang";     return 5; }

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would merge $common + $lang -> $target"
    return 0
  fi

  local tmp; tmp="$(mktemp)"
  if ! jq -s '
    reduce .[] as $x (
      {hooks:{}};
      .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
      .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
    )
  ' "$common" "$lang" > "$tmp"; then
    log_error "jq merge failed"
    rm -f "$tmp"
    return 6
  fi

  if ! jq empty "$tmp" >/dev/null 2>&1; then
    log_error "merged settings.json is invalid JSON"
    rm -f "$tmp"
    return 7
  fi

  mkdir -p "$(dirname "$target")"
  mv "$tmp" "$target"
  log_ok "merged settings.json -> $target"
}
