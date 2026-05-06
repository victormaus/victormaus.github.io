"""Build _talks.yml from per-talk metadata for the talks page listing.

For each subdirectory under assets/talks/<NAME>/, gather listing fields
in this order of precedence:

  1. index.qmd front-matter — top-level title/subtitle/date/image/categories.
  2. index.Rmd / index.md front-matter — top-level `title:`, plus a nested
     `listing:` block holding subtitle/date/image/categories so that
     xaringan ignores them. (xaringan + Quarto do not interpret unknown
     keys, so the source file remains a self-describing record.)
  3. _listing.yml sidecar — used for talks that are HTML-only (no .Rmd
     source on disk). Fills any field still missing.

Emits _talks.yml at the project root, sorted by date desc. talks.qmd then
references it via `contents: _talks.yml`.

Image paths inside source files are usually written relative to the talk
folder (e.g. ./img/foo.png or ../img/bar.png); the script resolves them
to project-root-relative paths for the listing.

Quarto pre-render hook; runs from the project root.
"""

from pathlib import Path
import sys
import yaml

ROOT = Path(__file__).resolve().parent
TALKS = ROOT / "assets" / "talks"
OUT = ROOT / "talks-listing.yml"

LISTING_FIELDS = ("title", "subtitle", "date", "image", "categories", "path")


def read_yaml_block(path: Path) -> dict | None:
    """Return the first ---YAML--- block in a Markdown/Rmd file, or None."""
    try:
        text = path.read_text(encoding="utf-8")
    except OSError:
        return None
    if not text.startswith("---"):
        return None
    parts = text.split("---", 2)
    if len(parts) < 3:
        return None
    try:
        return yaml.safe_load(parts[1]) or {}
    except yaml.YAMLError as e:
        print(f"[build_talks_listing] cannot parse YAML in {path}: {e}",
              file=sys.stderr)
        return None


def read_yaml(path: Path) -> dict | None:
    try:
        return yaml.safe_load(path.read_text(encoding="utf-8")) or {}
    except (yaml.YAMLError, OSError) as e:
        print(f"[build_talks_listing] cannot read {path}: {e}", file=sys.stderr)
        return None


def normalize_path_field(value: str, talk_dir: Path) -> str:
    """Resolve a relative path (image / path) to a project-root-relative one."""
    if not value or "://" in value:
        return value
    if value.startswith("/"):
        return value.lstrip("/")
    resolved = (talk_dir / value).resolve()
    try:
        return str(resolved.relative_to(ROOT))
    except ValueError:
        return value


def listing_for(talk_dir: Path) -> dict | None:
    entry: dict = {}

    # 1. Source-file front-matter (.qmd top-level OR .Rmd/.md with `listing:`).
    src = next(
        (talk_dir / n for n in ("index.qmd", "index.Rmd", "index.md")
         if (talk_dir / n).exists()),
        None,
    )
    if src is not None:
        fm = read_yaml_block(src) or {}
        if src.suffix == ".qmd":
            # qmd: listing fields at top level
            for k in LISTING_FIELDS:
                if k in fm:
                    entry[k] = fm[k]
        else:
            # .Rmd / .md: listing.* takes precedence; otherwise fall back to
            # the slide's top-level `title:` so simple cases just work.
            listing = fm.get("listing") or {}
            for k in LISTING_FIELDS:
                if k in listing:
                    entry[k] = listing[k]
            if "title" not in entry and "title" in fm:
                entry["title"] = fm["title"]

    # 2. Sidecar _listing.yml fills any still-missing field.
    sidecar = talk_dir / "_listing.yml"
    if sidecar.exists():
        for k, v in (read_yaml(sidecar) or {}).items():
            if k in LISTING_FIELDS and k not in entry:
                entry[k] = v

    # Required.
    if "title" not in entry or "date" not in entry:
        return None

    # Resolve a user-provided `path` relative to the talk folder, then
    # default to <folder>/index.html (already project-root-relative).
    if "path" in entry:
        entry["path"] = normalize_path_field(entry["path"], talk_dir)
    else:
        entry["path"] = f"{talk_dir.relative_to(ROOT)}/index.html"

    # Resolve image relative to the talk folder.
    if "image" in entry:
        entry["image"] = normalize_path_field(entry["image"], talk_dir)

    # Stable key order.
    return {k: entry[k] for k in
            ("title", "subtitle", "date", "image", "path", "categories")
            if k in entry}


def main() -> None:
    if not TALKS.exists():
        return
    entries = []
    skipped = []
    for d in sorted(TALKS.iterdir()):
        if not d.is_dir() or d.name in {"img", "libs"}:
            continue
        e = listing_for(d)
        if e is None:
            skipped.append(d.name)
        else:
            entries.append(e)

    entries.sort(key=lambda e: str(e.get("date", "")), reverse=True)

    OUT.write_text(
        yaml.safe_dump(entries, sort_keys=False, allow_unicode=True),
        encoding="utf-8",
    )
    print(f"[build_talks_listing] {len(entries)} entries → {OUT.name}"
          + (f" (skipped: {', '.join(skipped)})" if skipped else ""))


if __name__ == "__main__":
    main()
