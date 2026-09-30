#!/usr/bin/env bash
# gate.sh — the railroad. Scripts own ticket state; the agent writes code,
# commits, and spawns the reviewer. Nothing else moves a ticket.
#
# Usage:
#   scripts/gate.sh next [NN] [--all]   the one legal next move (read-only)
#   scripts/gate.sh advance [NN]        run every step a script can run; stop
#                                       where the agent or a human is needed
#   scripts/gate.sh new <slug> [--tier LOW|MEDIUM|HIGH] [--title "..."]
#   scripts/gate.sh implement NN [--worktree] [--widen]   claim the ticket
#   scripts/gate.sh check NN            run the Done Contract Check: commands
#   scripts/gate.sh critic NN           reviewer payload / Mode B reviewer / claims
#   scripts/gate.sh ship NN             final checks, close the ticket on its branch
#   scripts/gate.sh reopen NN           closed but unmerged ticket back to in-progress
#   scripts/gate.sh pr NN [--require-shipped]   read-only revalidation (CI)
#
# NN defaults to the ticket of the current branch (ticket/NN-slug).
# next/advance print STATE/NEXT/WHY/THEN. Exit 0 = at rest or waiting on a
# human; 1 = the agent has work (or a step failed).
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

CMD="${1:-}"
[ $# -gt 0 ] && shift

ARG_NN=""
ARG_SLUG=""
ARG_TIER=""
ARG_TITLE=""
ALL=0
WIDEN=0
WORKTREE=0
REQUIRE_SHIPPED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --all) ALL=1 ;;
    --widen) WIDEN=1 ;;
    --worktree) WORKTREE=1 ;;
    --require-shipped) REQUIRE_SHIPPED=1 ;;
    --tier) ARG_TIER="${2:-}"; shift ;;
    --title) ARG_TITLE="${2:-}"; shift ;;
    -*) echo "gate: unknown flag '$1'" >&2; exit 2 ;;
    *)
      if [ "$CMD" = "new" ] && [ -z "$ARG_SLUG" ]; then
        ARG_SLUG="$1"
      elif [ -z "$ARG_NN" ]; then
        ARG_NN="$1"
      else
        echo "gate: unexpected argument '$1'" >&2; exit 2
      fi
      ;;
  esac
  shift
done

usage() {
  sed -n '5,16p' "$0" | sed 's/^# \{0,1\}//' >&2
  exit 2
}

PREFIX="$(config_get branch_prefix)"
[ -z "$PREFIX" ] && PREFIX="ticket/"
ADVANCING="${ADVANCING:-0}"

NN=""
if [ -n "$ARG_NN" ]; then
  case "$ARG_NN" in *[!0-9]*) echo "gate: NN must be a number (got '$ARG_NN')" >&2; exit 2 ;; esac
  NN="$(nn_pad "$ARG_NN")"
elif [ "$CMD" != "new" ]; then
  NN="$(branch_nn)"
fi

TICKET="" TIER="" STATUS="" TITLE="" SLUG=""
load_ticket() {
  TICKET="" TIER="" STATUS="" TITLE="" SLUG=""
  [ -n "$NN" ] || return 0
  TICKET="$(ticket_file "$NN" || true)"
  [ -n "$TICKET" ] || return 0
  TIER="$(ticket_yaml "$TICKET" risk_tier)"
  STATUS="$(ticket_yaml "$TICKET" status)"
  TITLE="$(ticket_title "$TICKET")"
  SLUG="$(basename "$TICKET" .md)"
  SLUG="${SLUG#"$NN"-}"
}
load_ticket

STEP="$CMD"

# --- step bookkeeping -------------------------------------------------------

record_step() {
  local code="$1" detail="${2:-}"
  [ -n "$NN" ] || return 0
  mkdir -p "$STATE"
  python3 -c 'import json,sys; d=(sys.argv[4].replace("\\n","\n").splitlines() or [""])[0]; print(json.dumps({"step":sys.argv[1],"fp":sys.argv[2],"exit":int(sys.argv[3]),"detail":d}))' \
    "$STEP" "$(worktree_fp)" "$code" "$detail" > "$STATE/step-$NN.json"
}

finish() {
  local code="$1"
  metrics_append "\"step\":\"$STEP\",\"nn\":\"$NN\",\"exit\":$code,\"tier\":\"$TIER\""
  record_step "$code" "${FAIL_DETAIL:-}"
  if [ "$code" -eq 0 ]; then echo "STATUS: PASS"; else echo "STATUS: FAIL"; fi
  if [ "$code" -ne 0 ] && [ "$ADVANCING" != 1 ] && [ "$STEP" != next ]; then
    echo
    compute_next
    print_next
  fi
  exit "$code"
}

FAIL_DETAIL=""
fail() {
  FAIL_DETAIL="$1"
  printf 'gate %s: %b\n' "$STEP" "$1" >&2
  finish 1
}

warn() { echo "gate $STEP: WARNING: $1" >&2; }

# Run a linter; on failure, fail with its last lines.
lint_or_fail() {
  local out
  out="$("$@" 2>&1)" || fail "$(basename "$1") failed: $(printf '%s' "$out" | grep -v ': OK' | tail -6)"
}

# --- predicates (never fail; used by next) ----------------------------------

FAST=0
set_fast() {
  FAST=0
  if [ "$TIER" = "LOW" ] && [ "$(config_get risk.low_fast_lane)" != "false" ]; then FAST=1; fi
}

branch_name() { printf '%s%s-%s' "$PREFIX" "$NN" "$SLUG"; }

on_ticket_branch() { [ -n "$NN" ] && [ "$(branch_nn)" = "$NN" ]; }

claimed_here() {
  on_ticket_branch && [ "$STATUS" = "in-progress" ] && [ -s "$STATE/scope-$NN.txt" ]
}

# Local branch for NN, if any.
ticket_branch_for() {
  git -C "$ROOT" for-each-ref --format='%(refname:short)' "refs/heads/${PREFIX}$1-*" 2>/dev/null | head -1
}

# Worktree path that has BRANCH checked out (other than this one).
worktree_of_branch() {
  local want="refs/heads/$1" path="" line here
  here="$(cd "$ROOT" && pwd -P)"
  while IFS= read -r line; do
    case "$line" in
      "worktree "*) path="${line#worktree }" ;;
      "branch $want")
        [ "$(cd "$path" 2>/dev/null && pwd -P)" != "$here" ] && { printf '%s' "$path"; return 0; } ;;
    esac
  done < <(git -C "$ROOT" worktree list --porcelain 2>/dev/null)
  return 1
}

