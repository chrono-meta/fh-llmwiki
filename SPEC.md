# forge-wiki SPEC v0.1 — a governed wiki for LLM agents

> Scope: the contract between humans, agents, and the mechanical layer (`bin/fw.py`).
> Identity: **content is curated; recency is derived.** Everything else follows.
> Several wikis (company · org · project · personal): see `LAYERS.md` — the contract *between* wikis.

## 1. Layer model

| Layer | Owner | Conflict semantics |
|---|---|---|
| **Curated pointers** (INDEX.md above AUTO block) | human / HITL-gated agent | human merge — `fw` never touches it (warns only) |
| **AUTO-INDEX block** (INDEX.md between markers) | machine (`fw sync`) | **regeneration IS the resolution** — first-START..last-END collapse heals merge duplication and conflict markers |
| **Knowledge files** (`<section>/*.md`) | authors, in **scoped files** | scoped-by-construction: one writer per file ⇒ concurrent writes cannot conflict |
| **Shared mutable files** (cards, handoffs) | discouraged; if needed, machine-scoped (`<name>.<machine>.md`) | scar-derived rule (multi-machine field incident, 2026-07: a shared manifest let every machine clobber the others' copy) |

## 2. Format — OKF v0.1-compatible, superset not fork

- Knowledge file = markdown + YAML frontmatter; `type` required (OKF), `description` required
  (forge-wiki addition — the index derives from it, so it is load-bearing here).
- `index.md`/`log.md` reserved per OKF. The wiki home is `INDEX.md` **or** the OKF root
  `index.md` — first-existing wins and ONE file serves both roles (curated pointers +
  AUTO block are valid OKF sectioned link lists). F-4, field-found: on case-insensitive
  filesystems (macOS/Windows) the two names are the same file, so coexistence was never
  real — role-merge is the design, not a workaround.
- Links: standard markdown links (OKF edges). `[[wikilink]]` is accepted **at author time only** and
  is normalized to a standard link at commit; an unnormalized wikilink **fails CI**. "Tolerated" was
  the ambiguity that let vaults drift back to a form GitHub and generic tooling cannot resolve.
- Recency: filename date `YYYY-MM-DD` > nearest dated parent dir > mtime. Filenames SHOULD embed
  dates — mtime is untrustworthy across rsync/copy/clone (field-measured).

## 3. Write protocol (agent-facing)

1. Read `INDEX.md` first; open only what it makes relevant (progressive disclosure).
2. Write into your own scoped file; never rewrite another author's file wholesale.
3. Cross-author changes go through a proposal surface (PR / handoff note) — HITL gate.
   Agent writes are proposals by default; merge is the human act. (Market gap #1: every
   competitor is either fully-automatic memory or human-curation service — this PR-gated
   middle is the product.)
4. **Content-first writes (measured — the load-bearing rule):** push knowledge files
   WITHOUT regenerating the index per write; the index is synced in a post-hoc pass
   (CI, session close, or any later `fw sync --write`). Regenerating the derived block
   in every commit makes all writers conflict with each other — measured at N=50:
   per-write sync lost 87/150 files to retry exhaustion; content-first lost 0/0/0
   (reps=3). Low-concurrency solo use may sync per write; under contention, defer.
5. Push retry recipe (measured): on rejected push, back off exponentially with jitter
   (`min(0.05·2^n, 2.0)s × U(0.5,1.5)`), cap 30 (~60s worst wait). A give-up is not
   data loss — the commit stays local and republishes on the next attempt.
6. On a merge conflict in INDEX.md: take either side, rerun `fw sync --write` (or
   `fw heal --write`) — never hand-merge the AUTO block.

## 4. Freshness contract

- `fw doctor` reports: last-sync date · files dated after last sync · curated pointers to
  missing files (this-wiki paths only; cross-repo pointers are out of jurisdiction).
- Closed knowledge is stamped (`STATUS: SUPERSEDED by <path>` / `status: DONE`) — never deleted;
  the index tags it ⛔closed. Deletion is a Destructive-Op (enumerate→recover→destroy) surface.
- `fw check` is the CI gate: exit 1 on index drift. Advisory locally, blocking in CI.

## 5. Degrade directions (fail-direction table)

| Surface | Tooling down / conflict | Direction |
|---|---|---|
| AUTO block | regenerate (self-healing) | fail-safe by construction |
| Curated region conflict | warn + stop | fail-closed to human (HITL) |
| Corrupt/binary .md | lint flags, sync skips gracefully | degrade-to-advisory (content layer) |
| INDEX.md destroyed | `fw sync --write` re-appends AUTO block; curated half restored from git | recoverable — wiki state is git + derivation, never only the file |

## 6. Dual-track positioning

- **Org with an existing project-scaffolding tool**: let that tool lay the project floor;
  forge-wiki specializes in the KNOWLEDGE layer on top — complementary layers, not competitors.
- **Standalone/personal**: `fw init` golden path (Phase-0 state audit → non-overwriting scaffold).

## 7. Verification anchor

`tests/sim_concurrency.*` — N-writer concurrency + corruption-injection chamber (N up to 50,
reps=3 at the top scale) is the product's permanent regression suite. A change to fw.py's
merge/heal semantics MUST re-run it. Claims about robustness cite the sim report, not prose.
