#!/usr/bin/env bash
# test_layers.sh — known-pair lanes for bin/fw_layers.py (LAYERS.md is the contract).
#
# Every command gets at least one KNOWN-POSITIVE (a fixture carrying the exact defect — must exit 1)
# and one KNOWN-NEGATIVE (the clean example federation — must exit 0), plus an UNMEASURED lane where
# the input is empty (must exit 2, never 0). A lane that only ever saw clean input proves nothing:
# a checker that always says PASS would pass it.
#
# Negatives are built by copying examples/federation/ and changing ONE thing, so a red lane names
# the one property that broke. Each positive also asserts a NEEDLE in the output — "exit 1" alone is
# satisfied by a checker that crashes.
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="python3 $REPO/bin/fw_layers.py"
EX="$REPO/examples/federation"
pass=0; fail=0
# $1 name · $2 want rc · $3 needle ("" = none) · rest = command
lane() {
  local name="$1" want="$2" needle="$3"; shift 3
  local out rc
  out=$("$@" 2>&1); rc=$?
  if [ "$rc" = "$want" ] && { [ -z "$needle" ] || printf '%s' "$out" | grep -qF -- "$needle"; }; then
    echo "✅ $name"; pass=$((pass+1))
  else
    echo "❌ $name — rc=$rc want=$want needle=[$needle]"; printf '%s\n' "$out" | sed 's/^/     /' | head -8
    fail=$((fail+1))
  fi
}
fresh() { local d; d=$(mktemp -d); cp -R "$EX/." "$d/"; echo "$d"; }

# ── registry ──
lane "R-neg  clean registry passes"                0 "PASS (3 entries)" $T registry "$EX/wikis.yaml"
d=$(fresh); sed -i.bak 's/inherits: \[company-rules\]$/inherits: [company-ruls]/' "$d/wikis.yaml"
lane "R-pos1 dangling inherits id"                 1 "is not an id" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- id: deep\n  layer: L1\n  repo: r\n  entry: index.md\n  inherits: [org-a/harness-x]\n' >> "$d/wikis.yaml"
lane "R-pos2 inherits from a LOWER layer"          1 "authority flows down only" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- id: me\n  layer: L3\n  repo: r\n  entry: index.md\n' >> "$d/wikis.yaml"
lane "R-pos3 L3 in a shared registry"              1 "L3 entry in a shared registry" $T registry "$d/wikis.yaml"
lane "R-neg2 same L3 row with --personal"          0 "PASS" $T registry "$d/wikis.yaml" --personal
d=$(fresh); printf -- '- id: x\n  layer: L1\n  repo: r\n  entry: index.md\n  summary: copied text\n' >> "$d/wikis.yaml"
lane "R-pos4 content key in the registry"          1 "holds links, not content" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- id: y\n  layer: L1\n  repo: r\n  entry: index.md\n  inherits:\n    - company-rules\n' >> "$d/wikis.yaml"
lane "R-pos5 block list fails CLOSED, not skipped" 1 "outside the supported subset" $T registry "$d/wikis.yaml"
e=$(mktemp); printf '# only comments\n' > "$e"
lane "R-unm  empty registry is UNMEASURED"         2 "UNMEASURED" $T registry "$e"

# ── declare ──
lane "D-neg  L1 with explicit floor pointer"       0 "PASS (layer L1)" $T declare "$EX/org-a"
d=$(fresh); sed -i.bak '/^- floor: company-rules/d' "$d/org-a/index.md"
lane "D-pos1 inherits but no floor pointer line"   1 "no 'floor: company-rules" $T declare "$d/org-a"
d=$(fresh); sed -i.bak '/^inherits:/d' "$d/org-a/index.md"
lane "D-pos2 L1 without inherits key"              1 "undeclared parent" $T declare "$d/org-a"
d=$(fresh); sed -i.bak 's/^inherits: .*/inherits: []/' "$d/org-a/index.md"
lane "D-neg2 inherits: [] is an explicit answer"   0 "PASS" $T declare "$d/org-a"
d=$(fresh); sed -i.bak '/^layer:/d' "$d/org-a/index.md"
lane "D-unm  no layer: is UNMEASURED, not L1"      2 "UNMEASURED" $T declare "$d/org-a"
d=$(fresh); rm "$d/company-rules/floor.md"
lane "D-pos3 L0 declares a floor file that is gone" 1 "missing" $T declare "$d/company-rules"

# ── links ──
lane "L-neg  clean wiki"                           0 "PASS" $T links "$EX/org-a"
d=$(fresh); echo "See [gone](memory/nope.md)." >> "$d/org-a/index.md"
lane "L-pos1 broken intra-wiki link"               1 "memory/nope.md" $T links "$d/org-a"
d=$(fresh); printf 'A [cross-repo](../../company-rules/floor.md) and [web](https://example.com/x.md).\n' >> "$d/org-a/memory/review_rule.md"
lane "L-neg2 links leaving the wiki are not judged" 0 "1 leave this wiki" $T links "$d/org-a"
d=$(fresh); printf '```\n[x](memory/in-code.md)\n```\n' >> "$d/org-a/index.md"
lane "L-neg3 links inside code fences are text"    0 "PASS" $T links "$d/org-a"
e=$(mktemp -d)
lane "L-unm  no markdown is UNMEASURED"            2 "UNMEASURED" $T links "$e"

