#!/usr/bin/env bash
# guard.sh — shell guard (Cursor beforeShellExecution protocol; Claude/Codex via adapt.sh).
# Denies the irreversible or evidence-forging few; asks for host-level changes.
# Everything else is allowed. Standalone: does not source scripts/lib.sh.
# Fails closed: missing jq or an internal error denies.
set -u

deny_raw() {
  printf '{"permission":"deny","user_message":"%s","agent_message":"%s"}\n' "$1" "$1"
  exit 0
}
command -v jq >/dev/null 2>&1 || deny_raw "Blocked: scripts/hooks/guard.sh requires jq (fail closed). Install jq."
trap 'deny_raw "Blocked: guard.sh internal error (fail closed)."' ERR

input="$(cat)"
cmd="$(printf '%s' "$input" | jq -r '.command // empty')"
cwd="$(printf '%s' "$input" | jq -r '.cwd // .workspace_roots[0] // empty')"
[ -n "$cwd" ] && [ -d "$cwd" ] || cwd="$(pwd)"
trap - ERR

deny() { jq -n --arg m "$1" '{permission:"deny", user_message:$m, agent_message:$m}'; exit 0; }
ask() { jq -n --arg m "$1" '{permission:"ask", user_message:$m, agent_message:$m}'; exit 0; }
allow() { echo '{"permission":"allow"}'; exit 0; }

[ -n "$cmd" ] || allow

# Directory the command acts in: a leading `cd X &&` or `git -C X` wins.
dir="$cwd"
lead="$(printf '%s' "$cmd" | sed -nE 's/^[[:space:]]*cd[[:space:]]+([^;&|[:space:]]+)[[:space:]]*(&&|;).*/\1/p')"
[ -z "$lead" ] && lead="$(printf '%s' "$cmd" | sed -nE 's/.*git[[:space:]]+-C[[:space:]]+([^;&|[:space:]]+).*/\1/p')"
if [ -n "$lead" ]; then
  lead="${lead/#\~/$HOME}"
  case "$lead" in /*) ;; *) lead="$cwd/$lead" ;; esac
  [ -d "$lead" ] && dir="$lead"
fi
ROOT="$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null || printf '%s' "$dir")"
CONFIG="$ROOT/.agentic/config.yml"

cfg() {
  awk -v top="$1" -v subk="$2" '
    $0 ~ "^" top ":" { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb && $0 ~ "^[[:space:]]+" subk ":" {
      line=$0
      sub(/^[[:space:]]+[^:]+:[[:space:]]*/, "", line)
      sub(/[[:space:]]*#.*$/, "", line)
      gsub(/^["'\'']|["'\'']$/, "", line)
      gsub(/[[:space:]]+$/, "", line)
      print line
      exit
    }
  ' "$CONFIG" 2>/dev/null
}
top_cfg() { awk -v k="$1" '$0 ~ "^" k ":" { sub(/^[^:]+:[[:space:]]*/, ""); sub(/[[:space:]]*#.*$/, ""); gsub(/"/, ""); print; exit }' "$CONFIG" 2>/dev/null; }

NETWORK="$(cfg guard network)";          [ -z "$NETWORK" ] && NETWORK=allow
INSTALL_PIPE="$(cfg guard install_pipe)"; [ -z "$INSTALL_PIPE" ] && INSTALL_PIPE=deny
NEW_DEPS="$(cfg guard new_deps)";        [ -z "$NEW_DEPS" ] && NEW_DEPS=allow
SECRETS="$(cfg guard secrets)";          [ -z "$SECRETS" ] && SECRETS=deny
PRIV="$(cfg guard privileged)";          [ -z "$PRIV" ] && PRIV=deny
META="$(cfg guard metadata)";            [ -z "$META" ] && META=deny
COMMIT_NN="$(cfg guard commit_requires_nn)"; [ -z "$COMMIT_NN" ] && COMMIT_NN=true
BASE="$(top_cfg base_branch)";           [ -z "$BASE" ] && BASE=main
PREFIX="$(top_cfg branch_prefix)";       [ -z "$PREFIX" ] && PREFIX="ticket/"

# Tool invoked as a command (start, or after ; & | ( ), not merely mentioned.
invoked() {
  printf '%s' "$cmd" | grep -Eq '(^|[;&|(][[:space:]]*)(sudo[[:space:]]+)?(command[[:space:]]+)?([A-Za-z_][A-Za-z0-9_]*=[^[:space:]]+[[:space:]]+)*'"$1"'([[:space:]]|$)'
}
git_sub() {  # git [-C x] [-c k=v] <sub>
  printf '%s' "$cmd" | grep -Eq '(^|[;&|(][[:space:]]*)git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'"$1"'([[:space:]]|$)'
}

