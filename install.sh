#!/usr/bin/env bash
# install.sh — bootstrap a new project from base-files.
# Run from inside the target project directory:
#   ~/projects/00.base-files/install.sh [--lang rails|python|go|bash|nextjs] [--dry-run] [--force] [--skip-skills]
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/log.sh
source "$SCRIPT_DIR/lib/log.sh"
# shellcheck source=lib/detect-language.sh
source "$SCRIPT_DIR/lib/detect-language.sh"
# shellcheck source=lib/check-deps.sh
source "$SCRIPT_DIR/lib/check-deps.sh"
# shellcheck source=lib/copy-files.sh
source "$SCRIPT_DIR/lib/copy-files.sh"
# shellcheck source=lib/merge-settings.sh
source "$SCRIPT_DIR/lib/merge-settings.sh"
# shellcheck source=lib/install-skills.sh
source "$SCRIPT_DIR/lib/install-skills.sh"
# shellcheck source=lib/agent-compat.sh
source "$SCRIPT_DIR/lib/agent-compat.sh"

usage() {
  cat <<EOF
Usage: install.sh [options]

Run from inside the new project's directory. Detects language from manifest
files, copies the common core + one language overlay, merges hook settings,
creates Claude/Codex/opencode compatibility paths, and installs recommended
Claude Code plugins.

Options:
  --lang <rails|python|go|bash|nextjs>
                             Override language auto-detection
  --dry-run                  Print the plan without writing files or invoking claude
  --force                    Overwrite existing files (always with timestamped backup)
  --skip-skills              Skip plugin installation entirely
  -h, --help                 Show this help

Examples:
  cd ~/projects/my-rails-app && ~/projects/00.base-files/install.sh
  cd ~/projects/my-py-app && ~/projects/00.base-files/install.sh --lang python --force
EOF
}

LANG_OVERRIDE=""
DRY_RUN=0
FORCE=0
SKIP_SKILLS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --lang)        LANG_OVERRIDE="${2:-}"; shift 2 ;;
    --dry-run)     DRY_RUN=1; shift ;;
    --force)       FORCE=1; shift ;;
    --skip-skills) SKIP_SKILLS=1; shift ;;
    -h|--help)     usage; exit 0 ;;
    *)             log_error "unknown argument: $1"; usage >&2; exit 2 ;;
  esac
done

TARGET="$(pwd)"
log_section "Bootstrapping $(basename "$TARGET")"
log_info "source:  $SCRIPT_DIR"
log_info "target:  $TARGET"
[[ "$DRY_RUN"     -eq 1 ]] && log_warn "DRY-RUN mode — no changes will be written"
[[ "$FORCE"       -eq 1 ]] && log_warn "FORCE mode — existing files will be overwritten (backed up)"
[[ "$SKIP_SKILLS" -eq 1 ]] && log_warn "SKIP-SKILLS mode — plugin installation suppressed"

log_section "1/6  Detecting language"
DETECTED_LANG="$(detect_language "$LANG_OVERRIDE")" || exit $?
log_ok "language: $DETECTED_LANG"

log_section "2/6  Checking OS dependencies"
check_deps "$DETECTED_LANG" || exit $?
MISSING_COUNT="${#MISSING_DEPS[@]}"

log_section "3/6  Copying common + $DETECTED_LANG files"
copy_files \
  "$SCRIPT_DIR/common" \
  "$SCRIPT_DIR/langs/$DETECTED_LANG" \
  "$TARGET" \
  "$FORCE" \
  "$DRY_RUN" || exit $?

if [[ "$DRY_RUN" -ne 1 && -f "$TARGET/PROJECT_STATE.md" ]]; then
  TODAY="$(date +%Y-%m-%d)"
  # Seed only the literal placeholder, leave any real date alone.
  if grep -q "Lifecycle Stage: Setup (since YYYY-MM-DD)" "$TARGET/PROJECT_STATE.md"; then
    # Cross-platform sed-in-place: write to a temp file, then move.
    sed "s/Lifecycle Stage: Setup (since YYYY-MM-DD)/Lifecycle Stage: Setup (since ${TODAY})/" \
      "$TARGET/PROJECT_STATE.md" > "$TARGET/PROJECT_STATE.md.tmp" \
      && mv "$TARGET/PROJECT_STATE.md.tmp" "$TARGET/PROJECT_STATE.md"
    log_ok "seeded Lifecycle Stage date: ${TODAY}"
  fi
fi

log_section "4/6  Merging .claude/settings.json"
merge_settings \
  "$SCRIPT_DIR/common/.claude/settings.json" \
  "$SCRIPT_DIR/langs/$DETECTED_LANG/.claude/settings.json" \
  "$TARGET/.claude/settings.json" \
  "$DRY_RUN" || exit $?

log_section "5/6  Creating agent compatibility links"
setup_agent_compat "$TARGET" "$FORCE" "$DRY_RUN" || exit $?

if [[ "$SKIP_SKILLS" -eq 0 ]]; then
  log_section "6/6  Installing recommended Claude Code plugins"
  install_skills "$DRY_RUN"
else
  log_section "6/6  Plugin installation skipped (--skip-skills)"
fi

log_section "Done"
log_ok "language:        $DETECTED_LANG"
log_ok "files copied:    common/ + langs/$DETECTED_LANG/"
log_ok "settings merged: $TARGET/.claude/settings.json"
log_ok "skills path:     $TARGET/.agents/skills + .claude/skills symlink"
if [[ "$MISSING_COUNT" -gt 0 ]]; then
  log_warn "missing OS tools: ${MISSING_DEPS[*]}"
  log_warn "review the warnings above and install the missing tools before working in this project"
fi
log_info "next: git init && git add . && git commit -m 'Bootstrap from base-files'"
log_info "      then: pre-commit install   # registers the git hook (one-time)"