# ── frontmatter ──
lane "F-neg  clean wiki"                           0 "PASS" $T frontmatter "$EX/org-a"
d=$(fresh); sed -i.bak '/^description:/d' "$d/org-a/memory/review_rule.md"
lane "F-pos1 missing description"                  1 "missing description" $T frontmatter "$d/org-a"
d=$(fresh); printf '# no frontmatter\n' > "$d/org-a/memory/bare.md"
lane "F-pos2 page with no frontmatter"             1 "no frontmatter" $T frontmatter "$d/org-a"
lane "F-pos3 --require adds a key"                 1 "missing owner" $T frontmatter "$EX/org-a" --require type,owner

# ── promote ──
w=$(mktemp -d); mkdir -p "$w/src" "$w/dest"
cat > "$w/src/finding_2026-11-07.md" <<'EOF'
---
type: signal
description: A finding worth sharing.
status: current
---

# Finding

Retry with jitter halves the conflicts.

# Sources
- my notebook
EOF
pf="$w/patterns"; printf '# org names\nMED\tacme-internal\n' > "$pf"
lane "P-pos1 no patterns file BLOCKS"              1 "no --patterns file" $T promote "$w/src/finding_2026-11-07.md" "$w/dest"
lane "P-pos2 patterns file missing BLOCKS"         1 "fail-closed" $T promote "$w/src/finding_2026-11-07.md" "$w/dest" --patterns "$w/none"
lane "P-neg  clean source, dry run writes nothing" 0 "dry run" $T promote "$w/src/finding_2026-11-07.md" "$w/dest" --patterns "$pf"
[ -z "$(ls -A "$w/dest")" ] && { echo "✅ P-neg2 dry run left dest empty"; pass=$((pass+1)); } || { echo "❌ P-neg2 dry run wrote"; fail=$((fail+1)); }
lane "P-neg3 --write stamps provenance"            0 "promoted_from: L3:" $T promote "$w/src/finding_2026-11-07.md" "$w/dest" --patterns "$pf" --write
out="$w/dest/finding_2026-11-07.md"
if grep -q '^status: draft$' "$out" && ! grep -q '^status: current$' "$out" && grep -q '^- L3:[0-9a-f]\{12\} ' "$out" \
   && [ "$(head -1 "$out")" = "---" ] && ! grep -q "$w" "$out"; then
  echo "✅ P-neg4 copy is a draft, cites an opaque id, leaks no source path"; pass=$((pass+1))
else echo "❌ P-neg4 provenance shape"; sed 's/^/     /' "$out"; fail=$((fail+1)); fi
lane "P-pos3 second promote refuses to fork"       1 "extend that page" $T promote "$w/src/finding_2026-11-07.md" "$w/dest" --patterns "$pf"
cp "$w/src/finding_2026-11-07.md" "$w/src/leak.md"; echo "Ask ops@acme-internal.example about it." >> "$w/src/leak.md"
lane "P-pos4 org pattern hit BLOCKS"               1 "[org:2]" $T promote "$w/src/leak.md" "$w/dest" --patterns "$pf"
lane "P-pos5 generic email hit BLOCKS"             1 "[email]" $T promote "$w/src/leak.md" "$w/dest" --no-org-patterns
# The fake token is assembled at run time so the literal never sits in a tracked file — a secret
# scanner on this repo would (rightly) flag it, and an allow-list entry for it would be a hole.
fake="gh""p_abcdefghijklmnopqrstuvwxyz0123456789"
cp "$w/src/finding_2026-11-07.md" "$w/src/k.md"; echo "token = $fake" >> "$w/src/k.md"
lane "P-pos6 token BLOCKS, and is masked"          1 "[github-token] gh…" $T promote "$w/src/k.md" "$w/dest" --no-org-patterns
if $T promote "$w/src/k.md" "$w/dest" --no-org-patterns 2>&1 | grep -q "abcdefghijklmnop"; then
  echo "❌ P-pos7 the scan printed the secret it found"; fail=$((fail+1))
else echo "✅ P-pos7 the scan does not echo the secret"; pass=$((pass+1)); fi

# ── split-report ──
lane "S-neg  report runs, names D1 as a question"  0 "D1 (strongest, not countable)" $T split-report "$EX/org-a"
lane "S-neg2 outside git: UNMEASURED, not 0"       0 "UNMEAS." $T split-report "$(fresh)/org-a"
g=$(fresh); git -C "$g" init -q
lane "S-neg3 git repo, nothing committed: no-hist" 0 "no-hist" $T split-report "$g/org-a"
git -C "$g" add -A && git -C "$g" -c user.email=a@x -c user.name=a commit -qm one
if $T split-report "$g/org-a" | grep -qE '^memory +1 +1 +1$'; then echo "✅ S-pos  committed section counts 1 author · 1 commit"; pass=$((pass+1))
else echo "❌ S-pos  committed counts"; $T split-report "$g/org-a" | sed 's/^/     /'; fail=$((fail+1)); fi
lane "S-unm  no home is UNMEASURED"                2 "UNMEASURED" $T split-report "$(mktemp -d)"

echo "-- fw_layers lanes: $pass passed · $fail failed --"
[ "$fail" -eq 0 ]
