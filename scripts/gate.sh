#!/usr/bin/env bash
# gate.sh — stage-transition spine. Each stage is a hard precondition check.
#
# Usage:
#   scripts/gate.sh implement NN
#   scripts/gate.sh critic NN
#   scripts/gate.sh pr NN [pr-body-file]
#   scripts/gate.sh archive NN [--accepted-by "verbatim human words"]
#
# Protocol: GATE, TICKET, STATUS, plus stage-specific KEY: value lines.
# Every invocation appends one line to .agentic/journal/metrics.jsonl.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

STAGE="${1:-}"
NN_RAW="${2:-}"
shift 2 2>/dev/null || true

if [ -z "$STAGE" ] || [ -z "$NN_RAW" ]; then
  echo "usage: scripts/gate.sh implement|critic|pr|archive NN" >&2
  exit 2
fi

NN="$(nn_pad "$NN_RAW")"
TICKET="$(ticket_file "$NN" || true)"
EXIT_CODE=0

finish() {
  EXIT_CODE="$1"
  metrics_append "\"stage\":\"$STAGE\",\"nn\":\"$NN\",\"exit\":$EXIT_CODE,\"tier\":\"${TIER:-}\""
  protocol GATE "$STAGE"
  protocol TICKET "$NN"
  if [ "$EXIT_CODE" -eq 0 ]; then
    protocol STATUS PASS
  else
    protocol STATUS FAIL
  fi
  exit "$EXIT_CODE"
}

fail() { echo "gate $STAGE: $1" >&2; finish 1; }

[ -n "$TICKET" ] || fail "ticket $NN not found"
TIER="$(ticket_yaml "$TICKET" risk_tier)"
STATUS="$(ticket_yaml "$TICKET" status)"
TEMPLATE="$(ticket_yaml "$TICKET" template)"

write_scope() {
  mkdir -p "$STATE"
  local out="$STATE/scope-$NN.txt"
  ticket_yaml_list "$TICKET" scope_paths > "$out"
  [ -s "$out" ] || fail "scope_paths empty; cannot freeze scope"
  echo "$NN" > "$STATE/active-ticket"
  protocol SCOPE "$out"
}

session_traps() {
  local var val host
  for var in DATABASE_URL REDIS_URL AMQP_URL; do
    eval "val=\${$var:-}"
    [ -z "$val" ] && continue
    host="$(printf '%s' "$val" | sed -E 's#^[a-zA-Z0-9+.-]+://([^/:]+).*#\1#')"
    case "$host" in
      localhost|127.0.0.1|::1|"" ) ;;
      *) fail "session trap: $var points at '$host' (non-localhost). Wrong-target risk." ;;
    esac
  done
  # *_API_KEY with a host-like value is unusual; flag URL-shaped secrets.
  local name
  while IFS= read -r name; do
    eval "val=\${$name:-}"
    case "$val" in
      http://*|https://*)
        host="$(printf '%s' "$val" | sed -E 's#^[a-zA-Z0-9+.-]+://([^/:]+).*#\1#')"
        case "$host" in
          localhost|127.0.0.1|::1) ;;
          *) fail "session trap: $name looks like a remote URL ($host)" ;;
        esac
        ;;
    esac
  done < <(env | awk -F= '/_API_KEY=/{print $1}')
}

claim_lock() {
  local claimed sid
  claimed="$(ticket_yaml "$TICKET" claimed_by)"
  sid="${AGENTIC_SESSION_ID:-}"
  if [ "$STATUS" = "in-progress" ] && [ -n "$claimed" ] && [ "$claimed" != '""' ] && [ -n "$sid" ] && [ "$claimed" != "$sid" ]; then
    local ledger="$JOURNAL/$NN-ledger.md" mtime="unknown"
    [ -f "$ledger" ] && mtime="$(date -u -r "$ledger" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || stat -c %y "$ledger" 2>/dev/null || echo unknown)"
    fail "ticket $NN claimed by '$claimed' (this session '$sid'); last ledger mtime $mtime"
  fi
}

handoff_stale() {
  local handoff="$JOURNAL/$NN-handoff.md" ledger="$JOURNAL/$NN-ledger.md"
  [ -f "$handoff" ] && [ -f "$ledger" ] || return 0
  if [ "$handoff" -ot "$ledger" ]; then
    echo "gate $STAGE: WARNING: handoff is older than ledger — treat handoff as stale" >&2
    protocol HANDOFF STALE
  fi
}

