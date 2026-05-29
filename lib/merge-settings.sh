# lib/merge-settings.sh — deep-merge two Claude Code settings.json files.
# Usage (sourced): merge_settings <common.json> <lang.json> <target.json> <dry:0|1>
# Concatenates arrays under .hooks.SessionStart / PreToolUse / PostToolUse / UserPromptSubmit.
# Validates the result with `jq empty`. Atomic write on success.
#
# Re-run safety: if <target.json> already exists, its non-hook keys (e.g.
# permissions, env) and any hook categories we don't manage are PRESERVED, the
# managed hook arrays are regenerated from source (so re-running never
# duplicates hooks), and the previous file is backed up to
# <target>.bak.YYYYMMDD-HHMMSS before being overwritten.

_merge_settings_backup_suffix() { date +".bak.%Y%m%d-%H%M%S"; }

merge_settings() {
  local common="$1" lang="$2" target="$3" dry="$4"

  [[ -f "$common" ]] || { log_error "missing common settings: $common"; return 5; }
  [[ -f "$lang"   ]] || { log_error "missing lang settings: $lang";     return 5; }

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would merge $common + $lang -> $target"
    [[ -f "$target" ]] && log_action "(dry-run) would back up existing $target before overwrite"
    return 0
  fi

  # Build the managed hook tree from the two source files.
  local built; built="$(mktemp)"
  if ! jq -s '
    reduce .[] as $x (
      {hooks:{}};
      .hooks.SessionStart     = ((.hooks.SessionStart     // []) + ($x.hooks.SessionStart     // [])) |
      .hooks.PreToolUse       = ((.hooks.PreToolUse       // []) + ($x.hooks.PreToolUse       // [])) |
      .hooks.PostToolUse      = ((.hooks.PostToolUse      // []) + ($x.hooks.PostToolUse      // [])) |
      .hooks.UserPromptSubmit = ((.hooks.UserPromptSubmit // []) + ($x.hooks.UserPromptSubmit // []))
    )
  ' "$common" "$lang" > "$built"; then
    log_error "jq merge failed"
    rm -f "$built"
    return 6
  fi

  local tmp; tmp="$(mktemp)"
  if [[ -f "$target" ]] && jq empty "$target" >/dev/null 2>&1; then
    # Preserve the user's existing settings, then overlay the freshly built
    # hooks. jq's `*` replaces (does not concatenate) array values, so the
    # managed SessionStart/PreToolUse/PostToolUse/UserPromptSubmit arrays are
    # regenerated cleanly while other keys and unmanaged hook categories survive.
    if ! jq -s '.[0] * .[1]' "$target" "$built" > "$tmp"; then
      log_error "jq merge with existing target failed"
      rm -f "$built" "$tmp"
      return 6
    fi
  else
    cp "$built" "$tmp"
  fi
  rm -f "$built"

  if ! jq empty "$tmp" >/dev/null 2>&1; then
    log_error "merged settings.json is invalid JSON"
    rm -f "$tmp"
    return 7
  fi

  mkdir -p "$(dirname "$target")"
  # Back up the existing file before overwriting, mirroring copy_files behavior.
  if [[ -f "$target" ]]; then
    local bak; bak="${target}$(_merge_settings_backup_suffix)"
    cp -p "$target" "$bak"
    log_action "backed up $target -> $bak"
  fi
  mv "$tmp" "$target"
  log_ok "merged settings.json -> $target"
}
