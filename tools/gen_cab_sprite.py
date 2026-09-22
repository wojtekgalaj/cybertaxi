#!/usr/bin/env python3
"""Render the cyber-cab drone spritesheet.

Each heading is redrawn: the nose, belly, rotors, and flame are real geometry
at that angle, not a rotated copy of one bitmap. Lighting and rotor downwash
stay oriented to the screen, the way F-Zero's machine sprites do.

Sheet layout (keep in sync with scripts/player/cyber_cab.gd):
  FRAME  = 80
  ANGLES = 36     # 10 degrees per row. 0 = nose right, 90 = nose up.
  ANIM   = 4      # rotor / lamp / flame cycle
  hframes = 8     # columns 0-3 empty cabin, 4-7 passenger aboard
  vframes = 36
"""

from __future__ import annotations

import math
import os
from typing import List, Optional, Sequence, Tuple

from PIL import Image

FRAME = 80
ANGLES = 36
ANIM = 4
STEP_DEG = 360.0 / ANGLES
SCALE = 1.42
# Oblique shift so the near rotor sits above the far one (a slight top view).
OBL_X = 0.22
OBL_Y = 0.50

Color = Tuple[int, int, int]
RGBA = Tuple[int, int, int, int]

# Night-sky friendly. Close to the original cab cyan, with a warm cabin.
HULL = (46, 206, 220)
HULL_LIT = (158, 246, 252)
HULL_DARK = (14, 72, 112)
BELLY = (8, 36, 70)
MECH = (32, 52, 82)
MECH_LIT = (96, 128, 162)
OUTLINE = (6, 8, 16)
SKID = (168, 178, 192)
YELLOW = (255, 208, 48)
YELLOW_DIM = (156, 96, 28)
BLACK = (16, 18, 28)
SKIN = (255, 206, 168)
SKIN_SH = (196, 124, 96)
SUIT = (44, 64, 138)
VISOR = (28, 236, 232)
HAIR = (255, 96, 176)
HAIR_DK = (176, 40, 112)
SHIRT = (64, 84, 168)
FLAME_OUT = (255, 86, 32)
FLAME = (255, 168, 40)
FLAME_HOT = (255, 248, 214)
BLADE = (232, 250, 255)
HUB = (110, 255, 244)
DISC = (8, 14, 28)
RING = (28, 150, 176)
NOSE = (236, 255, 255)
WASH = ((120, 255, 236), (36, 190, 196), (12, 96, 120))
GLOW = (255, 156, 64)


class Canvas:
    def __init__(self) -> None:
        self.px: List[RGBA] = [(0, 0, 0, 0)] * (FRAME * FRAME)
        self.gid: List[int] = [0] * (FRAME * FRAME)
        self._next = 1

    def new_group(self) -> int:
        gid = self._next
        self._next += 1
        return gid

    def _i(self, x: int, y: int) -> int:
        return y * FRAME + x

    def plot(self, x: int, y: int, color: Color, gid: int) -> None:
        if 0 <= x < FRAME and 0 <= y < FRAME:
            i = self._i(x, y)
            self.px[i] = (color[0], color[1], color[2], 255)
            self.gid[i] = gid

    def get(self, x: int, y: int) -> RGBA:
        if 0 <= x < FRAME and 0 <= y < FRAME:
            return self.px[self._i(x, y)]
        return (0, 0, 0, 0)

    def stroke(self, gid: int, color: Color = OUTLINE) -> None:
        """1px external crease on this group, including where it meets another."""
        src_g = self.gid[:]
        src_p = self.px[:]
        for y in range(FRAME):
            for x in range(FRAME):
                i = self._i(x, y)
                if src_g[i] != gid:
                    continue
                edge = False
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + dx, y + dy
                    if not (0 <= nx < FRAME and 0 <= ny < FRAME) or src_g[self._i(nx, ny)] != gid:
                        edge = True
                        break
                if edge:
                    self.px[i] = (color[0], color[1], color[2], 255)
                    self.gid[i] = gid
        del src_p

    def image(self) -> Image.Image:
        img = Image.new("RGBA", (FRAME, FRAME))
        img.putdata(self.px)
        return img


