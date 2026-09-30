#!/usr/bin/env bash
# floor-guard.sh — diff-scoped cheap-green detector.
# Usage: scripts/floor-guard.sh [--base <ref>]
# Exit 0 clean, 1 violation, 2 could not run (never treat 2 as 0).
set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib.sh
source "$SCRIPT_DIR/lib.sh"

BASE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --base) BASE="$2"; shift 2 ;;
    *) echo "usage: scripts/floor-guard.sh [--base <ref>]" >&2; exit 2 ;;
  esac
done

enabled="$(config_get floor_guard)"
if [ "$enabled" = "false" ]; then
  echo "floor-guard: skipped (floor_guard: false)"
  exit 0
fi

has_git || { echo "floor-guard: not a git repo" >&2; exit 2; }

if [ -z "$BASE" ]; then
  if ! BASE="$(base_ref)"; then
    if [ -n "${CI:-}" ]; then
      echo "floor-guard: base '$(base_branch)' not found (tried $(base_branch), origin/$(base_branch)) — fetch it" >&2
      exit 2
    fi
    echo "floor-guard: WARNING: base '$(base_branch)' not found; checking uncommitted changes only" >&2
    BASE=HEAD
  fi
fi

merge_base=""
if git -C "$ROOT" rev-parse --verify "$BASE" >/dev/null 2>&1; then
  merge_base="$(git -C "$ROOT" merge-base "$BASE" HEAD 2>/dev/null || true)"
fi
if [ -z "$merge_base" ]; then
  # First commit / unborn: compare against empty tree.
  merge_base="$(git -C "$ROOT" hash-object -t tree /dev/null 2>/dev/null || true)"
fi
if [ -z "$merge_base" ]; then
  echo "floor-guard: no merge base against $BASE" >&2
  exit 2
fi

ignored_match() {
  local f="$1" g
  while IFS= read -r g; do
    [ -z "$g" ] && continue
    glob_match "$f" "$g" && return 0
  done < <(config_list floor_ignore)
  case "$f" in
    *.md|*.jsonl|*.txt) return 0 ;;
  esac
  return 1
}

exception_covers() {
  local rule="$1" file="$2"
  # floor_exceptions lines: "- id: E1" blocks are too nested; support
  # "id|rule|path|expires" via config_list of "id|rule|path|YYYY-MM-DD"
  local row id r p exp today
  today="$(date -u +%Y-%m-%d)"
  while IFS= read -r row; do
    [ -z "$row" ] && continue
    case "$row" in
      *\|*\|*\|*)
        r="$(printf '%s' "$row" | awk -F'|' '{print $2}')"
        p="$(printf '%s' "$row" | awk -F'|' '{print $3}')"
        exp="$(printf '%s' "$row" | awk -F'|' '{print $4}')"
        [ "$r" = "$rule" ] || [ "$r" = "*" ] || continue
        glob_match "$file" "$p" || continue
        if [ -n "$exp" ] && [ "$exp" \< "$today" ]; then
          echo "floor-guard: expired exception '$row'" >&2
          continue
        fi
        return 0
        ;;
    esac
  done < <(config_list floor_exceptions)
  return 1
}

TMPD="$(mktemp -d "${TMPDIR:-/tmp}/floor-guard.XXXXXX")"
trap 'rm -rf "$TMPD"' EXIT

git -C "$ROOT" diff --unified=0 "$merge_base" -- > "$TMPD/tracked.diff" || true
git -C "$ROOT" ls-files --others --exclude-standard > "$TMPD/untracked" || true
: > "$TMPD/all.diff"
cat "$TMPD/tracked.diff" >> "$TMPD/all.diff"
while IFS= read -r uf; do
  [ -z "$uf" ] && continue
  git -C "$ROOT" diff --no-index --unified=0 /dev/null "$uf" >> "$TMPD/all.diff" 2>/dev/null || true
done < "$TMPD/untracked"

python3 - "$TMPD/all.diff" "$ROOT" <<'PY' > "$TMPD/findings"
import fnmatch, os, re, sys

diff_path, root = sys.argv[1], sys.argv[2]
text = open(diff_path, encoding="utf-8", errors="replace").read()