require_ticket_lint() {
  "$SCRIPT_DIR/ticket-lint.sh" "$TICKET" || fail "ticket-lint failed"
}

require_fresh_stamp() {
  "$SCRIPT_DIR/stamp-check.sh" || fail "fresh green verify stamp required for this HEAD"
}

require_baseline_stamp() {
  "$SCRIPT_DIR/stamp-check.sh" --baseline || fail "baseline verify stamp missing — run verify.sh before implementing"
}

diff_files() {
  has_git || return 0
  local base
  base="$(base_branch)"
  [ -z "$base" ] && base="dev"
  if git -C "$ROOT" rev-parse --verify "$base" >/dev/null 2>&1; then
    git -C "$ROOT" diff --name-only "$base"...HEAD 2>/dev/null || git -C "$ROOT" diff --name-only
  else
    git -C "$ROOT" diff --name-only
  fi
}

risk_reprice() {
  local f floor
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    floor="$(path_risk_floor "$f")"
    if [ "$(tier_rank "$floor")" -gt "$(tier_rank "$TIER")" ]; then
      fail "diff touches '$f' (floor $floor) above ticket tier $TIER — re-price the ticket"
    fi
  done < <(diff_files)
}

assumed_left() {
  awk '/^## Load-Bearing Assumptions/{inb=1;next} inb && /^## /{inb=0} inb && /ASSUMED/' "$TICKET" \
    | grep -v '| A1 | | | | |' | grep -v '^|---' || true
}

test_ratchet() {
  local stamp baseline_count now_count
  stamp="$(last_stamp || true)"
  [ -z "$stamp" ] && return 0
  now_count="$(json_get "$stamp" test_count)"
  [ "$now_count" = "null" ] || [ -z "$now_count" ] && return 0
  local first="$JOURNAL/verify-stamps.jsonl"
  [ -f "$first" ] || return 0
  baseline_count="$(head -1 "$first" | { json_get "$(cat)" test_count; })"
  # json_get on a line:
  baseline_count="$(head -1 "$first")"
  baseline_count="$(json_get "$baseline_count" test_count)"
  [ "$baseline_count" = "null" ] || [ -z "$baseline_count" ] && return 0
  if [ "$now_count" -lt "$baseline_count" ] 2>/dev/null; then
    if ! grep -q 'Ruling:.*test' "$JOURNAL/$NN-ledger.md" 2>/dev/null; then
      fail "test count dropped $baseline_count -> $now_count without a Ruling: naming the removed tests"
    fi
  fi
}