# NN<TAB>branch for in-progress tickets on other local ticket branches.
other_claims() {
  local b n path st
  while IFS= read -r b; do
    [ -z "$b" ] && continue
    n="${b#"$PREFIX"}"; n="${n%%-*}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    n="$(nn_pad "$n")"
    [ "$n" = "$NN" ] && continue
    path="$(git -C "$ROOT" ls-tree --name-only "$b" -- .agentic/tickets/open/ 2>/dev/null | grep "/$n-" | head -1)"
    [ -z "$path" ] && continue
    st="$(git -C "$ROOT" show "$b:$path" 2>/dev/null | awk '/^---/{n++; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}')"
    [ "$st" = "in-progress" ] && printf '%s\t%s\t%s\n' "$n" "$b" "$path"
  done < <(git -C "$ROOT" for-each-ref --format='%(refname:short)' "refs/heads/$PREFIX*" 2>/dev/null)
}

# Status of NN's ticket on its local branch (empty if no branch).
branch_status() {
  local b path
  b="$(ticket_branch_for "$1")"
  [ -n "$b" ] || return 0
  path="$(git -C "$ROOT" ls-tree -r --name-only "$b" -- .agentic/tickets/ 2>/dev/null | grep "/$1-" | head -1)"
  [ -n "$path" ] || return 0
  git -C "$ROOT" show "$b:$path" 2>/dev/null | awk '/^---/{n++; next} n==1 && /^status:/{sub(/^status:[[:space:]]*/,""); print; exit}'
}

ticket_closed_anywhere() {
  local id="$1" ref
  ls "$TICKETS_CLOSED/$id"-*.md >/dev/null 2>&1 && return 0
  ref="$(base_ref 2>/dev/null)" || return 1
  git -C "$ROOT" ls-tree --name-only "$ref" -- .agentic/tickets/closed/ 2>/dev/null | grep -q "/$id-"
}

unresolved_blockers() {
  local f="$1" bb id out=""
  bb="$(ticket_yaml "$f" blocked_by | tr -d ' ')"
  [ -z "$bb" ] || [ "$bb" = "none" ] && return 0
  local IFS=','
  for id in $bb; do
    [ -z "$id" ] && continue
    id="$(nn_pad "$id")"
    ticket_closed_anywhere "$id" || out="$out $id"
  done
  printf '%s' "${out# }"
}

stamp_ok() { "$SCRIPT_DIR/stamp-check.sh" >/dev/null 2>&1; }

check_cmds() {
  dc_checks "$TICKET"
  if [ "$(config_get floor_guard)" != "false" ]; then
    echo "scripts/floor-guard.sh"
  fi
}

record_fresh() {  # FILE KEY — result file green, key matches, evidence fresh
  local f="$1" key="$2" j
  [ -f "$f" ] || return 1
  j="$(cat "$f")"
  [ "$(json_get "$j" exit)" = "0" ] || return 1
  [ "$(json_get "$j" key)" = "$key" ] || return 1
  evidence_fresh "$(json_get "$j" head)" "$(json_get "$j" dirty)"
}

checks_ok() { record_fresh "$STATE/checks-$NN.json" "$(check_cmds | sha_text)"; }

CRITIC_REPORT() { printf '%s' "$JOURNAL/$NN-critic.md"; }
SECURITY_REPORT() { printf '%s' "$JOURNAL/$NN-critic-security.md"; }

security_required() {
  [ "$TIER" = "HIGH" ] || return 1
  [ "$(config_get critic.fanout)" = "true" ] || return 1
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    [ "$(path_risk_floor "$f")" = "HIGH" ] && return 0
  done < <(product_diff_files)
  return 1
}

required_reports() {
  CRITIC_REPORT; echo
  if security_required; then SECURITY_REPORT; echo; fi
}

report_current() {
  local f="$1" h
  [ -f "$f" ] || return 1
  h="$(report_head "$f")"
  [ -n "$h" ] || return 1
  [ "$(is_dirty)" = "false" ] || return 1
  product_same "$h"
}

reports_current() {
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    report_current "$f" || return 1
  done < <(required_reports)
}

reports_key() {
  local f
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    cat "$f" 2>/dev/null
  done < <(required_reports) | sha_text
}

claims_ok() { record_fresh "$STATE/claims-$NN.json" "$(reports_key)"; }

payload_current() {
  local h
  [ -f "$STATE/payload-$NN/HEAD" ] || return 1
  h="$(cat "$STATE/payload-$NN/HEAD")"
  [ "$(is_dirty)" = "false" ] && product_same "$h"
}

lessons_ok() {
  local f="$JOURNAL/lessons/$NN.md"
  [ -s "$f" ] && grep -qE 'Lessons: none|^- \[' "$f"
}

has_product_diff() { [ -n "$(product_diff_files)" ]; }

close_commit() { git -C "$ROOT" log -1 --format=%H --grep="^$NN: close" 2>/dev/null; }

changed_since_close() {
  local c
  c="$(close_commit)"
  [ -n "$c" ] || return 1
  [ "$(is_dirty)" = "true" ] || ! product_same "$c"
}

# --- the table ---------------------------------------------------------------
# First matching row wins. WHO: gate (advance runs STEP_FN) | agent | human | rest.

WHO="" NEXT_MSG="" WHY="" THEN="" STEP_FN=""
row() { WHO="$1"; NEXT_MSG="$2"; WHY="$3"; STEP_FN="${4:-}"; THEN=""; }

