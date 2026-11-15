"""Splits art/red_flash_attack_frames.piskel into what the game uses:

  assets/sprites/attack/poses.png    the three strike poses (sword, no arc)
  assets/sprites/attack/arcN.png     each slash arc: white, outer edge red
  assets/sprites/attack/arcN_t.png   how far along the swing each arc pixel
                                     is (grey: black = start, white = end at
                                     the sword tip), so the game can sweep it

Run from the project folder after editing the attack frames:
  python3 tools/build_attack_arcs.py art/red_flash_attack_frames.piskel assets/sprites/attack
Needs Pillow. Which layer holds each arc and sword is set in ARC / SWORD.
"""
import json, base64, io, math, sys, os
from PIL import Image
SRC = sys.argv[1]; OUT = sys.argv[2]
os.makedirs(OUT, exist_ok=True)
W = 170
d = json.load(open(SRC)); L = {}
order = []
for ls in d['piskel']['layers']:
    l = json.loads(ls); ch = l['chunks'][0]
    im = Image.open(io.BytesIO(base64.b64decode(ch['base64PNG'].split(',')[1]))).convert('RGBA')
    L[l['name']] = [im.crop((i*W, 0, i*W+W, W)) for i in range(l['frameCount'])]
    order.append(l['name'])
# which layer/frame holds the arc vs the sword (from looking at the file)
ARC = {0: ('Layer 8', 0), 1: ('Layer 8', 1), 2: ('Layer 7', 2)}
SWORD = {0: ('Layer 7', 0), 1: ('Layer 6', 1), 2: ('Layer 6', 2)}
RED = (225, 25, 35); WHITE = (255, 248, 248)
info = {}
poses = []
for f in range(3):
    # pose = every layer except this frame's arc
    pose = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    for name in order:
        if (name, f) == ARC[f]: continue
        pose.alpha_composite(L[name][f])
    arc = L[ARC[f][0]][f]
    tb = L['Layer 2'][f].getbbox()            # torso: the swing's centre
    cx, cy = (tb[0] + tb[2]) / 2, (tb[1] + tb[3]) / 2
    sw = L[SWORD[f][0]][f]
    tip = max(((x, y) for y in range(W) for x in range(W) if sw.getpixel((x, y))[3] > 0),
              key=lambda p: (p[0]-cx)**2 + (p[1]-cy)**2)
    tip_a = math.atan2(tip[1]-cy, tip[0]-cx)
    px = [(x, y) for y in range(W) for x in range(W) if arc.getpixel((x, y))[3] > 0]
    def delta(x, y):
        a = math.atan2(y-cy, x-cx) - tip_a
        return (a + math.pi) % (2*math.pi) - math.pi
    ds = [delta(x, y) for x, y in px]
    # the arc lies mostly on one side of the sword: progress runs from the far end (0) to the sword (1)
    side = -1 if sum(1 for v in ds if v < 0) > len(ds) / 2 else 1
    # distance back along the swing from the sword, measured continuously
    # (0..2pi), so an arc that wraps far around her has no jump
    back = [((v * side) % (2 * math.pi)) for v in ds]
    span = max(back) or 1.0
    # outer (cutting) edge: per angle bin, the outermost 2 px of the arc
    rmax = {}
    for (x, y) in px:
        b = int((math.degrees(math.atan2(y-cy, x-cx)) + 360) // 4)
        r = math.hypot(x-cx, y-cy); rmax[b] = max(rmax.get(b, 0), r)
    colour = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    tmap = Image.new('RGBA', (W, W), (0, 0, 0, 0))
    ts = [1.0 - min(((v * side) % (2 * math.pi)) / span, 1.0) for v in ds]
    lo, hi = min(ts), max(ts)
    for (x, y), t in zip(px, ts):
        t = (t - lo) / (hi - lo) if hi > lo else 1.0
        b = int((math.degrees(math.atan2(y-cy, x-cx)) + 360) // 4)
        edge = math.hypot(x-cx, y-cy) > rmax[b] - 2.5
        colour.putpixel((x, y), (*(RED if edge else WHITE), 255))
        g = int(t * 255)
        tmap.putpixel((x, y), (g, g, g, 255))
    in_front = ARC[f][0] == order[-1] or order.index(ARC[f][0]) > order.index('Layer 3')
    poses.append(pose); colour.save(f'{OUT}/arc{f}.png'); tmap.save(f'{OUT}/arc{f}_t.png')
    info[f] = {'front': in_front, 'centre': (cx, cy), 'tip': tip, 'side': side}
    print(f, info[f])
strip = Image.new('RGBA', (W * len(poses), W), (0, 0, 0, 0))
for i, p in enumerate(poses):
    strip.paste(p, (i * W, 0))
strip.save(f'{OUT}/poses.png')
json.dump(info, open(f'{OUT}/arcs.json', 'w'), indent=1)
