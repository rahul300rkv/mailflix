#!/usr/bin/env python
"""
Mailflix recovery patch (run from the repository root in Codespaces).

Conservative, repeatable fixes:
- removes committed backup snapshots from the deployable repository;
- normalizes internal HTML links (including fragments and query strings);
- normalizes canonical, Open Graph URL, and absolute site URLs;
- removes the inaccurate "Free unlimited use" structured-data claim;
- refreshes sitemap lastmod dates only for files actually changed;
- checks URL/metadata consistency and prints financial claims needing human verification.

It intentionally does NOT rewrite tax slab calculations or claim they are current.
Tax formulas must be verified against official rules before changing their tax-year labels.
"""
from __future__ import annotations

import datetime as dt
import json
import re
import shutil
from pathlib import Path
from urllib.parse import urlsplit, urlunsplit
import xml.etree.ElementTree as ET

ROOT = Path.cwd()
BASE = "https://mailflix.netlify.app"
SITEMAP = ROOT / "sitemap.xml"
ROBOTS = ROOT / "robots.txt"
BACKUP_PREFIX = "mailflix_backup_"
TODAY = dt.date.today().isoformat()

if not (ROOT / ".git").exists() or not (ROOT / "index.html").exists():
    raise SystemExit("Run this script from the Mailflix repository root (where .git and index.html exist).")

# Keep a local backup outside the published root, so it cannot become public content.
backup_dir = ROOT.parent / f"mailflix_pre_recovery_backup_{dt.datetime.now().strftime('%Y%m%d_%H%M%S')}"
backup_dir.mkdir(parents=True, exist_ok=True)

html_files = sorted(p for p in ROOT.glob("*.html") if p.is_file())
if not html_files:
    raise SystemExit("No root-level HTML pages found.")

# filename -> clean URL path
path_map = {p.name: ("/" if p.name == "index.html" else "/" + p.stem) for p in html_files}
changed_pages: set[str] = set()
issues: list[str] = []

# Backup only files this script may modify.
for p in html_files + [SITEMAP, ROBOTS]:
    if p.exists():
        shutil.copy2(p, backup_dir / p.name)

def canonical_for(page: Path) -> str:
    return BASE + ("/" if page.name == "index.html" else "/" + page.stem)

def clean_url(url: str) -> str:
    """Normalize URLs on this site's canonical host; preserve query/fragment."""
    if not url:
        return url
    if url.startswith("//"):
        parts = urlsplit("https:" + url)
        if parts.netloc.lower() in {"www.mailflix.netlify.app", "mailflix.netlify.app"}:
            url = urlunsplit(("https", "mailflix.netlify.app", parts.path, parts.query, parts.fragment))
        return url
    parts = urlsplit(url)
    if parts.scheme and parts.netloc.lower() in {"www.mailflix.netlify.app", "mailflix.netlify.app"}:
        path = parts.path or "/"
        if path == "/index.html":
            path = "/"
        elif path.endswith(".html") and path[1:] in path_map:
            path = path_map[path[1:]]
        return urlunsplit(("https", "mailflix.netlify.app", path, parts.query, parts.fragment))
    return url

def normalize_internal_href(match: re.Match) -> str:
    quote, value = match.group(1), match.group(2)
    if not value or value.startswith(("#", "mailto:", "tel:", "javascript:", "data:")):
        return match.group(0)
    if value.startswith(("http://", "https://", "//")):
        return f'href={quote}{clean_url(value)}{quote}'
    parts = urlsplit(value)
    path = parts.path
    if path in path_map:
        new_path = path_map[path]
    elif path.startswith("./") and path[2:] in path_map:
        new_path = path_map[path[2:]]
    elif path.startswith("/") and path[1:] in path_map:
        new_path = path_map[path[1:]]
    else:
        return match.group(0)
    return f'href={quote}{urlunsplit(("", "", new_path, parts.query, parts.fragment))}{quote}'

def replace_canonical(html: str, canonical: str) -> str:
    tag = f'<link rel="canonical" href="{canonical}"/>'
    pattern = re.compile(r'<link\b(?=[^>]*\brel=["\']canonical["\'])[^>]*>', re.I)
    matches = list(pattern.finditer(html))
    if matches:
        # Replace first canonical and remove accidental duplicates.
        html = pattern.sub("", html)
        head_end = re.search(r"</head\s*>", html, re.I)
        if head_end:
            html = html[:head_end.start()] + tag + "\n" + html[head_end.start():]
        else:
            html = tag + "\n" + html
    else:
        head_end = re.search(r"</head\s*>", html, re.I)
        if head_end:
            html = html[:head_end.start()] + tag + "\n" + html[head_end.start():]
        else:
            html = tag + "\n" + html
    return html

