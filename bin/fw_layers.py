#!/usr/bin/env python3
"""fw_layers — the layer tools of forge-wiki (LAYERS.md is the contract these enforce).

Zero dependencies, like fw.py. Every command checks a PROPERTY OF THE RECORD (present, typed,
pointed-to), never a conclusion: whether two wikis should be split, or whether a promoted page is
safe to publish, stays a human judgment. The tools make that judgment cheap; they do not replace it.

Commands (exit 0 = clean · 1 = finding · 2 = UNMEASURED — nothing to check, never a silent PASS):

  registry <wikis.yaml> [--personal]   validate a federation registry (LAYERS §4)
  declare  [root]                      the wiki declares its layer and points at every floor it inherits (§2)
  links    [root]                      intra-wiki markdown links resolve (cross-repo links are tolerated)
  frontmatter [root] [--require a,b]   every knowledge file carries the required keys (default type,description)
  promote  <src.md> <dest_dir> [--patterns FILE | --no-org-patterns] [--write]
                                       narrow → wide copy: local scrub BEFORE any push, opaque provenance (§6)
  split-report [root]                  the D1–D4 inputs as numbers and questions — never a verdict (§3)
"""

from __future__ import annotations

import hashlib
import os
import re
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from urllib.parse import unquote

LAYERS = ("L0", "L1", "L2", "L3")
UNMEASURED = 2
HOME_NAMES = ("INDEX.md", "index.md")
# Files that are not knowledge pages: the home, the log, the agent/readme surfaces.
NON_KNOWLEDGE = {"INDEX.md", "index.md", "log.md", "llms.txt", "AGENTS.md", "CLAUDE.md"}


def die(msg: str, code: int) -> int:
    print(msg)
    return code


# ───────────────────────── frontmatter ─────────────────────────

def read_frontmatter(p: Path) -> dict | None:
    """Top-level scalar keys of a leading YAML block. None = no frontmatter at all."""
    try:
        text = p.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    out = {}
    for ln in text[3:end].splitlines():
        m = re.match(r"([A-Za-z_][\w-]*):\s*(.*?)\s*$", ln)
        if m:
            v = m.group(2)
            if not v[:1] in ("'", '"'):
                v = re.sub(r"\s+#.*$", "", v)  # YAML comment after an unquoted value
            out[m.group(1)] = v.strip().strip("\"'")
    return out


def parse_inline_list(v: str) -> list | None:
    v = v.strip()
    if not (v.startswith("[") and v.endswith("]")):
        return None
    inner = v[1:-1].strip()
    if not inner:
        return []
    if inner.endswith(",") and inner[:-1].strip():  # YAML flow sequences allow one trailing comma
        inner = inner[:-1]
    items = [x.strip().strip("\"'") for x in inner.split(",")]
    # `[,]` or `[a,,b]` is not an empty list — an element that vanished is an invalid record.
    return None if any(not x for x in items) else items


def home_file(root: Path) -> Path | None:
    # Match on the real directory listing: on a case-insensitive filesystem `INDEX.md`.exists()
    # is also true for `index.md`, and the report would name a file that is not there.
    try:
        names = {c.name for c in root.iterdir()}
    except OSError:
        return None
    return next((root / n for n in HOME_NAMES if n in names), None)


def md_files(root: Path):
    for p in sorted(root.rglob("*.md")):
        rel = p.relative_to(root)
        if any(part.startswith(".") for part in rel.parts) or rel.parts[0] in ("raw", "node_modules"):
            continue
        yield p


# ───────────────────────── registry ─────────────────────────

def not_flat(key: str, val: str) -> bool:
    """True when a value is not a flat scalar: empty (a nested block follows), a flow mapping, a block
    scalar, an anchor/alias, a YAML tag, or a flow list on any key but `inherits`."""
    return (not val or val.startswith(("{", "|", ">", "&", "*", "!"))
            or (val.startswith("[") and key != "inherits"))


