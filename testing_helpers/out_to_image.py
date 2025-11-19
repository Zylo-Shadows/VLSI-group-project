#!/usr/bin/env python3
import argparse, re
from pathlib import Path
from PIL import Image

W = H = 250
N = W * H

def read_hex(path: Path) -> bytes:
    """Read Verilog-style hex with comments and optional @addr directives."""
    vals = [0] * N                # pre-alloc; we'll fill sequentially or by address
    use_addr = False
    addr = 0
    filled = 0

    with path.open("r") as f:
        for line in f:
            # strip comments
            s = line.split("//", 1)[0].strip()
            if not s:
                continue

            # address directive like @0010
            if s.startswith("@"):
                addr = int(s[1:], 16)
                use_addr = True
                continue

            # extract all hex tokens on the line
            tokens = re.findall(r"[0-9A-Fa-f]+", s)
            for tok in tokens:
                b = int(tok, 16) & 0xFF
                if use_addr:
                    if addr >= N:
                        raise ValueError(f"Address {addr} out of range (N={N})")
                    vals[addr] = b
                    addr += 1
                    filled = max(filled, addr)
                else:
                    if filled >= N:
                        raise ValueError(f"Too many data bytes; N={N}")
                    vals[filled] = b
                    filled += 1

    if filled < N:
        # If your DUT legitimately outputs fewer than N values, adjust N/W/H.
        # Otherwise this is an error in the dump.
        raise ValueError(f"Expected {N} bytes, got {filled}")

    return bytes(vals)

def read_raw(path: Path) -> bytes:
    data = path.read_bytes()
    if len(data) != N:
        raise ValueError(f"Expected {N} bytes, got {len(data)}")
    return data

def main():
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group(required=True)
    g.add_argument("--hex", type=Path, help="Input hex file ($writememh-style)")
    g.add_argument("--raw", type=Path, help="Input raw file (exactly 250*250 bytes)")
    ap.add_argument("--png", type=Path, default=Path("convolved.png"),
                    help="Output PNG path (default: convolved.png)")
    args = ap.parse_args()

    data = read_hex(args.hex) if args.hex else read_raw(args.raw)
    img = Image.frombytes("L", (W, H), data)
    img.save(args.png)
    print(f"Wrote {args.png}")

if __name__ == "__main__":
    main()
