# Citation helper for xaringan slides.
#
# xaringan injects slide bodies via --include-after-body, so Pandoc citeproc
# never parses them. This helper reads a .bib file via `pandoc -t csljson`
# and exposes:
#   cite(key)        -> in-body citation, e.g.  Maus et al. (2024) <em>Nature</em>
#   bibliography()   -> ordered HTML list of all keys cited so far
#   has_citations()  -> TRUE if any cite() has been called

suppressPackageStartupMessages(library(jsonlite))

mtg_init_citations <- function(bib_path = "references.bib") {
  bib_json <- system2("pandoc", c(bib_path, "-t", "csljson"),
                      stdout = TRUE, stderr = TRUE)
  refs_list <- jsonlite::fromJSON(paste(bib_json, collapse = "\n"),
                                  simplifyVector = FALSE)
  .refs <<- setNames(refs_list, vapply(refs_list, function(r) r$id, character(1)))
  .cited <<- character(0)
  invisible(NULL)
}

.fmt_authors_short <- function(authors) {
  fams <- vapply(authors, function(a) a$family, character(1))
  n <- length(fams)
  if (n == 1) fams[1]
  else if (n == 2) paste(fams, collapse = " &amp; ")
  else paste0(fams[1], " et al.")
}

.fmt_authors_long <- function(authors) {
  parts <- vapply(authors, function(a) {
    given <- if (!is.null(a$given)) a$given else ""
    initials <- paste(vapply(strsplit(given, "[ -]")[[1]], function(g) {
      if (nchar(g) > 0) paste0(toupper(substr(g, 1, 1)), ".") else ""
    }, character(1)), collapse = " ")
    paste0(a$family, ", ", initials)
  }, character(1))
  n <- length(parts)
  if (n == 1) parts[1]
  else if (n == 2) paste0(parts[1], ", &amp; ", parts[2])
  else paste0(paste(parts[-n], collapse = ", "), ", &amp; ", parts[n])
}

.get_url <- function(ref) {
  if (!is.null(ref$URL) && nchar(ref$URL) > 0) return(ref$URL)
  if (!is.null(ref$DOI) && nchar(ref$DOI) > 0) return(paste0("https://doi.org/", ref$DOI))
  NA_character_
}

.get_year <- function(ref) {
  dp <- ref$issued$`date-parts`
  if (!is.null(dp)) as.character(dp[[1]][[1]]) else "n.d."
}

cite <- function(key) {
  ref <- .refs[[key]]
  if (is.null(ref)) {
    warning("Citation key not found: ", key)
    return(sprintf("[? %s]", key))
  }
  .cited <<- unique(c(.cited, key))
  authors <- .fmt_authors_short(ref$author)
  year <- .get_year(ref)
  journal <- if (!is.null(ref$`container-title`))
    sprintf("<em>%s</em>", ref$`container-title`) else ""
  text <- trimws(paste(authors, sprintf("(%s)", year), journal))
  url <- .get_url(ref)
  if (!is.na(url)) {
    sprintf('<a class="cite-link" href="%s" target="_blank" rel="noopener">%s</a>',
            url, text)
  } else {
    sprintf('<span class="cite-link">%s</span>', text)
  }
}

bibliography <- function() {
  if (length(.cited) == 0) return("")
  cited_refs <- .refs[.cited]
  cited_refs <- cited_refs[order(vapply(cited_refs,
                                        function(r) r$author[[1]]$family,
                                        character(1)))]
  entries <- vapply(cited_refs, function(ref) {
    authors <- .fmt_authors_long(ref$author)
    year <- .get_year(ref)
    title <- ref$title
    journal <- if (!is.null(ref$`container-title`))
      sprintf("<em>%s</em>", ref$`container-title`) else NULL
    vol <- if (!is.null(ref$volume)) ref$volume else NULL
    pages <- if (!is.null(ref$page)) ref$page else NULL
    journal_part <- paste(c(journal, vol, pages), collapse = ", ")
    url <- .get_url(ref)
    link_part <- if (!is.na(url))
      sprintf(' <a href="%s" target="_blank" rel="noopener">%s</a>', url, url)
    else ""
    note_part <- if (!is.null(ref$note)) sprintf(" %s.", ref$note) else ""
    sprintf('<div class="csl-entry">%s (%s). %s. %s.%s%s</div>',
            authors, year, title, journal_part, link_part, note_part)
  }, character(1))
  paste(entries, collapse = "\n")
}

has_citations <- function() length(.cited) > 0
