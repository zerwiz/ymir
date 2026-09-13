#!/usr/bin/env python3
"""Generate Sessrúmnir desktop icons from icon.svg — the Ymir emblem.

The source is `icon.svg` (the Ymir root mark: Algiz rising from an anvil, cyan on
slate). Do not embed the artwork here; edit the SVG.
"""

from pathlib import Path
import subprocess

ICON_DIR = Path(__file__).resolve().parent
OUTPUT_SIZES = [16, 32, 48, 64, 128, 256, 512]


def svg_to_png(svg_path: Path, size: int, out_path: Path) -> None:
    """Convert SVG to PNG using ImageMagick."""
    subprocess.run(
        ["convert", "-background", "none", "-density", "300",
         f"{svg_path}", "-resize", f"{size}x{size}", str(out_path)],
        check=True, capture_output=True,
    )


def main() -> None:
    svg_path = ICON_DIR / "icon.svg"
    if not svg_path.exists():
        raise SystemExit(f"missing source {svg_path}")
    print("Generating Sessrúmnir icons from icon.svg (Ymir emblem)...")
    for size in OUTPUT_SIZES:
        out_path = ICON_DIR / f"icon-{size}.png"
        svg_to_png(svg_path, size, out_path)
        print(f"  ok {out_path.name} ({size}×{size})")
    (ICON_DIR / "icon.png").write_bytes((ICON_DIR / "icon-512.png").read_bytes())
    print("  ok icon.png")


if __name__ == "__main__":
    main()
