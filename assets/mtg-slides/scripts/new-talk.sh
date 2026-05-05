#!/usr/bin/env bash
# Scaffold a new talk from the mtg-slides template.
#
#   ./scripts/new-talk.sh <target-dir> [rmd|python]
#
# Examples:
#   ./scripts/new-talk.sh talks/20260601-FOO            # defaults to rmd
#   ./scripts/new-talk.sh talks/20260601-FOO python
#
# Vendors a snapshot of lib/ into <target-dir>/libs/ so the talk is fully
# self-contained: future template updates won't break it.

set -euo pipefail

if [ $# -lt 1 ]; then
  echo "Usage: $0 <target-dir> [rmd|python]" >&2
  exit 1
fi

TARGET="$1"
LANG_KIND="${2:-rmd}"
TEMPLATE_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

case "$LANG_KIND" in
  rmd|python) ;;
  *)
    echo "Error: language must be 'rmd' or 'python' (got '$LANG_KIND')" >&2
    exit 1 ;;
esac

if [ -e "$TARGET" ]; then
  echo "Error: $TARGET already exists; refusing to overwrite." >&2
  exit 1
fi

mkdir -p "$TARGET"
cp -r "$TEMPLATE_ROOT/templates/$LANG_KIND/." "$TARGET/"
mkdir -p "$TARGET/libs"
cp -r "$TEMPLATE_ROOT/lib/." "$TARGET/libs/"

echo "✓ Scaffolded $TARGET ($LANG_KIND flavor)"
echo "  - edit $TARGET/$([ "$LANG_KIND" = rmd ] && echo index.Rmd || echo index.md)"
echo "  - drop talk-specific images into $TARGET/img/"
echo "  - tweak $TARGET/custom.css for talk-specific positioning/branding"
if [ "$LANG_KIND" = rmd ]; then
  echo "  - render: Rscript -e 'rmarkdown::render(\"$TARGET/index.Rmd\")'"
else
  echo "  - render: cd $TARGET && python build.py"
fi
