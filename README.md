# forge-wiki

English · **[한국어](README.ko.md)** · **[日本語](README.ja.md)** · **[中文](README.zh.md)**

A governed markdown wiki for LLM agents — and the humans they work with.

Most agent-knowledge tools are either fully automatic memory (mem0, Zep, Letta — no
approval concept) or human curation services. forge-wiki holds the middle: **agents
write, humans gate, the index maintains itself.**

## Three design commitments

1. **Content is curated; recency is derived.** The `AUTO-INDEX` block in `INDEX.md` is
   regenerated from frontmatter + filename dates — a merge conflict there is resolved by
   regeneration, not by hand. Verified under concurrent multi-writer simulation
   (see `tests/` — N writers up to 50, corruption injection included).
2. **OKF v0.1-compatible.** Files are markdown + YAML frontmatter (`type`, `description`),
   reserved `index.md`, links as edges — readable by any OKF consumer, no lock-in.
3. **Scoped writes, gated merges.** Each writer owns its files; cross-author changes are
   proposals (PR/handoff), not silent edits. HITL is the write protocol, not a feature flag.
   The human gate exists to add **taste** — personal and organizational judgment — not to
   catch defects: functional integrity is the machine layer's job, verified by simulation
   before anything reaches a reviewer.

## Quick start

Nothing to install: one Python file, no dependencies beyond `python3`. Clone it once, keep it
anywhere, call it by path.

```sh
git clone https://github.com/chrono-meta/forge-wiki.git ~/tools/forge-wiki
alias fw='python3 ~/tools/forge-wiki/bin/fw.py'   # optional — every example below uses `fw`

cd your-knowledge-repo   # the repo that will HOLD your wiki — not the clone above
fw init                  # Phase-0 audit + non-overwriting scaffold (creates signals/)
mkdir -p memory          # add whichever other sections you want; a section is just a directory
# drop markdown files into the section dirs
fw sync --write          # regenerate the recency index + llms.txt
fw doctor                # freshness + stale-pointer report
```

**You succeeded when** `INDEX.md` holds an `AUTO-INDEX` block listing your files by section and
`fw check` exits 0. `doctor` is advisory — a non-zero exit from it is a report, not a failed
install.

Your repo now looks like:

```
your-knowledge-repo/
├── INDEX.md      curated pointers on top, generated AUTO-INDEX block below
├── AGENTS.md     wiki-protocol block appended by init — the agent-facing contract
├── llms.txt      generated on every sync --write
├── memory/
└── signals/
```

On a merge conflict in `INDEX.md`: take either side, run `fw heal --write`. Done.

## Your org's instance

`fw init` gives you a working index. It does not tell you *what to put in it* — that decision
is what makes the wiki yours, and no tool can make it for you.

The pairing this is built for: **a harness carries method and gates; the wiki carries your
org's context.** Neither substitutes for the other. A harness with no context landing site
re-derives the same organizational facts every session; a wiki with no harness has no gate on
what enters it.

A section axis that survived ~2 months of daily operation (981 files — the four largest
sections hold 73% of them):

| Section | Holds | Enters when |
|---|---|---|
| `memory/` | durable facts that outlive the session that found them | a fact will be needed again and is not derivable from the code |
| `tracks/<project>/` | per-project working records, accumulated | work on that project produced something worth re-reading |
| `signals/` | an observation or measurement that *may* matter later | you notice it — recorded before you know whether it pays off |
| `handoff/` | state passed between machines, sessions, or people | the next reader is not the current writer |
| `audit/` | periodic reviews on a cadence | the cadence fires, not when you feel like it |
| `digests/` | recurring external scans | an automated job lands its output |

Start with two — `memory/` and `signals/` — and let a section appear the first time a file
genuinely does not fit the existing ones. Adding a directory is cheap; **a section nobody
writes to is the signal to delete it, not to fill it.**

**Which of the two?** Two questions settle most files. *Can this be re-derived from the code?*
— if yes, it does not belong in `memory/`. *Has a verdict been reached?* — if not, it is a
`signals/` entry, not a decision record.

`examples/org-instance/` is a minimal filled-in skeleton. Copy it into a repo you have **not**
`init`-ed yet — it brings its own `INDEX.md`, and `fw init` refuses to overwrite one:

```sh
cp -r ~/tools/forge-wiki/examples/org-instance/. your-knowledge-repo/
cd your-knowledge-repo
fw init          # keeps the copied INDEX.md, still appends the AGENTS.md block
fw sync --write
```

## Subcommands

| cmd | does | fail direction |
|---|---|---|
| `init` | state-audit + scaffold (never overwrites) | refuses on existing files |
| `sync [--write]` | regenerate AUTO-INDEX block | dry-run by default |
| `heal [--write]` | collapse conflict markers / duplicate blocks, then sync | curated-region conflicts stay human |
| `lint` | frontmatter report | report-only, never rewrites |
| `doctor` | freshness + stale-pointer report | advisory |
| `check` | index-drift gate | exit 1 on drift (CI-blocking) |

## Several wikis — company, org, project, person

One wiki per confidentiality boundary, joined by a registry of links — never by copies.
[`LAYERS.md`](LAYERS.md) is that contract (layers L0–L3, when to split, promotion from a personal
wiki to an org one); `bin/fw_layers.py` checks the parts a machine can check:

```sh
python3 bin/fw_layers.py declare .          # this wiki states its layer and points at its parents
python3 bin/fw_layers.py links .            # intra-wiki links resolve
python3 bin/fw_layers.py promote notes/x.md ../org-wiki/signals --patterns <org-patterns>   # scrub before any push
python3 bin/fw_layers.py split-report .     # the numbers behind "should this be two repos?" — no verdict
```

A database or MCP gateway is an adapter, added only when its condition occurs — each one is a
build sheet in [`adapters/`](adapters/README.md), nothing wired by default. `examples/federation/`
is a three-wiki example; `tests/test_layers.sh` is its anchor.

## Status

v0.1 — extracted from ~2 months of daily operation of a private operator wiki: **981 markdown
files, commits on 50 of 57 days, multi-machine** (measured 2026-07-21 —
`git ls-files '*.md' | wc -l`; the store itself stays private). The concurrency simulation in
`tests/` is the regression anchor for every robustness claim; nothing here is asserted that
the sim did not measure.

## Distribution surfaces

- `llms.txt` is generated on every `sync --write` (derived, like the index).
- `bin/fw_mcp.py` — zero-dependency read-only MCP server (`wiki_index` / `wiki_get` /
  `wiki_search`). Reads go through MCP; writes go through git + the gate — that asymmetry
  is the write protocol, not a missing feature.
  `claude mcp add forge-wiki -- python3 <abs>/bin/fw_mcp.py <wiki_root>`

See `SPEC.md` for the full contract.