def to_screen(mx: float, my: float, mz: float, heading: float) -> Tuple[float, float]:
    h = math.radians(heading)
    c, s = math.cos(h), math.sin(h)
    rx = mx * c - my * s
    ry = mx * s + my * c
    sx = FRAME * 0.5 + rx * SCALE + mz * OBL_X
    sy = FRAME * 0.5 - ry * SCALE - mz * OBL_Y
    return sx, sy


def _dist_point_seg(px: float, py: float, x0: float, y0: float, x1: float, y1: float) -> float:
    dx, dy = x1 - x0, y1 - y0
    l2 = dx * dx + dy * dy
    if l2 < 1e-8:
        return math.hypot(px - x0, py - y0)
    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / l2))
    return math.hypot(px - (x0 + t * dx), py - (y0 + t * dy))


def fill_capsule(
    cv: Canvas,
    a: Tuple[float, float],
    b: Tuple[float, float],
    radius: float,
    color: Color,
    gid: int,
) -> None:
    if radius <= 0.2:
        return
    minx = max(0, int(math.floor(min(a[0], b[0]) - radius - 1)))
    maxx = min(FRAME - 1, int(math.ceil(max(a[0], b[0]) + radius + 1)))
    miny = max(0, int(math.floor(min(a[1], b[1]) - radius - 1)))
    maxy = min(FRAME - 1, int(math.ceil(max(a[1], b[1]) + radius + 1)))
    r = radius
    for y in range(miny, maxy + 1):
        for x in range(minx, maxx + 1):
            if _dist_point_seg(x + 0.5, y + 0.5, a[0], a[1], b[0], b[1]) <= r:
                cv.plot(x, y, color, gid)


def fill_ellipse(
    cv: Canvas,
    c: Tuple[float, float],
    ux: float,
    uy: float,
    vx: float,
    vy: float,
    color: Color,
    gid: int,
    inner: float = 0.0,
) -> None:
    """Ellipse spanned by vectors U and V. inner>0 keeps only the outer ring."""
    # Bounding box of the two axes.
    ext = abs(ux) + abs(vx)
    eyt = abs(uy) + abs(vy)
    if ext < 0.4 and eyt < 0.4:
        return
    minx = max(0, int(math.floor(c[0] - ext - 1)))
    maxx = min(FRAME - 1, int(math.ceil(c[0] + ext + 1)))
    miny = max(0, int(math.floor(c[1] - eyt - 1)))
    maxy = min(FRAME - 1, int(math.ceil(c[1] + eyt + 1)))
    det = ux * vy - uy * vx
    if abs(det) < 1e-4:
        return
    inv00, inv01 = vy / det, -vx / det
    inv10, inv11 = -uy / det, ux / det
    inner2 = inner * inner
    for y in range(miny, maxy + 1):
        for x in range(minx, maxx + 1):
            dx, dy = (x + 0.5) - c[0], (y + 0.5) - c[1]
            a = inv00 * dx + inv01 * dy
            b = inv10 * dx + inv11 * dy
            d2 = a * a + b * b
            if d2 <= 1.0 and d2 >= inner2:
                cv.plot(x, y, color, gid)


def disc_axes(
    heading: float, mx: float, my: float, mz: float, radius: float, plane: str
) -> Tuple[Tuple[float, float], Tuple[float, float], Tuple[float, float]]:
    """Project a disc. plane 'xz' is a rotor (horizontal), 'xy' is a side-view bubble."""
    c = to_screen(mx, my, mz, heading)
    if plane == "xz":
        au = to_screen(mx + radius, my, mz, heading)
        av = to_screen(mx, my, mz + radius, heading)
    else:
        au = to_screen(mx + radius, my, mz, heading)
        av = to_screen(mx, my + radius, mz, heading)
    return c, (au[0] - c[0], au[1] - c[1]), (av[0] - c[0], av[1] - c[1])


def draw_disc(
    cv: Canvas,
    heading: float,
    mx: float,
    my: float,
    mz: float,
    radius: float,
    plane: str,
    color: Color,
    gid: int,
    inner: float = 0.0,
) -> Tuple[float, float]:
    c, u, v = disc_axes(heading, mx, my, mz, radius, plane)
    fill_ellipse(cv, c, u[0], u[1], v[0], v[1], color, gid, inner=inner)
    return c


