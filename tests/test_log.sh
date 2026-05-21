#!/usr/bin/env bash
# Test: lib/log.sh emits expected prefixes and respects NO_COLOR.
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
# shellcheck source=../lib/log.sh
source "$ROOT/lib/log.sh"

fail() { echo "FAIL: $1" >&2; exit 1; }
ok()   { echo "ok: $1"; }

# Capture stdout/stderr and verify each helper prefixes its output.
out="$(log_info "hello" 2>&1)"
[[ "$out" == *"[INFO]"*"hello"* ]] || fail "log_info missing [INFO] prefix: $out"
ok "log_info"

out="$(log_ok "fine" 2>&1)"
[[ "$out" == *"[OK]"*"fine"* ]] || fail "log_ok missing [OK] prefix: $out"
ok "log_ok"

out="$(log_warn "careful" 2>&1)"
[[ "$out" == *"[WARN]"*"careful"* ]] || fail "log_warn missing [WARN] prefix: $out"
ok "log_warn"

out="$(log_error "boom" 2>&1)"
[[ "$out" == *"[ERROR]"*"boom"* ]] || fail "log_error missing [ERROR] prefix: $out"
ok "log_error"

out="$(log_action "doing" 2>&1)"
[[ "$out" == *"[*]"*"doing"* ]] || fail "log_action missing [*] prefix: $out"
ok "log_action"

out="$(log_section "Phase 1" 2>&1)"
[[ "$out" == *"Phase 1"* ]] || fail "log_section missing label: $out"
ok "log_section"

# NO_COLOR: when set, no ANSI escapes should appear.
out="$(NO_COLOR=1 log_info "plain" 2>&1)"
[[ "$out" != *$'\e['* ]] || fail "NO_COLOR did not suppress ANSI escapes"
ok "NO_COLOR honored"

# log_warn must write to stderr, not stdout.
out_stdout="$(log_warn "to-stderr" 2>/dev/null)"
[[ -z "$out_stdout" ]] || fail "log_warn leaked to stdout: $out_stdout"
ok "log_warn routes to stderr"

# log_error must write to stderr, not stdout.
out_stdout="$(log_error "to-stderr" 2>/dev/null)"
[[ -z "$out_stdout" ]] || fail "log_error leaked to stdout: $out_stdout"
ok "log_error routes to stderr"

# log_section header marker (==) must appear, not just the label.
out="$(log_section "Sec" 2>&1)"
[[ "$out" == *"== Sec =="* ]] || fail "log_section missing == ==: $out"
ok "log_section delimiters"

echo "test_log.sh: ALL PASS"
