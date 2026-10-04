"""Writes CREDITS.txt for a release zip from the "Kullanılanlar (krediler)" table in docs/ASSETS.md.

Usage: python tools/ci/make_credits.py OUT_FILE
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main() -> None:
    text = (ROOT / "docs" / "ASSETS.md").read_text(encoding="utf-8")
    section = text.split("## Kullanılanlar (krediler)", 1)[1]
    lines = ["SFB:GO - third-party assets", ""]
    for row in section.splitlines():
        cells = [c.strip() for c in row.strip().strip("|").split("|")]
        if len(cells) != 5 or cells[0] in ("Asset", "---"):
            continue
        name, _, source, author, license_name = cells
        link = re.search(r"\((https?://[^)]+)\)", source)
        lines.append(f"{name} - {author} - {license_name}" + (f" - {link.group(1)}" if link else ""))
    Path(sys.argv[1]).write_text("\n".join(lines) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