branch="$(git -C "$ROOT" branch --show-current 2>/dev/null || true)"
protected() { case "$1" in main|master|"$BASE") return 0 ;; *) return 1 ;; esac; }
branch_nn="$(printf '%s' "$branch" | sed -nE "s#^${PREFIX}0*([0-9]+)-.*#\1#p")"
[ -n "$branch_nn" ] && branch_nn="$(printf '%02d' "$((10#$branch_nn))")"

is_localhost_url() { printf '%s' "$1" | grep -Eqi '^[a-z]+://(localhost|127\.0\.0\.1|\[::1\]|0\.0\.0\.0)([:/]|$)'; }

# --- 1. Remote code execution --------------------------------------------------
pipe_to_interp() {
  printf '%s' "$cmd" | grep -Eqi \
    '\|[[:space:]]*(sudo[[:space:]]+)?(ba)?sh([[:space:]]|$)|[[:space:]]*\|[[:space:]]*(sudo[[:space:]]+)?(zsh|fish|dash|ksh|csh|tcsh|python3?|perl|ruby|node|php|pwsh|powershell)([[:space:]]|$)'
}
remote_eval() {
  printf '%s' "$cmd" | grep -Eqi '(ba)?sh[[:space:]]+<\([[:space:]]*(curl|wget|fetch)|source[[:space:]]+<\([[:space:]]*(curl|wget)' \
    || printf '%s' "$cmd" | grep -Eqi 'eval[[:space:]]+(\$\(|"?\$\(|`"?)[[:space:]]*(curl|wget|fetch)' \
    || printf '%s' "$cmd" | grep -Eqi '(ba)?sh[[:space:]]+-c[[:space:]]+["'\'']?\$\((curl|wget|fetch)'
}
if [ "$INSTALL_PIPE" != "allow" ]; then
  if pipe_to_interp && (invoked curl || invoked wget || invoked fetch || invoked ftp || invoked aria2c); then
    deny "Blocked: piping a remote fetch into a shell/interpreter (curl|sh). Download it, read it, then run it."
  fi
  if remote_eval && (invoked bash || invoked sh || invoked eval || invoked source || invoked zsh); then
    deny "Blocked: evaluating remote content (bash <(curl ...), eval \"\$(curl ...)\")."
  fi
  if (invoked base64 || invoked openssl) && printf '%s' "$cmd" | grep -Eqi '\|[[:space:]]*(ba)?sh'; then
    deny "Blocked: decoded blob piped to a shell."
  fi
fi

# --- 2. Cloud metadata -----------------------------------------------------------
if [ "$META" != "allow" ] && printf '%s' "$cmd" | grep -Eq '169\.254\.169\.254|metadata\.google\.internal|fd00:ec2::254'; then
  deny "Blocked: cloud-metadata address (169.254.169.254 and friends)."
fi

# --- 3. Network (only when guard.network is not allow) ------------------------
if [ "$NETWORK" != "allow" ]; then
  if invoked curl || invoked wget || invoked fetch || invoked aria2c || invoked nc || invoked ncat \
    || invoked socat || invoked ssh || invoked scp || invoked sftp; then
    urls="$(printf '%s' "$cmd" | grep -Eo '(https?|ftp)://[^[:space:]"'\'']+' || true)"
    remote=1
    if [ -n "$urls" ]; then
      remote=0
      while IFS= read -r u; do [ -n "$u" ] && ! is_localhost_url "$u" && remote=1; done <<< "$urls"
    fi
    if [ "$remote" -eq 1 ]; then
      [ "$NETWORK" = "ask" ] && ask "Remote network call (guard.network: ask). Confirm the host."
      deny "Blocked: remote network call with guard.network: $NETWORK."
    fi
  fi
fi

# --- 4. Package installs (only when guard.new_deps is not allow) --------------
if [ "$NEW_DEPS" != "allow" ] && printf '%s' "$cmd" | grep -Eqi \
  '(npm|pnpm|yarn|bun)[[:space:]]+(i|install|add)[[:space:]]+[^-]|(pip3?|pipx|uv)[[:space:]]+(pip[[:space:]]+)?(install|add)[[:space:]]|poetry[[:space:]]+add|cargo[[:space:]]+add|go[[:space:]]+get|gem[[:space:]]+install|composer[[:space:]]+require'; then
  [ "$NEW_DEPS" = "ask" ] && ask "Package install (guard.new_deps: ask). List it under the ticket's new_deps:."
  deny "Blocked: package install with guard.new_deps: $NEW_DEPS."
fi

# --- 5. Host damage ---------------------------------------------------------------
if [ "$PRIV" != "allow" ]; then
  printf '%s' "$cmd" | grep -Eq -- '--privileged|--cap-add[[:space:]=]*ALL' \
    && deny "Blocked: privileged container (--privileged / --cap-add ALL)."
  printf '%s' "$cmd" | grep -Eq 'chmod[[:space:]]+(-R[[:space:]]+)?(0?777|a\+rwx)([[:space:]]|$)' \
    && deny "Blocked: world-writable chmod (777 / a+rwx)."
  if invoked mkfs || invoked fdisk || invoked parted || printf '%s' "$cmd" | grep -Eq 'diskutil[[:space:]]+(erase|partition|zero)'; then
    deny "Blocked: disk partitioning / formatting."
  fi
  invoked dd && printf '%s' "$cmd" | grep -Eq 'of=/dev/' && deny "Blocked: dd writing to a device node."
  if invoked sudo || invoked doas || invoked su; then
    ask "sudo/su: confirm this needs root."
  fi
  if invoked crontab || invoked launchctl || invoked systemctl; then
    ask "Changing scheduled/system services (crontab/launchctl/systemctl). Confirm."
  fi
fi
printf '%s' "$cmd" | grep -Eq '~/\.ssh|\$HOME/\.ssh|/etc/ssh|authorized_keys' && ask "Touching SSH configuration. Confirm."

# --- 6. Secrets -------------------------------------------------------------------
if [ "$SECRETS" != "allow" ]; then
  secret_re='(^|/|[[:space:]])(\.env(\.[A-Za-z0-9_-]+)?|[^[:space:]]*\.pem|[^[:space:]]*\.key|id_rsa|id_ed25519|\.kube/config|\.aws/credentials|\.netrc)([[:space:]]|$|["'\''])'
  if printf '%s' "$cmd" | grep -Eq "$secret_re" && ! printf '%s' "$cmd" | grep -Eq '\.env\.(example|sample|template)'; then
    if printf '%s' "$cmd" | grep -Eq '(^|[;&|][[:space:]]*|[[:space:]])(cat|less|more|head|tail|bat|cp|mv|scp|base64|xxd|strings|grep|rg|awk|sed)[[:space:]]|>|tee[[:space:]]'; then
      [ "$SECRETS" = "ask" ] && ask "Reading or writing a secret file (.env, keys). Confirm."
      deny "Blocked: reading or writing secret files (.env, *.pem, keys) — guard.secrets: $SECRETS. Use .env.example for shape."
    fi
  fi
