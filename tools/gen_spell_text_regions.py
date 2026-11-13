#!/usr/bin/env python3
"""Regenerate scripts/spell_text_regions.gd from the spell card images.

The rules text on each card is baked into its PNG, so to highlight the words
for one level the game needs to know where those words are. This script OCRs
every card used in scripts/spell_data.gd (tesseract word boxes) and splits
the text box into segments:

  pre    -- text before the first level line ("The opponent who ... pays you:")
  levels -- one entry per level line, in card order, including its circled
            level badge ("(2): $200.")
  post   -- text after the last level that isn't a wrapped continuation of
            it (Tax Haven's "(You no longer pay ...)")

The trailing ":" of a segment is trimmed (it introduces the levels, it isn't
part of the effect); a sentence's closing "." stays highlighted with it. Rects are stored normalized to the card size (0-1), so
they scale with however large the card is drawn.

Requirements: tesseract on PATH, and `pip install pillow`.
Run from the repo root:  python3 tools/gen_spell_text_regions.py
"""
import os
import re
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "scripts", "spell_text_regions.gd")
SCALE = 4
# The rules text box at the card's native 375 x 523 size.
X0, Y0, X1, Y1 = 28, 322, 348, 475
# Level lines start a little right of normal lines (the circled badge).
LEVEL_LINE_MIN_X = 38.5
PAD = 1.0


def spell_icons():
    """[(spell_name, res_path, [level keys in order])] from spell_data.gd."""
    src = open(os.path.join(ROOT, "scripts", "spell_data.gd"), encoding="utf-8").read()
    out = []
    for m in re.finditer(r'^\t"([^"]+)": \{\n(.*?)^\t\},', src, re.S | re.M):
        body = m.group(2)
        icon = re.search(r'"icon": "([^"]+)"', body).group(1)
        levels = [int(k) for k in re.findall(r'^\t\t\t(\d+): \{', body, re.M)]
        out.append((m.group(1), icon, levels))
    return out


def ocr_lines(png_path):
    gray = Image.open(png_path).convert("L")
    crop = gray.crop((X0, Y0, X1, Y1)).resize(((X1 - X0) * SCALE, (Y1 - Y0) * SCALE), Image.LANCZOS)
    with tempfile.NamedTemporaryFile(suffix=".png", delete=False) as f:
        crop.save(f.name)
        tsv = subprocess.run(["tesseract", f.name, "-", "--psm", "6", "tsv"],
                             capture_output=True, text=True, check=True).stdout
    os.unlink(f.name)
    lines = {}
    for row in tsv.splitlines()[1:]:
        c = row.split("\t")
        if len(c) < 12 or c[0] != "5" or not c[11].strip():
            continue
        l, t, w, h = (int(v) for v in c[6:10])
        lines.setdefault((int(c[2]), int(c[3]), int(c[4])), []).append({
            "text": c[11], "px": (l, t, w, h),
            "x": X0 + l / SCALE, "y": Y0 + t / SCALE, "w": w / SCALE, "h": h / SCALE,
        })
    ordered = sorted(lines.values(), key=lambda ws: ws[0]["y"])
    ordered = [ws for ws in ordered if any(ch.isalnum() or ch == "$" for w in ws for ch in w["text"])]
    for i, ws in enumerate(ordered):
        for w in ws:
            w["line"] = i
    return crop, ordered


def trim_trailing_punct(word, crop):
    """Drop a trailing ':' from the word's box by finding its glyph cluster in
    the upscaled crop. (A '.' ends the effect's sentence, so it's kept.)"""
    if not word["text"] or word["text"][-1] != ":":
        return word
    l, t, w, h = word["px"]
    cols = []
    for x in range(l, l + w):
        cols.append(any(crop.getpixel((x, y)) < 110 for y in range(t, t + h)))
    # Rightmost dark cluster = the punctuation; cut just left of the gap before it.
    x = len(cols) - 1
    while x >= 0 and not cols[x]:
        x -= 1
    right = x
    while x >= 0 and cols[x]:
        x -= 1
    if right - x > 0.3 * h:
        # Too wide for a lone '.' / ':' -- it's touching the letter before
        # it (e.g. "if:"), so just cut a punctuation-sized slice instead.
        new = dict(word)
        new["w"] = (right + 1 - 0.2 * h) / SCALE
        return new
    while x >= 0 and not cols[x]:
        x -= 1
    if x <= 0:
        return word
    new = dict(word)
    new["w"] = (x + 1) / SCALE
    return new


