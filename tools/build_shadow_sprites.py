"""Builds the Shadow's sprites (shadow.gd) from the player's: the same
kunoichi, darkened (black-purple body, ash-grey skin, her red gone to dried
blood), one red eye, everything on one 170x170 frame (her attack canvas, her
feet at (84, 123)), and her lightning (black core, red glow).

Run from the repo root:  python3 tools/build_shadow_sprites.py
"""
from PIL import Image

OUT = "assets/sprites/shadow/"
F = 170                      # one frame size for every sheet
SMALL = 96                   # her idle/run/fall frames
IDLE_OFFSET = (37, 35)       # where a 96 frame sits on the 170 canvas (feet line up with the poses')

# Her colours -> the Shadow's.
RECOLOUR = {
    (1, 12, 13): (14, 9, 18),        # outfit: near black, a little purple
    (3, 29, 39): (34, 26, 44),       # outfit shading: grey-purple
    (244, 46, 31): (112, 10, 22),    # hair, scarf: dried blood
    (122, 24, 34): (54, 6, 14),
    (255, 212, 194): (104, 100, 112),  # skin: ash grey
    (252, 167, 144): (74, 70, 82),
    (133, 133, 133): (84, 84, 92),   # blade
    (6, 6, 8): (4, 3, 6),
    (255, 255, 255): (186, 184, 196),  # blade shine (not pure white: white is read as a slash arc)
    (255, 229, 38): (96, 18, 26),    # hilt: dark red
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
        # One red eye: on the face (the topmost skin), toward its front edge.
        top = min(y for _, y in face)
        row = [x for x, y in face if y == top + 3] or [x for x, y in face if y <= top + 4]
        if row:
            ex = max(row) - 2
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


def main():
    sheet = Image.open("assets/sprites/kunoichi.png")
    poses = Image.open("assets/sprites/attack/poses.png")
    idle = [on_canvas(recolour(small_frame(sheet, i)), IDLE_OFFSET) for i in range(6)]
    fall = [on_canvas(recolour(small_frame(sheet, i)), IDLE_OFFSET) for i in range(5, 8)]
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
    # Her lightning: black core, red glow.
    for name in ("lightning_3", "lightning_6"):
        img = Image.open("assets/vfx/%s.png" % name).convert("RGBA")
        px = img.load()
        for y in range(img.height):
            for x in range(img.width):
                p = px[x, y]
                if p[3] == 0:
                    continue
                if p[:3] == (255, 255, 255):
                    px[x, y] = (26, 8, 14, p[3])
                else:
                    px[x, y] = (190, 0, 16, p[3])
        img.save("assets/vfx/%s_shadow.png" % name)


main()