def capsule_m(
    cv: Canvas,
    heading: float,
    a: Sequence[float],
    b: Sequence[float],
    radius_m: float,
    color: Color,
    gid: int,
) -> None:
    pa = to_screen(a[0], a[1], a[2], heading)
    pb = to_screen(b[0], b[1], b[2], heading)
    fill_capsule(cv, pa, pb, radius_m * SCALE, color, gid)


def _norm(x: float, y: float) -> Tuple[float, float]:
    length = math.hypot(x, y)
    if length < 1e-6:
        return (1.0, 0.0)
    return (x / length, y / length)


def draw_blades(
    cv: Canvas,
    heading: float,
    mx: float,
    my: float,
    mz: float,
    radius: float,
    spin: float,
    gid: int,
) -> None:
    c = to_screen(mx, my, mz, heading)
    for k in range(2):
        ang = spin + k * math.pi
        dx, dz = math.cos(ang) * radius * 0.92, math.sin(ang) * radius * 0.92
        tip = to_screen(mx + dx, my, mz + dz, heading)
        fill_capsule(cv, c, tip, 1.05, BLADE, gid)


def render_frame(heading: float, anim: int, occupied: bool) -> Image.Image:
    cv = Canvas()
    spin = anim * (math.pi / 4.0)
    bob = (0.0, 0.45, 0.1, 0.28)[anim]
    flame_len = (6.4, 9.6, 8.0, 5.0)[anim]

    # Far hardware first (negative Z), then body, then the near side.
    _rotors(cv, heading, spin, z_sign=-1.0, gid=cv.new_group())
    _skids(cv, heading, z_sign=-1.0, gid=cv.new_group())

    flame_g = cv.new_group()
    _flame(cv, heading, flame_len, flame_g)

    body = cv.new_group()
    _body(cv, heading, body)
    cv.stroke(body)

    _checker(cv, heading, cv.new_group())
    _fin(cv, heading, cv.new_group())

    canopy = cv.new_group()
    draw_disc(cv, heading, 3.6, 5.6 + bob * 0.15, 0.2, 5.15, "xy", (10, 28, 52), canopy)
    if occupied:
        # Warm cabin behind the riders, still inside the bubble.
        draw_disc(cv, heading, 1.0, 5.2, 0.4, 2.4, "xy", GLOW, canopy)
    _rider(
        cv,
        heading,
        5.2,
        5.5 + bob,
        0.9,
        driver=True,
        gid=cv.new_group(),
    )
    _canopy_ring(cv, heading, 3.6, 5.6 + bob * 0.15, 0.2, 5.15, cv.new_group(), anim)
    if occupied:
        # Drawn after the bezel so the rider stays visible in the rear of the bubble.
        _rider(cv, heading, 1.0, 6.5 + bob * 0.35, 0.3, driver=False, gid=cv.new_group())

    _skids(cv, heading, z_sign=1.0, gid=cv.new_group())
    near = cv.new_group()
    _rotors(cv, heading, spin, z_sign=1.0, gid=near)

    _lamp(cv, heading, anim, cv.new_group())
    # Nose lamp last so the heading stays obvious when the flame is behind the body.
    nose = cv.new_group()
    draw_disc(cv, heading, 18.6, 0.5, 0.6, 1.35, "xy", NOSE, nose)
    draw_disc(cv, heading, 16.6, 0.45, 0.5, 1.7, "xy", HULL_LIT, nose)

    _wash(cv, heading, anim, spin)
    return cv.image()


def _body(cv: Canvas, heading: float, gid: int) -> None:
    # Main pod, darker belly tucked under the model-down side, lighter roof.
    capsule_m(cv, heading, (-13.2, 0.2, 0.0), (12.4, 0.2, 0.0), 4.35, HULL, gid)
    capsule_m(cv, heading, (-11.0, -1.7, 0.0), (10.0, -1.7, 0.0), 2.7, BELLY, gid)
    capsule_m(cv, heading, (-8.0, 1.8, 0.3), (8.5, 1.8, 0.3), 1.7, HULL_LIT, gid)
    # Stepped nose. Fills only — the body stroke pass outlines the union.
    for x, r in ((13.4, 3.15), (15.5, 2.25), (17.2, 1.55)):
        draw_disc(cv, heading, x, 0.45, 0.0, r, "xy", HULL, gid)
    # Tail cap
    draw_disc(cv, heading, -14.0, 0.15, 0.0, 3.1, "xy", MECH, gid)