migration_gate() {
  local dir
  dir="$(config_get migrations_dir)"
  [ -z "$dir" ] && dir="migrations"
  local f changed=0
  while IFS= read -r f; do
    case "$f" in
      "$dir"/*|*/"$dir"/*)
        changed=1
        if grep -Eq '\b(DROP|TRUNCATE)\b|\bALTER\b.*\bTYPE\b|\bDROP COLUMN\b|\bRENAME COLUMN\b|\bALTER TABLE\b.*\bRENAME\b' "$ROOT/$f" 2>/dev/null; then
          if ! ls "$ROOT/$dir"/*down* "$ROOT/$dir"/*.down.* 2>/dev/null | grep -q .; then
            fail "destructive DDL in $f without a paired down-migration"
          fi
          rev="$(ticket_yaml "$TICKET" reversibility)"
          if [ "$rev" != "expand-contract" ] && [ "$rev" != "irreversible" ]; then
            fail "in-place rename/drop in $f requires reversibility: expand-contract (or irreversible + rollback)"
          fi
        fi
        ;;
    esac
  done < <(diff_files)
  [ "$changed" -eq 0 ] && return 0
  if [ "$(tier_rank "$TIER")" -lt "$(tier_rank HIGH)" ]; then
    fail "migration files in diff require HIGH tier"
  fi
}

assemble_critic_payload() {
  local dest="$STATE/critic-payload-$NN"
  rm -rf "$dest"
  mkdir -p "$dest"
  local pkg
  pkg="$(ls -1 "$JOURNAL/reviews/$NN-final"* "$JOURNAL/reviews/"*final* 2>/dev/null | head -1 || true)"
  if [ -z "$pkg" ]; then
    pkg="$(ls -1t "$JOURNAL/reviews/"*.md 2>/dev/null | head -1 || true)"
  fi
  [ -n "$pkg" ] && [ -f "$pkg" ] && cp "$pkg" "$dest/package.md"
  last_stamp >/dev/null 2>&1 && last_stamp > "$dest/verify-stamp.json"
  awk '/^## Done Contract/{inb=1} inb{print} inb && /^## / && !/^## Done Contract/{exit}' "$TICKET" > "$dest/contract.md"
  awk '/^## Constraints/{inb=1} inb{print} inb && /^## / && !/^## Constraints/{exit}' "$TICKET" >> "$dest/contract.md"
  printf '%s\n' "READ-ONLY. Evaluate these evidence files. Do not mutate the tree. Do not trust generator narrative." > "$dest/PREAMBLE.txt"
  # Deterministic: payload contains only evidence files.
  protocol PAYLOAD "$dest"
}

merge_base_ok() {
  has_git || return 0
  local base
  base="$(base_branch)"
  [ -z "$base" ] && return 0
  git -C "$ROOT" rev-parse --verify "$base" >/dev/null 2>&1 || return 0
  git -C "$ROOT" merge-base --is-ancestor "$base" HEAD 2>/dev/null \
    || fail "HEAD does not contain merge-base with $base — confirm the branch forked from config base_branch"
}

branch_maps_to_ticket() {
  has_git || return 0
  local cur prefix
  cur="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
  prefix="$(config_get branch_prefix)"
  [ -z "$prefix" ] && prefix="ticket/"
  case "$cur" in
    "$prefix$NN"-*) ;;
    *) echo "gate $STAGE: WARNING: current branch '$cur' does not match ${prefix}${NN}-*" >&2 ;;
  esac
}

done_contract_checked() {
  awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /^[0-9]+\./' "$TICKET" | grep -q . \
    || fail "Done Contract has no assertions"
  # Full-template constraint checkboxes: if any exist, they must be [x]
  if grep -q '^\- \[ \]' "$TICKET"; then
    fail "unchecked boxes remain in the ticket (Done Contract / Constraints / Critic Sign-off)"
  fi
}

floor_guard_gate() {
  local on
  on="$(config_get floor_guard)"
  [ "$on" = "false" ] && return 0
  local base
  base="$(base_branch)"
  [ -z "$base" ] && base="dev"
  "$SCRIPT_DIR/floor-guard.sh" --base "$base" || fail "floor-guard failed"
}

require_worktree() {
  local req
  req="$(config_get limits.require_worktree)"
  [ "$req" = "true" ] || return 0
  has_git || return 0
  local gd gc
  gd="$(cd "$(git -C "$ROOT" rev-parse --git-dir)" && pwd -P)"
  gc="$(cd "$(git -C "$ROOT" rev-parse --git-common-dir)" && pwd -P)"
  if [ "$gd" = "$gc" ]; then
    fail "limits.require_worktree: implement from a linked worktree, not the main checkout"
  fi
}

diff_size_gate() {
  has_git || return 0
  local warn failn stat insertions
  warn="$(config_get limits.diff_warn_lines)"
  failn="$(config_get limits.diff_fail_lines)"
  [ -z "$warn" ] && warn=300
  [ -z "$failn" ] && failn=0
  local base
  base="$(base_branch)"
  [ -z "$base" ] && base="dev"
  if ! git -C "$ROOT" rev-parse --verify "$base" >/dev/null 2>&1; then
    return 0
  fi
  insertions="$(git -C "$ROOT" diff --numstat "$base"...HEAD | awk '{s+=$1} END {print s+0}')"
  if [ "$failn" -gt 0 ] && [ "$insertions" -gt "$failn" ]; then
    fail "diff insertions $insertions exceed limits.diff_fail_lines=$failn — split the change"
  fi
  if [ "$warn" -gt 0 ] && [ "$insertions" -gt "$warn" ]; then
    echo "gate $STAGE: WARNING: diff insertions $insertions > limits.diff_warn_lines=$warn" >&2
  fi
}

lockfile_new_deps() {
  has_git || return 0
  local nd
  nd="$(config_get guard.new_deps)"
  case "$nd" in false|off) return 0 ;; esac
  local hit=0 f
  while IFS= read -r f; do
    case "$f" in
      package-lock.json|pnpm-lock.yaml|yarn.lock|Cargo.lock|go.sum|poetry.lock|uv.lock|Gemfile.lock)
        hit=1 ;;
    esac
  done < <(diff_files)
  [ "$hit" -eq 0 ] && return 0
  local listed
  listed="$(ticket_yaml_list "$TICKET" new_deps)"
  if [ -z "$listed" ]; then
    fail "lockfile changed but ticket new_deps: is empty — list every added package"
  fi
  local base name missing
  base="$(base_branch)"
  [ -z "$base" ] && base="dev"
  git -C "$ROOT" rev-parse --verify "$base" >/dev/null 2>&1 || return 0
  missing=""
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    case "$listed" in
      *"$name"*) ;;
      *) missing="$missing $name" ;;
    esac
  done < <(lockfile_added_names "$ROOT" "$base")
  if [ -n "$missing" ]; then
    fail "lockfile added packages not in ticket new_deps:$missing"
  fi
}

require_audit_journal() {
  local on kind
  on="$(config_get limits.tdd_required)"
  [ "$on" = "true" ] || return 0
  [ "$TIER" = "MEDIUM" ] || [ "$TIER" = "HIGH" ] || return 0
  kind="$(ticket_yaml "$TICKET" type)"
  case "$kind" in directive|diagnosis) ;; *) return 0 ;; esac
  "$SCRIPT_DIR/evidence-check.sh" "$NN" --require-journal || fail "audit journal required for $TIER $kind"
}

require_hostile_journal() {
  local on kind report
  on="$(config_get limits.tdd_required)"
  [ "$on" = "true" ] || return 0
  [ "$TIER" = "MEDIUM" ] || [ "$TIER" = "HIGH" ] || return 0
  kind="$(ticket_yaml "$TICKET" type)"
  case "$kind" in directive|diagnosis) ;; *) return 0 ;; esac
  report="$JOURNAL/$NN-critic.md"
  [ -f "$report" ] || return 0
  "$SCRIPT_DIR/evidence-check.sh" "$NN" --require-journal --hostile "$report" || fail "hostile Command run missing from audit journal"
}

security_fanout() {
  local on
  on="$(config_get critic.fanout)"
  [ "$on" = "true" ] || return 0
  [ "$TIER" = "HIGH" ] || return 0
  local need=0 f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    case "$(path_risk_floor "$f")" in
      HIGH) need=1 ;;
    esac
  done < <(diff_files)
  [ "$need" -eq 0 ] && return 0
  local sec="$JOURNAL/$NN-critic-security.md"
  [ -f "$sec" ] || fail "critic.fanout: HIGH diff hits a HIGH risk_path — missing $sec (spawn security persona in the same turn as the critic)"
  grep -q 'APPROVED' "$sec" || fail "security critic verdict is not APPROVED"
}

tdd_evidence() {
  local on cmd kind
  on="$(config_get limits.tdd_required)"
  [ "$on" = "true" ] || return 0
  kind="$(ticket_yaml "$TICKET" type)"
  case "$kind" in directive|diagnosis) ;; *) return 0 ;; esac
  cmd="$(config_get verify.test)"
  [ -z "$cmd" ] && return 0
  case "$cmd" in
    *selftest.sh*) return 0 ;;
  esac
  "$SCRIPT_DIR/evidence-check.sh" "$NN" --tdd "$cmd" || fail "TDD evidence-check failed for '$cmd'"
}

dod_checked() {
  [ "$TIER" = "MEDIUM" ] || [ "$TIER" = "HIGH" ] || return 0
  grep -q '^## Definition of Done' "$TICKET" || fail "MEDIUM/HIGH ticket missing ## Definition of Done (see .agentic/references/dod.md)"
}


# --- stages ---

stage_implement() {
  require_ticket_lint
  [ "$STATUS" != "blocked-on-alignment" ] || fail "ticket is blocked-on-alignment — /agentic-grill"
  case "$STATUS" in
    open|in-progress) ;;
    *) fail "status '$STATUS' is not implementable" ;;
  esac
  claim_lock
  handoff_stale
  session_traps
  write_scope
  require_worktree
  require_baseline_stamp
  "$SCRIPT_DIR/model-check.sh" >/dev/null || fail "model-check failed"
}

stage_critic() {
  require_ticket_lint
  [ -f "$JOURNAL/$NN-ledger.md" ] || fail "ledger missing ($JOURNAL/$NN-ledger.md)"
  "$SCRIPT_DIR/artifact-lint.sh" ledger "$JOURNAL/$NN-ledger.md" "$NN" || fail "ledger lint failed"
  require_fresh_stamp
  assemble_critic_payload
  "$SCRIPT_DIR/evidence-check.sh" "$NN" || fail "evidence-check failed"
  require_audit_journal
  tdd_evidence
  [ -d "$STATE/critic-payload-$NN" ] || fail "payload directory missing"
  # Only evidence files allowed (gate assembled it; re-check).
  local extra
  extra="$(find "$STATE/critic-payload-$NN" -type f ! -name 'package.md' ! -name 'verify-stamp.json' ! -name 'contract.md' ! -name 'PREAMBLE.txt')"
  [ -z "$extra" ] || fail "critic payload contains non-evidence files"
}

stage_pr() {
  require_ticket_lint
  require_fresh_stamp
  merge_base_ok
  branch_maps_to_ticket
  risk_reprice
  test_ratchet
  migration_gate
  local assumed
  assumed="$(assumed_left)"
  [ -z "$assumed" ] || fail "ASSUMED load-bearing rows remain:\n$assumed"
  if [ "$TIER" = "MEDIUM" ] || [ "$TIER" = "HIGH" ]; then
    local report="$JOURNAL/$NN-critic.md"
    [ -f "$report" ] || fail "critic report missing for $TIER ticket"
    "$SCRIPT_DIR/artifact-lint.sh" critic "$report" || fail "critic-report lint failed"
    grep -q 'APPROVED' "$report" || fail "critic verdict is not APPROVED"
    if grep -q 'CHANGES_REQUESTED\|REOPEN_REQUIRED' "$report" && ! grep -q 'APPROVED' "$report"; then
      fail "critic verdict blocks PR"
    fi
    # Last verdict line must be APPROVED
    local v
    v="$(grep -E 'Verdict' "$report" | grep -oE 'APPROVED|CHANGES_REQUESTED|REOPEN_REQUIRED' | tail -1)"
    [ "$v" = "APPROVED" ] || fail "last critic verdict is '$v' (need APPROVED)"
    require_hostile_journal
  fi
  require_audit_journal
  "$SCRIPT_DIR/artifact-lint.sh" resolution "$TICKET" || fail "resolution lint failed"
  local body="${1:-}"
  if [ -n "$body" ]; then
    "$SCRIPT_DIR/artifact-lint.sh" pr-body "$body" "$JOURNAL/$NN-ledger.md" || fail "PR-body lint failed"
  fi
  "$SCRIPT_DIR/debt-lint.sh" >/dev/null || fail "debt-lint failed"
  "$SCRIPT_DIR/env-lint.sh" >/dev/null || fail "env-lint failed"
  floor_guard_gate
  diff_size_gate
  lockfile_new_deps
  security_fanout
}

stage_archive() {
  local accepted=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --accepted-by) accepted="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  if [ "$STATUS" != "ready-for-review" ] && [ -z "$accepted" ]; then
    fail "status is '$STATUS' (need ready-for-review, or --accepted-by \"<verbatim human words>\")"
  fi
  stage_pr
  done_contract_checked
  dod_checked
  if ! grep -qE 'Lessons: none|^- \[' "$JOURNAL/lessons.md" 2>/dev/null; then
    fail "lessons.md missing explicit 'Lessons: none' or a new '- [NN]' entry"
  fi
  mkdir -p "$STATE"
  local token="$STATE/close-authorized-$NN"
  {
    echo "nn=$NN"
    echo "ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "head=$(current_head)"
    [ -n "$accepted" ] && echo "accepted_by=$accepted"
  } > "$token"
  protocol CLOSE_TOKEN "$token"
}

case "$STAGE" in
  implement) stage_implement; finish 0 ;;
  critic) stage_critic; finish 0 ;;
  pr) stage_pr "$@"; finish 0 ;;
  archive) stage_archive "$@"; finish 0 ;;
  *) echo "unknown stage '$STAGE'" >&2; exit 2 ;;
esac