def parse_registry(text: str):
    """A deliberately tiny YAML subset: a top-level list of flat maps, scalar or [inline, list]
    values. Anything else fails CLOSED with a line number — a registry the tool half-reads is
    worse than one it refuses, because the half it skipped would read as 'no entries there'."""
    items, cur, errors = [], None, []
    for n, raw in enumerate(text.splitlines(), 1):
        line = re.sub(r"\s+#.*$", "", raw) if not raw.lstrip().startswith("#") else ""
        if not line.strip():
            continue
        m = re.match(r"^-\s+([A-Za-z_][\w-]*):\s*(.*)$", line)
        if m:
            cur = {}
            items.append((n, cur))
            cur[m.group(1)] = m.group(2).strip()
            if not_flat(m.group(1), cur[m.group(1)]):
                errors.append(f"line {n}: '{m.group(1)}' is not a flat scalar")
            continue
        m = re.match(r"^  ([A-Za-z_][\w-]*):\s*(.*)$", line)  # exactly the item's indent: deeper = nesting
        if m and cur is not None:
            val = m.group(2).strip()
            if not_flat(m.group(1), val):
                errors.append(f"line {n}: '{m.group(1)}' is not a flat scalar — nested values are outside "
                              f"the supported subset")
            if m.group(1) in cur:
                errors.append(f"line {n}: duplicate key '{m.group(1)}'")
            cur[m.group(1)] = m.group(2).strip()
            continue
        errors.append(f"line {n}: outside the supported subset (flat list of maps): {raw.strip()[:60]}")
    return items, errors


REQUIRED_REG = ("id", "layer", "repo", "entry")
# Content keys are refused: a registry is a list of WHERE, never a copy of WHAT (LAYERS §4, §9).
CONTENT_KEYS = ("content", "summary", "body", "rules", "excerpt")


def cmd_registry(path: Path, personal: bool) -> int:
    if not path.is_file():
        return die(f"UNMEASURED  registry not found: {path}", UNMEASURED)
    items, errors = parse_registry(path.read_text(encoding="utf-8", errors="replace"))
    if not items and not errors:
        return die(f"UNMEASURED  {path}: 0 entries — an empty registry is not a valid one", UNMEASURED)
    ids = {}
    for n, it in items:
        for k in REQUIRED_REG:
            if not it.get(k):
                errors.append(f"line {n}: missing '{k}'")
        for k in CONTENT_KEYS:
            if k in it:
                errors.append(f"line {n}: '{k}' — the registry holds links, not content (copies go stale)")
        lid = it.get("layer", "")
        if lid and lid not in LAYERS:
            errors.append(f"line {n}: layer '{lid}' not one of {'/'.join(LAYERS)}")
        if lid == "L3" and not personal:
            errors.append(f"line {n}: L3 entry in a shared registry — the personal layer lives in its "
                          f"owner's private repo and is not listed where others read (pass --personal "
                          f"for your own registry)")
        if it.get("id") in ids:
            errors.append(f"line {n}: duplicate id '{it['id']}'")
        ids[it.get("id")] = (n, it)
    for iid, (n, it) in ids.items():
        refs = []
        if it.get("parent"):
            refs.append(("parent", it["parent"]))
        if "inherits" in it:
            lst = parse_inline_list(it["inherits"])
            if lst is None:
                errors.append(f"line {n}: inherits must be an inline list, e.g. [company-rules] or []")
                lst = []
            refs += [("inherits", r) for r in lst]
        for kind, ref in refs:
            if ref not in ids:
                errors.append(f"line {n}: {kind} '{ref}' is not an id in this registry")
                continue
            mine, theirs = it.get("layer", ""), ids[ref][1].get("layer", "")
            if mine in LAYERS and theirs in LAYERS and LAYERS.index(theirs) >= LAYERS.index(mine):
                errors.append(f"line {n}: {kind} '{ref}' is {theirs}, not above {mine} — authority "
                              f"flows down only (LAYERS §2)")
    for e in errors:
        print(f"FAIL  {e}")
    print(f"-- registry: {'FAIL' if errors else 'PASS'} ({len(items)} entries) --")
    return 1 if errors else 0


