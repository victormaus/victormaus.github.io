#!/usr/bin/env python3
"""Build a remark.js slide deck from index.md + lib/default.html.

This is the Python sibling of the Rmd/xaringan flow. Both pipelines emit
HTML that loads the same theme.css and uses the same default.html shell,
so the deck looks the same regardless of which path produced it.

Usage:
    python build.py            # builds index.html (and optionally runs figures.py)
    python build.py --no-figs  # skip running figures.py

index.md format
---------------
The file starts with a YAML front-matter block (between '---' lines) with
keys: title, subtitle, author, date, notes, footer. The body that follows
is raw remark.js slide markdown — exactly what you would put in an Rmd's
slide body. Use `<<cite:KEY>>` to reference a bib entry; the script
resolves it via pandoc (`pandoc references.bib -t csljson`) and inserts a
hyperlinked Author (Year) Journal span. After the last slide, if any
citations were used, a `# References` slide is appended automatically.
"""

from __future__ import annotations

import argparse
import json
import re
import string
import subprocess
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit("PyYAML missing — install with: pip install pyyaml")


HERE = Path(__file__).resolve().parent


# ---------------------------------------------------------------------------
# Citations
# ---------------------------------------------------------------------------

class Citations:
    def __init__(self, bib_path: Path):
        self.bib_path = bib_path
        self._refs: dict = {}
        self._cited: list[str] = []
        if bib_path.exists():
            self._load()

    def _load(self) -> None:
        out = subprocess.run(
            ["pandoc", str(self.bib_path), "-t", "csljson"],
            check=True, capture_output=True, text=True,
        ).stdout
        for ref in json.loads(out):
            self._refs[ref["id"]] = ref

    @staticmethod
    def _authors_short(authors: list[dict]) -> str:
        fams = [a.get("family", "") for a in authors]
        if len(fams) == 1:
            return fams[0]
        if len(fams) == 2:
            return " &amp; ".join(fams)
        return f"{fams[0]} et al."

    @staticmethod
    def _authors_long(authors: list[dict]) -> str:
        parts = []
        for a in authors:
            given = a.get("given", "")
            initials = " ".join(
                f"{p[0].upper()}." for p in re.split(r"[ -]", given) if p
            )
            parts.append(f"{a.get('family', '')}, {initials}")
        if len(parts) == 1:
            return parts[0]
        if len(parts) == 2:
            return f"{parts[0]}, &amp; {parts[1]}"
        return ", ".join(parts[:-1]) + f", &amp; {parts[-1]}"

    @staticmethod
    def _url(ref: dict) -> str | None:
        if ref.get("URL"):
            return ref["URL"]
        if ref.get("DOI"):
            return f"https://doi.org/{ref['DOI']}"
        return None

    @staticmethod
    def _year(ref: dict) -> str:
        dp = ref.get("issued", {}).get("date-parts")
        return str(dp[0][0]) if dp else "n.d."

    def cite(self, key: str) -> str:
        ref = self._refs.get(key)
        if ref is None:
            print(f"[build.py] WARNING: unknown citation key: {key}", file=sys.stderr)
            return f"[? {key}]"
        if key not in self._cited:
            self._cited.append(key)
        authors = self._authors_short(ref.get("author", []))
        year = self._year(ref)
        journal = (
            f"<em>{ref['container-title']}</em>"
            if ref.get("container-title") else ""
        )
        text = f"{authors} ({year}) {journal}".strip()
        url = self._url(ref)
        if url:
            return (f'<a class="cite-link" href="{url}" target="_blank" '
                    f'rel="noopener">{text}</a>')
        return f'<span class="cite-link">{text}</span>'

    def bibliography(self) -> str:
        if not self._cited:
            return ""
        cited = sorted(
            (self._refs[k] for k in self._cited),
            key=lambda r: r.get("author", [{}])[0].get("family", ""),
        )
        out = []
        for ref in cited:
            authors = self._authors_long(ref.get("author", []))
            year = self._year(ref)
            title = ref.get("title", "")
            journal = (
                f"<em>{ref['container-title']}</em>"
                if ref.get("container-title") else None
            )
            vol = ref.get("volume")
            pages = ref.get("page")
            journal_part = ", ".join(p for p in [journal, vol, pages] if p)
            url = self._url(ref)
            link = (f' <a href="{url}" target="_blank" rel="noopener">{url}</a>'
                    if url else "")
            note = f" {ref['note']}." if ref.get("note") else ""
            out.append(
                f'<div class="csl-entry">{authors} ({year}). {title}. '
                f'{journal_part}.{link}{note}</div>'
            )
        return "\n".join(out)

    def has_citations(self) -> bool:
        return bool(self._cited)


# ---------------------------------------------------------------------------
# Markdown loading + slide composition
# ---------------------------------------------------------------------------

def load_markdown(path: Path) -> tuple[dict, str]:
    text = path.read_text(encoding="utf-8")
    if not text.startswith("---"):
        return {}, text
    _, fm, body = text.split("---", 2)
    return yaml.safe_load(fm) or {}, body.lstrip("\n")