compute_next() {
  WHO="" NEXT_MSG="" WHY="" THEN="" STEP_FN=""
  if [ -z "$NN" ]; then
    local f id st cand="" blk
    for f in "$TICKETS_OPEN"/*.md; do
      [ -f "$f" ] || continue
      st="$(ticket_yaml "$f" status)"
      [ "$st" = "open" ] || [ "$st" = "in-progress" ] || continue
      [ -n "$(unresolved_blockers "$f")" ] && continue
      id="$(basename "$f" | sed 's/-.*//')"
      [ -n "$(ticket_branch_for "$id")" ] && continue
      cand="$cand $id"
    done
    cand="${cand# }"
    if [ -n "$cand" ]; then
      row agent "scripts/gate.sh advance ${cand%% *}" "open, unblocked tickets: $cand"
    else
      row rest "nothing to do — new work starts with /agentic-task (scripts/gate.sh new <slug> --tier LOW|MEDIUM|HIGH)" "no open, unblocked ticket in this worktree"
    fi
    return
  fi

  if [ -z "$TICKET" ]; then
    local b wt
    b="$(ticket_branch_for "$NN")"
    if [ -n "$b" ] && wt="$(worktree_of_branch "$b")"; then
      row agent "work on ticket $NN in its worktree: cd $wt" "$b is checked out there"
    elif [ -n "$b" ]; then
      row gate "switch to $b" "ticket $NN lives on $b" step_implement
    else
      row agent "create it: scripts/gate.sh new <slug>" "ticket $NN not found"
    fi
    return
  fi
  set_fast

  if [ "$STATUS" = "closed" ]; then
    if ! on_ticket_branch; then
      row rest "nothing — ticket $NN is closed" "closed"
    elif changed_since_close; then
      row gate "reopen" "product files changed after ship (PR feedback?)" step_reopen
    elif [ "$TIER" = "HIGH" ] && [ "$(config_get risk.high_requires_human_merge)" != "false" ]; then
      row human "a human reviews and merges $(current_branch) into $(base_branch)" "HIGH tickets need a human merge"
    elif git -C "$ROOT" rev-parse --verify --quiet "origin/$(current_branch)" >/dev/null 2>&1 \
      && [ -z "$(git -C "$ROOT" rev-list "origin/$(current_branch)..HEAD" 2>/dev/null)" ]; then
      row rest "wait for the PR to merge" "shipped and pushed"
    else
      row agent "/agentic-pr $NN — push $(current_branch) and open a PR into $(base_branch)" "shipped on the branch; not pushed"
    fi
    return
  fi

  if [ "$STATUS" = "blocked-on-alignment" ]; then
    row human "/agentic-grill $NN — a human settles the open decision, then sets status: open" "status is blocked-on-alignment"
    return
  fi

  local lint
  if ! lint="$("$SCRIPT_DIR/ticket-lint.sh" "$TICKET" 2>&1)"; then
    row agent "fix the ticket: $(relpath_from "$TICKET")" "$(printf '%s' "$lint" | grep -v '^ticket-lint: OK' | head -5 | tr '\n' ' ')"
    return
  fi

  local blockers
  blockers="$(unresolved_blockers "$TICKET")"
  if [ -n "$blockers" ]; then
    row agent "ship the blocker first: scripts/gate.sh advance ${blockers%% *}" "blocked_by $blockers not closed"
    return
  fi

  if [ -f "$STATE/step-$NN.json" ]; then
    local memo
    memo="$(cat "$STATE/step-$NN.json")"
    if [ "$(json_get "$memo" exit)" != "0" ] && [ "$(json_get "$memo" fp)" = "$(worktree_fp)" ]; then
      row agent "fix: $(json_get "$memo" detail)" "'$(json_get "$memo" step)' failed and nothing changed since"
      THEN="scripts/gate.sh advance $NN"
      return
    fi
  fi

  if ! on_ticket_branch; then
    local tb twt
    tb="$(ticket_branch_for "$NN")"
    if [ -n "$tb" ] && twt="$(worktree_of_branch "$tb")"; then
      row agent "work on ticket $NN in its worktree: cd $twt" "$tb is checked out there"
      return
    fi
  fi
  if ! claimed_here; then
    row gate "claim" "not claimed in this worktree" step_implement
    return
  fi

  local f v
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    report_current "$f" || continue
    v="$(report_verdict "$f")"
    case "$v" in
      CHANGES_REQUESTED)
        row agent "fix the findings in $(relpath_from "$f"), commit" "reviewer: CHANGES_REQUESTED"
        THEN="scripts/gate.sh advance $NN"; return ;;
      REOPEN_REQUIRED)
        row agent "rethink the approach per $(relpath_from "$f"); fix the ticket or the code, commit" "reviewer: REOPEN_REQUIRED"
        THEN="scripts/gate.sh advance $NN"; return ;;
    esac
  done < <([ "$FAST" -eq 1 ] || required_reports)

  if ! has_product_diff; then
    row agent "implement: edit files inside scope_paths ($(tr '\n' ' ' < "$STATE/scope-$NN.txt"))" "no product change against $(base_branch) yet"
    THEN="scripts/gate.sh advance $NN"
    return
  fi

  local breach
  if breach="$(tier_breach)"; then
    row agent "set risk_tier: ${breach##* } in the ticket, or drop the change to ${breach% *}" "'${breach% *}' has risk floor ${breach##* }, above tier $TIER"
    THEN="scripts/gate.sh advance $NN"
    return
  fi

  if [ "$FAST" -eq 1 ]; then
    row gate "ship" "LOW fast lane: commit in-scope changes, run checks, close" step_ship
    return
  fi

  if [ "$(is_dirty)" = "true" ]; then
    row agent "commit your changes (message starts with '$NN:')" "verify and review need a committed tree"
    THEN="scripts/gate.sh advance $NN"
    return
  fi
  if ! stamp_ok; then row gate "verify" "no fresh green verify stamp for this product state" step_verify; return; fi
  if ! checks_ok; then row gate "check" "Done Contract checks not green for this product state" step_check; return; fi

  if ! reports_current; then
    if [ -n "$(config_get critic.command)" ] || ! payload_current; then
      row gate "critic" "no reviewer report for this product state" step_critic
    else
      row agent "spawn the reviewer: agentic-evaluator subagent with brief $(relpath_from "$STATE/payload-$NN/BRIEF.md") (one per report named there, same turn)" "reviewer payload is ready; no report yet"
      THEN="scripts/gate.sh advance $NN"
    fi
    return
  fi
  if ! claims_ok; then row gate "critic" "reviewer claims not re-run for this report" step_critic; return; fi

  if ! lessons_ok; then
    row agent "write .agentic/journal/lessons/$NN.md: '- [$NN] <lesson>' lines or 'Lessons: none' (see /agentic-archive)" "MEDIUM/HIGH ship distills memory"
    THEN="scripts/gate.sh advance $NN"
    return
  fi
  row gate "ship" "green: stamp, checks, review, claims, lessons" step_ship
}

print_next() {
  local st
  if [ -z "$NN" ]; then
    st="no ticket selected (branch $(current_branch))"
  elif [ -z "$TICKET" ]; then
    st="ticket $NN (not in this worktree)"
  else
    st="ticket $NN · $TIER · $STATUS · $(current_branch)"
  fi
  echo "STATE: $st"
  if [ "$WHO" = "gate" ]; then
    echo "NEXT: scripts/gate.sh advance $NN"
    echo "WHY: $WHY — the gate runs: $NEXT_MSG"
  else
    [ "$WHO" = "human" ] && echo "NEXT: human: $NEXT_MSG" || echo "NEXT: $NEXT_MSG"
    echo "WHY: $WHY"
    [ -n "$THEN" ] && echo "THEN: $THEN"
  fi
  return 0
}

next_exit() { case "$WHO" in rest|human) return 0 ;; *) return 1 ;; esac; }

# --- ported checks ----------------------------------------------------------

session_traps() {
  local var val host name
  for var in DATABASE_URL REDIS_URL AMQP_URL; do
    eval "val=\${$var:-}"
    [ -z "$val" ] && continue
    host="$(printf '%s' "$val" | sed -E 's#^[a-zA-Z0-9+.-]+://([^@/]*@)?([^/:]+).*#\2#')"
    case "$host" in
      localhost|127.0.0.1|::1|"") ;;
      *) fail "session trap: $var points at '$host' (non-localhost). Unset it or point it at a local instance." ;;
    esac
  done
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

