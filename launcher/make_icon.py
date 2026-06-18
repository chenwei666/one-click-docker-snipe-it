from __future__ import annotations

import struct
import zlib
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "app-icon.ico"


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_color.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha


def blend(dst: tuple[int, int, int, int], src: tuple[int, int, int, int]) -> tuple[int, int, int, int]:
    sr, sg, sb, sa = src
    dr, dg, db, da = dst
    a = sa / 255
    return (
        int(sr * a + dr * (1 - a)),
        int(sg * a + dg * (1 - a)),
        int(sb * a + db * (1 - a)),
        255,
    )


def draw_rounded_rect(img: list[list[tuple[int, int, int, int]]], x: int, y: int, w: int, h: int, r: int, color: tuple[int, int, int, int]) -> None:
    for py in range(y, y + h):
        for px in range(x, x + w):
            cx = min(max(px, x + r), x + w - r - 1)
            cy = min(max(py, y + r), y + h - r - 1)
            if (px - cx) ** 2 + (py - cy) ** 2 <= r ** 2:
                img[py][px] = blend(img[py][px], color)


def draw_circle(img: list[list[tuple[int, int, int, int]]], cx: int, cy: int, r: int, color: tuple[int, int, int, int]) -> None:
    for py in range(max(0, cy - r), min(len(img), cy + r + 1)):
        for px in range(max(0, cx - r), min(len(img[0]), cx + r + 1)):
            if (px - cx) ** 2 + (py - cy) ** 2 <= r ** 2:
                img[py][px] = blend(img[py][px], color)


def draw_line(img: list[list[tuple[int, int, int, int]]], x1: int, y1: int, x2: int, y2: int, width: int, color: tuple[int, int, int, int]) -> None:
    steps = max(abs(x2 - x1), abs(y2 - y1), 1)
    radius = max(width // 2, 1)
    for i in range(steps + 1):
        t = i / steps
        x = int(x1 + (x2 - x1) * t)
        y = int(y1 + (y2 - y1) * t)
        draw_circle(img, x, y, radius, color)


def make_png(size: int) -> bytes:
    scale = size / 256
    img = [[rgba("#000000", 0) for _x in range(size)] for _y in range(size)]

    def s(value: int) -> int:
        return int(round(value * scale))

    draw_rounded_rect(img, 0, 0, size, size, s(52), rgba("#2563eb"))
    draw_rounded_rect(img, s(52), s(62), s(112), s(88), s(14), rgba("#ffffff"))
    draw_rounded_rect(img, s(72), s(88), s(72), s(12), s(6), rgba("#93c5fd"))
    draw_rounded_rect(img, s(72), s(114), s(52), s(12), s(6), rgba("#93c5fd"))
    draw_rounded_rect(img, s(63), s(164), s(128), s(27), s(13), rgba("#dbeafe"))
    draw_circle(img, s(178), s(91), s(38), rgba("#10b981"))
    draw_line(img, s(160), s(91), s(172), s(103), s(13), rgba("#ffffff"))
    draw_line(img, s(172), s(103), s(197), s(74), s(13), rgba("#ffffff"))
    draw_line(img, s(70), s(190), s(186), s(190), s(14), rgba("#ffffff", 230))

    raw = bytearray()
    for row in img:
        raw.append(0)
        for pixel in row:
            raw.extend(pixel)

    compressed = zlib.compress(bytes(raw), 9)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0))
        + chunk(b"IDAT", compressed)
        + chunk(b"IEND", b"")
    )


def make_ico() -> None:
    OUT.parent.mkdir(parents=True, exist_ok=True)
    images = [(256, make_png(256)), (64, make_png(64)), (32, make_png(32)), (16, make_png(16))]
    offset = 6 + 16 * len(images)
    entries = []
    payload = bytearray()
    for size, data in images:
        width = 0 if size == 256 else size
        entries.append(struct.pack("<BBBBHHII", width, width, 0, 0, 1, 32, len(data), offset))
        payload.extend(data)
        offset += len(data)

    OUT.write_bytes(struct.pack("<HHH", 0, 1, len(images)) + b"".join(entries) + payload)
    print(OUT)


if __name__ == "__main__":
    make_ico()
