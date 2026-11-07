---
type: adapter
description: Build sheet for a read-only MCP gateway over one or many fh-llmwiki repos — caller's token, three tools, no state.
status: current
---

# Read-only MCP gateway

## When

Add it only if one of these is **actually true now**:
- a runtime that has no filesystem (a web chat, a hosted model gateway) must read org context;
- the registry lists more wikis than people follow by hand.

If neither holds, agents read the clone directly and this file stays a document.

## Two sizes

**One wiki, local** — already shipped: `bin/fw_mcp.py <wiki_root>` (`wiki_index` / `wiki_get` /
`wiki_search`, read-only, path-traversal guarded). Register it with your MCP client; nothing else.

**Many wikis, federated** — build only when the condition above holds. Shape:

| Tool | Does |
|---|---|
| `wiki_list` | rows of `wikis.yaml` **whose entry file the caller's token can read** |
| `wiki_index(id)` | that wiki's entry index |
| `wiki_get(id, path)` | one page |

Three tools, no more: every tool schema is loaded into the agent's context before the first call.
Search, if needed, is delegated to the git host's own search **with the caller's token**.

## Must

- **Authenticate as the caller.** Each request carries the end user's token (OAuth on-behalf-of or
  token passthrough); the gateway never holds a broad token of its own.
- **Decide readability by reading content.** Repo *metadata* can be visible without content
  permission, so "the repo exists" is not "the caller may read it". Probe the entry file.
- **Four outcomes, not two:** read · denied · ambiguous (rate limit, 403 that may be throttling,
  404 that may be "no such repo") · no token. Only "read" lists the wiki; the other three are reported
  as such, never folded into an empty list.
- **Stateless.** No cache that outlives a request unless it is keyed by the caller and expires.

## Must not

- write, open PRs, or accept "just this once" write tools;
- return a wiki whose entry file the caller could not read;
- log page contents.

## Known pair (run before trusting it)

Registry with three rows: one public repo, one private repo of someone else whose existence you have
confirmed, one private repo of yours.
- your token → 2 read · 1 denied;
- a token with metadata-only scope → **0 read** (if it reads 3, the gateway is judging by metadata);
- no token → "no token" for all three, not an empty list.
