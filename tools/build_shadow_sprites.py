"""Builds the Shadow's sprites (shadow.gd) from the player's: the same
kunoichi in dark plum (like Celeste's dark Madeline: purple, not black;
pale lavender skin), two red eyes, her katana in hand and in her hair's plum, everything on one 170x170 frame (her attack canvas, her
feet at (84, 123)), and her lightning (black core, pale lavender glow).

Run from the repo root:  python3 tools/build_shadow_sprites.py
"""
from PIL import Image

OUT = "assets/sprites/shadow/"
F = 170                      # one frame size for every sheet
SMALL = 96                   # her idle/run/fall frames
IDLE_OFFSET = (37, 35)       # where a 96 frame sits on the 170 canvas (feet line up with the poses')

# Her colours -> the Shadow's.
RECOLOUR = {
    (1, 12, 13): (30, 18, 40),        # outfit: dark plum (like Celeste's dark Madeline: purple, not black)
    (3, 29, 39): (58, 34, 74),        # outfit shading
    (244, 46, 31): (112, 44, 92),     # hair, scarf: muted plum
    (122, 24, 34): (70, 26, 58),
    (255, 212, 194): (214, 206, 222),  # skin: pale lavender-white (the brightest part of her)
    (252, 167, 144): (168, 158, 182),
    (133, 133, 133): (112, 44, 92),   # blade: her hair's plum
    (6, 6, 8): (4, 3, 6),
    (255, 255, 255): (168, 92, 146),  # blade shine: a lighter plum (not white: white is read as a slash arc)
    (255, 229, 38): (70, 26, 58),     # hilt: her hair's dark plum
}
SKIN = {(255, 212, 194), (252, 167, 144)}
EYE = (255, 36, 36)
ARC_EDGE = {(225, 25, 35): (120, 0, 14)}   # her slash's red edge, darker (the white stays)


def recolour(img, eye=True):
    img = img.convert("RGBA")
    px = img.load()
    w, h = img.size
    face = []
    for y in range(h):
        for x in range(w):
            p = px[x, y]
            if p[3] == 0:
                continue
            if p[:3] in SKIN:
                face.append((x, y))
            c = RECOLOUR.get(p[:3])
            if c:
                px[x, y] = c + (p[3],)
    if eye and face:
        # Her eyes: on the face (the topmost skin), toward its front edge.
        top = min(y for _, y in face)
        row = [x for x, y in face if y == top + 3] or [x for x, y in face if y <= top + 4]
        # Two red eyes, two pixels apart (fewer face pixels: as far apart as fit).
        row = sorted(set(row))
        if row:
            right = row[-1] - 1 if len(row) >= 3 else row[-1]
            left = right - 3 if right - 3 >= row[0] else row[0]
            for ex in {left, right}:
                px[ex, top + 3] = EYE + (255,)
    return img


def small_frame(sheet, i):
    cols = sheet.width // SMALL
    return sheet.crop(((i % cols) * SMALL, (i // cols) * SMALL, (i % cols + 1) * SMALL, (i // cols + 1) * SMALL))


def on_canvas(frame, offset):
    c = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    c.alpha_composite(frame, offset)
    return c


def strip(frames):
    s = Image.new("RGBA", (F * len(frames), F), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        s.alpha_composite(f, (i * F, 0))
    return s


def arc_layer(i, alpha=1.0):
    arc = Image.open("assets/sprites/attack/arc%d.png" % i).convert("RGBA")
    px = arc.load()
    for y in range(arc.height):
        for x in range(arc.width):
            p = px[x, y]
            if p[3] == 0:
                continue
            c = ARC_EDGE.get(p[:3], p[:3])
            px[x, y] = c + (int(p[3] * alpha),)
    return arc


# Her idle frames hold the katana (the player's: assets/sprites/katana.png)
# in her hanging back hand, as the player holds it in her death fall
# (player.gd: KATANA_HELD_ANGLE, KATANA_GRIP), behind her body.
KATANA_ANGLE = 3.7   # radians, clockwise on screen: tip down and back
KATANA_GRIP = 5.0    # pixels of hilt inside her hand


def back_hand(frame):
    """Her hanging back hand in a 96 idle frame: the lowest pixels left of her body."""
    px = frame.load()
    pts = [(x, y) for x in range(24, 37) for y in range(50, 66) if px[x, y][3] > 0]
    low = max(y for _, y in pts)
    xs = [x for x, y in pts if y == low]
    return (sum(xs) / len(xs), low)


FALL_HAND = (35, 56)   # her hand in the fall frames (player.gd FALL_HAND): she keeps the katana as she dies


def with_katana(frame, hand=None):
    import math
    katana = recolour(Image.open("assets/sprites/katana.png"), eye=False)
    hx, hy = hand if hand else back_hand(frame)
    rotated = katana.rotate(-math.degrees(KATANA_ANGLE), resample=Image.NEAREST, expand=True)
    half = katana.height / 2.0
    bx, by = math.sin(KATANA_ANGLE), -math.cos(KATANA_ANGLE)   # hilt to tip
    cx, cy = hx + bx * (half - KATANA_GRIP), hy + by * (half - KATANA_GRIP)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    out.alpha_composite(rotated, (int(round(cx - rotated.width / 2.0)), int(round(cy - rotated.height / 2.0))))
    out.alpha_composite(frame)
    return out


def main():
    sheet = Image.open("assets/sprites/kunoichi.png")
    poses = Image.open("assets/sprites/attack/poses.png")
    idle = [on_canvas(with_katana(recolour(small_frame(sheet, i))), IDLE_OFFSET) for i in range(6)]
    fall = [on_canvas(with_katana(recolour(small_frame(sheet, i)), FALL_HAND), IDLE_OFFSET) for i in range(5, 8)]
    bare = [recolour(poses.crop((k * F, 0, (k + 1) * F, F))) for k in range(3)]
    # Swings: per pose, bare / with its arc / the arc fading.
    swings = []
    for k in range(3):
        swings.append(bare[k].copy())
        for a in (1.0, 0.5):
            f = bare[k].copy()
            f.alpha_composite(arc_layer(k, a))
            swings.append(f)
    strip(idle).save(OUT + "idle.png")
    strip(fall).save(OUT + "fall.png")
    strip(swings).save(OUT + "swings.png")
    # Her lightning: black core, a pale lavender glow (her own glow's colour; not
    # the player's red, so her blinks read as hers).
    for name in ("lightning_3", "lightning_6"):   # (her strike, her sparks)
        img = Image.open("assets/vfx/%s.png" % name).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                p = px[x, y]
                if p[3] == 0:
                    continue
                if p[:3] == (255, 255, 255):
                    px[x, y] = (22, 10, 30, p[3])
                else:
                    px[x, y] = (196, 180, 232, p[3])
        img.save("assets/vfx/%s_shadow.png" % name)


main()
