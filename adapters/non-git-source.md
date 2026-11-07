---
type: adapter
description: Build sheet for importing knowledge that lives outside git (hosted wiki, tickets, chat) into a forge-wiki as markdown.
status: current
---

# Non-git source import

## When

The org's knowledge lives in a hosted wiki, a ticket tracker or chat, not in git — and an agent
needs it as files.

## Four things to write down before the first run

| | |
|---|---|
| **who** runs the export | a named person or job, not "someone" |
| **how often** | a cadence, and what happens when it is missed |
| **where** it lands | a section of one wiki (`imported/<source>/`), inside ONE confidentiality boundary |
| **on failure** | stop and report; never land a partial export as if it were complete |

## Shape

- Export → markdown with frontmatter (`type`, `description`, `source:` the original location,
  `synced_at:`) → scrub (same local scan as `fw_layers.py promote`, org patterns required) → PR.
- The source system stays the canon for its pages; mark imported pages `status: historical` or link
  back, so nobody edits the copy expecting it to flow back.
- Record the path in the wiki's adoption note (`adoption_path: export`, `synced_at:`).

## Must not

- import across a boundary (a team-only space into an org-wide wiki) — that is a promotion (LAYERS §6);
- run on a token broader than the wiki's readers'.

## Known pair

One page that exists in the source and must appear after a run; one page in a space the export token
cannot read — it must be reported as skipped, not silently absent.
