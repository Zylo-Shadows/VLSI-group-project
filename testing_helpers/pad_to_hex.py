#!/usr/bin/env python3
"""
pad_to_hex.py

Reads a 250x250 image, converts to 8-bit grayscale, zero-pads by 1 pixel
on all sides (-> 252x252), and writes a HEX file suitable for $readmemh:

  p_input_252x252.hex   # one byte per line, lowercase hex

Also writes a quick visual sanity check:
  padded_preview.png

Usage:
  python3 pad_to_hex.py <input_image>
Optional:
  --hex <path>    (default: p_input_252x252.hex)
  --preview <png> (default: padded_preview.png)
"""
import argparse
from pathlib import Path
from PIL import Image, ImageOps

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("input_image", help="Path to a 250x250 image")
    ap.add_argument("--hex", default="p_input_252x252.hex", help="Output HEX file path")
    ap.add_argument("--preview", default="padded_preview.png", help="Preview PNG path")
    args = ap.parse_args()

    in_path = Path(args.input_image)
    if not in_path.exists():
        raise SystemExit(f"Input file not found: {in_path}")

    # Load, force 8-bit grayscale
    img = Image.open(in_path).convert("L")
    if img.size != (250, 250):
        raise SystemExit(f"Expected 250x250, got {img.size} from {in_path}")

    # Zero-pad to 252x252
    padded = ImageOps.expand(img, border=1, fill=0)
    assert padded.size == (252, 252), padded.size

    # Write HEX (one byte per line)
    data = padded.tobytes()  # row-major
    with open(args.hex, "w") as f:
        for b in data:
            f.write(f"{b:02x}\n")

    # Save preview
    padded.save(args.preview)

    print(f"Wrote {args.hex} with {len(data)} lines")
    print(f"Wrote {args.preview}")

if __name__ == "__main__":
    main()
