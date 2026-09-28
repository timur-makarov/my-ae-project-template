#!/usr/bin/env bash
# ticket-lint.sh — validate ticket files against the template contract.
#
# Usage: scripts/ticket-lint.sh [ticket-file ...]
#   With no args, lints every ticket in .agentic/tickets/open/.
#   Exit 0 = all tickets valid; exit 1 = violations printed to stderr.
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

FILES=("$@")
if [ ${#FILES[@]} -eq 0 ]; then
  while IFS= read -r f; do FILES+=("$f"); done < <(find "$TICKETS_OPEN" -name '*.md' -not -name '.gitkeep' 2>/dev/null | sort)
fi

if [ ${#FILES[@]} -eq 0 ]; then
  echo "ticket-lint: no tickets to lint."
  exit 0
fi

fail=0
err() { echo "ticket-lint: $1: $2" >&2; fail=1; }
warn() { echo "ticket-lint: $1: WARNING: $2" >&2; }

ticket_exists() {
  local id="$1"
  id="$(echo "$id" | tr -d ' ')";
  [ -z "$id" ] && return 1
  [ "$id" = "none" ] && return 0
  ticket_file "$(nn_pad "$id")" >/dev/null 2>&1
}

# Very small cycle detector: walk blocked_by refs.
cycle_from() {
  local start="$1" current="$1" seen=" $1 "
  local hops=0
  while [ "$hops" -lt 32 ]; do
    local f next
    f="$(ticket_file "$(nn_pad "$current")" 2>/dev/null)" || return 1
    next="$(ticket_yaml "$f" blocked_by)"
    next="$(echo "$next" | tr -d ' ')"
    [ -z "$next" ] || [ "$next" = "none" ] && return 1
    # take first id if comma-separated
    next="${next%%,*}"
    case "$seen" in
      *" $next "*) echo "$start -> ... -> $next"; return 0 ;;
    esac
    seen="$seen$next "
    current="$next"
    hops=$((hops + 1))
  done
  return 1
}

for f in "${FILES[@]}"; do
  [ -f "$f" ] || { err "$f" "file not found"; continue; }

  if ! awk 'BEGIN{n=0} /^---[[:space:]]*$/{n++} END{exit !(n>=2)}' "$f"; then
    err "$f" "missing YAML front matter (--- ... ---)"
    continue
  fi

  status="$(ticket_yaml "$f" status)"
  case "$status" in
    open|in-progress|blocked-on-alignment|ready-for-critic|ready-for-review|closed) ;;
    "") err "$f" "missing status in front matter" ;;
    *)  err "$f" "invalid Status: '$status'" ;;
  esac

  kind="$(ticket_yaml "$f" type)"
  case "$kind" in
    directive|diagnosis|question|thinking-out-loud|prototype|wide-refactor) ;;
    "") err "$f" "missing type in front matter" ;;
    *)  err "$f" "invalid Type: '$kind'" ;;
  esac

  tier="$(ticket_yaml "$f" risk_tier)"
  case "$tier" in
    LOW|MEDIUM|HIGH) ;;
    "") err "$f" "missing risk_tier" ;;
    *)  err "$f" "invalid Risk Tier: '$tier'" ;;
  esac

  template="$(ticket_yaml "$f" template)"
  case "$template" in
    lite|full) ;;
    "") err "$f" "missing template marker (lite|full)" ;;
    *)  err "$f" "invalid Template: '$template'" ;;
  esac
  if { [ "$tier" = "MEDIUM" ] || [ "$tier" = "HIGH" ]; } && [ "$template" = "lite" ]; then
    err "$f" "Risk Tier $tier requires the full template"
  fi

  if ! grep -q '^## Done Contract' "$f"; then
    err "$f" "missing '## Done Contract' section"
  elif ! awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /^[0-9]+\. *[^ <]/{found=1} END{exit !found}' "$f"; then
    err "$f" "Done Contract has no concrete numbered assertion (placeholders don't count)"
  else
    if ! awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /^[0-9]+\./{c++; if ($0 !~ /Check:/) bad=1} END{exit (c==0 || bad)}' "$f"; then
      err "$f" "each Done Contract assertion must include a Check: token naming a runnable command"
    else
      while IFS= read -r dcline; do
        payload="${dcline#*Check:}"
        payload="$(printf '%s' "$payload" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        [ -z "$payload" ] && continue
        has_tick=0
        case "$payload" in *\`*) has_tick=1 ;; esac
        bare="$(printf '%s' "$payload" | tr -d '`' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
        low="$(printf '%s' "$bare" | tr '[:upper:]' '[:lower:]')"
        case "$low" in
          pass|ok|works)
            err "$f" "vacuous Check: '$payload' — name a runnable command"
            continue
            ;;
          true)
            if [ "$has_tick" -eq 0 ]; then
              err "$f" "vacuous Check: true (English) — use \`true\` (shell) or a real command"
            fi
            continue
            ;;
        esac
        case "$bare" in
          selftest.sh|scripts/selftest.sh|pytest|"pytest -q"|"npm test")
            err "$f" "Check: '$bare' is the blanket suite — name the focused command"
            continue
            ;;
        esac
        case "$bare" in
          /*|*/*|scripts/*|make|make\ *|cargo\ *|pytest*|go\ test*|npm\ *|pnpm\ *|yarn\ *|bash\ *|true|/bin/true)
            ;;
          *)
            err "$f" "Check: must name a runnable command (got '$payload')"
            ;;
        esac
      done < <(awk '/^## Done Contract/{inb=1;next} /^## /{inb=0} inb && /Check:/ {print}' "$f")
    fi
  fi

  blast="$(grep -o 'NARROWING\|EXPANDING' "$f" | head -1)"
  if [ -z "$blast" ]; then
    err "$f" "missing Blast Radius classification (NARROWING|EXPANDING)"
  elif [ "$blast" = "EXPANDING" ] && [ "$status" != "blocked-on-alignment" ] && [ "$status" != "closed" ]; then
    err "$f" "EXPANDING blast radius requires Status blocked-on-alignment (found '$status')"
  fi

  scopes="$(ticket_yaml_list "$f" scope_paths)"
  if [ -z "$scopes" ]; then
    err "$f" "scope_paths is empty — freeze at least one glob"
  else
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      gs="$(printf '%s' "$g" | tr -d ' ')"
      case "$gs" in
        '*'|'**')
          if [ "$kind" != "wide-refactor" ] || [ "$tier" != "HIGH" ]; then
            err "$f" "lone '$g' glob requires type: wide-refactor and HIGH"
          fi
          ;;
      esac
      floor="$(path_risk_floor "$g")"
      # also check the glob as a path prefix
      if [ "$(tier_rank "$floor")" -gt "$(tier_rank "$tier")" ]; then
        warn "$f" "scope path '$g' intersects risk floor $floor above stated tier $tier"
      fi
      # check common expansions
      case "$g" in
        *.cursor*|scripts*|.agentic/templates*|.agents*|.github*)
          floor2="$(path_risk_floor "${g%/}")"
          if [ "$(tier_rank "$floor2")" -gt "$(tier_rank "$tier")" ]; then
            warn "$f" "scope path '$g' intersects risk floor $floor2 above stated tier $tier"
          fi
          ;;
      esac
    done <<< "$scopes"
  fi

  blocked="$(ticket_yaml "$f" blocked_by)"
  blocked="$(echo "$blocked" | tr -d ' ')"
  if [ -n "$blocked" ] && [ "$blocked" != "none" ]; then
    IFS=',' read -ra ids <<< "$blocked"
    for id in "${ids[@]}"; do
      [ -z "$id" ] && continue
      if ! ticket_exists "$id"; then
        err "$f" "Blocked by: '$id' does not resolve to an existing ticket"
      fi
    done
    cyc="$(cycle_from "$(basename "$f" | sed 's/-.*//; s/^0*//')")" && err "$f" "blocked_by cycle: $cyc"
  fi


  intake="$(config_get limits.intake_strict)"
  [ -z "$intake" ] && intake="true"
  if [ "$intake" = "true" ]; then
    rev="$(ticket_yaml "$f" reversibility)"
    case "$rev" in
      reversible|expand-contract|irreversible) ;;
      "") err "$f" "missing reversibility: reversible|expand-contract|irreversible" ;;
      *) err "$f" "invalid reversibility: '$rev'" ;;
    esac
    rb="$(ticket_yaml "$f" rollback)"
    if [ "$rev" = "irreversible" ]; then
      if [ -z "$rb" ] || [ "$rb" = "n/a" ] || [ "$rb" = "—" ]; then
        err "$f" "irreversible tickets need a compensating rollback: command (not n/a)"
      fi
      if [ "$blast" != "EXPANDING" ] && [ "$status" != "closed" ]; then
        err "$f" "irreversible work is EXPANDING (must grill) unless already closed"
      fi
    fi
    vb="$(grep -m1 -E '\*\*Verbatim:\*\*' "$f" || true)"
    vb_val="$(printf '%s' "$vb" | sed -E 's/.*\*\*Verbatim:\*\*[[:space:]]*//; s/^["'"'"']//; s/["'"'"']$//; s/[[:space:]]*$//')"
    if [ -z "$vb_val" ]; then
      err "$f" "Verbatim is empty"
    fi
    if [ "$template" = "full" ]; then
      grep -q '^\*\*Out of scope:\*\*\|^\\- \*\*Out of scope:\*\*' "$f" \
        || grep -q 'Out of scope:' "$f" \
        || err "$f" "full template missing Out of scope in the Restate Contract"
    else
      grep -qi 'Out of scope' "$f" || err "$f" "lite ticket missing Out of scope"
    fi
    oos="$(grep -m1 -i 'Out of scope' "$f" || true)"
    oos_val="$(printf '%s' "$oos" | sed -E 's/.*[Oo]ut of scope:\**[[:space:]]*//; s/[`*"]//g; s/[[:space:]]*$//')"
    if [ -z "$oos_val" ]; then
      err "$f" "Out of scope is empty"
    fi
    title="$(grep -m1 '^# Ticket' "$f" || true)"
    case "$title" in
      *" and "*|*" And "*)
        if [ "$kind" != "wide-refactor" ]; then
          err "$f" "title contains 'and' — split into atomic tickets or set type: wide-refactor"
        fi
        ;;
    esac
    nscopes=0
    while IFS= read -r g; do
      [ -z "$g" ] && continue
      nscopes=$((nscopes + 1))
    done <<< "$scopes"
    maxg="$(config_get limits.max_scope_globs)"
    [ -z "$maxg" ] && maxg=5
    if [ "$nscopes" -gt "$maxg" ]; then
      grep -q '^## Capability Map' "$f" || err "$f" "more than $maxg scope_paths requires ## Capability Map"
    fi
  fi

  if [ "$status" = "in-progress" ]; then
    claimed="$(ticket_yaml "$f" claimed_by)"
    if [ -z "$claimed" ] || [ "$claimed" = '""' ]; then
      warn "$f" "in-progress ticket has empty claimed_by"
    fi
  fi

  # Status transition vs last committed copy (skip if not in git).
  if has_git && git -C "$ROOT" ls-files --error-unmatch "$f" >/dev/null 2>&1; then
    rel="$(relpath_from "$f")"
    old="$(git -C "$ROOT" show "HEAD:$rel" 2>/dev/null || true)"
    if [ -n "$old" ]; then
      old_status="$(printf '%s' "$old" | awk '/^status:/{sub(/^status:[[:space:]]*/,""); print; exit}')"
      if [ -n "$old_status" ] && [ "$old_status" != "$status" ]; then
        if ! legal_status_transition "$old_status" "$status"; then
          if ! grep -q '^Ruling:' "$f" && ! grep -q 'Ruling:' "$ROOT/.agentic/journal/"* 2>/dev/null; then
            err "$f" "illegal status jump $old_status -> $status (needs a legal transition or a Ruling:)"
          elif ! legal_status_transition "$old_status" "$status"; then
            # regressions allowed with Ruling:
            if ! grep -q 'Ruling:' "$f" "$ROOT/.agentic/journal/$(basename "$f" | sed 's/-.*//')-ledger.md" 2>/dev/null; then
              err "$f" "status regression $old_status -> $status requires a Ruling:"
            fi
          fi
        fi
      fi
    fi
  fi
done

if [ "$fail" -eq 0 ]; then
  echo "ticket-lint: OK (${#FILES[@]} ticket(s))"
fi
exit "$fail"
