#!/usr/bin/env python3
"""Generate a minimal PNG icon for My Time Tracker — pure stdlib, no PIL."""

import struct, zlib, math, os

def write_png(path, pixels, width, height):
    def pack_chunk(tag, data):
        c = zlib.crc32(tag + data) & 0xFFFFFFFF
        return struct.pack('>I', len(data)) + tag + data + struct.pack('>I', c)

    raw = b''
    for row in pixels:
        raw += b'\x00'  # filter type None
        for r, g, b, a in row:
            raw += bytes([r, g, b, a])
    compressed = zlib.compress(raw, 9)

    png = b'\x89PNG\r\n\x1a\n'
    png += pack_chunk(b'IHDR', struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
                      .replace(struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0),
                               struct.pack('>II', width, height) + bytes([8, 6, 0, 0, 0])))
    png += pack_chunk(b'IDAT', compressed)
    png += pack_chunk(b'IEND', b'')

    # rebuild properly
    signature = b'\x89PNG\r\n\x1a\n'
    ihdr_data = struct.pack('>II', width, height) + bytes([8, 6, 0, 0, 0])
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xFFFFFFFF
    idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xFFFFFFFF
    iend_crc = zlib.crc32(b'IEND') & 0xFFFFFFFF

    out = signature
    out += struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)
    out += struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)
    out += struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(out)

def lerp(a, b, t):
    return a + (b - a) * t

def clamp(v, lo=0, hi=255):
    return max(lo, min(hi, int(v)))

def make_icon(size):
    w = h = size
    pixels = []
    cx, cy = w / 2, h / 2
    r = w / 2

    for y in range(h):
        row = []
        for x in range(w):
            dx = x - cx
            dy = y - cy
            dist = math.sqrt(dx*dx + dy*dy)

            # Background gradient: deep indigo → violet
            t = (y / h) * 0.6 + (x / w) * 0.4
            bg_r = clamp(lerp(63,  100, t))
            bg_g = clamp(lerp(55,  40,  t))
            bg_b = clamp(lerp(201, 160, t))

            # Corner radius = 22.5% of size
            corner_r = r * 0.45
            # Rounded square SDF
            qx = abs(dx) - (r - corner_r)
            qy = abs(dy) - (r - corner_r)
            sdf = math.sqrt(max(qx,0)**2 + max(qy,0)**2) + min(max(qx,qy),0) - corner_r
            if sdf > 1.0:
                row.append((0, 0, 0, 0))
                continue

            bg_a = clamp(255 * max(0, 1 - max(sdf, 0)))

            pr, pg, pb = bg_r, bg_g, bg_b

            # Clock circle outline
            clock_r = r * 0.55
            clock_thickness = size * 0.055
            clock_dist = abs(dist - clock_r)
            in_clock = clock_dist < clock_thickness / 2

            # Clock hands
            angle = math.atan2(dy, dx)  # -π to π; 12 o'clock = -π/2

            # Hour hand: points toward ~10 o'clock (angle -π/2 - π/3 = -5π/6)
            def in_hand(target_angle, length, width_frac):
                hand_dx = math.cos(target_angle)
                hand_dy = math.sin(target_angle)
                proj = dx * hand_dx + dy * hand_dy
                perp = abs(dx * (-hand_dy) + dy * hand_dx)
                return 0 < proj < r * length and perp < r * width_frac

            hour_angle = -math.pi / 2 - math.pi / 3.5
            minute_angle = -math.pi / 2 + math.pi / 5

            in_hour = in_hand(hour_angle, 0.38, 0.06)
            in_minute = in_hand(minute_angle, 0.50, 0.045)

            # Center dot
            in_center = dist < r * 0.08

            # Play triangle (right side of clock, small)
            tri_cx = r * 0.0
            tri_cy = r * 0.0
            # skip play triangle for cleaner look

            # White elements
            if in_clock or in_hour or in_minute or in_center:
                # white with slight blue tint
                alpha_factor = 1.0
                if in_clock:
                    edge = clock_dist / (clock_thickness / 2)
                    alpha_factor = max(0, 1 - edge * edge)
                pr = clamp(lerp(pr, 255, 0.92 * alpha_factor))
                pg = clamp(lerp(pg, 255, 0.92 * alpha_factor))
                pb = clamp(lerp(pb, 255, 0.95 * alpha_factor))

            # Subtle inner glow at center
            glow = math.exp(-(dist / (r * 0.35))**2) * 0.18
            pr = clamp(pr + glow * 80)
            pg = clamp(pg + glow * 60)
            pb = clamp(pb + glow * 120)

            row.append((pr, pg, pb, bg_a))
        pixels.append(row)
    return pixels

base = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Icon.iconset")
os.makedirs(base, exist_ok=True)

sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes:
    px = make_icon(s)
    name = f"icon_{s}x{s}.png"
    write_png(f"{base}/{name}", px, s, s)
    # @2x variants
    if s <= 512:
        write_png(f"{base}/icon_{s}x{s}@2x.png", px, s, s)

# Rename to standard iconset names
import shutil
mapping = {
    "icon_16x16.png":      "icon_16x16.png",
    "icon_16x16@2x.png":   "icon_32x32.png",
    "icon_32x32.png":      "icon_32x32.png",
    "icon_32x32@2x.png":   "icon_64x64.png",
    "icon_128x128.png":    "icon_128x128.png",
    "icon_128x128@2x.png": "icon_256x256.png",
    "icon_256x256.png":    "icon_256x256.png",
    "icon_256x256@2x.png": "icon_512x512.png",
    "icon_512x512.png":    "icon_512x512.png",
    "icon_512x512@2x.png": "icon_1024x1024.png",
}

# Write with proper iconset naming
proper = {
    "icon_16x16.png":      16,
    "icon_16x16@2x.png":   32,
    "icon_32x32.png":      32,
    "icon_32x32@2x.png":   64,
    "icon_128x128.png":    128,
    "icon_128x128@2x.png": 256,
    "icon_256x256.png":    256,
    "icon_256x256@2x.png": 512,
    "icon_512x512.png":    512,
    "icon_512x512@2x.png": 1024,
}

for fname, sz in proper.items():
    px = make_icon(sz)
    write_png(f"{base}/{fname}", px, sz, sz)

print("Done:", os.listdir(base))