def badge_box(ws, crop):
    """A pseudo-word covering the whole circled badge at the start of a level
    line -- the OCR box only covers the digit, not the grey circle around it."""
    first = ws[0]
    l, t, w, h = first["px"]
    x_lo = max(0, int((34 - X0) * SCALE))      # stay clear of the text box frame
    # About one circle-width: the badge can be OCR'd merged with the text
    # after it ("2:7."), and that text mustn't count as badge.
    x_hi = min(crop.width, l + min(w, h))
    y_lo = max(0, t - 4 * SCALE)
    y_hi = min(crop.height, t + h + 4 * SCALE)
    xs, ys = [], []
    for y in range(y_lo, y_hi):
        for x in range(x_lo, x_hi):
            if crop.getpixel((x, y)) <= 232:
                xs.append(x)
                ys.append(y)
    if len(xs) < 20:
        return None
    xs.sort()
    ys.sort()
    # Trim a couple of stray texture pixels off each end.
    k = max(1, len(xs) // 200)
    x0, x1, y0, y1 = xs[k], xs[-k - 1], ys[k], ys[-k - 1]
    return {"text": "", "line": first["line"], "x": X0 + x0 / SCALE, "y": Y0 + y0 / SCALE,
            "w": (x1 - x0 + 1) / SCALE, "h": (y1 - y0 + 1) / SCALE}


def line_rects(words):
    """One rect per line (the words of a segment on that line merged)."""
    by_line = {}
    for w in words:
        by_line.setdefault(w["line"], []).append(w)
    rects = []
    for ws in by_line.values():
        x0 = min(w["x"] for w in ws) - PAD
        y0 = min(w["y"] for w in ws) - PAD
        x1 = max(w["x"] + w["w"] for w in ws) + PAD / 2  # tight: periods sit close
        y1 = max(w["y"] + w["h"] for w in ws) + PAD
        rects.append((x0, y0, x1 - x0, y1 - y0))
    return sorted(rects, key=lambda r: r[1])


def segment(lines, crop):
    pre, levels, post = [], [], []
    prev_text = ""
    for ws in lines:
        # A line after the levels continues the last level unless the line
        # before it finished a sentence -- then it's separate post-text.
        sentence_done = prev_text.rstrip().endswith((".", ")"))
        prev_text = ws[-1]["text"]
        if ws[0]["x"] >= LEVEL_LINE_MIN_X:
            # Keep the whole line, badge included, and widen it to the badge's
            # full circle (badge_box goes first so trimming still hits the
            # line's real last word).
            badge = badge_box(ws, crop)
            levels.append([([badge] if badge else []) + list(ws)])
        elif levels and not post and not sentence_done:
            levels[-1].append(ws)
        elif levels:
            post.append(ws)
        else:
            pre.append(ws)

    def words_of(seg_lines):
        words = [w for ws in seg_lines for w in ws]
        if words:
            words[-1] = trim_trailing_punct(words[-1], crop)
        return words

    return (line_rects(words_of(pre)),
            [line_rects(words_of(l)) for l in levels],
            line_rects(words_of(post)))


def gd_rects(rects, size):
    w, h = size
    return "[" + ", ".join("Rect2(%.4f, %.4f, %.4f, %.4f)" % (x / w, y / h, rw / w, rh / h)
                           for x, y, rw, rh in rects) + "]"


def main():
    out = [
        "class_name SpellTextRegions",
        "extends RefCounted",
        "",
        "# GENERATED by tools/gen_spell_text_regions.py -- don't edit by hand; rerun",
        "# it after changing any card image.",
        "#",
        "# Card icon path -> where its rules text sits on the image, as Rect2s",
        "# normalized to the card size (0-1): \"pre\" (text before the levels),",
        "# \"levels\" (level key -> that level's text, badge included) and \"post\"",
        "# (text after the levels). Highlighting pre + one level + post spells out",
        "# that level's full effect.",
        "const REGIONS: Dictionary = {",
    ]
    problems = []
    for name, icon, level_keys in spell_icons():
        path = os.path.join(ROOT, icon.replace("res://", ""))
        size = Image.open(path).size
        crop, lines = ocr_lines(path)
        pre, levels, post = segment(lines, crop)
        if len(levels) != len(level_keys):
            problems.append("%s: card shows %d levels, spell_data has %d" % (name, len(levels), len(level_keys)))
        for key, rects in zip(level_keys, levels):
            if not rects:
                problems.append("%s: no text found for level %d" % (name, key))
        out.append('\t"%s": {' % icon)
        out.append('\t\t"pre": %s,' % gd_rects(pre, size))
        out.append('\t\t"levels": {')
        for key, rects in zip(level_keys, levels):
            out.append("\t\t\t%d: %s," % (key, gd_rects(rects, size)))
        out.append("\t\t},")
        out.append('\t\t"post": %s,' % gd_rects(post, size))
        out.append("\t},")
    out.append("}")
    out.append("")
    open(OUT, "w", encoding="utf-8").write("\n".join(out))
    print("Wrote", os.path.relpath(OUT, ROOT))
    for p in problems:
        print("WARNING:", p, file=sys.stderr)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
