"""Make a dark-theme copy of a PDF by remapping its RGB colours (text stays vector and selectable).

Built for the ReportLab-generated guides in docs/ (plain `rg`/`RG`/`g`/`G` colour operators, no images).

    python scripts/pdf/make-dark.py docs/Laptop-Kubernetes-Guide.pdf            # -> docs/Laptop-Kubernetes-Guide_dark_mode.pdf
    python scripts/pdf/make-dark.py in.pdf out.pdf

Mapping (hue is kept, lightness is flipped):
- page background                  -> near-black
- text: dark/grey -> light, coloured -> lighter tint, white text (sits on accent blocks) stays white
- fills/strokes: white and light tints -> dark tints, saturated accent blocks stay (slightly dimmed),
  blocks that were already dark (code boxes) stay dark
"""
import colorsys
import re
import sys
from pathlib import Path

from pypdf import PdfReader, PdfWriter
from pypdf.generic import DecodedStreamObject

PAGE_BG = (0.071, 0.086, 0.110)  # #12161c

NUM = r"[-+]?(?:\d+\.?\d*|\.\d+)"
TOKEN = re.compile(
    rf"(?P<str>\((?:\\.|[^\\)])*\))"  # string literal: passed through untouched
    rf"|(?P<op>\bBT\b|\bET\b|\bq\b|\bQ\b)"
    rf"|(?P<r>{NUM})\s+(?P<g>{NUM})\s+(?P<b>{NUM})\s+(?P<rgb>rg|RG)\b"
    rf"|(?P<grey>{NUM})\s+(?P<gop>g|G)\b"
)


def clamp(x):
    return max(0.0, min(1.0, x))


def remap(rgb, in_text):
    h, l, s = colorsys.rgb_to_hls(*rgb)
    accent = s > 0.35 and 0.18 < l < 0.72
    if in_text:
        if l > 0.85:  # white text on an accent block
            l2, s2 = 0.97, s
        elif accent:  # coloured headings / inline code
            l2, s2 = 0.72, min(s, 0.75)
        else:  # body and muted text
            l2, s2 = clamp(0.92 - l * 0.45), s
    else:
        if accent:  # header bands, badges, accent bars
            l2, s2 = l * 0.85, s * 0.9
        elif l < 0.35:  # blocks that are already dark (e.g. code boxes): keep dark, just above the page
            l2, s2 = 0.11 + l * 0.35, s
        else:  # backgrounds, table rows, borders, rules
            l2, s2 = clamp(0.075 + (1 - l) * 0.55), s * 0.6
    return colorsys.hls_to_rgb(h, l2, s2)


def fmt(rgb):
    return " ".join(f"{c:.4f}".rstrip("0").rstrip(".") or "0" for c in rgb)


def transform(content):
    """Remap colours. A fill colour is often set outside BT and then used for text, so the original fill colour
    is tracked (with the q/Q stack) and re-emitted with the text mapping after BT, and the shape mapping after ET."""
    in_text = False
    fill = (0.0, 0.0, 0.0)  # PDF default fill colour
    stack = []

    def sub(m):
        nonlocal in_text, fill
        if m.group("str"):
            return m.group("str")
        op = m.group("op")
        if op == "q":
            stack.append(fill)
        elif op == "Q":
            fill = stack.pop() if stack else fill
        elif op == "BT":
            in_text = True
            return f"BT {fmt(remap(fill, True))} rg"
        elif op == "ET":
            in_text = False
            return f"ET {fmt(remap(fill, False))} rg"
        if op:
            return op
        if m.group("rgb"):
            rgb, kind = tuple(float(m.group(k)) for k in "rgb"), m.group("rgb")
        else:
            grey = float(m.group("grey"))
            rgb, kind = (grey, grey, grey), ("rg" if m.group("gop") == "g" else "RG")
        if kind == "rg":
            fill = rgb
        return f"{fmt(remap(rgb, in_text))} {kind}"

    return TOKEN.sub(sub, content)


def main(src, dst):
    writer = PdfWriter(clone_from=PdfReader(src))
    for page in writer.pages:
        box = page.mediabox
        body = transform(page.get_contents().get_data().decode("latin-1"))
        bg = f"q {fmt(PAGE_BG)} rg {box.left} {box.bottom} {box.width} {box.height} re f Q\n"
        stream = DecodedStreamObject()
        stream.set_data((bg + body).encode("latin-1"))
        page.replace_contents(stream)
        page.compress_content_streams()
    with open(dst, "wb") as f:
        writer.write(f)
    print(f"{src} -> {dst}")


if __name__ == "__main__":
    if len(sys.argv) not in (2, 3):
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    main(src, Path(sys.argv[2]) if len(sys.argv) == 3 else src.with_name(src.stem + "_dark_mode.pdf"))
