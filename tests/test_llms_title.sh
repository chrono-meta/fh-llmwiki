#!/usr/bin/env bash
# test_llms_title.sh — llms.txt's H1 comes from the wiki, not from the folder it was cloned into.
#
# WHY (field-found 2026-11-07): a worktree named after its branch regenerated llms.txt with that
# folder name as the title, so the same wiki produced a different derived file depending on where
# it was checked out. Fix: home frontmatter `title:` first, folder name only as a fallback.
#
# Lanes
#   P1  declared title → H1 is that title
#   P2  declared title, two folders with different names → byte-identical llms.txt
#   N1  CONTROL — no title → H1 is still the folder name (old output unchanged for every wiki that
#       declares nothing; downstream CI diffs llms.txt, so this is the lane that keeps them green)
#   N2  CONTROL — `title:` in the BODY, not the frontmatter, is ignored
set -u
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FW="python3 $REPO/bin/fw.py"
pass=0; fail=0
_t(){ if [ "$2" = "$3" ]; then echo "✅ $1"; pass=$((pass+1)); else echo "❌ $1 — got [$3] want [$2]"; fail=$((fail+1)); fi; }
mk(){  # $1 dir · $2 frontmatter line or "" · $3 body line or ""
  mkdir -p "$1/signals"
  { echo "---"; echo "type: index"; [ -n "$2" ] && echo "$2"; echo "---"; echo "# Home"; [ -n "$3" ] && echo "$3"; } > "$1/INDEX.md"
  printf -- '---\ntype: note\ndescription: a note\n---\nx\n' > "$1/signals/n_2026-11-07.md"
  (cd "$1" && $FW sync --write >/dev/null 2>&1)
}
b=$(mktemp -d)
mk "$b/alpha" "title: Team Wiki" ""
_t "P1 declared title is the H1" "# Team Wiki" "$(head -1 "$b/alpha/llms.txt")"
mk "$b/some-worktree-name" "title: Team Wiki" ""
cmp -s "$b/alpha/llms.txt" "$b/some-worktree-name/llms.txt"; _t "P2 two folder names, one llms.txt" 0 $?
mk "$b/plainwiki" "" ""
_t "N1 no title → folder name (unchanged)" "# plainwiki" "$(head -1 "$b/plainwiki/llms.txt")"
mk "$b/bodywiki" "" "title: Not A Title"
_t "N2 title: in the body is ignored" "# bodywiki" "$(head -1 "$b/bodywiki/llms.txt")"
echo "-- llms title lanes: $pass passed · $fail failed --"; [ "$fail" -eq 0 ]
