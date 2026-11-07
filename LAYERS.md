# forge-wiki LAYERS v0.1 — one org, several wikis, loosely joined

> Scope: how several forge-wiki instances relate when a company, its orgs, their projects and
> individual people each keep one. `SPEC.md` is the contract *inside* one wiki; this file is the
> contract *between* wikis. `bin/fw_layers.py` checks the parts a machine can check — that a record
> is present, typed and pointed-to. Whether to split, promote or publish stays a human call.
>
> Identity: **one confidentiality boundary = one git repo. Wikis link to each other; they never copy
> each other. Permissions are the git host's, not ours.**

## 1. Why layers, and why not one big wiki

A single wiki for a whole company fails in three measurable ways: its entry index outgrows an
agent's first read, its readers are no longer one set of people, and its fast-moving notes bury its
slow-moving rules. Splitting by *size* fixes the first and ignores the other two. Splitting by the
four criteria in §3 fixes all three.

## 2. The layer model

A layer is **a bundle with its own authority and its own lifecycle** — not a folder.

| Layer | Holds | Writes | Changes | Reads |
|---|---|---|---|---|
| **L0** company floor | rules every org follows · security/confidentiality policy · shared vocabulary | few maintainers, PR + named reviewer | quarterly | everyone |
| **L1** org wiki | the org's rules, quality bar, vocabulary · the org's registry | org leads + contributors, PR | monthly | the org |
| **L2** project wiki | decisions, measurements, handoffs for one project/harness · "for this job use that" routers | that project's contributors | daily | the org (other orgs on request) |
| **L3** personal research | unpublished experiments, drafts, raw notes | its owner | hourly | **its owner only** |

**The org is the owning unit; authority still flows down.** Repos, contributors and lifecycle are
managed inside an org (L1–L2) — that is what "the org is the top unit" means. Prohibitions run the
other way: an L0 rule cannot be loosened by L1–L3.

- **Lower layers may narrow, never widen.** Agent instruction files across the industry concatenate
  root-to-leaf and let the *nearer* file win a conflict. That is right for style and wrong for
  prohibitions: a team convention that is "more specific" would otherwise override a company
  security rule. So: on a **prohibition**, the higher layer wins; on anything else, the nearer one.
- **The pointer to a parent is explicit.** Instruction files are discovered along the working
  path, not across repos — an L1 wiki in its own repo never auto-loads L0. So every non-L0 wiki
  declares its parents and its home carries one line per parent:

  ```yaml
  # INDEX.md / index.md frontmatter
  layer: L1
  inherits: [company-rules]     # [] = "no parent", stated — not "forgot to say"
  ```
  ```markdown
  - floor: company-rules → <where its floor page lives> — wins over anything here on a prohibition.
  ```
  The line needs the exact id, an arrow (`→` or `->`) and a destination; a line inside a code
  fence is an example, not a pointer. `fw_layers.py declare` fails when a declared parent has no such line, and reports UNMEASURED
  (never "L1 by default") when `layer:` is missing.
- **Layer count is not fixed.** Most real setups need L0 · org · personal. An L2 starts as a
  directory inside L1 (`projects/<name>/`) and becomes its own repo only when §3 says so.

**Plug point — L0 owner (open question).** If nobody owns a company floor yet, start at L1 with
`inherits: []`. When an owner appears, add the L0 repo to the registry and change the one line.

## 3. When to split a wiki — D1 to D4

Split when **one of these differs** between two parts, strongest first. Size alone is D4, the weakest.

| # | Differs | Why it forces a split | Question |
|---|---|---|---|
| D1 | confidentiality boundary | git grants read access per repo, not per file — mixed content cannot be un-shared by permissions | may every reader of this repo read all of it? |
| D2 | writer set | reviewers and CODEOWNERS diverge; "other people's files go through PR" gets heavy | do the people who edit this also edit that? |
| D3 | lifecycle speed | daily handoffs bury quarterly rules in history and review | how often does each change? ~10× apart is a candidate |
| D4 | entry index outgrows the first read | an agent burns context before it opens a page | entry-index size — **threshold UNCALIBRATED**; split the index by section first |

**Do not split** when boundary, writers and pace are the same: a directory is enough, and every extra
repo adds registry, permission and sync cost. L3 always differs on D1, so it is always separate (§5).

`fw_layers.py split-report` prints the D2–D4 inputs (files, distinct authors and commits per section,
entry-index size) and asks D1 as a question. It never prints a verdict.

## 4. Federation — a registry, never a copy

