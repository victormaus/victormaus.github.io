import requests
import os
import time
import re
import unicodedata 

# --- CONFIGURATION ---
ORCID_ID = "0000-0002-7385-4723"
ASSETS_DIR = "assets"
BIB_SUBDIR = os.path.join(ASSETS_DIR, "bib")
BIB_FILE = os.path.join(ASSETS_DIR, "publications_orcid.bib")
CACHE_DURATION_HOURS = 24

# Headers
orcid_headers = {"Accept": "application/vnd.orcid+json"}
doi_headers = {"Accept": "application/x-bibtex; charset=utf-8"}

# --- GENERIC LATEX MAPPING FOR BIBTEX PORTABILITY ---
LATEX_MAP = {
    # Accents (fixes generic accent issues)
    'á': r"{\'a}", 'Á': r"{\'A}", 'à': r"{\`a}", 'À': r"{\`A}", 'ã': r"{\~a}", 'Ã': r"{\~A}",
    'é': r"{\'e}", 'É': r"{\'E}", 'è': r"{\`e}", 'È': r"{\`E}",
    'í': r"{\'i}", 'Í': r"{\'I}",
    'ó': r"{\'o}", 'Ó': r"{\'O}", 'ò': r"{\`o}", 'Ò': r"{\`O}", 'õ': r"{\~o}", 'Õ': r"{\~O}",
    'ú': r"{\'u}", 'Ú': r"{\'U}", 'ù': r"{\`u}", 'Ù': r"{\`U}",
    'ä': r"{\"a}", 'Ä': r"{\"A}",
    'ö': r"{\"o}", 'Ö': r"{\"O}",
    'ü': r"{\"u}", 'Ü': r"{\"U}",
    'ñ': r"{\~n}", 'Ñ': r"{\~N}",
    'ç': r"{\c c}", 'Ç': r"{\c C}",
    # Dashes (fixes the 'â€“' misinterpretation issue)
    '–': r"--",    # En-dash
    '—': r"---",   # Em-dash
    # Punctuation/Symbols
    'ß': r"{\ss}",
    'º': r"^{\circ}", # Degree symbol
    # Ambiguous Ampersands (Only target the malformed ones)
    '&Amp;': r"{\&}",
    '&amp;': r"{\&}",
    # Quotes
    "“": "``",
    "”": "''",
    
    # --- NEW: TARGET THE VISIBLY CORRUPTED SEQUENCES DIRECTLY ---
    # The corrupted sequence 'Ã¢' is often produced by malformed UTF-8/ISO-8859-1 conversion.
    # We replace common corrupted sequences with their intended LaTeX/BibTeX equivalent.
    'Ã¢': r"{\^a}", # Corresponds to â or sometimes â€š
    'Ã©': r"{\'e}", # Corresponds to é
    'â€“': r"--",   # Directly replace the corrupted string 'â€“' with the en-dash equivalent
    'â€': r"---",   # Corresponds to a partial em-dash or other symbol
}

def ensure_directories():
    if not os.path.exists(BIB_SUBDIR):
        os.makedirs(BIB_SUBDIR)

def slugify(text):
    """
    Create a safe filename from a DOI. 
    """
    return re.sub(r'[^a-zA-Z0-9-_]', '_', text)

def cleanup_bibtex_entry(bib_text):
    """Applies generic character cleanup using LaTeX escape sequences."""
    # 1. Normalize the text
    safe_text = unicodedata.normalize('NFKC', bib_text)

    # 2. Apply LaTeX mapping to all characters
    for utf_char, latex_escape in LATEX_MAP.items():
        safe_text = safe_text.replace(utf_char, latex_escape)
        
    return safe_text