for page in html_files:
    original = page.read_text(encoding="utf-8")
    text = original

    # Normalize absolute site URLs everywhere in HTML, including JSON-LD and links.
    text = re.sub(
        r'https?://(?:www\.)?mailflix\.netlify\.app(?:/[^\s"\'<>]*)?',
        lambda m: clean_url(m.group(0)),
        text,
        flags=re.I,
    )

    # Normalize links to local .html pages, preserving #fragments and ?queries.
    text = re.sub(r'\bhref=(["\'])(.*?)\1', normalize_internal_href, text, flags=re.I)

    # Ensure exactly one canonical URL for this page.
    text = replace_canonical(text, canonical_for(page))

    # Keep existing og:url aligned with canonical URL.
    text = re.sub(
        r'(<meta\b(?=[^>]*\bproperty=["\']og:url["\'])[^>]*\bcontent=["\'])[^"\']*(["\'][^>]*>)',
        lambda m: m.group(1) + canonical_for(page) + m.group(2),
        text,
        flags=re.I,
    )

    # Remove demonstrably contradictory structured-data promise. Preserve page's real daily limit.
    text = re.sub(r',?\s*"Free unlimited use"\s*,?', '', text, flags=re.I)
    text = re.sub(r',\s*,', ',', text)

    # Normalize product/site brand spelling in user-visible metadata only.
    # Do not globally rewrite body copy where the historical brand context may matter.
    text = text.replace("MAILFIX.IN", "MailFix")
    text = text.replace("MailFlix", "MailFix")

    if text != original:
        changed_pages.add(page.name)
        page.write_text(text, encoding="utf-8")

# Remove accidental backup folders from repository root, but preserve them in external backup.
for folder in sorted(ROOT.glob(BACKUP_PREFIX + "*")):
    if folder.is_dir():
        dest = backup_dir / (folder.name + "_removed_from_repo")
        shutil.copytree(folder, dest, dirs_exist_ok=True)
        shutil.rmtree(folder)
        issues.append(f"Removed published-root backup directory: {folder.name}")

# Ensure robots references the one canonical sitemap.
if ROBOTS.exists():
    old = ROBOTS.read_text(encoding="utf-8")
    lines = [line for line in old.splitlines() if not line.strip().lower().startswith("sitemap:")]
    lines += ["", f"Sitemap: {BASE}/sitemap.xml"]
    new = "\n".join(lines).strip() + "\n"
    if new != old:
        ROBOTS.write_text(new, encoding="utf-8")
        issues.append("Normalized robots.txt sitemap directive.")

# Update lastmod only for pages whose source changed. Do not fake freshness for untouched pages.
if SITEMAP.exists() and changed_pages:
    try:
        ET.register_namespace("", "http://www.sitemaps.org/schemas/sitemap/0.9")
        tree = ET.parse(SITEMAP)
        root = tree.getroot()
        ns = {"sm": "http://www.sitemaps.org/schemas/sitemap/0.9"}
        for entry in root.findall("sm:url", ns):
            loc = entry.find("sm:loc", ns)
            lastmod = entry.find("sm:lastmod", ns)
            if loc is None or not loc.text:
                continue
            parts = urlsplit(loc.text.strip())
            name = "index.html" if parts.path in ("", "/") else parts.path.strip("/") + ".html"
            if name in changed_pages:
                if lastmod is None:
                    lastmod = ET.SubElement(entry, "{http://www.sitemaps.org/schemas/sitemap/0.9}lastmod")
                lastmod.text = TODAY
        tree.write(SITEMAP, encoding="utf-8", xml_declaration=True)
    except ET.ParseError as e:
        issues.append(f"ERROR: sitemap.xml is not valid XML: {e}")

# Audit pages after changes.
for page in html_files:
    text = page.read_text(encoding="utf-8")
    canonicals = re.findall(r'<link\b(?=[^>]*\brel=["\']canonical["\'])[^>]*>', text, flags=re.I)
    if len(canonicals) != 1:
        issues.append(f"{page.name}: expected exactly one canonical tag; found {len(canonicals)}")
    if "www.mailflix.netlify.app" in text:
        issues.append(f"{page.name}: still contains www.mailflix.netlify.app")
    if re.search(r'href=["\'][^"\']+\.html(?:[?#][^"\']*)?["\']', text, re.I):
        issues.append(f"{page.name}: internal .html href remains (review manually; may be an asset or intentional link)")
    if re.search(r"FY 2025[-–]26|FY 2025[-–]2026|2025[-–]26 tax slabs", text, re.I):
        issues.append(f"{page.name}: contains FY 2025-26 claim; verify formula/content before changing its label")
    if re.search(r"Free unlimited use", text, re.I):
        issues.append(f"{page.name}: contradictory unlimited-use claim remains")

print("MAILFLIX RECOVERY PATCH FINISHED")
print(f"Backup saved outside deploy root: {backup_dir}")
print(f"HTML files scanned: {len(html_files)}")
print(f"HTML files changed: {len(changed_pages)}")
print("Changed files:", ", ".join(sorted(changed_pages)) if changed_pages else "(none)")
print("\nIMPORTANT: This patch does not guarantee Google indexing.")
print("Review all financial formulas against current official rules before updating tax-year labels.")
print("\nAudit notes:")
for issue in issues:
    print("-", issue)
if not issues:
    print("- No flagged issues from the conservative checks.")
print("\nNext: run git diff --check, inspect git diff, test all tool forms, then commit and deploy.")
