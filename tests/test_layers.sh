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
d=$(fresh); printf -- '- id: x\n  layer: L1\n  repo: {summary: copied}\n  entry: index.md\n' >> "$d/wikis.yaml"
lane "R-pos6 mapping value fails CLOSED (codex 4)" 1 "not a flat scalar" $T registry "$d/wikis.yaml"
d=$(fresh); # The parent key has a value, so ONLY the indentation guard can catch the deeper line (codex r2).
printf -- '- id: x\n  layer: L1\n  repo: r\n  entry: index.md\n  metadata: x\n    note: copied\n' >> "$d/wikis.yaml"
lane "R-pos7 nested map fails CLOSED (codex 5)"    1 "outside the supported subset" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- id: x\n  layer: L1\n  repo: r\n  entry: index.md\n  inherits: [,]\n' >> "$d/wikis.yaml"
lane "R-pos8 inherits [,] is not [] (codex 6)"     1 "inline list" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- id: x\n  layer: L1\n  repo: !!map {summary: copied}\n  entry: index.md\n' >> "$d/wikis.yaml"
lane "R-pos9 YAML tag fails CLOSED (codex r2)"     1 "not a flat scalar" $T registry "$d/wikis.yaml"
d=$(fresh); printf -- '- inherits: [company-rules,]\n  id: x\n  layer: L1\n  repo: r\n  entry: index.md\n' >> "$d/wikis.yaml"
lane "R-neg3 inherits first + trailing comma is valid (codex r2)" 0 "PASS" $T registry "$d/wikis.yaml"
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
d=$(fresh); sed -i.bak 's/^- floor: company-rules → .*/- floor: company-rules →/' "$d/org-a/index.md"
lane "D-pos4 floor pointer with no destination"    1 "no 'floor: company-rules" $T declare "$d/org-a"
d=$(fresh); sed -i.bak 's/^- floor: company-rules /- floor: company-rules-other /' "$d/org-a/index.md"
lane "D-pos5 floor pointer to a longer id"         1 "no 'floor: company-rules" $T declare "$d/org-a"
d=$(fresh); python3 - "$d/org-a/index.md" <<'PY'
import sys,re;p=sys.argv[1];s=open(p).read()
line=re.search(r"(?m)^- floor: company-rules .*$",s).group(0)
open(p,"w").write(s.replace(line,"```\n"+line+"\n```"))
PY
lane "D-pos6 floor pointer only inside a code fence" 1 "no 'floor: company-rules" $T declare "$d/org-a"
for fence in '~~~markdown' '```'; do
  d=$(fresh); python3 - "$d/org-a/index.md" "$fence" <<'PY'
import sys,re;p,f=sys.argv[1],sys.argv[2];s=open(p).read()
line=re.search(r"(?m)^- floor: company-rules .*$",s).group(0)
close="~~~" if f.startswith("~") else ""   # the backtick case is left UNCLOSED on purpose
open(p,"w").write(s.replace(line,f+"\n"+line+("\n"+close if close else "")))
PY
  lane "D-pos8 pointer inside a ${fence:0:3} fence (codex r2)" 1 "no 'floor: company-rules" $T declare "$d/org-a"
done
d=$(fresh); sed -i.bak 's/^inherits: .*/inherits: [,]/' "$d/org-a/index.md"
lane "D-pos7 inherits [,] in a home"               1 "inline list" $T declare "$d/org-a"
d=$(fresh); sed -i.bak -e 's/^layer: L1$/layer: L1   # org wiki/' -e 's/^inherits: \[company-rules\]$/inherits: [company-rules]   # parent/' "$d/org-a/index.md"
lane "D-neg3 trailing YAML comments are ignored"   0 "PASS (layer L1)" $T declare "$d/org-a"
d=$(fresh); sed -i.bak '/^layer:/d' "$d/org-a/index.md"
lane "D-unm  no layer: is UNMEASURED, not L1"      2 "UNMEASURED" $T declare "$d/org-a"
d=$(fresh); rm "$d/company-rules/floor.md"
lane "D-pos3 L0 declares a floor file that is gone" 1 "missing" $T declare "$d/company-rules"

# ── links ──
lane "L-neg  clean wiki"                           0 "PASS" $T links "$EX/org-a"
d=$(fresh); echo "See [gone](memory/nope.md)." >> "$d/org-a/index.md"
lane "L-pos1 broken intra-wiki link"               1 "memory/nope.md" $T links "$d/org-a"
# The outside target must NOT exist — an existing one passes even with the exemption removed (codex 9).
d=$(fresh); printf 'A [cross-repo](../../nowhere-repo/floor.md) and [web](https://example.com/x.md).\n' >> "$d/org-a/memory/review_rule.md"
lane "L-neg2 links leaving the wiki are not judged" 0 "1 leave this wiki" $T links "$d/org-a"
d=$(fresh); printf '```\n[x](memory/in-code.md)\n```\n' >> "$d/org-a/index.md"
lane "L-neg3 links inside code fences are text"    0 "PASS" $T links "$d/org-a"
d=$(fresh); printf '[gone][g]\n\n[g]: memory/missing-ref.md\n' >> "$d/org-a/index.md"
lane "L-pos2 reference-style link is checked (codex 8)" 1 "missing-ref.md" $T links "$d/org-a"
d=$(fresh); printf 'x\n' > "$d/org-a/memory/a b.md"; printf '[x][g]\n\n[g]: <memory/a b.md>\n' >> "$d/org-a/index.md"
lane "L-neg4 <angle> destination with a space (codex r2)" 0 "PASS" $T links "$d/org-a"
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

printf 'Header: Bearer\nAAAAAAAAAAAAAAAAAAAAAAAAAAAA\n' > "$w/src/split.md"
lane "P-pos8 secret split across a line break (codex 1)" 1 "[bearer]" $T promote "$w/src/split.md" "$w/dest" --no-org-patterns
printf 'MED\tacme\\s+internal\n' > "$w/pat2"; printf 'see acme\ninternal notes\n' > "$w/src/split2.md"
lane "P-pos9 org pattern across a line break"      1 "[org:1]" $T promote "$w/src/split2.md" "$w/dest" --patterns "$w/pat2"
printf -- '---\ntype: signal\ndescription: d\npromoted_from: /home/alice/private-wiki/project-x.md\n---\nbody\n' > "$w/src/prov.md"
printf -- '---\ntype: signal\ndescription: d\n"promoted_from": /home/alice/q.md\npromoted_at: |\n  /home/alice/r.md\n---\nbody\n' > "$w/src/prov2.md"
$T promote "$w/src/prov2.md" "$w/dest" --no-org-patterns --write >/dev/null 2>&1
if ! grep -q alice "$w/dest/prov2.md" && grep -q '^type: signal$' "$w/dest/prov2.md"; then
  echo "✅ P-neg6 quoted key and block-scalar provenance are dropped whole (codex r2)"; pass=$((pass+1))
else echo "❌ P-neg6"; sed 's/^/     /' "$w/dest/prov2.md"; fail=$((fail+1)); fi
$T promote "$w/src/prov.md" "$w/dest" --no-org-patterns --write >/dev/null 2>&1
if [ "$(grep -c '^promoted_from:' "$w/dest/prov.md")" = 1 ] && ! grep -q 'alice' "$w/dest/prov.md"; then
  echo "✅ P-neg5 an old address-shaped promoted_from is replaced, not kept (codex 7)"; pass=$((pass+1))
else echo "❌ P-neg5 old provenance survived"; sed 's/^/     /' "$w/dest/prov.md"; fail=$((fail+1)); fi

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