fi

# --- 7. Discarding work -----------------------------------------------------------
if git_sub reset && printf '%s' "$cmd" | grep -Eq 'reset[[:space:]]+(.*[[:space:]])?--hard'; then
  ask "git reset --hard discards uncommitted work. Confirm."
fi
if git_sub clean && printf '%s' "$cmd" | grep -Eq 'clean[[:space:]]+(.*[[:space:]])?-[a-zA-Z]*f'; then
  ask "git clean -f deletes untracked files. Confirm."
fi
if (git_sub checkout || git_sub restore) && printf '%s' "$cmd" | grep -Eq '(checkout[[:space:]]+--[[:space:]]+\.|restore[[:space:]]+(--[a-z]+[[:space:]]+)*\.)([[:space:]]|$)'; then
  ask "Discarding all uncommitted changes. Confirm."
fi
# rm -r on something outside the repo and temp dirs.
if printf '%s' "$cmd" | grep -Eq '(^|[;&|][[:space:]]*)(sudo[[:space:]]+)?rm[[:space:]]+(-[a-zA-Z]*[rR][a-zA-Z]*|--recursive)'; then
  targets="$(printf '%s' "$cmd" | grep -oE '(^|[;&|][[:space:]]*)(sudo[[:space:]]+)?rm[[:space:]][^;&|]*' | sed -E 's/^[;&|[:space:]]*(sudo[[:space:]]+)?rm[[:space:]]+//' | tr ' ' '\n' | grep -v '^-' || true)"
  while IFS= read -r t; do
    [ -z "$t" ] && continue
    t="${t%\"}"; t="${t#\"}"; t="${t%\'}"; t="${t#\'}"
    case "$t" in
      /tmp/*|/private/tmp/*|/var/folders/*|/private/var/folders/*|"$ROOT"/?*|'$TMPDIR'/*|'${TMPDIR}'/*) ;;
      /*|~*|'$HOME'*|'${HOME}'*|..|../*|.|./|'*'|'.*')
        ask "rm -r on '$t' (outside the repo or the whole tree). Confirm." ;;
    esac
  done <<< "$targets"
fi

# --- 8. Evidence and history --------------------------------------------------------
if printf '%s' "$cmd" | grep -Eq '(>|tee[[:space:]]|cp[[:space:]]|mv[[:space:]]|ln[[:space:]]|sed[[:space:]]+-i|touch[[:space:]])[^|;&]*\.agentic/state/'; then
  deny "Blocked: .agentic/state/ is written only by scripts (gate.sh, verify.sh). Run the script instead of forging its output."
fi
if printf '%s' "$cmd" | grep -Eq '(>|tee[[:space:]]|rm[[:space:]]|mv[[:space:]]|sed[[:space:]]+-i|truncate[[:space:]])[^|;&]*\.agentic/tickets/closed/'; then
  deny "Blocked: closed tickets are history. scripts/gate.sh ship NN closes a ticket; to change shipped work, open a new ticket."
fi

# --- 9. Git rules -------------------------------------------------------------------
# The text of one git subcommand, up to the next ; & |
# Quoted strings are blanked first, so a message can't look like a flag.
git_seg() {
  printf '%s' "$cmd" | sed -E "s/\"[^\"]*\"/\"\"/g; s/'[^']*'/''/g" \
    | grep -oE 'git([[:space:]]+-[Cc][[:space:]]+[^[:space:]]+)*[[:space:]]+'"$1"'([[:space:]][^;&|]*)?' | head -1
}

if git_sub push; then
  seg="$(git_seg push)"
  if printf '%s' "$seg" | grep -Eq '(--force|[[:space:]]-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)|[[:space:]]\+[A-Za-z])'; then
    dest="$(printf '%s' "$seg" | sed -E 's/.*[[:space:]]push//' | tr ' ' '\n' | grep -v '^-' | grep -v '^$' | sed -n '2p')"
    dest="${dest##*:}"; dest="${dest#+}"; dest="${dest#refs/heads/}"
    [ -z "$dest" ] && dest="$branch"
    protected "$dest" && deny "Blocked: force-push to protected branch '$dest'."
  fi
fi

if git_sub commit; then
  seg="$(git_seg commit)"
  printf '%s' "$seg" | grep -Eq -- '--no-verify|[[:space:]]-[a-zA-Z]*n[a-zA-Z]*([[:space:]]|$)' && deny "Blocked: git commit --no-verify."
  protected "$branch" && deny "Blocked: commit on protected branch '$branch'. Claim a ticket: scripts/gate.sh advance NN."
  if [ "$COMMIT_NN" = "true" ] && [ -n "$branch_nn" ]; then
    msg="$(printf '%s' "$cmd" | sed -nE 's/.*(--message|-m)[[:space:]]*(["'"'"'])([^"'"'"']*).*/\3/p')"
    [ -z "$msg" ] && msg="$(printf '%s' "$seg" | sed -nE 's/.*(--message|-m)[[:space:]]+([^[:space:]"'"'"']+).*/\2/p')"
    if [ -n "$msg" ]; then
      case "$msg" in
        *"$branch_nn"*|*"#$((10#$branch_nn))"*) ;;
        *) deny "Blocked: commit message must name ticket $branch_nn (e.g. '$branch_nn: <summary>')." ;;
      esac
    fi
  fi