def _flame(cv: Canvas, heading: float, length: float, gid: int) -> None:
    # Pointing backward (-X). Three cores, no outline, so it reads as light.
    x0 = -14.5
    capsule_m(cv, heading, (x0, 0.1, 0.0), (x0 - length, 0.1, 0.0), 1.55, FLAME_OUT, gid)
    capsule_m(cv, heading, (x0, 0.15, 0.0), (x0 - length * 0.72, 0.15, 0.0), 1.0, FLAME, gid)
    capsule_m(cv, heading, (x0, 0.2, 0.0), (x0 - length * 0.4, 0.2, 0.0), 0.55, FLAME_HOT, gid)


def _checker(cv: Canvas, heading: float, gid: int) -> None:
    for i, x in enumerate((-9.0, -5.5, -2.0, 1.5, 5.0, 8.5)):
        col = YELLOW if i % 2 == 0 else BLACK
        draw_disc(cv, heading, x, -2.35, 1.2, 1.25, "xy", col, gid)


def _fin(cv: Canvas, heading: float, gid: int) -> None:
    capsule_m(cv, heading, (-12.2, 2.2, 0.0), (-12.6, 6.4, 0.0), 1.15, MECH_LIT, gid)
    cv.stroke(gid)


def _skids(cv: Canvas, heading: float, z_sign: float, gid: int) -> None:
    z = 3.2 * z_sign
    capsule_m(cv, heading, (-8.0, -6.3, z), (10.0, -6.3, z), 0.7, SKID, gid)
    capsule_m(cv, heading, (-5.0, -6.0, z), (-5.0, -3.6, z * 0.3), 0.55, SKID, gid)
    capsule_m(cv, heading, (7.0, -6.0, z), (7.0, -3.6, z * 0.3), 0.55, SKID, gid)
    cv.stroke(gid, (40, 48, 64))


def _rotors(cv: Canvas, heading: float, spin: float, z_sign: float, gid: int) -> None:
    z = 8.4 * z_sign
    phase = 0.4 if z_sign > 0 else 1.3
    for x in (7.4, -7.6):
        # Arm from the roof out toward this duct.
        capsule_m(cv, heading, (x, 3.4, 0.4 * z_sign), (x, 7.6, z * 0.82), 1.05, MECH, gid)
        c = to_screen(x, 8.15, z, heading)
        cu, cvv = disc_axes(heading, x, 8.15, z, 5.5, "xz")[1:]
        fill_ellipse(cv, c, cu[0], cu[1], cvv[0], cvv[1], RING, gid)
        fill_ellipse(cv, c, cu[0] * 0.62, cu[1] * 0.62, cvv[0] * 0.62, cvv[1] * 0.62, DISC, gid)
        phase += 0.85
    # Outline the housings before the blades, so the spin stays bright instead of
    # turning into a crust of dark pixels.
    cv.stroke(gid)
    phase = 0.4 if z_sign > 0 else 1.3
    for x in (7.4, -7.6):
        draw_blades(cv, heading, x, 8.35, z, 5.15, spin + phase + (0.2 if x > 0 else 0.0), gid)
        draw_disc(cv, heading, x, 8.5, z, 1.25, "xz", HUB, gid)
        phase += 0.85


def _canopy_ring(
    cv: Canvas, heading: float, mx: float, my: float, mz: float, radius: float, gid: int, anim: int
) -> None:
    c, u, v = disc_axes(heading, mx, my, mz, radius, "xy")
    # Bright bezel. Inner hole left alone so the riders stay visible.
    fill_ellipse(cv, c, u[0], u[1], v[0], v[1], (190, 252, 255), gid, inner=0.78)
    # Specular that walks around the bubble across the rotor cycle.
    shift = (-1.2, -0.2, 1.0, 0.3)[anim]
    glint = to_screen(mx + shift, my + 2.4, mz, heading)
    fill_capsule(cv, glint, (glint[0] + 1.6, glint[1] + 0.4), 0.7, (255, 255, 255), gid)


