# lib/copy-files.sh — copy common/ and langs/<lang>/ trees into a target dir.
# Usage (sourced): copy_files <common_src> <lang_src> <dst> <force:0|1> <dry:0|1>
# Skips .claude/settings.json (handled by merge_settings).

_backup_suffix() { date +".bak.%Y%m%d-%H%M%S"; }

_copy_one() {
  # _copy_one <src_file> <dst_file> <force> <dry>
  local src="$1" dst="$2" force="$3" dry="$4"

  # Skip settings.json — merge_settings handles it.
  if [[ "$(basename "$dst")" == "settings.json" && "$(dirname "$dst")" == *".claude" ]]; then
    return 0
  fi

  if [[ -e "$dst" ]]; then
    if [[ "$force" -eq 1 ]]; then
      local bak; bak="${dst}$(_backup_suffix)"
      if [[ "$dry" -eq 1 ]]; then
        log_action "(dry-run) would back up $dst -> $bak"
      else
        mv "$dst" "$bak"
        log_action "backed up $dst -> $bak"
      fi
    else
      printf 'File exists: %s\n  [o]verwrite (with backup) / [s]kip / [q]uit ? ' "$dst" >&2
      local ans; read -r ans </dev/tty
      case "${ans:-}" in
        o|O)
          local bak; bak="${dst}$(_backup_suffix)"
          if [[ "$dry" -eq 1 ]]; then
            log_action "(dry-run) would back up $dst -> $bak"
          else
            mv "$dst" "$bak"
            log_action "backed up $dst -> $bak"
          fi
          ;;
        s|S) log_info "skipping $dst"; return 0 ;;
        *)   log_error "aborting on user request"; return 4 ;;
      esac
    fi
  fi

  if [[ "$dry" -eq 1 ]]; then
    log_action "(dry-run) would copy $src -> $dst"
  else
    mkdir -p "$(dirname "$dst")"
    cp "$src" "$dst"
    log_ok "copied $src -> $dst"
  fi
}

_walk_and_copy() {
  # _walk_and_copy <src_root> <dst_root> <force> <dry>
  local src="$1" dst="$2" force="$3" dry="$4"
  [[ -d "$src" ]] || return 0
  local rel
  while IFS= read -r -d '' f; do
    rel="${f#"$src/"}"
    _copy_one "$f" "$dst/$rel" "$force" "$dry" || return $?
  done < <(find "$src" -type f -print0)
}

copy_files() {
  local common_src="$1" lang_src="$2" dst="$3" force="$4" dry="$5"
  _walk_and_copy "$common_src" "$dst" "$force" "$dry" || return $?
  _walk_and_copy "$lang_src"   "$dst" "$force" "$dry" || return $?
}