# ───────────────────────── declare ─────────────────────────

def cmd_declare(root: Path) -> int:
    home = home_file(root)
    if home is None:
        return die(f"UNMEASURED  {root}: no INDEX.md/index.md", UNMEASURED)
    fm = read_frontmatter(home) or {}
    layer = fm.get("layer")
    if not layer:
        return die(f"UNMEASURED  {home.name}: no 'layer:' in frontmatter — undeclared is not 'L1 by default'",
                   UNMEASURED)
    if layer not in LAYERS:
        return die(f"FAIL  layer '{layer}' not one of {'/'.join(LAYERS)}", 1)
    errors = []
    # Code blocks are examples, not pointers: a home whose only floor line sits in a fence points nowhere.
    # (fences only — a destination written as inline `code` is still a destination)
    body = strip_fences(home.read_text(encoding="utf-8", errors="replace"))
    if layer == "L0":
        floor = fm.get("floor")
        if floor and not (root / floor).is_file():
            errors.append(f"floor file '{floor}' declared but missing")
    else:
        if "inherits" not in fm:
            errors.append("no 'inherits:' — write [] if this wiki has no parent (an undeclared parent is "
                          "not the same as no parent)")
        else:
            lst = parse_inline_list(fm["inherits"])
            if lst is None:
                errors.append("inherits must be an inline list, e.g. [company-rules] or []")
            for ref in lst or []:
                # The pointer must be EXPLICIT: instruction files are not discovered across repos, so
                # a parent the home does not point at is a parent no agent reads (frontier, LAYERS §2).
                # exact id (not a longer id that starts with it), then an arrow, then a destination
                if not re.search(rf"(?im)^\s*[-*]?\s*\S*\s*floor:[ \t]*{re.escape(ref)}[ \t]+(→|->)[ \t]*\S", body):
                    errors.append(f"inherits '{ref}' but the home has no 'floor: {ref} → <where>' pointer line")
    for e in errors:
        print(f"FAIL  {e}")
    print(f"-- declare: {'FAIL' if errors else 'PASS'} (layer {layer}) --")
    return 1 if errors else 0


# ───────────────────────── links ─────────────────────────

LINK_RE = re.compile(r"(?<!!)\[[^\]]*\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)|^ {0,3}\[[^\]]+\]:[ \t]*(?:<([^>\n]+)>|(\S+))", re.M)


def strip_fences(text: str) -> str:
    """Drop fenced code blocks (``` or ~~~, length >= 3). An unclosed fence runs to the end of the
    file, as CommonMark renders it — so text after it is code, not a pointer."""
    out, fence = [], None
    for ln in text.splitlines(keepends=True):
        m = re.match(r"^ {0,3}(`{3,}|~{3,})", ln)
        if fence is None:
            if m:
                fence = m.group(1)
                continue
            out.append(ln)
        elif m and m.group(1)[0] == fence[0] and len(m.group(1)) >= len(fence) and not ln.strip()[len(m.group(1)):].strip():
            fence = None
    return "".join(out)


def strip_code(text: str) -> str:
    return re.sub(r"`[^`\n]*`", "", strip_fences(text))


def cmd_links(root: Path) -> int:
    files = list(md_files(root))
    if not files:
        return die(f"UNMEASURED  {root}: 0 markdown files", UNMEASURED)
    broken, outside, checked = [], 0, 0
    for p in files:
        text = strip_code(p.read_text(encoding="utf-8", errors="replace"))
        for m in LINK_RE.finditer(text):
            tgt = m.group(1) or m.group(2) or m.group(3)  # inline `[x](t)` · reference `[x]: <t>` · `[x]: t`
            if re.match(r"^[a-z][a-z0-9+.-]*:", tgt, re.I) or tgt.startswith("#"):
                continue  # http(s)/mailto/…: another repo's jurisdiction — tolerated (OKF)
            if any(c in tgt for c in "<>{}*"):
                continue  # placeholder in a template, not a pointer
            path = unquote(tgt.split("#", 1)[0])
            if not path:
                continue
            dest = (root / path.lstrip("/")) if path.startswith("/") else (p.parent / path)
            dest = dest.resolve()
            checked += 1
            if not str(dest).startswith(str(root.resolve())):
                outside += 1
                continue  # leaves this wiki — cross-layer links may look broken to readers without access
            if not dest.exists():
                broken.append(f"{p.relative_to(root)} → {tgt}")
    for b in broken:
        print(f"FAIL  {b}")
    print(f"-- links: {'FAIL' if broken else 'PASS'} ({checked} links in {len(files)} files · "
          f"{outside} leave this wiki, not judged) --")
    return 1 if broken else 0


