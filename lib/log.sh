# lib/log.sh — color logger for install.sh and lib/* modules.
# Source this file; do not execute it directly.

# Respect NO_COLOR (https://no-color.org/) and the absence of a TTY.
if [[ -n "${NO_COLOR:-}" || ! -t 1 ]]; then
  _LOG_C_RESET=""
  _LOG_C_INFO=""
  _LOG_C_OK=""
  _LOG_C_WARN=""
  _LOG_C_ERROR=""
  _LOG_C_ACTION=""
  _LOG_C_SECTION=""
else
  _LOG_C_RESET=$'\e[0m'
  _LOG_C_INFO=$'\e[36m'        # cyan
  _LOG_C_OK=$'\e[32m'          # green
  _LOG_C_WARN=$'\e[33m'        # yellow
  _LOG_C_ERROR=$'\e[31m'       # red
  _LOG_C_ACTION=$'\e[35m'      # magenta
  _LOG_C_SECTION=$'\e[1;34m'   # bold blue
fi

log_info()    { printf '%s[INFO]%s %s\n'    "$_LOG_C_INFO"    "$_LOG_C_RESET" "$*"; }
log_ok()      { printf '%s[OK]%s %s\n'      "$_LOG_C_OK"      "$_LOG_C_RESET" "$*"; }
log_warn()    { printf '%s[WARN]%s %s\n'    "$_LOG_C_WARN"    "$_LOG_C_RESET" "$*" >&2; }
log_error()   { printf '%s[ERROR]%s %s\n'   "$_LOG_C_ERROR"   "$_LOG_C_RESET" "$*" >&2; }
log_action()  { printf '%s[*]%s %s\n'       "$_LOG_C_ACTION"  "$_LOG_C_RESET" "$*"; }
log_section() {
  local label="$*"
  printf '\n%s== %s ==%s\n' "$_LOG_C_SECTION" "$label" "$_LOG_C_RESET"
}
