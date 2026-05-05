"""Re-render talk sources before Quarto builds the site.

For each subdirectory under assets/talks/<NAME>/:
  index.Rmd  -> Rscript -e 'rmarkdown::render(...)'   (xaringan)
  build.py   -> python3 build.py                      (mtg-slides python)
  (neither)  -> skipped (PDF-only, .qmd-only, or pre-rendered talks)

Incremental: a talk is rendered only when *any* source file in its
folder is newer than index.html. Set RENDER_TALKS_FORCE=1 to force a
full rebuild; set RENDER_TALKS_SKIP=1 to bypass entirely.

Quarto invokes this via the pre-render hook in _quarto.yml.
"""

import os
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
TALKS = ROOT / "assets" / "talks"
FORCE = os.environ.get("RENDER_TALKS_FORCE") == "1"
SKIP = os.environ.get("RENDER_TALKS_SKIP") == "1"

# Files / directories under a talk folder that are *outputs* — excluded
# from the mtime comparison so they don't make the talk look "fresh".
OUTPUT_TOP_LEVEL = {"index.html", "index_files"}


def latest_source_mtime(talk_dir: Path) -> float:
    """Return the newest mtime among non-output files in the talk folder."""
    latest = 0.0
    for p in talk_dir.rglob("*"):
        if p.is_dir():
            continue
        if p.name == "index.html":
            continue
        if p.relative_to(talk_dir).parts[0] in OUTPUT_TOP_LEVEL:
            continue
        try:
            latest = max(latest, p.stat().st_mtime)
        except OSError:
            pass
    return latest


def needs_rebuild(talk_dir: Path) -> bool:
    out = talk_dir / "index.html"
    if not out.exists():
        return True
    return latest_source_mtime(talk_dir) > out.stat().st_mtime


def render_talk(talk_dir: Path) -> str | None:
    """Render the talk if needed; return 'rendered', 'skipped', or None."""
    rmd = talk_dir / "index.Rmd"
    build_py = talk_dir / "build.py"

    if not rmd.exists() and not build_py.exists():
        return None  # PDF-only / .qmd-only / pre-rendered

    if not FORCE and not needs_rebuild(talk_dir):
        return "skipped"

    if rmd.exists():
        print(f"[render_talks] knitting {talk_dir.name}/index.Rmd")
        subprocess.run(
            ["Rscript", "-e", f'rmarkdown::render("{rmd}", quiet = TRUE)'],
            check=True,
        )
    else:
        print(f"[render_talks] running {talk_dir.name}/build.py")
        subprocess.run(
            [sys.executable, str(build_py)], check=True, cwd=build_py.parent
        )
    return "rendered"


def main() -> None:
    if SKIP:
        print("[render_talks] RENDER_TALKS_SKIP=1 — bypassing")
        return
    if not TALKS.exists():
        return

    rendered = skipped = 0
    for talk_dir in sorted(TALKS.iterdir()):
        if not talk_dir.is_dir():
            continue
        result = render_talk(talk_dir)
        if result == "rendered":
            rendered += 1
        elif result == "skipped":
            skipped += 1

    if rendered or skipped:
        print(f"[render_talks] {rendered} rendered, {skipped} up-to-date")


if __name__ == "__main__":
    main()
