"""Generate figures for this talk.

build.py invokes this script (if it exists) before rendering index.html, so
any plt.savefig(...) below ends up in img/ and is referenced from index.md.

Edit freely — this is a starter. Delete the file if you don't generate
figures from Python.
"""

from pathlib import Path

IMG = Path(__file__).parent / "img"
IMG.mkdir(exist_ok=True)

# Example:
#
# import matplotlib.pyplot as plt
# fig, ax = plt.subplots(figsize=(8, 4.5))
# ax.plot([0, 1, 2], [0, 1, 4])
# fig.tight_layout()
# fig.savefig(IMG / "demo.png", dpi=150)
