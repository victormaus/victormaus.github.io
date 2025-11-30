import os
import re
import shutil

# --- CONFIGURATION ---
def slugify(text):
    # slugify is no longer used but kept for completeness
    return re.sub(r'[^a-zA-Z0-9-_]', '_', text)

def find_output_file():
    # Check standard Quarto output directory (_site) first
    site_path = os.path.join("_site", "publications.html")
    if os.path.exists(site_path):
        return site_path
    
    # Check current directory
    local_path = "publications.html"
    if os.path.exists(local_path):
        return local_path
        
    return None

def copy_bib_assets(output_html_path):
    src_dir = os.path.join("assets", "bib")
    
    if not os.path.exists(src_dir):
        print(f"Warning: Source directory {src_dir} does not exist. Skipping copy.")
        return

    output_dir = os.path.dirname(output_html_path)
    dest_dir = os.path.join(output_dir, "assets", "bib")

    if os.path.abspath(src_dir) == os.path.abspath(dest_dir):
        return

    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)

    count = 0
    for filename in os.listdir(src_dir):
        if filename.endswith(".bib"):
            s = os.path.join(src_dir, filename)
            d = os.path.join(dest_dir, filename)
            shutil.copy2(s, d)
            count += 1
            
    if count > 0:
        print(f"Post-process: Copied {count} .bib files to {dest_dir}")

def process_content(content):
    entry_pattern = re.compile(
        r'(<div[^>]*class="[^"]*\bcsl-entry\b[^"]*"[^>]*>)(.*?)(</div>)', 
        re.DOTALL | re.IGNORECASE
    )
    
    def modify_entry(entry_match):
        div_start = entry_match.group(1)
        entry_content = entry_match.group(2)
        div_end = entry_match.group(3)
        
        # --- STEP 1: Bold Author Name ---
        # This remains, as it's the only remaining modification.
        entry_content = re.sub(r'Maus(?![^<]*>)', '<strong>Maus</strong>', entry_content)

        # --- STEP 2: The link insertion logic is removed entirely ---
        
        return f"{div_start}{entry_content}{div_end}"

    new_content = entry_pattern.sub(modify_entry, content)
    return new_content

def main():
    file_path = find_output_file()
    if not file_path:
        print("Post-process: 'publications.html' not found. Skipping.")
        return

    print(f"Post-processing {file_path}...")
    
    with open(file_path, "r", encoding="utf-8") as f:
        content = f.read()

    new_content = process_content(content)
    
    if new_content != content:
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(new_content)
        print("Post-process: Successfully updated publications HTML.")
    else:
        print("Post-process: No HTML changes made.")

    # The bib asset copying remains, as it's still useful.
    copy_bib_assets(file_path)

if __name__ == "__main__":
    main()