scopes_hit() {
  local a="$1" b="$2" pa pb
  [ "$a" = "$b" ] && return 0
  pa="${a%%\**}"; pb="${b%%\**}"
  pa="${pa%/}"; pb="${pb%/}"
  { [ -z "$pa" ] || [ -z "$pb" ]; } && return 0
  case "$pa" in "$pb"|"$pb"/*) return 0 ;; esac
  case "$pb" in "$pa"|"$pa"/*) return 0 ;; esac
  return 1
}

claims_rule() {
  local max n=0 id b path tmp a c others=""
  max="$(config_get limits.max_active_tickets)"
  [ -z "$max" ] && max=1
  tmp="$(mktemp)"
  while IFS=$'\t' read -r id b path; do
    [ -z "$id" ] && continue
    n=$((n + 1))
    others="$others $id($b)"
    git -C "$ROOT" show "$b:$path" > "$tmp" 2>/dev/null
    case ",$(ticket_yaml "$TICKET" blocked_by | tr -d ' ')," in
      *",$id,"*|*",$((10#$id)),"*) rm -f "$tmp"; fail "ticket $NN is blocked_by $id, which is in progress on $b — ship it first" ;;
    esac
    case ",$(ticket_yaml "$tmp" blocked_by | tr -d ' ')," in
      *",$NN,"*|*",$((10#$NN)),"*) rm -f "$tmp"; fail "ticket $id (in progress on $b) is blocked_by $NN — they cannot run in parallel" ;;
    esac
    while IFS= read -r a; do
      [ -z "$a" ] && continue
      while IFS= read -r c; do
        [ -z "$c" ] && continue
        if scopes_hit "$a" "$c"; then
          rm -f "$tmp"
          fail "scope overlap with ticket $id on $b: '$a' vs '$c'. Ship $id first, or narrow scope_paths"
        fi
      done < <(ticket_yaml_list "$tmp" scope_paths)
    done < <(ticket_yaml_list "$TICKET" scope_paths)
  done < <(other_claims)
  rm -f "$tmp"
  if [ "$n" -ge "$max" ]; then
    fail "$n ticket(s) already in progress:$others (limits.max_active_tickets=$max). Ship one, delete an abandoned branch (git branch -D <branch>), or raise the limit"
  fi
}

require_worktree() {
  [ "$(config_get limits.require_worktree)" = "true" ] || return 0
  local gd gc
  gd="$(cd "$(git -C "$ROOT" rev-parse --git-dir)" && pwd -P)"
  gc="$(cd "$(git -C "$ROOT" rev-parse --git-common-dir)" && pwd -P)"
  if [ "$gd" = "$gc" ]; then
    fail "limits.require_worktree: claim from a linked worktree: scripts/gate.sh implement $NN --worktree"
  fi
}

freeze_scope() {
  mkdir -p "$STATE"
  local out="$STATE/scope-$NN.txt" g
  if [ -s "$out" ] && [ "$WIDEN" -ne 1 ]; then
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      grep -Fxq -- "$g" "$out" || fail "scope_paths now include '$g', past the frozen scope. Widening is deliberate: scripts/gate.sh implement $NN --widen"
    done < <(ticket_yaml_list "$TICKET" scope_paths)
  fi
  ticket_yaml_list "$TICKET" scope_paths > "$out"
  [ -s "$out" ] || fail "scope_paths empty; cannot freeze scope"
}

protected_branch() {
  local b="$1"
  [ "$b" = "$(base_branch)" ] || [ "$b" = "main" ] || [ "$b" = "master" ]
}

merge_base_ok() {
  local ref
  if ! ref="$(base_ref)"; then
    [ -n "${CI:-}" ] && fail "base '$(base_branch)' not found (tried $(base_branch), origin/$(base_branch)) — fetch it (actions/checkout: fetch-depth: 0)"
    warn "base '$(base_branch)' not found; skipping merge-base check"
    return 0
  fi
  git -C "$ROOT" merge-base --is-ancestor "$ref" HEAD 2>/dev/null \
    || fail "branch does not contain $ref — rebase or merge $ref into it"
}

scope_gate() {
  local tmp f out=""
  tmp="$(mktemp)"
  ticket_yaml_list "$TICKET" scope_paths > "$tmp"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    path_in_scope "$f" "$tmp" || out="$out $f"
  done < <(product_diff_files)
  rm -f "$tmp"
  [ -z "$out" ] || fail "files outside scope_paths:$out — revert them, or widen scope_paths and re-claim with --widen"
}

# First changed file whose risk floor is above the ticket tier: "<file> <floor>".
tier_breach() {
  local f floor
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    floor="$(path_risk_floor "$f")"
    if [ "$(tier_rank "$floor")" -gt "$(tier_rank "$TIER")" ]; then
      echo "$f $floor"
      return 0
    fi
  done < <(product_diff_files)
  return 1
}

risk_reprice() {
  local b
  b="$(tier_breach)" || return 0
  fail "diff touches '${b% *}' (floor ${b##* }) above ticket tier $TIER — set risk_tier: ${b##* } in the ticket, or drop that change"
}

assumed_left() {
  awk -F'|' '/^## Load-Bearing Assumptions/{inb=1;next} inb && /^## /{inb=0}
    inb && /^\|/ { s=$4; gsub(/[[:space:]*`]/, "", s); if (toupper(s) == "ASSUMED") print }' "$TICKET"
}

test_ratchet() {
  local now mb base_count
  now="$(last_stamp 2>/dev/null)" || return 0
  now="$(json_get "$now" test_count)"
  case "$now" in ''|null|*[!0-9]*) return 0 ;; esac
  local ref
  ref="$(base_ref)" || return 0
  mb="$(git -C "$ROOT" merge-base "$ref" HEAD 2>/dev/null)" || return 0
  base_count="$(grep -F "\"head\":\"$mb\"" "$STATE/verify-stamps.jsonl" 2>/dev/null | grep '"exit":0' | tail -1)"
  [ -n "$base_count" ] || return 0
  base_count="$(json_get "$base_count" test_count)"
  case "$base_count" in ''|null|*[!0-9]*) return 0 ;; esac
  if [ "$now" -lt "$base_count" ] && ! grep -q 'Ruling:.*test' "$TICKET"; then
    fail "test count dropped $base_count -> $now since $(base_branch) without a 'Ruling:' line in the ticket naming the removed tests"
  fi
}

migration_gate() {
  local dir f changed=0 rev
  dir="$(config_get migrations_dir)"
  [ -z "$dir" ] && dir="migrations"
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
  done < <(product_diff_files)
  [ "$changed" -eq 0 ] && return 0
  [ "$TIER" = "HIGH" ] || fail "migration files in diff require HIGH tier"
}

diff_size_gate() {
  local warn_n fail_n ins ref mb
  warn_n="$(config_get limits.diff_warn_lines)"; [ -z "$warn_n" ] && warn_n=300
  fail_n="$(config_get limits.diff_fail_lines)"; [ -z "$fail_n" ] && fail_n=0
  ref="$(base_ref)" || return 0
  mb="$(git -C "$ROOT" merge-base "$ref" HEAD 2>/dev/null)" || return 0
  ins="$(git -C "$ROOT" diff --numstat "$mb" -- . "${NON_PRODUCT[@]}" | awk '{s+=$1} END {print s+0}')"
  if [ "$fail_n" -gt 0 ] && [ "$ins" -gt "$fail_n" ]; then
    fail "diff insertions $ins exceed limits.diff_fail_lines=$fail_n — split the ticket"
  fi
  [ "$warn_n" -gt 0 ] && [ "$ins" -gt "$warn_n" ] && warn "diff insertions $ins > limits.diff_warn_lines=$warn_n"
  return 0
}

lockfile_new_deps() {
  case "$(config_get guard.new_deps)" in false|off) return 0 ;; esac
  local hit=0 f listed ref name missing=""
  while IFS= read -r f; do
    case "$(basename "$f")" in
      package-lock.json|pnpm-lock.yaml|yarn.lock|Cargo.lock|go.sum|poetry.lock|uv.lock|Gemfile.lock) hit=1 ;;
    esac
  done < <(product_diff_files)
  [ "$hit" -eq 0 ] && return 0
  listed="$(ticket_yaml_list "$TICKET" new_deps)"
  [ -n "$listed" ] || fail "lockfile changed but ticket new_deps: is empty — list every added package"
  ref="$(base_ref)" || return 0
  while IFS= read -r name; do
    [ -z "$name" ] && continue
    printf '%s\n' "$listed" | grep -Fxq -- "$name" || missing="$missing $name"
  done < <(lockfile_added_names "$ROOT" "$ref")
  [ -z "$missing" ] || fail "lockfile added packages not in ticket new_deps:$missing"
}

# --- steps ------------------------------------------------------------------

step_new() {
  STEP=new
  [ -n "$ARG_SLUG" ] || usage
  printf '%s' "$ARG_SLUG" | grep -Eq '^[a-z0-9][a-z0-9-]*$' || fail "slug must be lowercase letters, digits, dashes (got '$ARG_SLUG')"
  local tier="${ARG_TIER:-LOW}" tpl max n f title dest
  case "$tier" in LOW) tpl=lite ;; MEDIUM|HIGH) tpl=full ;; *) fail "--tier must be LOW, MEDIUM or HIGH" ;; esac
  git -C "$ROOT" rev-parse --verify --quiet HEAD >/dev/null || fail "no commits yet — make an initial commit first"
  max=0
  while IFS= read -r n; do
    n="${n%%-*}"
    case "$n" in ''|*[!0-9]*) continue ;; esac
    [ "$((10#$n))" -gt "$max" ] && max="$((10#$n))"
  done < <(
    for f in "$TICKETS_OPEN"/*.md "$TICKETS_CLOSED"/*.md; do [ -f "$f" ] && basename "$f"; done
    git -C "$ROOT" for-each-ref --format='%(refname:lstrip=3)' refs/agentic/nn/ 2>/dev/null
    git -C "$ROOT" for-each-ref --format='%(refname:short)' "refs/heads/$PREFIX*" 2>/dev/null | sed "s#^$PREFIX##"
  )
  n=$((max + 1))
  while ! git -C "$ROOT" update-ref "refs/agentic/nn/$(nn_pad "$n")" HEAD "" 2>/dev/null; do
    n=$((n + 1))
    [ "$n" -gt $((max + 50)) ] && fail "could not reserve a ticket number"
  done
  NN="$(nn_pad "$n")"
  title="${ARG_TITLE:-$(printf '%s' "$ARG_SLUG" | tr '-' ' ')}"
  mkdir -p "$TICKETS_OPEN"
  dest="$TICKETS_OPEN/$NN-$ARG_SLUG.md"
  T="# Ticket $NN — $title" awk '!d && /^# Ticket NN/ { print ENVIRON["T"]; d = 1; next } { print }' \
    "$ROOT/.agentic/templates/ticket-$tpl.md" > "$dest"
  ticket_set "$dest" risk_tier "$tier"
  echo "created $(relpath_from "$dest")"
  echo "NEXT: fill Request, Done Contract (each assertion with Check: \`<command>\`) and scope_paths"
  echo "THEN: scripts/gate.sh advance $NN"
  exit 0
}

make_worktree() {
  local b dir common main_root wt
  b="$(ticket_branch_for "$NN")"
  [ -n "$b" ] || b="$(branch_name)"
  if wt="$(worktree_of_branch "$b")"; then
    echo "ticket $NN already has a worktree: $wt"
  else
    common="$(git -C "$ROOT" rev-parse --path-format=absolute --git-common-dir)"
    main_root="$(dirname "$common")"
    dir="$(config_get worktree_dir)"; [ -z "$dir" ] && dir=".worktrees"
    wt="$main_root/$dir/$NN-$SLUG"
    if git -C "$ROOT" rev-parse --verify --quiet "refs/heads/$b" >/dev/null; then
      git -C "$ROOT" worktree add "$wt" "$b" >/dev/null 2>&1 || fail "git worktree add $wt $b failed"
    else
      local ref
      ref="$(base_ref)" || ref=HEAD
      git -C "$ROOT" worktree add --no-track -b "$b" "$wt" "$ref" >/dev/null 2>&1 || fail "git worktree add -b $b $wt $ref failed"
    fi
    local rel
    rel="$(relpath_from "$TICKET")"
    if [ ! -f "$wt/$rel" ]; then
      mkdir -p "$(dirname "$wt/$rel")"
      cp "$TICKET" "$wt/$rel"
      git -C "$ROOT" ls-files --error-unmatch "$TICKET" >/dev/null 2>&1 || rm -f "$TICKET"
    fi
  fi
  echo "worktree: $wt"
  ( cd "$wt" && AGENTIC_ROOT="" ADVANCING="$ADVANCING" ./scripts/gate.sh implement "$NN" $([ "$WIDEN" -eq 1 ] && echo --widen) )
  local rc=$?
  echo "THEN: open $wt as the workspace and run scripts/gate.sh advance $NN there"
  exit "$rc"
}

step_implement() {
  STEP=implement
  [ -n "$NN" ] || usage
  local b wt
  b="$(ticket_branch_for "$NN")"
  if [ -n "$b" ] && ! on_ticket_branch; then
    wt="$(worktree_of_branch "$b")" && fail "ticket $NN is checked out in $wt — work there"
    [ "$(is_dirty)" = "false" ] || fail "uncommitted product changes on $(current_branch); commit or stash them before switching to $b"
    git -C "$ROOT" checkout "$b" >/dev/null 2>&1 || fail "git checkout $b failed"
    load_ticket
  fi
  [ -n "$TICKET" ] || fail "ticket $NN not found${b:+ on $b}"
  if [ "$STATUS" = "closed" ]; then
    echo "ticket $NN is already shipped on $(current_branch)"
    finish 0
  fi
  lint_or_fail "$SCRIPT_DIR/ticket-lint.sh" "$TICKET"
  case "$STATUS" in
    open|in-progress) ;;
    blocked-on-alignment) fail "ticket is blocked-on-alignment — /agentic-grill $NN" ;;
    *) fail "status '$STATUS' cannot be claimed" ;;
  esac
  local blockers
  blockers="$(unresolved_blockers "$TICKET")"
  [ -z "$blockers" ] || fail "blocked_by $blockers not closed"
  claims_rule
  [ "$WORKTREE" -eq 1 ] && make_worktree
  session_traps
  if [ "$TIER" != "LOW" ]; then
    lint_or_fail "$SCRIPT_DIR/model-check.sh"
  fi
  require_worktree

  local want cur
  want="$(branch_name)"
  cur="$(current_branch)"
  if ! on_ticket_branch; then
    protected_branch "$cur" || [ "$(is_dirty)" = "false" ] \
      || fail "uncommitted product changes on $cur; commit or stash them before claiming $NN"
    local wt
    wt="$(worktree_of_branch "$want")" && fail "$want is checked out in $wt — work there"
    if git -C "$ROOT" rev-parse --verify --quiet "refs/heads/$want" >/dev/null; then
      git -C "$ROOT" checkout "$want" >/dev/null 2>&1 || fail "git checkout $want failed"
    else
      local ref
      ref="$(base_ref)" || { ref=HEAD; warn "base '$(base_branch)' not found; branching from HEAD"; }
      git -C "$ROOT" checkout --no-track -b "$want" "$ref" >/dev/null 2>&1 || fail "git checkout -b $want $ref failed"
    fi
    load_ticket
    [ -n "$TICKET" ] || fail "ticket $NN disappeared on checkout of $want"
  fi
  freeze_scope
  if [ "$STATUS" != "in-progress" ]; then
    ticket_set "$TICKET" status in-progress
    STATUS=in-progress
  fi
  git -C "$ROOT" add -- "$TICKET"
  if ! git -C "$ROOT" diff --cached --quiet -- "$TICKET"; then
    git -C "$ROOT" commit -q -m "$NN: claim" -- "$TICKET" || fail "claim commit failed"
  fi
  echo "claimed $NN on $(current_branch); scope frozen: $(tr '\n' ' ' < "$STATE/scope-$NN.txt")"
  finish 0
}

step_verify() {
  STEP=verify
  "$SCRIPT_DIR/verify.sh" || fail "verify failed — the failing step and its output are above; log in .agentic/state/verify-stamps.jsonl"
  finish 0
}

run_checks() {
  local tmp rc
  tmp="$(mktemp)"
  check_cmds > "$tmp"
  run_commands "$tmp" "$STATE/checks-$NN.json" "check-$NN" "$(sha_text < "$tmp")"
  rc=$?
  rm -f "$tmp"
  return "$rc"
}

step_check() {
  STEP=check
  [ -n "$TICKET" ] || fail "ticket $NN not found"
  run_checks || fail "a Done Contract check failed (output above; logs in .agentic/state/logs/)"
  finish 0
}

write_brief() {
  local dir="$1" report="$2" persona="$3" n
  n="$(dc_assertion_count "$TICKET")"
  {
    echo "# Review brief — ticket $NN ($TIER)"
    echo
    echo "You are the evaluator. You did not write this change and you do not trust its author."
    echo "Read-only: do not edit product files. The only file you write is the report."
    echo
    echo "- Procedure: .agents/skills/agentic-critic/SKILL.md"
    [ -n "$persona" ] && echo "- Persona: $persona"
    echo "- Evidence in $(relpath_from "$dir")/: contract.md, diff.md, checks.json, verify-stamp.json"
    echo "- You may read any repo file and run read-only commands (tests, greps)."
    echo "- Report template: .agentic/templates/critic_report.md"
    echo "- Write the report to: $report"
    echo
    echo "The report must contain:"
    echo "- \`**Head:** $(cat "$dir/HEAD")\` — the commit you evaluated"
    echo "- \`**Verdict:** APPROVED | CHANGES_REQUESTED | REOPEN_REQUIRED\`"
    if [ -z "$persona" ]; then
      echo "- a \`## Claims\` table with at least $n row(s), one per Done Contract assertion, each with a"
    else
      echo "- a \`## Claims\` table with at least 1 row, each with a"
    fi
    echo "  runnable command. The gate re-runs every command; any failure blocks ship."
    echo "- a judgment on the tests: would they fail without this change?"
  } > "$dir/${4:-BRIEF.md}"
}

build_payload() {
  local dir="$STATE/payload-$NN" ref mb
  rm -rf "$dir"
  mkdir -p "$dir"
  current_head > "$dir/HEAD"
  ref="$(base_ref)" || ref=""
  mb=""
  [ -n "$ref" ] && mb="$(git -C "$ROOT" merge-base "$ref" HEAD 2>/dev/null || true)"
  [ -n "$mb" ] || mb="$(git -C "$ROOT" rev-list --max-parents=0 HEAD | tail -1)"
  "$SCRIPT_DIR/review-package.sh" "$mb" HEAD "$dir/diff.md" >/dev/null || fail "review-package failed"
  {
    echo "# Contract — ticket $NN: $TITLE"
    echo
    awk '/^## (Request|Restate Contract|Done Contract|Constraints|Constraints & Residue|Definition of Done)/{inb=1; print; next} /^## /{inb=0} inb' "$TICKET"
    echo
    echo "## scope_paths"
    ticket_yaml_list "$TICKET" scope_paths | sed 's/^/- /'
  } > "$dir/contract.md"
  cp "$STATE/checks-$NN.json" "$dir/checks.json" 2>/dev/null || true
  last_stamp > "$dir/verify-stamp.json" 2>/dev/null || true
  write_brief "$dir" "$(relpath_from "$(CRITIC_REPORT)")" "" BRIEF.md
  if security_required; then
    write_brief "$dir" "$(relpath_from "$(SECURITY_REPORT)")" ".agents/personas/security-auditor.md" BRIEF-security.md
    printf '\nA second, independent reviewer uses BRIEF-security.md in the same turn.\n' >> "$dir/BRIEF.md"
  fi
  echo "payload: $(relpath_from "$dir")"
}

# Mode B: run critic.command in a throwaway worktree; its stdout is the report.
run_reviewer() {
  local report="$1" brief="$2" cmd wt head rc
  cmd="$(config_get critic.command)"
  head="$(cat "$STATE/payload-$NN/HEAD")"
  wt="$(mktemp -d)/review"
  git -C "$ROOT" worktree add --detach "$wt" "$head" >/dev/null 2>&1 || fail "could not create review worktree"
  echo "critic: running reviewer ($cmd) for $(relpath_from "$report")"
  ( cd "$wt" && AGENTIC_PAYLOAD="$STATE/payload-$NN" AGENTIC_BRIEF="$brief" AGENTIC_NN="$NN" bash -c "$cmd" ) > "$report.tmp"
  rc=$?
  git -C "$ROOT" worktree remove --force "$wt" >/dev/null 2>&1
  if [ "$rc" -ne 0 ] || [ ! -s "$report.tmp" ]; then
    rm -f "$report.tmp"
    fail "critic.command exited $rc or wrote nothing"
  fi
  if [ -z "$(report_head "$report.tmp")" ]; then
    { echo "**Head:** $head"; echo; cat "$report.tmp"; } > "$report"
    rm -f "$report.tmp"
  else
    mv "$report.tmp" "$report"
  fi
  sha_file "$report" > "$STATE/reviewer-$(basename "$report" .md).sha"
}

validate_report() {
  local f="$1" min="$2" v n rec
  v="$(report_verdict "$f")"
  [ -n "$v" ] || fail "$(relpath_from "$f") has no **Verdict:** line"
  [ -n "$(report_head "$f")" ] || fail "$(relpath_from "$f") has no **Head:** line"
  rec="$STATE/reviewer-$(basename "$f" .md).sha"
  if [ -f "$rec" ] && [ "$(cat "$rec")" != "$(sha_file "$f")" ]; then
    fail "$(relpath_from "$f") changed after the reviewer wrote it — delete it and re-run the reviewer"
  fi
  [ "$v" = "APPROVED" ] || fail "$(relpath_from "$f") verdict is $v — address it, commit, re-review"
  n="$(claim_commands "$f" | grep -c .)"
  [ "$n" -ge "$min" ] || fail "$(relpath_from "$f") has $n claim command(s); need at least $min"
}

step_critic() {
  STEP=critic
  [ -n "$TICKET" ] || fail "ticket $NN not found"
  set_fast
  [ "$FAST" -eq 0 ] || fail "LOW fast-lane tickets have no reviewer step"
  [ "$(is_dirty)" = "false" ] || fail "commit first — the reviewer evaluates a commit"
  checks_ok || fail "Done Contract checks not green for this tree: scripts/gate.sh check $NN"

  if ! reports_current; then
    payload_current || build_payload
    if [ -n "$(config_get critic.command)" ]; then
      report_current "$(CRITIC_REPORT)" || run_reviewer "$(CRITIC_REPORT)" "$STATE/payload-$NN/BRIEF.md"
      if security_required; then
        report_current "$(SECURITY_REPORT)" || run_reviewer "$(SECURITY_REPORT)" "$STATE/payload-$NN/BRIEF-security.md"
      fi
    else
      echo "NEXT: spawn the reviewer (agentic-evaluator subagent) with $(relpath_from "$STATE/payload-$NN/BRIEF.md")"
      finish 0
    fi
  fi

  validate_report "$(CRITIC_REPORT)" "$(dc_assertion_count "$TICKET")"
  security_required && validate_report "$(SECURITY_REPORT)" 1

  local tmp f
  tmp="$(mktemp)"
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    claim_commands "$f"
  done < <(required_reports) > "$tmp"
  run_commands "$tmp" "$STATE/claims-$NN.json" "claims-$NN" "$(reports_key)"
  local rc=$?
  rm -f "$tmp"
  [ "$rc" -eq 0 ] || fail "a reviewer claim command failed (output above) — the report's claim is false, or the code is"
  finish 0
}

# Every check ship and CI need. Runs missing evidence; never moves the ticket.
pr_checks() {
  [ -n "$TICKET" ] || fail "ticket $NN not found"
  set_fast
  lint_or_fail "$SCRIPT_DIR/ticket-lint.sh" "$TICKET"
  merge_base_ok
  has_product_diff || fail "no product change against $(base_branch)"
  scope_gate
  risk_reprice
  migration_gate
  lockfile_new_deps
  diff_size_gate
  local assumed
  assumed="$(assumed_left)"
  [ -z "$assumed" ] || fail "ASSUMED load-bearing rows remain in the ticket:\n$assumed"
  lint_or_fail "$SCRIPT_DIR/debt-lint.sh"
  lint_or_fail "$SCRIPT_DIR/env-lint.sh"
  if [ "$FAST" -eq 0 ]; then
    [ "$(is_dirty)" = "false" ] || fail "uncommitted product changes — commit them"
    stamp_ok || fail "no fresh green verify stamp: scripts/verify.sh"
    test_ratchet
  fi
  checks_ok || run_checks || fail "a Done Contract check failed (output above)"
  if [ "$FAST" -eq 0 ]; then
    reports_current || fail "no reviewer report for this product state (Head: must match)"
    validate_report "$(CRITIC_REPORT)" "$(dc_assertion_count "$TICKET")"
    security_required && validate_report "$(SECURITY_REPORT)" 1
    if ! claims_ok; then
      local tmp f rc
      tmp="$(mktemp)"
      while IFS= read -r f; do [ -n "$f" ] && claim_commands "$f"; done < <(required_reports) > "$tmp"
      run_commands "$tmp" "$STATE/claims-$NN.json" "claims-$NN" "$(reports_key)"
      rc=$?
      rm -f "$tmp"
      [ "$rc" -eq 0 ] || fail "a reviewer claim command failed (output above)"
    fi
  fi
}

step_pr() {
  STEP=pr
  pr_checks
  if [ "$REQUIRE_SHIPPED" -eq 1 ] && [ "$STATUS" != "closed" ]; then
    fail "ticket $NN is not shipped on this branch — run scripts/gate.sh advance $NN until it ships"
  fi
  finish 0
}

# Move the ticket between open/ and closed/ with its new status, in one commit
# (plus any EXTRA paths). Rolls the move back if the commit fails.
move_ticket() {
  local st="$1" msg="$2" old new prev dir f add=()
  shift 2
  old="$(relpath_from "$TICKET")"
  prev="$STATUS"
  [ "$st" = "closed" ] && dir=closed || dir=open
  new=".agentic/tickets/$dir/$(basename "$TICKET")"
  mkdir -p "$ROOT/.agentic/tickets/$dir"
  git -C "$ROOT" mv "$old" "$new" || fail "git mv $old $new failed"
  ticket_set "$ROOT/$new" status "$st"
  add=("$new")
  for f in "$@"; do add+=("$f"); done
  if ! git -C "$ROOT" add -A -- "${add[@]}" || ! git -C "$ROOT" commit -q -m "$msg" -- "$old" "${add[@]}"; then
    git -C "$ROOT" mv "$new" "$old" >/dev/null 2>&1
    ticket_set "$ROOT/$old" status "$prev"
    fail "commit '$msg' failed; ticket left at $old"
  fi
  TICKET="$ROOT/$new"
  STATUS="$st"
}

step_ship() {
  STEP=ship
  [ -n "$TICKET" ] || fail "ticket $NN not found"
  [ "$STATUS" = "closed" ] && { echo "ticket $NN already shipped"; finish 0; }
  claimed_here || fail "ticket $NN is not claimed in this worktree: scripts/gate.sh implement $NN"
  protected_branch "$(current_branch)" && fail "refusing to ship on protected branch $(current_branch)"
  set_fast
  local f files=() out="" scope="$STATE/scope-$NN.txt"
  if [ "$FAST" -eq 1 ] && [ "$(is_dirty)" = "true" ]; then
    while IFS= read -r f; do
      [ -z "$f" ] && continue
      if path_in_scope "$f" "$scope"; then files+=("$f"); else out="$out $f"; fi
    done < <({ git -C "$ROOT" diff --name-only HEAD -- . "${NON_PRODUCT[@]}"; git -C "$ROOT" ls-files -o --exclude-standard -- . "${NON_PRODUCT[@]}"; } | sort -u)
    [ -z "$out" ] || fail "uncommitted files outside the frozen scope:$out — revert them, or widen scope_paths and re-claim with --widen"
    files+=("$(relpath_from "$TICKET")")
    git -C "$ROOT" add -A -- "${files[@]}" || fail "git add failed"
    git -C "$ROOT" commit -q -m "$NN: $TITLE" -- "${files[@]}" || fail "commit failed"
    echo "committed: ${files[*]}"
  fi
  pr_checks
  if [ "$FAST" -eq 0 ]; then
    lessons_ok || fail "write .agentic/journal/lessons/$NN.md ('- [$NN] ...' lines or 'Lessons: none')"
  fi
  files=()
  for f in "$JOURNAL/$NN"-*.md "$JOURNAL/lessons/$NN.md"; do
    [ -f "$f" ] && files+=("$(relpath_from "$f")")
  done
  move_ticket closed "$NN: close" ${files[@]+"${files[@]}"}
  echo "shipped $NN on $(current_branch)"
  finish 0
}

step_reopen() {
  STEP=reopen
  [ -n "$TICKET" ] || fail "ticket $NN not found"
  [ "$STATUS" = "closed" ] || fail "ticket $NN is not closed"
  on_ticket_branch || fail "reopen runs on the ticket's own branch"
  local ref
  if ref="$(base_ref)" && git -C "$ROOT" ls-tree --name-only "$ref" -- .agentic/tickets/closed/ 2>/dev/null | grep -q "/$NN-"; then
    fail "ticket $NN is already merged into $(base_branch) — new work is a new ticket"
  fi
  move_ticket in-progress "$NN: reopen"
  WIDEN=1
  freeze_scope
  echo "reopened $NN on $(current_branch)"
  finish 0
}

step_next() {
  STEP=next
  if [ "$ALL" -eq 1 ]; then
    next_all
    exit 0
  fi
  compute_next
  print_next
  next_exit
  exit $?
}

next_all() {
  local f id st blk t busy
  busy=" $(other_claims | cut -f1 | tr '\n' ' ') $(branch_nn) "
  echo "IN FLIGHT:"
  other_claims | while IFS=$'\t' read -r id b _; do echo "  $id on $b"; done
  if [ -n "$(branch_nn)" ]; then echo "  $(branch_nn) on $(current_branch) (this worktree)"; fi
  echo "OPEN:"
  for f in "$TICKETS_OPEN"/*.md; do
    [ -f "$f" ] || continue
    id="$(basename "$f" | sed 's/-.*//')"
    case "$busy" in *" $id "*) continue ;; esac
    st="$(branch_status "$id")"
    [ -n "$st" ] && [ "$st" != "open" ] && { echo "  $id $st on $(ticket_branch_for "$id") — $(ticket_title "$f")"; continue; }
    st="$(ticket_yaml "$f" status)"
    t="$(ticket_yaml "$f" risk_tier)"
    blk="$(unresolved_blockers "$f")"
    if [ "$st" = "blocked-on-alignment" ]; then
      echo "  $id $t blocked-on-alignment — $(ticket_title "$f")"
    elif [ -n "$blk" ]; then
      echo "  $id $t waiting on $blk — $(ticket_title "$f")"
    else
      echo "  $id $t $st — $(ticket_title "$f")"
    fi
  done
  echo "RECENTLY CLOSED:"
  ls -1t "$TICKETS_CLOSED"/*.md 2>/dev/null | head -5 | while IFS= read -r f; do
    echo "  $(basename "$f" .md)"
  done
}

step_advance() {
  STEP=advance
  ADVANCING=1
  export ADVANCING
  rm -f "$STATE/step-$NN.json" 2>/dev/null
  local i=0 last="" key
  while [ "$i" -lt 25 ]; do
    compute_next
    if [ "$WHO" != "gate" ]; then
      echo
      print_next
      next_exit
      exit $?
    fi
    key="$STEP_FN:$(worktree_fp):$(ls -l "$STATE" 2>/dev/null | sha_text)"
    if [ "$key" = "$last" ]; then
      echo "gate advance: '$NEXT_MSG' ran but changed nothing — stopping (gate bug?)" >&2
      print_next
      exit 1
    fi
    last="$key"
    echo "== gate: $NEXT_MSG ($WHY)"
    ( "$STEP_FN" )
    load_ticket
    [ -z "$NN" ] && NN="$(branch_nn)" && load_ticket
    i=$((i + 1))
  done
  echo "gate advance: too many steps — stopping" >&2
  exit 1
}

[ -n "$CMD" ] || usage
case "$CMD" in
  next) step_next ;;
  advance) step_advance ;;
  new) step_new ;;
  implement) step_implement ;;
  check) [ -n "$NN" ] || usage; step_check ;;
  critic) [ -n "$NN" ] || usage; step_critic ;;
  ship) [ -n "$NN" ] || usage; step_ship ;;
  reopen) [ -n "$NN" ] || usage; step_reopen ;;
  pr) [ -n "$NN" ] || usage; step_pr ;;
  -h|--help|help) usage ;;
  *) echo "gate: unknown command '$CMD'" >&2; usage ;;
esac