# ───────────────────────── frontmatter ─────────────────────────

def cmd_frontmatter(root: Path, require: list) -> int:
    files = [p for p in md_files(root) if p.name not in NON_KNOWLEDGE and not p.name.startswith("README")]
    if not files:
        return die(f"UNMEASURED  {root}: 0 knowledge files", UNMEASURED)
    bad = []
    for p in files:
        fm = read_frontmatter(p)
        if fm is None:
            bad.append(f"{p.relative_to(root)}: no frontmatter")
            continue
        missing = [k for k in require if not fm.get(k)]
        if missing:
            bad.append(f"{p.relative_to(root)}: missing {', '.join(missing)}")
    for b in bad:
        print(f"FAIL  {b}")
    print(f"-- frontmatter: {'FAIL' if bad else 'PASS'} ({len(files)} files · required {','.join(require)}) --")
    return 1 if bad else 0


# ───────────────────────── promote ─────────────────────────

# Generic secret shapes. They catch the obvious; they cannot know your org's names —
# that is what --patterns is for, and why its absence BLOCKS instead of passing.
BUILTIN = [
    ("private-key", r"-----BEGIN [A-Z ]*PRIVATE KEY-----"),
    ("aws-key", r"\bAKIA[0-9A-Z]{16}\b"),
    ("github-token", r"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    ("slack-token", r"\bxox[abposr]-[A-Za-z0-9-]{10,}"),
    ("bearer", r"(?i)\bbearer\s+[A-Za-z0-9._-]{20,}"),
    ("assignment-secret", r"(?i)\b(password|passwd|secret|api[_-]?key|token)\s*[:=]\s*\S{6,}"),
    ("email", r"\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}\b"),
    ("private-ip", r"\b(10\.\d{1,3}|192\.168|172\.(1[6-9]|2\d|3[01]))\.\d{1,3}\.\d{1,3}\b"),
]


def load_patterns(path: Path):
    pats = []
    for n, ln in enumerate(path.read_text(encoding="utf-8", errors="replace").splitlines(), 1):
        ln = ln.rstrip("\n")
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        # Also reads the public-surface-patterns format (`SEVERITY<TAB>regex`), so one org file
        # serves both the publish gate and this promotion scan — no second list to drift.
        sev = re.match(r"^(HIGH|MED|MEDIUM|LOW|CRIT|CRITICAL)\t(.+)$", ln)
        ln = (sev.group(2) if sev else ln).strip()
        if ln:
            try:
                pats.append((f"org:{n}", re.compile(ln, re.I)))
            except re.error as e:
                raise SystemExit(f"FAIL  {path}:{n}: bad regex ({e}) — a pattern the scan cannot "
                                 f"compile is a scan that did not run")
    return pats


def mask(s: str) -> str:
    return s[:2] + "…" + s[-1:] if len(s) > 4 else "…"


def cmd_promote(src: Path, dest_dir: Path, patterns: Path | None, no_org: bool, write: bool) -> int:
    if not src.is_file():
        return die(f"UNMEASURED  source not found: {src}", UNMEASURED)
    if patterns is None and not no_org:
        return die("FAIL  no --patterns file: the generic scan cannot know your org's names, so a "
                   "promotion without them is blocked (pass --no-org-patterns to state, on the record, "
                   "that this wiki has none)", 1)
    if patterns is not None and not patterns.is_file():
        return die(f"FAIL  patterns file missing: {patterns} — scan tooling down blocks (fail-closed)", 1)
    pats = [(n, re.compile(r)) for n, r in BUILTIN] + (load_patterns(patterns) if patterns else [])
    text = src.read_text(encoding="utf-8", errors="replace")
    hits = []
    for name, rx in pats:
        if rx.search(src.name):
            hits.append(f"(file name) [{name}]")
        # The whole text, not line by line: a pattern with `\s` must still match across a line break.
        for m in rx.finditer(text):
            hits.append(f"line {text.count(chr(10), 0, m.start()) + 1} [{name}] {mask(m.group(0))}")
    urls = sorted(set(re.findall(r"https?://[^\s)>\]]+", text)))
    print(f"-- promote: {src.name} → {dest_dir} --")
    print(f"   scanned with {len(BUILTIN)} generic + {len(pats) - len(BUILTIN)} org pattern(s)"
          + ("  (org patterns waived on the record: --no-org-patterns)" if no_org else ""))
    if hits:
        for h in hits:
            print(f"FAIL  {h}")
        print("-- promote: BLOCKED — scrub the source in its own layer, then rerun --")
        return 1
    if urls:
        print(f"   {len(urls)} URL(s) — an address is information too (account, repo, project names). "
              f"Confirm each before the copy leaves the narrow layer:")
        for u in urls:
            print(f"     {u}")
    target = dest_dir / src.name
    if target.exists():
        return die(f"FAIL  {target} exists — extend that page instead of forking a second copy", 1)
    pid = "L3:" + hashlib.sha256((str(src.resolve()) + "\0" + text).encode()).hexdigest()[:12]
    if not write:
        print(f"   dry run — would write {target} with promoted_from: {pid}, status: draft (add --write)")
        return 0
    out = add_provenance(text, pid)
    dest_dir.mkdir(parents=True, exist_ok=True)
    target.write_text(out, encoding="utf-8")
    print(f"   wrote {target}  (promoted_from: {pid} · status: draft)")
    print("   next — by a human, in this order: read the copy for anything the narrow layer knew "
          "that this wider audience should not · branch · PR · reviewer merges. Nothing was committed or pushed.")
    return 0


def drop_keys(block: str, keys: set) -> str:
    """Remove top-level keys (quoted or not) AND their indented continuation lines — a block scalar
    (`key: |`) carries its value on the lines below, and dropping only the key line leaves it."""
    out, skipping = [], False
    for ln in block.splitlines(keepends=True):
        m = re.match(r"""^["']?([A-Za-z_][\w-]*)["']?\s*:""", ln)
        if m and not ln[:1].isspace():
            skipping = m.group(1) in keys
            if skipping:
                continue
        elif skipping and (ln[:1].isspace() or not ln.strip()):
            continue
        else:
            skipping = False
        out.append(ln)
    return "".join(out)


def add_provenance(text: str, pid: str) -> str:
    stamp = f"promoted_from: {pid}\npromoted_at: {date.today().isoformat()}\nstatus: draft\n"
    end = text.find("\n---", 3) if text.startswith("---") else -1
    if end != -1:
        # the copy starts life as a draft, and any provenance it already carried is replaced —
        # an older promoted_from may hold the very address this step exists to keep from travelling
        head = drop_keys(text[3:end + 1], {"status", "promoted_from", "promoted_at"})
        text = "---" + head + stamp + text[end + 1:]
    else:
        text = "---\n" + stamp + "---\n" + text
    line = f"- {pid} — promoted copy; the original stays in its own layer"
    if re.search(r"(?m)^#+\s*Sources\s*$", text):
        return re.sub(r"(?m)^(#+\s*Sources\s*)$", lambda m: m.group(1) + "\n" + line, text, count=1)
    return text.rstrip("\n") + "\n\n# Sources\n" + line + "\n"


# ───────────────────────── split-report ─────────────────────────

def git(root: Path, *args) -> str | None:
    try:
        r = subprocess.run(["git", "-C", str(root), *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return r.stdout if r.returncode == 0 else None


def cmd_split_report(root: Path) -> int:
    home = home_file(root)
    if home is None:
        return die(f"UNMEASURED  {root}: no INDEX.md/index.md", UNMEASURED)
    secs = sorted(d.name for d in root.iterdir() if d.is_dir() and not d.name.startswith(".")
                  and d.name not in ("raw", "bin", "tests", "scripts"))
    in_git = git(root, "rev-parse", "--is-inside-work-tree") is not None
    since = (datetime.now() - timedelta(days=90)).strftime("%Y-%m-%d")
    print(f"-- split-report: {root} (a report, not a verdict — LAYERS §3) --")
    chars = len(home.read_text(encoding="utf-8", errors="replace"))
    print(f"D4 entry index: {home.name} {chars} chars ≈ {chars // 4} tokens (chars/4 — UNCALIBRATED "
          f"for your tokenizer and for any threshold)")
    print(f"{'section':<24}{'files':>7}{'authors':>9}{'commits/90d':>13}")
    for s in secs:
        n = sum(1 for _ in (root / s).rglob("*.md"))
        if in_git:
            a = git(root, "log", "--format=%ae", "--", s) or ""
            c = git(root, "log", f"--since={since}", "--format=%h", "--", s) or ""
            if not a.strip():  # no history yet: 0 authors would be a measurement we did not make
                print(f"{s:<24}{n:>7}{'no-hist':>9}{'no-hist':>13}")
                continue
            authors, commits = len(set(a.split())), len(c.split())
            print(f"{s:<24}{n:>7}{authors:>9}{commits:>13}")
        else:
            print(f"{s:<24}{n:>7}{'UNMEAS.':>9}{'UNMEAS.':>13}")
    print("D1 (strongest, not countable): may every reader of this repo read every section? "
          "If not, that section needs its own repo — git grants read access per repo, not per file.")
    print("D2 · D3: sections whose author sets do not overlap, or whose change rates differ ~10x, are "
          "candidates. Same boundary + same writers + same pace → a directory is enough.")
    return 0


# ───────────────────────── main ─────────────────────────

def main(argv: list) -> int:
    if not argv or argv[0] in ("-h", "--help", "help"):
        print(__doc__)
        return 0
    cmd, rest = argv[0], argv[1:]
    if "--help" in rest or "-h" in rest:
        print(__doc__)
        return 0
    flags = {a for a in rest if a.startswith("--") and "=" not in a}
    pos = [a for a in rest if not a.startswith("--")]

    def opt(name):
        for i, a in enumerate(rest):
            if a == name and i + 1 < len(rest):
                return rest[i + 1]
        return None
    opt_vals = {opt("--patterns"), opt("--require")} - {None}
    pos = [a for a in pos if a not in opt_vals]
    root = Path(pos[0] if pos else ".").resolve()
    if cmd == "registry":
        if not pos:
            return die("usage: fw_layers.py registry <wikis.yaml> [--personal]", UNMEASURED)
        return cmd_registry(Path(pos[0]), "--personal" in flags)
    if cmd == "declare":
        return cmd_declare(root)
    if cmd == "links":
        return cmd_links(root)
    if cmd == "frontmatter":
        req = (opt("--require") or "type,description").split(",")
        return cmd_frontmatter(root, [r.strip() for r in req if r.strip()])
    if cmd == "promote":
        if len(pos) < 2:
            return die("usage: fw_layers.py promote <src.md> <dest_dir> [--patterns FILE | --no-org-patterns] "
                       "[--write]", UNMEASURED)
        p = opt("--patterns")
        return cmd_promote(Path(pos[0]), Path(pos[1]), Path(p) if p else None,
                           "--no-org-patterns" in flags, "--write" in flags)
    if cmd == "split-report":
        return cmd_split_report(root)
    return die(f"unknown command '{cmd}' — see --help", UNMEASURED)


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
