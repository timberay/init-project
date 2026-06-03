# lib/agent-compat.sh — create compatibility links between agent config paths.
# Usage (sourced): setup_agent_compat <target> <force:0|1> <dry:0|1>

setup_agent_compat() {
  local target="$1" force="$2" dry="$3"
  local claude_dir="$target/.claude"
  local link="$claude_dir/skills"
  local expected="../.agents/skills"

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would ensure $link -> $expected"
    return 0
  fi

  mkdir -p "$claude_dir" "$target/.agents/skills"

  if [[ -L "$link" ]]; then
    local current
    current="$(readlink "$link")"
    if [[ "$current" == "$expected" ]]; then
      log_info "Claude skills symlink already configured: $link -> $expected"
      return 0
    fi
    if [[ "$force" -ne 1 ]]; then
      log_warn "Claude skills symlink points to $current; rerun with --force to replace it"
      return 0
    fi
    rm "$link"
  elif [[ -e "$link" ]]; then
    if [[ "$force" -ne 1 ]]; then
      log_warn "$link already exists; rerun with --force to back it up and create symlink"
      return 0
    fi
    local bak
    bak="${link}$(_backup_suffix)"
    mv "$link" "$bak"
    log_action "backed up $link -> $bak"
  fi

  ln -s "$expected" "$link"
  log_ok "linked $link -> $expected"
}