fi

# Merging a ticket branch into base: it must be shipped; HIGH needs a human.
ticket_merge_check() {
  local tb="$1" nn path tier
  nn="$(printf '%s' "$tb" | sed -nE "s#^(origin/)?${PREFIX}0*([0-9]+)-.*#\2#p")"
  [ -n "$nn" ] || return 0
  nn="$(printf '%02d' "$((10#$nn))")"
  path="$(git -C "$ROOT" ls-tree --name-only "$tb" -- .agentic/tickets/closed/ 2>/dev/null | grep "/$nn-" | head -1)"
  [ -n "$path" ] || deny "Blocked: $tb is not shipped (no tickets/closed/$nn-*). Run scripts/gate.sh advance $nn on that branch first."
  tier="$(git -C "$ROOT" show "$tb:$path" 2>/dev/null | awk '/^risk_tier:/{print $2; exit}')"
  if [ "$tier" = "HIGH" ] && [ "$(cfg risk high_requires_human_merge)" != "false" ]; then
    deny "Blocked: ticket $nn is HIGH — a human merges it (risk.high_requires_human_merge)."
  fi
}
if git_sub merge && protected "$branch"; then
  for tb in $(printf '%s' "$cmd" | grep -oE "(origin/)?${PREFIX}[0-9]+-[A-Za-z0-9._-]+" || true); do
    ticket_merge_check "$tb"
  done
fi
if invoked gh && printf '%s' "$cmd" | grep -Eq 'gh[[:space:]]+pr[[:space:]]+merge' && [ -n "$branch_nn" ]; then
  ticket_merge_check "$branch"
fi

allow