def resolve_citations(body: str, cites: Citations) -> str:
    return re.sub(r"<<cite:([^>]+)>>", lambda m: cites.cite(m.group(1)), body)


def append_refs_slide(body: str, cites: Citations) -> str:
    if not cites.has_citations():
        return body
    return body + (
        "\n\n---\n"
        "layout: false\n"
        "class: refs-slide\n"
        "count: false\n"
        "# References\n\n"
        f'<div id="refs">\n{cites.bibliography()}\n</div>\n'
    )


# ---------------------------------------------------------------------------
# Default.html rendering
# ---------------------------------------------------------------------------

# Pandoc template variables we substitute. Loops/conditionals are unrolled
# directly because we control the input shape.
def render_default_html(template: str, ctx: dict) -> str:
    # First, substitute simple $var$ placeholders.
    out = template
    for key, val in ctx.items():
        out = out.replace(f"${key}$", val)

    # Now strip any pandoc conditional/loop blocks and leftover $...$ refs.
    out = re.sub(r"\$if\([^)]+\)\$.*?\$endif\$", "", out, flags=re.DOTALL)
    out = re.sub(r"\$for\([^)]+\)\$.*?\$endfor\$", "", out, flags=re.DOTALL)
    out = re.sub(r"\$[a-zA-Z0-9_-]+\$", "", out)
    return out


REMARK_BOOTSTRAP = """
<style data-target="print-only">@media screen {.remark-slide-container{display:block;}.remark-slide-scaler{box-shadow:none;}}</style>
<script src="./libs/remark-latest.min.js"></script>
<script src="./libs/macros.js"></script>
<script>
var slideshow = remark.create({
  "ratio": "16:9",
  "highlightStyle": "github",
  "highlightLines": true,
  "countIncrementalSlides": false,
  "slideNumberFormat": "%current%"
});
(function() {
  var deleted = false;
  slideshow.on('beforeShowSlide', function() {
    if (deleted) return;
    var sheets = document.styleSheets, node;
    for (var i = 0; i < sheets.length; i++) {
      node = sheets[i].ownerNode;
      if (node.dataset["target"] !== "print-only") continue;
      node.parentNode.removeChild(node);
    }
    deleted = true;
  });
})();
(function() {
  var links = document.getElementsByTagName('a');
  for (var i = 0; i < links.length; i++) {
    if (/^(https?:)?\\/\\//.test(links[i].getAttribute('href'))) {
      links[i].target = '_blank';
    }
  }
})();
</script>
"""


def build_html(
    fm: dict, body: str, default_html: str, css_files: list[str]
) -> str:
    title = fm.get("title", "Slides")
    subtitle = fm.get("subtitle", "")
    author = fm.get("author", "")
    date = fm.get("date", "")
    notes = fm.get("notes", "")

    # Compose the title-slide block manually (mirrors what pandoc/xaringan do).
    title_block = ["class: top, left, title-slide", "", ".title[", f"# {title}", "]"]
    if subtitle:
        title_block += [".subtitle[", f"## {subtitle}", "]"]
    if author:
        title_block += [".author[", f"### {author}", "]"]
    if date:
        title_block += [".date[", f"### {date}", "]"]
    if notes:
        title_block += ["", "???", notes]
    title_block += ["", "---"]
    full_body = "\n".join(title_block) + "\n\n" + body

    css_links = "\n    ".join(
        f'<link rel="stylesheet" href="{href}" type="text/css" />'
        for href in css_files
    )

    return f"""<!DOCTYPE html>
<html lang="" xml:lang="">
  <head>
    <title>{title}</title>
    <meta charset="utf-8" />
    <meta name="author" content="{author}" />
    {css_links}
  </head>
  <body>
    <textarea id="source">
{full_body}
    </textarea>
{REMARK_BOOTSTRAP}
  </body>
</html>
"""


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

CSS_FILES = [
    "./libs/theme.css",
    "./libs/theme-fonts.css",
    "./libs/tachyons-min.css",
    "./custom.css",
]


def main() -> None:
    p = argparse.ArgumentParser(description="Build remark.js slides from index.md.")
    p.add_argument("--input", default="index.md")
    p.add_argument("--output", default="index.html")
    p.add_argument("--bib", default="references.bib")
    p.add_argument("--no-figs", action="store_true",
                   help="Skip running figures.py if present")
    args = p.parse_args()

    src = HERE / args.input
    out = HERE / args.output
    bib = HERE / args.bib

    figs = HERE / "figures.py"
    if figs.exists() and not args.no_figs:
        print(f"[build.py] running {figs.name}")
        subprocess.run([sys.executable, str(figs)], check=True, cwd=HERE)

    fm, body = load_markdown(src)
    cites = Citations(bib)
    body = resolve_citations(body, cites)
    body = append_refs_slide(body, cites)

    default_html = (HERE / "libs" / "default.html").read_text(encoding="utf-8")
    html = build_html(fm, body, default_html, CSS_FILES)

    out.write_text(html, encoding="utf-8")
    print(f"[build.py] wrote {out.relative_to(HERE)}")


if __name__ == "__main__":
    main()
