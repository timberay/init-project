# lib/install-skills.sh — install recommended Claude Code plugins.
# Usage (sourced): install_skills <dry:0|1>
# Idempotent: skips marketplaces and plugins that are already present.

_TARGET_MARKETPLACES=(
  "claude-plugins-official|anthropics/claude-plugins-official"
  "karpathy-skills|forrestchang/andrej-karpathy-skills"
)

_TARGET_PLUGINS=(
  "superpowers@claude-plugins-official"
  "code-review@claude-plugins-official"
  "andrej-karpathy-skills@karpathy-skills"
)

_ensure_marketplace() {
  # _ensure_marketplace <name> <repo> <dry>
  local name="$1" repo="$2" dry="$3"
  if claude plugin marketplace list 2>/dev/null | grep -q "^${name}\b"; then
    log_info "marketplace already added: ${name}"
    return 0
  fi
  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would add marketplace ${name} (${repo})"
    return 0
  fi
  log_action "adding marketplace ${name} (${repo})"
  claude plugin marketplace add "$repo" || log_warn "marketplace add failed: ${name}"
}

_ensure_plugin() {
  # _ensure_plugin <plugin@marketplace> <dry>
  local spec="$1" dry="$2"
  if claude plugin list 2>/dev/null | grep -q "${spec}"; then
    log_info "plugin already installed: ${spec}"
    return 0
  fi
  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would install ${spec}"
    return 0
  fi
  log_action "installing plugin ${spec}"
  claude plugin install "$spec" || log_warn "plugin install failed: ${spec}"
}

install_skills() {
  local dry="${1:-0}"

  if ! command -v claude >/dev/null 2>&1; then
    log_warn "claude CLI not found; skipping plugin installation. See https://docs.claude.com/claude-code"
    return 0
  fi

  for entry in "${_TARGET_MARKETPLACES[@]}"; do
    local name="${entry%%|*}" repo="${entry#*|}"
    _ensure_marketplace "$name" "$repo" "$dry"
  done

  for spec in "${_TARGET_PLUGINS[@]}"; do
    _ensure_plugin "$spec" "$dry"
  done

  if [[ -d "${HOME}/.claude/skills/graphify" ]]; then
    log_ok "graphify skill detected at ~/.claude/skills/graphify"
  else
    log_warn "graphify skill not found at ~/.claude/skills/graphify; install manually if you want it"
  fi
}