def _rider(
    cv: Canvas,
    heading: float,
    mx: float,
    my: float,
    mz: float,
    driver: bool,
    gid: int,
) -> None:
    if driver:
        draw_disc(cv, heading, mx - 0.7, my - 1.5, mz, 2.0, "xy", SUIT, gid)
        draw_disc(cv, heading, mx - 0.8, my + 0.7, mz, 2.15, "xy", (72, 196, 214), gid)
        draw_disc(cv, heading, mx + 0.35, my + 0.45, mz, 1.85, "xy", SKIN, gid)
        # Visor across the face, perpendicular to the nose so it stays a face at every heading.
        nose = _screen_dir(heading)
        perp = (-nose[1], nose[0])
        face = to_screen(mx + 0.55, my + 0.55, mz, heading)
        half = 1.7
        a = (face[0] + perp[0] * half, face[1] + perp[1] * half)
        b = (face[0] - perp[0] * half, face[1] - perp[1] * half)
        fill_capsule(cv, a, b, 0.75, VISOR, gid)
        # Eyes just ahead of the visor, toward the nose.
        for s in (-0.7, 0.7):
            ex = face[0] + nose[0] * 0.9 + perp[0] * s
            ey = face[1] + nose[1] * 0.9 + perp[1] * s
            fill_capsule(cv, (ex, ey), (ex + nose[0] * 0.4, ey + nose[1] * 0.4), 0.55, (12, 18, 32), gid)
    else:
        draw_disc(cv, heading, mx, my - 1.15, mz, 1.7, "xy", SHIRT, gid)
        draw_disc(cv, heading, mx - 0.2, my + 1.35, mz, 2.35, "xy", HAIR, gid)
        draw_disc(cv, heading, mx + 0.45, my + 0.45, mz, 1.65, "xy", SKIN, gid)
        draw_disc(cv, heading, mx - 0.15, my + 2.05, mz, 1.85, "xy", HAIR_DK, gid)
        nose = _screen_dir(heading)
        perp = (-nose[1], nose[0])
        face = to_screen(mx + 0.45, my + 0.4, mz, heading)
        for s in (-0.55, 0.55):
            ex = face[0] + nose[0] * 0.7 + perp[0] * s
            ey = face[1] + nose[1] * 0.7 + perp[1] * s
            fill_capsule(cv, (ex, ey), (ex, ey), 0.45, (40, 16, 32), gid)


def _screen_dir(heading: float) -> Tuple[float, float]:
    o = to_screen(0.0, 0.0, 0.0, heading)
    n = to_screen(1.0, 0.0, 0.0, heading)
    return _norm(n[0] - o[0], n[1] - o[1])


def _lamp(cv: Canvas, heading: float, anim: int, gid: int) -> None:
    on = anim in (0, 1)
    capsule_m(cv, heading, (1.2, 10.7, 0.3), (5.6, 10.7, 0.3), 1.15, (120, 128, 142), gid)
    col = YELLOW if on else YELLOW_DIM
    capsule_m(cv, heading, (1.7, 10.75, 0.8), (5.1, 10.75, 0.8), 0.8, col, gid)
    if anim == 0:
        draw_disc(cv, heading, 3.4, 11.15, 1.0, 0.7, "xy", (255, 255, 230), gid)
    cv.stroke(gid, (30, 24, 16))


def _wash(cv: Canvas, heading: float, anim: int, spin: float) -> None:
    del spin
    for i, (x, z) in enumerate(((7.4, 8.4), (7.4, -8.4), (-7.6, 8.4), (-7.6, -8.4))):
        sx, sy = to_screen(x, 8.2, z, heading)
        shift = (anim + i) % 3
        for k, col in enumerate(WASH):
            xx = int(round(sx + (1 if (i + anim + k) % 2 == 0 else -1) * (k == 1)))
            yy = int(round(sy + 4 + k + (1 if shift == k else 0)))
            if 0 <= xx < FRAME and 0 <= yy < FRAME and cv.gid[yy * FRAME + xx] == 0:
                cv.plot(xx, yy, col, 99)


