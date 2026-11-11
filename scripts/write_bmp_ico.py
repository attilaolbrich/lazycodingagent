"""BMP-style branding outputs for LCL/fpImage (uncompressed BI_RGB / DIB)."""
from __future__ import annotations

import struct
import sys
from pathlib import Path

from PIL import Image


def _flatten_owl_rgba(png_path: Path) -> Image.Image:
    base = Image.open(png_path).convert("RGBA")
    bg = Image.new("RGBA", base.size, (8, 12, 24, 255))
    return Image.alpha_composite(bg, base)


def write_owl_icon_bmp(png_path: Path, bmp_path: Path, size: int = 128) -> None:
    im = _flatten_owl_rgba(png_path).resize((size, size), Image.Resampling.LANCZOS)
    w, h = im.size
    row_bytes = w * 4
    raw = im.tobytes("raw", "BGRA")
    rows = [raw[i * row_bytes : (i + 1) * row_bytes] for i in range(h)]
    rows.reverse()
    pixels = b"".join(rows)
    file_header = struct.pack("<2sIHHI", b"BM", 14 + 40 + len(pixels), 0, 0, 54)
    info_header = struct.pack(
        "<IIIHHIIIIII",
        40,
        w,
        h,
        1,
        32,
        0,
        len(pixels),
        0,
        0,
        0,
        0,
    )
    bmp_path.write_bytes(file_header + info_header + pixels)


def _dib_for_size(rgba: Image.Image, size: int) -> bytes:
    im = rgba.resize((size, size), Image.Resampling.LANCZOS)
    w, h = im.size
    row_bytes = w * 4
    raw = im.tobytes("raw", "BGRA")
    rows = [raw[i * row_bytes : (i + 1) * row_bytes] for i in range(h)]
    rows.reverse()
    xor_data = b"".join(rows)
    mask_row_bytes = ((w + 31) // 32) * 4
    and_mask = b"\x00" * (mask_row_bytes * h)
    header = struct.pack(
        "<IIIHHIIIIII",
        40,
        w,
        h * 2,
        1,
        32,
        0,
        len(xor_data) + len(and_mask),
        0,
        0,
        0,
        0,
    )
    return header + xor_data + and_mask


def write_bmp_ico(png_path: Path, ico_path: Path, sizes: tuple[int, ...] = (16, 32, 48)) -> None:
    flat = _flatten_owl_rgba(png_path)
    blobs = [_dib_for_size(flat, s) for s in sizes]
    count = len(blobs)
    header_size = 6 + 16 * count
    offset = header_size
    out = bytearray(struct.pack("<HHH", 0, 1, count))
    data = bytearray()
    for size, blob in zip(sizes, blobs):
        w = 0 if size >= 256 else size
        h = w
        out.extend(struct.pack("<BBBBHHII", w, h, 0, 0, 1, 32, len(blob), offset))
        offset += len(blob)
        data.extend(blob)
    ico_path.write_bytes(out + data)


def main() -> int:
    if len(sys.argv) < 3:
        print(
            "usage: write_bmp_ico.py <input.png> <output.ico|output.bmp> [bmp_size]",
            file=sys.stderr,
        )
        return 2
    src = Path(sys.argv[1])
    dst = Path(sys.argv[2])
    if dst.suffix.lower() == ".bmp":
        size = int(sys.argv[3]) if len(sys.argv) > 3 else 128
        write_owl_icon_bmp(src, dst, size)
    else:
        write_bmp_ico(src, dst)
    print(dst)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