SUPPRESS = re.compile(
    r"@ts-ignore|@ts-nocheck|eslint-disable|biome-ignore|# *noqa|# *type: *ignore"
    r"|istanbul ignore|nosemgrep|gitleaks:allow|Stryker disable"
    r"|# *pragma: *no cover|type: ignore\[|ruff: *noqa"
)
STUBS = re.compile(
    r"throw new (Error|NotImplemented).{0,40}[Nn]ot implemented"
    r"|catch\s*\(\w*\)\s*\{\s*\}"
    r"|catch\s*\{\s*\}"
    r"|raise NotImplementedError"
    r"|unimplemented!\(\)"
)
SKIPS = re.compile(
    r"\.(skip|todo)\b|\bxit\s*\(|\bxdescribe\s*\("
    r"|@pytest\.mark\.skip|t\.Skip\(|it\.skip|test\.skip"
    r"|@Ignore\b|@Disabled\b"
)
ASSERT = re.compile(r"\b(expect|assert|should|assertEquals|assert_eq|assertEqual)\b")
TEST_FILE = re.compile(r"(\.(test|spec)\.|_test\.|test_|\.tests\.)")

added, removed = [], []
file = ""
for line in text.splitlines():
    if line.startswith("+++ "):
        rest = line[4:].strip()
        if rest.startswith("b/"):
            rest = rest[2:]
        if rest == "/dev/null":
            file = ""
        else:
            file = rest
    elif line.startswith("+") and not line.startswith("+++"):
        added.append((file, line[1:]))
    elif line.startswith("-") and not line.startswith("---"):
        removed.append((file, line[1:]))

def is_md(f):
    return f.endswith((".md", ".jsonl", ".txt"))

findings = []

def flag(rule, f, snippet):
    snippet = snippet.strip()[:120]
    findings.append((rule, f, snippet))

for f, t in added:
    if not f or is_md(f):
        continue
    if SUPPRESS.search(t):
        flag("silenced-checker", f, t)
    if STUBS.search(t):
        flag("unfinished-work", f, t)
    if SKIPS.search(t):
        flag("test-made-easier", f, t)

for f, t in removed:
    if not f or is_md(f):
        continue
    if TEST_FILE.search(f) and ASSERT.search(t):
        flag("assertion-removed", f, t)

# Deleted test files (removed from tree, still in diff as --- a/file +++ /dev/null)
deleted_tests = set()
current = ""
in_deleted = False
for line in text.splitlines():
    if line.startswith("diff --git "):
        in_deleted = False
        current = ""
    if line.startswith("--- "):
        current = line[4:].strip()
        if current.startswith("a/"):
            current = current[2:]
    if line.startswith("+++ ") and line.strip().endswith("/dev/null") and current:
        if TEST_FILE.search(current) or "/test/" in current or current.startswith("tests/"):
            flag("test-made-easier", current, "deleted test file")

# Weakened numbers in config.yml (a value that went down on the same key).
def nums(s):
    return [float(x) for x in re.findall(r"\d+(?:\.\d+)?", s)]

cfg_rm = [(f, t) for f, t in removed if f.endswith("config.yml")]
cfg_ad = [(f, t) for f, t in added if f.endswith("config.yml")]
for rf, rt in cfg_rm:
    key = rt.split(":")[0].strip() if ":" in rt else ""
    if not key:
        continue
    for af, at in cfg_ad:
        if at.split(":")[0].strip() != key:
            continue
        rn, an = nums(rt), nums(at)
        if rn and an and any(a < r for a, r in zip(an, rn)):
            # boolean false replacing true for a gate is also a lowering
            flag("threshold-lowered", rf, rt.strip() + " -> " + at.strip())
        if re.search(r":\s*true\s*$", rt) and re.search(r":\s*false\s*$", at):
            flag("threshold-lowered", rf, rt.strip() + " -> " + at.strip())

for rule, f, snip in findings:
    print(f"{rule}\t{f}\t{snip}")
PY

fail=0
while IFS=$'\t' read -r rule file snip; do
  [ -z "$rule" ] && continue
  if ignored_match "$file"; then
    continue
  fi
  if exception_covers "$rule" "$file"; then
    continue
  fi
  echo "floor-guard: [$rule] $file: $snip" >&2
  fail=1
done < "$TMPD/findings"

if [ "$fail" -eq 0 ]; then
  echo "floor-guard: clean"
  protocol FLOOR_GUARD OK
  exit 0
fi
echo "floor-guard: floor violation(s) — fix the code or add a dated floor_exceptions row" >&2
exit 1
