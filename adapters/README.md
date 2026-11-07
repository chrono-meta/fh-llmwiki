# adapters/ — optional additions, as build sheets

> Nothing in this folder is wired by default. Each file is a document an agent (or a person) reads
> **when its condition actually occurs**, and follows to add that one adapter. Git + markdown stays
> the canon in every case (LAYERS §7): an adapter reads from the canon or derives from it, and can
> be deleted without losing anything.

| Adapter | Add it when | File |
|---|---|---|
| Read-only MCP gateway | a runtime with **no filesystem** must read the wiki, or there are so many wikis that people cannot follow the registry by hand | [mcp-read-gateway.md](mcp-read-gateway.md) |
| Derived search index | the wiki is large enough that grep + the entry index stop finding things — measured, not felt | [search-index.md](search-index.md) |
| Non-git source import | the org's knowledge lives in a hosted wiki, tickets or chat, not in git | [non-git-source.md](non-git-source.md) |

## Rules every adapter keeps

1. **Read-only toward the canon.** Writes go through git + PR (SPEC §3). An adapter that writes is a
   second write path with no review gate.
2. **The caller's permissions, never the adapter's.** An adapter that reads with its own service
   account lets every caller read with that account's rights.
3. **Rebuildable.** If deleting the adapter's state loses information, it was a canon, not an adapter.
4. **Absence is not zero.** When the adapter cannot answer (down, rate-limited, no token), it says so
   — it does not return an empty result.
5. **Known pair before trust.** Each build sheet ends with a check: one input that must succeed and
   one that must be refused. Run both before relying on the adapter.

## How an agent uses this folder

Read this table. If no condition holds, stop — do not build an adapter "for later". If one holds,
open that file, follow it, and land the result as a PR in the repo that will run it.
