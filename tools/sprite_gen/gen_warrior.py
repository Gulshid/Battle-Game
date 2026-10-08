"""Generates the placeholder warrior sprite sheet (pure Python + Pillow).

Sheet layout: 128x160 px, 32x32 frames, 4 columns x 5 rows
  row 0 idle (2 frames)   row 1 run (4)   row 2 attack (3)
  row 3 hit (1)           row 4 death (4)
Replace apps/game_client/assets/images/warrior.png with real art later;
keep the same layout and no code changes are needed.

Usage: python3 tools/sprite_gen/gen_warrior.py
"""
from PIL import Image, ImageDraw, ImageFilter
import math

OUT = 'apps/game_client/assets/images/warrior.png'
F = 32
SKIN = (240, 200, 160, 255)
BODY = (79, 195, 247, 255)
BODY_D = (45, 140, 200, 255)
HELM = (170, 176, 196, 255)
BOOT = (60, 52, 70, 255)
BLADE = (225, 230, 240, 255)
HILT = (150, 110, 60, 255)
OUTLINE = (20, 22, 36, 255)


def line(d, a, b, c):
    d.line([a, b], fill=c, width=1)


def character(bob=0, legs=(0, 0), sword='up', lean=0):
    im = Image.new('RGBA', (F, F), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fy = 28
    # legs (x offset forward/back per leg)
    for lx, off in ((13, legs[0]), (17, legs[1])):
        lift = 1 if off == 99 else 0
        ox = 0 if off == 99 else off
        d.rectangle([lx + ox, fy - 6 - lift, lx + 2 + ox, fy - 1 - lift], fill=BODY_D)
        d.rectangle([lx + ox, fy - 2 - lift, lx + 3 + ox, fy - lift], fill=BOOT)
    # torso
    ty = 14 + bob
    d.rectangle([12 + lean, ty, 20 + lean, ty + 8], fill=BODY)
    d.rectangle([12 + lean, ty + 6, 20 + lean, ty + 8], fill=BODY_D)
    # head + helmet
    hy = 6 + bob
    d.rectangle([12 + lean, hy, 20 + lean, hy + 7], fill=SKIN)
    d.rectangle([12 + lean, hy, 20 + lean, hy + 2], fill=HELM)
    d.rectangle([12 + lean, hy + 3, 13 + lean, hy + 4], fill=HELM)
    d.point((18 + lean, hy + 4), fill=OUTLINE)
    # sword (hand at 21,ty+3)
    hx, hy2 = 21 + lean, ty + 3
    tips = {
        'up': (hx + 1, hy2 - 10),
        'back': (hx - 7, hy2 - 8),
        'fwd': (hx + 9, hy2 - 1),
        'down': (hx + 7, hy2 + 7),
    }
    tip = tips[sword]
    line(d, (hx, hy2), tip, BLADE)
    line(d, (hx + 1, hy2), (tip[0] + 1, tip[1]), BLADE)
    d.rectangle([hx - 1, hy2 - 1, hx + 1, hy2 + 1], fill=HILT)
    return im


def outlined(im):
    a = im.split()[3]
    grown = a.filter(ImageFilter.MaxFilter(3))
    out = Image.new('RGBA', im.size, (0, 0, 0, 0))
    out.paste(Image.new('RGBA', im.size, OUTLINE), mask=grown)
    out.alpha_composite(im)
    return out


def tint(im, rgb, amt):
    r, g, b, a = im.split()
    over = Image.new('RGBA', im.size, rgb + (255,))
    mixed = Image.blend(im.convert('RGB'), over.convert('RGB'), amt)
    res = mixed.convert('RGBA')
    res.putalpha(a)
    return res


def rotate_about_feet(im, deg):
    return im.rotate(deg, resample=Image.NEAREST, center=(16, 28), translate=(0, 0))


idle = [character(0), character(1)]
run = [
    character(0, (2, -2)),
    character(1, (99, 99)),
    character(0, (-2, 2)),
    character(1, (99, 99)),
]
attack = [
    character(0, sword='back', lean=-1),
    character(0, sword='fwd', lean=1),
    character(1, sword='down', lean=1),
]
hit = [tint(character(1, sword='back', lean=-2), (255, 255, 255), 0.55)]
base = character(1, sword='back')
death = [
    tint(rotate_about_feet(base, 20), (255, 120, 120), 0.3),
    tint(rotate_about_feet(base, 50), (255, 120, 120), 0.3),
    tint(rotate_about_feet(base, 80), (200, 120, 120), 0.3),
    tint(rotate_about_feet(base, 90), (160, 110, 110), 0.4),
]

rows = [idle, run, attack, hit, death]
sheet = Image.new('RGBA', (F * 4, F * 5), (0, 0, 0, 0))
for r, frames in enumerate(rows):
    for c in range(4):
        fr = frames[min(c, len(frames) - 1)]
        sheet.alpha_composite(outlined(fr), (c * F, r * F))
sheet.save(OUT)
print('wrote', OUT, sheet.size)