The topmost wiki you run keeps `wikis.yaml`: **where** each wiki is, never **what** it says.

```yaml
- id: org-a
  layer: L1
  repo: <host>/<org-a>/wiki
  entry: index.md
  inherits: [company-rules]
- id: org-a/harness-x
  layer: L2
  repo: <host>/<org-a>/harness-x-wiki
  entry: index.md
  parent: org-a
  inherits: [company-rules, org-a]
```

- **Anyone who can read the registry sees every row.** Filtering happens only when a reader opens a
  wiki — the git host checks that, per repo. So list only wikis whose *existence* is not secret; a
  wiki whose existence is secret goes only in its own org's registry.
- **No content keys.** `summary:`, `content:`, `rules:` … are refused: a summary is a copy, a copy is
  always later than its source, and a stale rule that reads as current is worse than none.
- **No L3 rows** in a shared registry (`--personal` allows them in your own).
- Links between layers are ordinary markdown links. A link a reader cannot follow because they lack
  access is expected, not broken — `fw_layers.py links` judges only links inside one wiki.

`fw_layers.py registry` checks: required keys, known layers, unique ids, every `parent`/`inherits`
names an id **above** the entry, no content keys, no L3. The parser accepts a deliberately small YAML
subset and **fails closed** on anything else — a registry half-read would look like "no entries there".

## 5. Identity and permission

**Build no permission system.** Use the git host's: org accounts, teams, repo permissions, branch
protection or rulesets, CODEOWNERS.

| Need | Mechanism |
|---|---|
| read L0–L2 | repo read permission, per team |
| write L0–L2 | **every write is a PR** — enforced by branch protection / rulesets with "code owner review required". CODEOWNERS alone only *requests* reviewers; it enforces nothing |
| L3 owner-only | **a private repo owned by that person.** A `people/<id>/` folder in a shared repo is readable by everyone who can read the repo |
| an agent sees "shared layers + my own" | the agent runs on the user's own token, so what it can open *is* what that user can open. No identity→layer table to maintain |
| who did it | commit author = the human; agent on a `Co-Authored-By` line. A bot identity hides who asked |
| downloaded copies | clones survive revoked access — keep them per user, outside any shared repo's tree, and delete them on revocation |

**Plug point — personal layer as its own repo (open question).** The tools assume it (`registry`
refuses L3 rows; `promote` treats every source as narrower than its target). If you choose a shared
repo instead, nothing breaks mechanically — but §5 row 3 is then false, and the reason the default
exists is that it cannot be fixed later by permissions.

## 6. Promotion — narrow to wide

```
L3 personal ──PR (what a human chose)──▶ L2 project ──PR + org lead──▶ L1 org ──PR + L0 maintainer──▶ L0
```

- **Promotion is a copy with provenance.** The original stays where it was. The copy is born
  `status: draft` with `promoted_from: L3:<opaque id>` and a `# Sources` line citing that id — an
  address is information too (account, repo and project names), so the path itself never travels.
- **Scrub locally, before any push.** Pushing a branch to the target repo already shows it to that
  repo's readers, and a blocked PR still leaves it in history. `fw_layers.py promote` scans the
  source with generic secret shapes **plus your org's patterns file** (the same `SEVERITY<TAB>regex`
  format as a public-surface pattern list), and **blocks** if that file is absent — the generic scan
  cannot know your org's names. `--no-org-patterns` states on the record that there are none.
- **A wider write after a narrow read is an export.** A session that read L3 and then edits L2 is
  publishing, whatever the edit looks like — a scanner cannot recognize a confidential *conclusion*.
  The human step "what in this copy came from the narrow layer?" is not optional, and the tool prints
  it as the next step. The tool never commits or pushes.
- **Found → extend.** `promote` refuses when the target page already exists.
- Downward changes (an L0 rule moved) are not copied down: each wiki's `log.md` gets one line,
  "upstream X changed — <link>".

## 7. Storage — git is the canon; MCP and databases are adapters

| | git + markdown (canon) | read-only MCP gateway (adapter) | database as canon (not built) |
|---|---|---|---|
| boundary | repo = boundary | follows git | row-level possible — a new attack surface we would run |
| permission | git host | **caller's token**; a gateway reading with its own service account lets everyone read with its rights — forbidden | rebuilt from scratch |
| review gate | PR | uses git's PR | rebuilt |
| history | git | git | separate audit log |
| offline / portable | clone | needs a server | server + backup + migration |
| agent context cost | entry index only | tool schemas load before first use — keep ≤ 3 tools | small results, silently stale |
| across many repos | follow the registry | **strength** | strength |
| runtimes with no filesystem | cannot | **strength** | strength |

