# mtg-slides

A clean, professional slide template for `xaringan` / `remark.js` decks, with
an equivalent Python build pipeline. Intended to be cloned into a website
repo at `assets/mtg-slides/` and used to scaffold new talks.

- 16:9 HTML slides rendered by remark.js (no plugins, no build step at
  serve time — just static HTML and CSS).
- One organized stylesheet (`lib/theme.css`) driven by CSS variables so a
  whole deck can be re-skinned by overriding 4 values in `custom.css`.
- Two starters with identical look:
  - `templates/rmd/` — knit with R / `rmarkdown::render()`.
  - `templates/python/` — render with `python build.py` (PyYAML +
    pandoc on PATH; no other deps).
- Vendored: each new talk gets its own snapshot of `lib/`, so future
  template updates do not break old talks.

## Quick start

```bash
# from the website repo root
./assets/mtg-slides/scripts/new-talk.sh talks/20260601-FOO        # rmd
./assets/mtg-slides/scripts/new-talk.sh talks/20260601-FOO python
```

Then edit `talks/20260601-FOO/index.Rmd` (or `index.md`) and render.

See [USAGE.md](USAGE.md) for the full guide.

## Folder structure

```
assets/mtg-slides/
├── README.md                    quick start (this file)
├── USAGE.md                     full usage guide
├── lib/                         shared template assets (vendored per talk)
│   ├── theme.css                main organized stylesheet (CSS variables)
│   ├── theme-fonts.css          google-font imports
│   ├── tachyons-min.css         atomic utility classes
│   ├── default.html             pandoc template (used by xaringan + build.py)
│   ├── remark-latest.min.js     remark.js library
│   ├── macros.js                ![:scale 60%] image macro etc.
│   ├── cite-helper.R            bib → in-body cites + refs slide (R path)
│   └── img/                     stable, talk-spanning illustrations
├── templates/
│   ├── rmd/                     starter Rmd talk
│   │   ├── index.Rmd
│   │   ├── references.bib
│   │   ├── custom.css           per-talk overrides slot
│   │   └── img/                 talk-specific images
│   └── python/                  starter Python talk (mirrors rmd)
│       ├── index.md             markdown body + YAML front matter
│       ├── build.py             Jinja-free wrapper around default.html
│       ├── figures.py           optional matplotlib/etc. figure generator
│       ├── references.bib
│       ├── custom.css
│       └── img/
├── examples/
│   └── minimal/                 4-slide demo
└── scripts/
    └── new-talk.sh              ./new-talk.sh <dir> [rmd|python]
```

## What a new talk looks like

```
talks/20260601-FOO/
├── index.Rmd          (or index.md + build.py)
├── references.bib
├── custom.css         talk-specific palette overrides + logos/photos
├── img/               talk-specific images
└── libs/              snapshot of mtg-slides/lib/ at scaffold time
```
