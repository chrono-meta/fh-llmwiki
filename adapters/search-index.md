---
type: adapter
description: Build sheet for a derived, delete-and-rebuild search index over a fh-llmwiki — never the canon.
status: current
---

# Derived search index

## When

Only when finding things has measurably failed: an agent following the entry index + grep misses
pages that exist, on a task you can repeat. Agentic search over files is usually as good as a
prebuilt index and never stale; an index built ahead of time drifts from a corpus edited under git.
Measure the miss first (same question, with and without the index, 3 runs each).

## Shape

- Built from the files by a script; stored **outside** the repo or gitignored; deleted and rebuilt
  on demand (`rm -rf <index> && build`).
- Each hit carries the source path and the commit it was built from, so a stale hit is visible.
- Keyword (e.g. SQLite FTS) before vectors: no model dependency, no data leaving the machine.
- One index **per confidentiality boundary**. An index over two repos lets whoever can read the index
  read both.

## Must not

- become the place a fact lives (if the index is the only copy, it is a canon — see LAYERS §7);
- be shared with readers of a narrower repo than the widest one it indexes.

## Known pair

Delete the index, rebuild, and run one query whose answer was added after the previous build: it must
appear. Then change that page and query again **without** rebuilding: the hit must show the older
commit, not silently the new text.