**Git is the canon.** An adapter is added only when its condition actually occurs, and each one is a
document in `adapters/` that an agent reads when that condition occurs — no adapter is wired by
default. See [`adapters/README.md`](adapters/README.md).

**Plug point — does any runtime need the gateway (open question).** If none does, nothing is built;
`adapters/mcp-read-gateway.md` stays a document. If one does, that file is the build sheet.

## 8. What a harness reads from a layered wiki

A harness (e.g. a QA harness with an org-folder entry point) keeps its **judgment rules** inside
itself and reads only **what** from the wiki: vocabulary, policy, service map, past defect patterns.
Two degrade directions, not one:

- **domain context** missing or stale → say so and proceed;
- **a higher-layer prohibition** that cannot be read → the action it governs **stops**. Warning and
  proceeding would let "could not read the rule" bypass the rule.

Onboarding a new org then means: make its wiki pass `fw_layers.py declare/links/frontmatter`, map it
into the harness's org folder, and change no harness code.

## 9. Not built

A canonical database · a vector index as canon · our own permission server · "private folder" inside
a shared repo · syncing higher rules into lower wikis · summaries in the registry · regenerating the
index on every write (SPEC §3.4 measured the loss).

## 10. Checks

| Command | Asserts | 0 inputs |
|---|---|---|
| `registry <wikis.yaml>` | §4 shape | UNMEASURED (exit 2) |
| `declare [root]` | §2 layer + explicit floor pointers | UNMEASURED if no `layer:` |
| `links [root]` | intra-wiki links resolve | UNMEASURED |
| `frontmatter [root] [--require …]` | required keys on every knowledge page | UNMEASURED |
| `promote <src> <dest> …` | §6 scrub (fail-closed) + provenance | — |
| `split-report [root]` | §3 inputs, no verdict | UNMEASURED if no home |

Anchor: `tests/test_layers.sh` — each command has a known-positive fixture (must fail, with the
expected message), a known-negative (the clean `examples/federation/`), and an empty-input lane
(must be UNMEASURED, never PASS). Each guard was removed once and its lane went red (revert probe).
A cross-family review (codex, round 1) found 9 fail-open inputs — a secret split across a line break,
a floor pointer with no destination or to a longer id or only inside a code fence, nested registry
values, `[,]` read as `[]`, an old address-shaped `promoted_from` kept, reference-style links unchecked,
and a lane whose guard could be removed while it stayed green. Each has a lane that fails on the
earlier code.
Round 2 found 7 more (a `~~~` or unclosed fence, quoted-key and block-scalar provenance, YAML tags,
two valid inputs wrongly refused, `<angle>` link destinations, one more masked lane) — all fixed the
same way. **Review stopped at round 2 on purpose**: checks that parse text with patterns do not
converge, each round finds a shape the last did not list. The remaining risk, by name: the registry
parser refuses any shape it does not recognise (fail-closed), but `declare`, `links` and `promote`
read markdown and YAML with patterns, so an input shape nobody listed can still pass. `promote`'s
human step (§6) is the backstop for the one surface where that matters.

## Sources

- Design memo this contract came from: an FH design note, 2026-11-06 (L0–L3, D1–D4, storage
  comparison), reviewed once by a different model family (11 findings applied).
- Nested instruction files concatenate and the nearer file wins; discovery follows the working path —
  https://www.ssdnodes.com/learn/nested-agents-md-for-monorepos ·
  https://codex.danielvaughan.com/2026/03/26/agents-md-advanced-patterns/ ·
  https://github.com/github/copilot-cli/issues/3051
- Private notebook + shared wiki + promotion flow on git — https://hacker-news-nextjs.vercel.app/item/47899844
- Company / unit / team hierarchy with ownership frontmatter — https://jrs1986.github.io/CodingScaffold/wiki/Knowledge-Base.html
- A shared token reaches everything its owner can; per-user brokering instead —
  https://documentation.gravitee.io/gravitee-gamma/agent-management/build/configure-your-mcp/connect-and-secure-github-mcp-server ·
  https://stacklok.com/blog/github-authorization-for-mcp-servers/
- Tool schemas cost context before first use — https://tianpan.co/blog/2026-05-13-mcp-capability-disclosure-tax-context-window-bill
- CODEOWNERS requests, branch protection enforces — https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