def main():
    ensure_directories()

    # Skip if output file is fresh (less than CACHE_DURATION_HOURS old)
    if os.path.exists(BIB_FILE):
        age_hours = (time.time() - os.path.getmtime(BIB_FILE)) / 3600
        if age_hours < CACHE_DURATION_HOURS:
            print(f"Cache is fresh ({age_hours:.1f}h old, limit {CACHE_DURATION_HOURS}h). Skipping ORCID fetch.")
            return

    print(f"Fetching publications for ORCID iD: {ORCID_ID}...")
    publications_to_process = []

    # 1. Fetch works (omitted for brevity)
    orcid_response = requests.get(f"https://pub.orcid.org/v3.0/{ORCID_ID}/works", headers=orcid_headers)
    orcid_response.raise_for_status()
    works_data = orcid_response.json()
    works = works_data.get("group", [])
    
    # 2. Extract DOIs (omitted for brevity)
    for work_group in works:
        if work_group is None:
            continue
        for work_summary in work_group.get("work-summary", []):
            if not work_summary:
                print("Skipping a None work_summary.")
                continue
            external_ids = work_summary.get("external-ids", {}).get("external-id", [])
            doi = None
            year = 0
            for ext_id in external_ids:
                if ext_id.get("external-id-type") == "doi":
                    doi = ext_id.get("external-id-value")
                    pub_date = work_summary.get("publication-date")
                    if pub_date and pub_date.get("year"):
                        year_val = pub_date["year"]["value"]
                        year = int(year_val) if year_val else 0
                    break
            if doi:
                # Append the entire work summary for more context
                publications_to_process.append(work_summary)
                break 
    
    # 3. Sort by publication year (descending)
    publications_to_process.sort(
        key=lambda x: (
            int(((x.get("publication-date") or {}).get("year") or {}).get("value") or 0)
        ),
        reverse=True
    )

    # 4. Download BibTeX
    final_bib_entries = []
    print(f"Downloading BibTeX for {len(publications_to_process)} publications...")
    
    for i, pub in enumerate(publications_to_process):
        doi_info = next((eid for eid in pub.get("external-ids", {}).get("external-id", []) if eid.get("external-id-type") == "doi"), None)
        if not doi_info:
            continue

        doi = doi_info.get("external-id-value")
        
        try:
            bib_response = requests.get(f"https://doi.org/{doi}", headers=doi_headers)
            bib_response.raise_for_status()
            
            try:
                bib_response.encoding = 'utf-8'
                raw_bib_text = bib_response.text.strip()
            except UnicodeDecodeError:
                bib_response.encoding = 'iso-8859-1'
                raw_bib_text = bib_response.text.strip()
                
            bib_text = cleanup_bibtex_entry(raw_bib_text)
            
            # Regex to find the key and append the counter
            # Matches '@Type{ExistingKey,' and replaces it with '@Type{ExistingKey_i,
            bib_text = re.sub(r'^(@\w+\{)([^,]+)', rf'\1\2_{len(publications_to_process)-i}', bib_text)

        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                print(f"  DOI {doi} not found. Fetching full metadata from ORCID...")
                
                work_path = pub.get("path")
                if not work_path:
                    print(f"  Could not find work path for {doi}. Skipping.")
                    continue

                try:
                    # Fetch the full work details from ORCID
                    work_response = requests.get(f"https://pub.orcid.org{work_path}", headers=orcid_headers)
                    work_response.raise_for_status()
                    work_data = work_response.json()
                    
                    title = work_data.get("title", {}).get("title", {}).get("value", "No title")
                    year = work_data.get("publication-date", {}).get("year", {}).get("value", "N.A.")
                    journal = work_data.get("journal-title", {}).get("value", "N.A.")

                    # Extract and format authors
                    authors = []
                    contributors = work_data.get("contributors", {}).get("contributor", [])
                    for contributor in contributors:
                        credit_name = contributor.get("credit-name", {}).get("value")
                        if credit_name:
                            authors.append(credit_name)
                    
                    author_str = " and ".join(authors)

                    slug_title = slugify(title)[:50]
                    bib_key = f"{slugify(author_str.split(' ')[0])}_{year}"
                    
                    bib_text = f"""@article{{{bib_key},
title = {{{title}}},
author = {{{author_str}}},
journal = {{{journal}}},
year = {{{year}}}
}}"""
                except Exception as work_e:
                    print(f"  Failed to fetch full ORCID data for {doi}: {work_e}")
                    # Fallback to the simpler placeholder if full metadata fetch fails
                    title = pub.get("title", {}).get("title", {}).get("value", "No title")
                    year = pub.get("publication-date", {}).get("year", {}).get("value", "N.A.")
                    url = pub.get("url", {}).get("value")
                    slug_title = slugify(title)[:50]
                    bib_key = f"placeholder_{slug_title}_{year}"
                    bib_text = f"""@misc{{{bib_key},
title = {{{title}}},
author = {{Maus, Victor and others}},
year = {{{year}}},
howpublished = {{\\url{{{url}}}}},
note = {{DOI: {doi} (not yet registered)}}
}}"""

            else:
                print(f"  Failed {doi}: {e}")
                continue
        
        # Save individual file using slugified DOI
        slug = slugify(doi)
        individual_path = os.path.join(BIB_SUBDIR, f"{slug}.bib")
        with open(individual_path, "w", encoding="utf-8") as f:
            f.write(bib_text)
        
        final_bib_entries.append(bib_text)
        time.sleep(0.2)

    # 5. Save master file
    with open(BIB_FILE, "w", encoding="utf-8") as f:
        f.write("\n\n".join(final_bib_entries))
    print(f"Done! Saved to {BIB_FILE}")

if __name__ == "__main__":
    main()