def compose_sheet() -> Image.Image:
    sheet = Image.new("RGBA", (FRAME * ANIM * 2, FRAME * ANGLES), (0, 0, 0, 0))
    clipped = False
    for angle in range(ANGLES):
        heading = angle * STEP_DEG
        for anim in range(ANIM):
            for occupied in (0, 1):
                frame = render_frame(heading, anim, bool(occupied))
                sheet.paste(frame, ((anim + occupied * ANIM) * FRAME, angle * FRAME))
                bb = frame.getbbox()
                if bb and (bb[0] <= 0 or bb[1] <= 0 or bb[2] >= FRAME or bb[3] >= FRAME):
                    clipped = True
                    print(f"clip h={heading:.0f} anim={anim} occ={occupied} {bb}")
        if angle % 9 == 0:
            print(f"heading {heading:.0f}")
    if not clipped:
        print("no frame touches the canvas edge")
    # Report resting pose vertical placement so the scene can sit the skids on a pad.
    rest = render_frame(0, 0, False)
    bb = rest.getbbox()
    print("rest bbox", bb, "center", FRAME // 2)
    return sheet


def save_previews(out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    bg = (12, 10, 28, 255)

    def on_bg(frame: Image.Image) -> Image.Image:
        base = Image.new("RGBA", frame.size, bg)
        base.alpha_composite(frame)
        return base

    cols = 9
    rows = math.ceil(ANGLES / cols)
    grid = Image.new("RGBA", (cols * FRAME, rows * FRAME), bg)
    for angle in range(ANGLES):
        frame = on_bg(render_frame(angle * STEP_DEG, angle % ANIM, angle % 7 == 0))
        grid.paste(frame, ((angle % cols) * FRAME, (angle // cols) * FRAME))
    grid.save(os.path.join(out_dir, "angles.png"))

    headings = (0, 20, 40, 70, 90, 140, 180, 220, 270, 320)
    anim_grid = Image.new("RGBA", (ANIM * FRAME, len(headings) * FRAME), bg)
    for row, heading in enumerate(headings):
        for anim in range(ANIM):
            anim_grid.paste(on_bg(render_frame(heading, anim, heading in (0, 90))), (anim * FRAME, row * FRAME))
    anim_grid.save(os.path.join(out_dir, "anim.png"))

    flight = Image.new("RGBA", (560, 560), bg)
    for i in range(ANGLES):
        heading = i * STEP_DEG
        frame = render_frame(heading, i % ANIM, False)
        ang = math.radians(heading)
        cx = 280 + int(math.cos(ang) * 200) - FRAME // 2
        cy = 280 - int(math.sin(ang) * 200) - FRAME // 2
        flight.alpha_composite(frame, (cx, cy))
    flight.save(os.path.join(out_dir, "flight.png"))

    # Large single frames for inspection.
    for heading, name in ((0, "z0"), (30, "z30"), (90, "z90"), (180, "z180"), (270, "z270")):
        on_bg(render_frame(heading, 1, heading == 0)).resize((320, 320), Image.NEAREST).save(
            os.path.join(out_dir, f"{name}.png")
        )
    strip = Image.new("RGBA", (320 * 4, 320), bg)
    for anim in range(4):
        fr = on_bg(render_frame(0, anim, False)).resize((320, 320), Image.NEAREST)
        strip.paste(fr, (anim * 320, 0))
    strip.save(os.path.join(out_dir, "zoom_anim.png"))
    ride = on_bg(render_frame(20, 0, True)).resize((320, 320), Image.NEAREST)
    ride.save(os.path.join(out_dir, "zoom_ride.png"))
    print("previews", out_dir)


def main() -> None:
    import sys

    root = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
    if len(sys.argv) > 1 and sys.argv[1] == "preview":
        save_previews("/tmp/cab_preview")
        return
    out = os.path.join(root, "assets", "sprites", "cab_drone.png")
    sheet = compose_sheet()
    sheet.save(out)
    print("wrote", out, sheet.size)


if __name__ == "__main__":
    main()
