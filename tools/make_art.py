"""Draws the character portraits and the building in assets/, as drawing code.

Usage: python3 -I tools/make_art.py. Needs Pillow. The sleep screen cover comes from tools/make_brand_art.py.
"""
import math
import os
import random

from PIL import Image, ImageChops, ImageDraw

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
ASSETS = os.path.join(ROOT, "assets")
SCALE = 4
PORTRAIT = 300
BLACK, DARK, MID, LIGHT, WHITE = 0, 85, 150, 215, 255
LINE = 9 * SCALE // 4 + 4


class Canvas:
    def __init__(self, width, height, background=WHITE):
        self.w, self.h = width * SCALE, height * SCALE
        self.image = Image.new("L", (self.w, self.h), background)
        self.draw = ImageDraw.Draw(self.image)

    def s(self, *values):
        return [v * SCALE for v in values]

    def ellipse(self, x0, y0, x1, y1, fill=WHITE, outline=BLACK, width=LINE):
        self.draw.ellipse(self.s(x0, y0, x1, y1), fill=fill, outline=outline, width=width)

    def rect(self, x0, y0, x1, y1, fill=WHITE, outline=BLACK, width=LINE, radius=0):
        self.draw.rounded_rectangle(self.s(x0, y0, x1, y1), radius=radius * SCALE, fill=fill, outline=outline, width=width)

    def poly(self, points, fill=WHITE, outline=BLACK, width=LINE):
        scaled = [(x * SCALE, y * SCALE) for x, y in points]
        self.draw.polygon(scaled, fill=fill)
        if outline is not None:
            self.draw.line(scaled + [scaled[0]], fill=outline, width=width, joint="curve")

    def line(self, points, fill=BLACK, width=LINE):
        self.draw.line([(x * SCALE, y * SCALE) for x, y in points], fill=fill, width=width, joint="curve")

    def arc(self, x0, y0, x1, y1, start, end, fill=BLACK, width=LINE):
        self.draw.arc(self.s(x0, y0, x1, y1), start, end, fill=fill, width=width)

    def frame(self):
        # Flush with the edges, so nothing drawn under it shows outside.
        self.draw.rectangle([0, 0, self.w - 1, self.h - 1], outline=BLACK, width=SCALE * 3)

    def save(self, path):
        small = self.image.resize((self.w // SCALE, self.h // SCALE), Image.LANCZOS)
        small = small.point(lambda v: round(v / 17) * 17)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        small.save(path, optimize=True)


def background(c, kind):
    if kind == "dots":
        for y in range(10, PORTRAIT, 22):
            for x in range(10 + (y // 22 % 2) * 11, PORTRAIT, 22):
                c.ellipse(x - 2, y - 2, x + 2, y + 2, fill=LIGHT, outline=None)
    elif kind == "lines":
        for x in range(-PORTRAIT, PORTRAIT * 2, 22):
            c.line([(x, 0), (x + PORTRAIT, PORTRAIT)], fill=LIGHT, width=SCALE * 3)
    elif kind == "bricks":
        for row, y in enumerate(range(0, PORTRAIT, 30)):
            c.line([(0, y), (PORTRAIT, y)], fill=LIGHT, width=SCALE * 2)
            for x in range((row % 2) * 30, PORTRAIT, 60):
                c.line([(x, y), (x, y + 30)], fill=LIGHT, width=SCALE * 2)
    elif kind == "grid":
        for v in range(0, PORTRAIT, 30):
            c.line([(v, 0), (v, PORTRAIT)], fill=LIGHT, width=SCALE * 2)
            c.line([(0, v), (PORTRAIT, v)], fill=LIGHT, width=SCALE * 2)
    elif kind == "sun":
        for i in range(0, 360, 20):
            c.draw.pieslice(c.s(-150, -150, 450, 450), i, i + 10, fill=LIGHT)
    elif kind == "gray":
        c.rect(0, 0, PORTRAIT, PORTRAIT, fill=LIGHT, outline=None)


def neckline(c, skin, left, right, depth, shoulder_line):
    # An opening in the clothes that shows the neck. With shoulder_line, it starts just below the shoulder
    # line (y 222), which stays as its top edge; without it, it covers that line, for a neck under the chin.
    cy = 224 if shoulder_line else 220
    c.draw.chord(c.s(left, cy - depth, right, cy + depth), 0, 180, fill=skin)
    start = 0 if shoulder_line else math.degrees(math.asin(2 / depth))
    c.arc(left, cy - depth, right, cy + depth, start, 180 - start)


def body(c, p):
    style = p.get("body", "shirt")
    fill = p.get("body_fill", MID)
    skin = p.get("skin", WHITE)
    c.poly([(30, 300), (45, 245), (105, 222), (195, 222), (255, 245), (270, 300)], fill=fill)
    # Where the arms meet the chest: a thin line a little darker than the clothes (lighter only on black), so
    # they do not look flat.
    seam = fill - 34 if fill >= 34 else fill + 34
    c.line([(79, 264), (76, 304)], fill=seam, width=SCALE * 2)
    c.line([(221, 264), (224, 304)], fill=seam, width=SCALE * 2)
    if style == "suit":
        c.poly([(150, 300), (118, 225), (182, 225)], fill=WHITE)
        c.poly([(150, 300), (138, 240), (150, 228), (162, 240)], fill=BLACK, width=SCALE)
    elif style == "uniform":
        c.line([(150, 226), (150, 304)])
        c.rect(180, 256, 222, 282, fill=WHITE, width=SCALE * 2)
        c.line([(188, 264), (214, 264)], width=SCALE * 2)
        c.line([(188, 273), (208, 273)], width=SCALE * 2)
    elif style == "collar":
        # The open collar shows the neck between the two flaps, below the shoulder line, which stays as its edge.
        c.poly([(118, 224), (150, 256), (182, 224)], fill=skin, outline=None)
        # The flaps are a shade darker than the shirt, two if that would match the skin, so they never blend
        # with the neck, the shirt or a white background.
        flap = fill - 34 if abs(fill - 34 - skin) >= 30 else fill - 68
        c.poly([(118, 222), (150, 256), (132, 272), (106, 222)], fill=flap)
        c.poly([(182, 222), (150, 256), (168, 272), (194, 222)], fill=flap)
    elif style == "apron":
        c.poly([(100, 304), (112, 240), (188, 240), (200, 304)], fill=p.get("apron_fill", LIGHT))
        c.line([(112, 240), (120, 222)])
        c.line([(188, 240), (180, 222)])
    elif style == "tshirt":
        neckline(c, skin, 128, 172, 26, shoulder_line=False)
    elif style == "dress":
        neckline(c, skin, 114, 186, 36, shoulder_line=True)
        for y in (270, 288):
            c.ellipse(146, y - 4, 154, y + 4, fill=WHITE, width=SCALE * 2)


HEADS = {
    "oval": (88, 62, 212, 226),
    "round": (80, 72, 220, 222),
    "long": (96, 52, 204, 230),
    "square": (84, 66, 216, 224),
}


def face(c, p):
    x0, y0, x1, y1 = HEADS[p.get("head", "oval")]
    skin = p.get("skin", WHITE)
    c.ellipse(x0 - 12, 134, x0 + 12, 168, fill=skin)
    c.ellipse(x1 - 12, 134, x1 + 12, 168, fill=skin)
    if p.get("head") == "square":
        c.rect(x0, y0, x1, y1, fill=skin, radius=34)
    else:
        c.ellipse(x0, y0, x1, y1, fill=skin)
    return x0, y0, x1, y1


def eyes(c, p):
    kind = p.get("eyes", "dot")
    left, right = 122, 178
    if kind == "dot":
        c.ellipse(left - 6, 136, left + 6, 150, fill=BLACK, outline=None)
        c.ellipse(right - 6, 136, right + 6, 150, fill=BLACK, outline=None)
    elif kind == "tired":
        c.ellipse(left - 6, 138, left + 6, 150, fill=BLACK, outline=None)
        c.ellipse(right - 6, 138, right + 6, 150, fill=BLACK, outline=None)
        c.line([(left - 12, 134), (left + 12, 138)])
        c.line([(right - 12, 138), (right + 12, 134)])
        c.arc(left - 12, 148, left + 12, 162, 20, 160, width=SCALE * 2)
        c.arc(right - 12, 148, right + 12, 162, 20, 160, width=SCALE * 2)
    elif kind == "narrow":
        c.line([(left - 11, 142), (left + 11, 142)], width=SCALE * 4)
        c.line([(right - 11, 142), (right + 11, 142)], width=SCALE * 4)
    elif kind == "wide":
        for x in (left, right):
            c.ellipse(x - 12, 130, x + 12, 154, fill=WHITE, width=SCALE * 2)
            c.ellipse(x - 5, 137, x + 5, 149, fill=BLACK, outline=None)
    elif kind == "lash":
        for x in (left, right):
            c.ellipse(x - 7, 136, x + 7, 150, fill=BLACK, outline=None)
            c.line([(x - 13, 134), (x + 10, 130)], width=SCALE * 3)
    brows = p.get("brows")
    if brows == "angry":
        c.line([(left - 16, 118), (left + 14, 128)], width=SCALE * 4)
        c.line([(right + 16, 118), (right - 14, 128)], width=SCALE * 4)
    elif brows == "raised":
        c.arc(left - 16, 110, left + 16, 130, 200, 340, width=SCALE * 3)
        c.line([(right - 16, 124), (right + 16, 120)], width=SCALE * 3)
    elif brows == "thick":
        c.line([(left - 16, 124), (left + 14, 122)], width=SCALE * 6)
        c.line([(right - 14, 122), (right + 16, 124)], width=SCALE * 6)
    elif brows == "sad":
        c.line([(left - 16, 126), (left + 12, 118)], width=SCALE * 3)
        c.line([(right + 16, 126), (right - 12, 118)], width=SCALE * 3)


def glasses(c, kind):
    if kind == "round":
        c.ellipse(100, 124, 144, 164, fill=None, width=SCALE * 3)
        c.ellipse(156, 124, 200, 164, fill=None, width=SCALE * 3)
        c.line([(144, 142), (156, 142)], width=SCALE * 3)
    elif kind == "square":
        c.rect(98, 126, 146, 160, fill=None, width=SCALE * 3, radius=6)
        c.rect(154, 126, 202, 160, fill=None, width=SCALE * 3, radius=6)
        c.line([(146, 140), (154, 140)], width=SCALE * 3)
    elif kind == "half":
        c.arc(100, 118, 144, 164, 0, 180, width=SCALE * 3)
        c.arc(156, 118, 200, 164, 0, 180, width=SCALE * 3)
        c.line([(100, 141), (144, 141)], width=SCALE * 2)
        c.line([(156, 141), (200, 141)], width=SCALE * 2)
        c.line([(144, 141), (156, 141)], width=SCALE * 2)


def mouth(c, p):
    kind = p.get("mouth", "smile")
    if kind == "smile":
        c.arc(122, 164, 178, 202, 25, 155)
    elif kind == "flat":
        c.line([(130, 190), (172, 190)])
    elif kind == "frown":
        c.arc(126, 182, 174, 212, 205, 335)
    elif kind == "grin":
        c.draw.chord(c.s(118, 160, 182, 208), 0, 180, fill=WHITE, outline=BLACK, width=LINE)
        c.line([(122, 184), (178, 184)], width=SCALE * 2)
    elif kind == "smirk":
        c.line([(130, 192), (156, 192), (176, 180)])
    elif kind == "open":
        c.ellipse(136, 176, 164, 204, fill=BLACK, outline=None)


def facial_hair(c, kind, box):
    if kind == "mustache":
        c.poly([(150, 172), (118, 186), (112, 178), (134, 166), (166, 166), (188, 178), (182, 186)], fill=BLACK, outline=None)
    elif kind == "gray_mustache":
        c.poly([(150, 172), (116, 188), (110, 178), (134, 166), (166, 166), (190, 178), (184, 188)], fill=MID)
    elif kind == "stubble":
        x0, y0, x1, y1 = box
        cx, cy, rx, ry = (x0 + x1) / 2, (y0 + y1) / 2, (x1 - x0) / 2 - 8, (y1 - y0) / 2 - 8
        rng = random.Random(7)
        for _ in range(90):
            x, y = rng.randint(100, 200), rng.randint(172, 218)
            # Only dots inside the face, away from its outline, and none over the mouth.
            on_face = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1
            on_mouth = ((x - 150) / 38) ** 2 + ((y - 186) / 26) ** 2 <= 1
            if on_face and not on_mouth:
                c.ellipse(x - 1, y - 1, x + 1, y + 1, fill=DARK, outline=None)


def full_beard(c, box):
    x0, y0, x1, y1 = box
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    outer = []
    for deg in range(2, 179, 4):
        angle = math.radians(deg)
        outer.append((cx + rx * math.cos(angle), cy + ry * math.sin(angle)))
    inner = [(x0 + 16, cy + 8), (x0 + 30, cy + 26), (cx - 30, cy + 30), (cx - 16, cy + 24), (cx, cy + 28), (cx + 16, cy + 24), (cx + 30, cy + 30), (x1 - 30, cy + 26), (x1 - 16, cy + 8)]
    c.poly(outer + inner, fill=DARK)


def face_half_width(box, y):
    x0, y0, x1, y1 = box
    rx, ry = (x1 - x0) / 2, (y1 - y0) / 2
    dy = y - (y0 + y1) / 2
    return rx * math.sqrt(max(1 - (dy / ry) ** 2, 0))


def hair_cap(c, p, box, fill, edge="full", strokes=False):
    # edge: "full" outlines the cap, "arc" only its top curve (as a parting over long hair), None nothing.
    x0, y0, x1, y1 = box
    skin = p.get("skin", WHITE)
    cx = (x0 + x1) / 2
    outline = BLACK if edge == "full" else None
    if p.get("head") == "square":
        # Rounded on top like the face, so its corners never show past the hair.
        c.draw.rounded_rectangle(c.s(x0, y0 - 14, x1, y0 + 47), radius=48 * SCALE, corners=(True, True, False, False), fill=fill, outline=outline, width=LINE)
        cap = None
    else:
        half = face_half_width(box, y0 + 47)
        cap = (cx - half, y0 - 14, cx + half, y0 + 108)
        c.draw.chord(c.s(*cap), 180, 360, fill=fill, outline=outline, width=LINE)
        if edge == "arc":
            c.arc(*cap, 180, 360)
    if strokes and cap:
        # Combed lines that follow the curve of the hair; the forehead drawn next hides where they end.
        for inset in (9, 19):
            c.arc(cap[0] + inset, cap[1] + inset, cap[2] - inset, cap[3] - inset, 212, 292, fill=MID, width=SCALE * 2)
    rx = (x1 - x0) / 2 - 16
    top = y0 + 20
    c.ellipse(cx - rx, top, cx + rx, top + 90, fill=skin, outline=None)
    # The hairline ends where it meets the bottom edge of the cap (y0 + 47), not below it.
    lift = math.degrees(math.asin((top + 45 - (y0 + 47)) / 45))
    c.arc(cx - rx, top, cx + rx, top + 90, 180 + lift, 360 - lift)


def hair_behind(c, p, box):
    # Drawn before the body and the face, which cover what is behind the head.
    kind = p.get("hair")
    fill = p.get("hair_fill", BLACK)
    x0, y0, x1, y1 = box
    top = y0
    if kind == "balding":
        # Tufts above the ears; the face covers their inner half.
        for x in (x0, x1):
            c.ellipse(x - 14, 100, x + 14, 160, fill=fill)
    elif kind == "bob":
        c.draw.chord(c.s(x0 - 16, top - 14, x1 + 16, 236), 150, 390, fill=fill, outline=BLACK, width=LINE)
    elif kind == "long":
        c.rect(x0 - 16, top + 40, x0 + 22, 258, fill=fill, radius=16)
        c.rect(x1 - 22, top + 40, x1 + 16, 258, fill=fill, radius=16)
        c.draw.chord(c.s(x0 - 16, top - 14, x1 + 16, 170), 180, 360, fill=fill)
        c.arc(x0 - 16, top - 14, x1 + 16, 170, 180, 360)
    elif kind == "ponytail":
        c.ellipse(x1 - 6, 60, x1 + 42, 186, fill=fill)
    elif kind == "afro":
        c.ellipse(52, 22, 248, 172, fill=fill)


def hair_front(c, p, box):
    kind = p.get("hair")
    fill = p.get("hair_fill", BLACK)
    x0, y0, x1, y1 = box
    if kind == "bun":
        c.ellipse(116, 18, 184, 76, fill=fill)
        hair_cap(c, p, box, fill)
    elif kind in ("short", "ponytail"):
        hair_cap(c, p, box, fill)
    elif kind == "slick":
        hair_cap(c, p, box, fill, strokes=True)
    elif kind == "messy":
        # A wide mop that fills the space under the headphone band, with spikes sticking out above it. The
        # dome is cut flat at y 115, behind the ear cups.
        dome = (76, 36, 224, 194)
        cx, cy, rx, ry = 150, 115, 74, 79
        for i in range(9):
            mid = math.radians(200 + i * 17.5)
            spread = math.radians(8)
            tip = 16 + (i % 2) * 8
            c.poly([
                (cx + (rx - 8) * math.cos(mid - spread), cy + (ry - 8) * math.sin(mid - spread)),
                (cx + (rx + tip) * math.cos(mid), cy + (ry + tip) * math.sin(mid)),
                (cx + (rx - 8) * math.cos(mid + spread), cy + (ry - 8) * math.sin(mid + spread)),
            ], fill=fill)
        c.draw.chord(c.s(*dome), 180, 360, fill=fill)
        c.arc(*dome, 180, 360)
        hair_cap(c, p, box, fill, edge=None)
    elif kind == "long":
        hair_cap(c, p, box, fill, edge="arc")
    elif kind in ("bob", "afro"):
        hair_cap(c, p, box, fill, edge=None)
    elif kind == "curly":
        for cx, cy in [(92, 96), (116, 62), (150, 48), (184, 62), (208, 96), (84, 128), (216, 128)]:
            c.ellipse(cx - 26, cy - 26, cx + 26, cy + 26, fill=fill)
        c.ellipse(96, 68, 204, 122, fill=fill, outline=None)
    elif kind == "gray_wave":
        for cx, cy in [(100, 96), (126, 66), (156, 56), (186, 68), (204, 98)]:
            c.ellipse(cx - 24, cy - 22, cx + 24, cy + 22, fill=fill)
        c.ellipse(100, 74, 200, 118, fill=fill, outline=None)


def headwear(c, kind):
    if kind == "cap":
        c.draw.chord(c.s(82, 38, 218, 138), 180, 360, fill=DARK, outline=BLACK, width=LINE)
        c.poly([(82, 86), (218, 86), (248, 100), (82, 100)], fill=BLACK)
    elif kind == "helmet":
        c.draw.chord(c.s(72, 30, 228, 148), 180, 360, fill=WHITE, outline=BLACK, width=LINE)
        c.rect(58, 84, 242, 102, fill=WHITE, radius=8)
        c.rect(136, 28, 164, 84, fill=MID, radius=4)
    elif kind == "hardhat":
        c.draw.chord(c.s(78, 34, 222, 140), 180, 360, fill=LIGHT, outline=BLACK, width=LINE)
        c.rect(66, 84, 234, 100, fill=LIGHT, radius=8)
        c.line([(150, 34), (150, 84)])
    elif kind == "headphones":
        # A gray band and dark cups with black edges, so they stand out from dark hair.
        c.arc(72, 30, 228, 200, 180, 360, width=SCALE * 11)
        c.arc(72, 30, 228, 200, 181, 359, fill=MID, width=SCALE * 5)
        c.rect(62, 110, 94, 168, fill=DARK, radius=12)
        c.rect(206, 110, 238, 168, fill=DARK, radius=12)


def extras(c, p):
    x0, _, x1, _ = HEADS[p.get("head", "oval")]
    for kind in p.get("extras", []):
        if kind == "earrings":
            # The ears are centered on the sides of the head, from y 134 to 168.
            for x in (x0, x1):
                c.ellipse(x - 8, 164, x + 8, 182, fill=WHITE, width=SCALE * 3)
        elif kind == "necklace":
            # From one top corner of the neckline to the other, as if it went around the neck behind it.
            c.arc(120, 200, 180, 248, 0, 180, width=SCALE * 3)
            c.ellipse(144, 242, 156, 254, fill=BLACK, outline=None)
        elif kind == "freckles":
            for x, y in [(110, 166), (120, 172), (130, 166), (170, 166), (180, 172), (190, 166)]:
                c.ellipse(x - 2, y - 2, x + 2, y + 2, fill=BLACK, outline=None)
        elif kind == "phone":
            c.rect(216, 196, 268, 288, fill=BLACK, radius=8)
            c.rect(222, 206, 262, 276, fill=LIGHT, width=SCALE)
        elif kind == "wrench":
            c.line([(228, 304), (272, 216)], width=SCALE * 8)
            c.ellipse(258, 196, 292, 230, fill=None, width=SCALE * 5)
        elif kind == "calculator":
            c.rect(30, 214, 88, 304, fill=WHITE, radius=6)
            c.rect(38, 224, 80, 242, fill=LIGHT, width=SCALE)
            for y in (254, 272):
                for x in (42, 58, 74):
                    c.ellipse(x - 4, y - 4, x + 4, y + 4, fill=BLACK, outline=None)
        elif kind == "cake":
            c.rect(30, 256, 96, 304, fill=WHITE, radius=4)
            c.draw.chord(c.s(26, 236, 100, 276), 180, 360, fill=LIGHT, outline=BLACK, width=LINE)
        elif kind == "fork":
            c.line([(248, 304), (248, 200)], width=SCALE * 5)
            for x in (238, 248, 258):
                c.line([(x, 200), (x, 172)], width=SCALE * 3)
            c.line([(238, 200), (258, 200)], width=SCALE * 4)
        elif kind == "notes":
            c.ellipse(26, 60, 46, 78, fill=BLACK, outline=None)
            c.line([(44, 68), (44, 22), (66, 30)], width=SCALE * 3)
            c.ellipse(246, 80, 266, 98, fill=BLACK, outline=None)
            c.line([(264, 88), (264, 44), (284, 52)], width=SCALE * 3)
        elif kind == "clipboard":
            c.rect(24, 212, 92, 304, fill=WHITE, radius=4)
            c.rect(46, 204, 70, 220, fill=BLACK, width=SCALE)
            for y in (236, 254, 272):
                c.line([(36, y), (80, y)], width=SCALE * 2)
        elif kind == "suitcase":
            c.rect(218, 240, 284, 304, fill=DARK, radius=6)
            c.arc(236, 222, 266, 256, 180, 360, width=SCALE * 4)


def portrait(key, p):
    c = Canvas(PORTRAIT, PORTRAIT)
    background(c, p.get("bg"))
    box = HEADS[p.get("head", "oval")]
    hair_behind(c, p, box)
    body(c, p)
    face(c, p)
    hair_front(c, p, box)
    headwear(c, p.get("hat"))
    eyes(c, p)
    glasses(c, p.get("glasses"))
    if p.get("facial") == "beard":
        full_beard(c, box)
    # A mustache or a beard starts at about y 166, so the nose goes up to stay visible over it.
    nose = 12 if p.get("facial") in ("mustache", "gray_mustache", "beard") else 0
    c.arc(140, 150 - nose, 160, 176 - nose, 40, 160, width=SCALE * 3)
    mouth(c, p)
    facial_hair(c, p.get("facial"), box)
    extras(c, p)
    c.frame()
    c.save(os.path.join(ASSETS, "portraits", key + ".png"))


CHARACTERS = {
    "neide": dict(bg="dots", head="round", skin=WHITE, hair="bun", hair_fill=MID, eyes="narrow", brows="raised", glasses="half", mouth="smirk", body="dress", body_fill=LIGHT, extras=["necklace"]),
    "valdir": dict(bg="bricks", head="square", skin=LIGHT, hair="balding", hair_fill=MID, eyes="tired", brows="sad", mouth="flat", facial="gray_mustache", body="uniform", body_fill=MID),
    "marcia": dict(bg="grid", head="long", skin=WHITE, hair="bob", hair_fill=BLACK, eyes="lash", brows="raised", mouth="smirk", body="suit", body_fill=DARK, extras=["earrings", "clipboard"]),
    "rogerio": dict(bg="lines", head="long", skin=WHITE, hair="slick", hair_fill=BLACK, eyes="narrow", brows="raised", glasses="square", mouth="flat", body="suit", body_fill=BLACK),
    "kleber": dict(bg="bricks", head="round", skin=MID, hair=None, hat="cap", eyes="wide", mouth="grin", body="uniform", body_fill=DARK),
    "pri": dict(bg="gray", head="oval", skin=LIGHT, hair="ponytail", hair_fill=BLACK, eyes="tired", brows="sad", mouth="flat", body="uniform", body_fill=DARK, extras=["freckles"]),
    "jessica": dict(bg="sun", head="oval", skin=WHITE, hair="long", hair_fill=DARK, eyes="lash", mouth="grin", body="tshirt", body_fill=LIGHT, extras=["earrings", "phone"]),
    "ademir": dict(bg="grid", head="square", skin=WHITE, hair="short", hair_fill=LIGHT, eyes="narrow", brows="angry", mouth="frown", facial="mustache", body="collar", body_fill=LIGHT),
    "lurdes": dict(bg="dots", head="round", skin=MID, hair="curly", hair_fill=DARK, eyes="dot", mouth="smile", body="apron", body_fill=MID, extras=["cake", "earrings"]),
    "pedro": dict(bg="lines", head="oval", skin=WHITE, hair="messy", hair_fill=BLACK, eyes="tired", mouth="flat", body="tshirt", body_fill=DARK, hat="headphones", extras=["freckles"]),
    "carmem": dict(bg="dots", head="long", skin=LIGHT, hair="gray_wave", hair_fill=WHITE, eyes="narrow", brows="angry", glasses="round", mouth="frown", body="dress", body_fill=DARK, extras=["necklace"]),
    "rafael": dict(bg="sun", head="oval", skin=LIGHT, hair="slick", hair_fill=DARK, eyes="dot", brows="raised", mouth="grin", body="collar", body_fill=WHITE, extras=["suitcase"], facial="stubble"),
    "nelson": dict(bg="bricks", head="round", skin=LIGHT, hair=None, hat="hardhat", eyes="dot", mouth="smile", body="uniform", body_fill=MID, facial="mustache", extras=["wrench"]),
    "renata": dict(bg="grid", head="square", skin=MID, hair=None, hat="helmet", eyes="narrow", brows="angry", mouth="flat", body="uniform", body_fill=DARK, extras=["clipboard"]),
    "osmar": dict(bg="grid", head="long", skin=WHITE, hair="balding", hair_fill=DARK, eyes="wide", brows="sad", glasses="round", mouth="frown", body="suit", body_fill=MID, extras=["calculator"]),
    "yara": dict(bg="lines", head="oval", skin=DARK, hair="afro", hair_fill=BLACK, eyes="lash", mouth="smile", body="collar", body_fill=LIGHT, extras=["notes", "earrings"]),
    "beto": dict(bg="bricks", head="round", skin=LIGHT, hair="short", hair_fill=BLACK, eyes="dot", brows="thick", mouth="grin", facial="beard", body="apron", body_fill=DARK, extras=["fork"]),
}


def cat():
    c = Canvas(PORTRAIT, PORTRAIT)
    background(c, "dots")
    c.ellipse(40, 214, 260, 360, fill=DARK)
    # The collar is the head shape moved down, kept inside the body: the head drawn over it leaves a band
    # around the neck that ends where the head meets the body.
    band = Image.new("L", (c.w, c.h), 0)
    ImageDraw.Draw(band).ellipse(c.s(58, 78, 242, 252), fill=255)
    body_mask = Image.new("L", (c.w, c.h), 0)
    ImageDraw.Draw(body_mask).ellipse(c.s(43, 217, 257, 360), fill=255)
    c.image.paste(BLACK, (0, 0), ImageChops.multiply(band, body_mask))
    c.poly([(70, 110), (64, 28), (136, 72)], fill=DARK)
    c.poly([(230, 110), (236, 28), (164, 72)], fill=DARK)
    c.poly([(82, 96), (78, 50), (118, 76)], fill=LIGHT, width=SCALE * 2)
    c.poly([(218, 96), (222, 50), (182, 76)], fill=LIGHT, width=SCALE * 2)
    c.ellipse(58, 62, 242, 236, fill=DARK)
    for points in ([(150, 62), (140, 104), (160, 104)], [(100, 76), (106, 110), (120, 94)], [(200, 76), (194, 110), (180, 94)]):
        c.poly(points, fill=BLACK, outline=None)
    c.ellipse(92, 118, 138, 164, fill=WHITE, width=SCALE * 3)
    c.ellipse(162, 118, 208, 164, fill=WHITE, width=SCALE * 3)
    c.rect(109, 118, 121, 164, fill=BLACK, outline=None, radius=6)
    c.rect(179, 118, 191, 164, fill=BLACK, outline=None, radius=6)
    c.line([(90, 108), (138, 122)], width=SCALE * 4)
    c.line([(210, 108), (162, 122)], width=SCALE * 4)
    c.ellipse(116, 164, 184, 226, fill=WHITE, width=SCALE * 2)
    c.poly([(150, 182), (140, 172), (160, 172)], fill=BLACK, outline=None)
    c.line([(150, 182), (150, 196)], width=SCALE * 2)
    c.arc(130, 186, 150, 208, 20, 150, width=SCALE * 2)
    c.arc(150, 186, 170, 208, 30, 160, width=SCALE * 2)
    for y, dy in ((176, -8), (190, 0), (204, 8)):
        for x_start, x_end in ((116, 42), (184, 258)):
            c.line([(x_start, y), (x_end, y + dy)], fill=BLACK, width=SCALE * 5)
            c.line([(x_start, y), (x_end, y + dy)], fill=WHITE, width=SCALE * 2)
    c.ellipse(139, 246, 161, 268, fill=LIGHT, width=SCALE * 2)
    c.frame()
    c.save(os.path.join(ASSETS, "portraits", "almirante.png"))


def draw_building(width, height, damaged=False, seed=3):
    rng = random.Random(seed)
    c = Canvas(width, height)
    margin = width // 7
    roof = height // 8
    if not damaged:
        sx, sy = width - margin // 2 - 6, 46
        for i in range(0, 360, 30):
            angle = math.radians(i)
            c.line([(sx + 24 * math.cos(angle), sy + 24 * math.sin(angle)), (sx + 38 * math.cos(angle), sy + 38 * math.sin(angle))], width=SCALE * 3)
        c.ellipse(sx - 18, sy - 18, sx + 18, sy + 18, fill=WHITE)
    c.rect(margin, roof, width - margin, height - 4, fill=WHITE)
    c.rect(margin + 24, roof - 26, margin + 74, roof, fill=MID)
    ax = width - margin - 60
    c.line([(ax, roof), (ax, roof - 44)])
    for y, half in ((roof - 40, 22), (roof - 30, 16), (roof - 20, 10)):
        c.line([(ax - half, y - 6), (ax, y), (ax + half, y - 6)], width=SCALE * 2)
    floors, cols = 9, 4
    door_h = 60
    gw = (width - 2 * margin - 30) / cols
    gh = (height - roof - door_h - 34) / floors
    for row in range(floors):
        y = roof + 14 + row * gh
        for col in range(cols):
            x = margin + 16 + col * gw
            lit = rng.random() < 0.45
            fill = WHITE if lit else DARK
            c.rect(x + 3, y + 3, x + gw - 7, y + gh - 7, fill=fill, width=SCALE * 2)
            if lit and rng.random() < 0.5:
                c.line([(x + gw / 2 - 2, y + 3), (x + gw / 2 - 2, y + gh - 7)], width=SCALE)
    cx = width // 2
    c.rect(cx - 34, height - door_h - 4, cx + 34, height - 4, fill=MID)
    c.line([(cx, height - door_h - 4), (cx, height - 4)])
    c.rect(cx - 56, height - door_h - 22, cx + 56, height - door_h - 6, fill=WHITE, width=SCALE * 2)
    if damaged:
        crack = [(margin + 30, roof), (margin + 62, roof + 70), (margin + 40, roof + 120), (margin + 90, roof + 200), (margin + 64, roof + 260)]
        c.line(crack, width=SCALE * 5)
        crack = [(width - margin - 20, roof + 40), (width - margin - 70, roof + 110), (width - margin - 40, roof + 180), (width - margin - 90, roof + 250)]
        c.line(crack, width=SCALE * 4)
    return c


def building(path, width, height, damaged=False, seed=3):
    draw_building(width, height, damaged, seed).save(path)


def main():
    for key, params in CHARACTERS.items():
        portrait(key, params)
    cat()
    building(os.path.join(ASSETS, "building.png"), 420, 520)
    building(os.path.join(ASSETS, "building_damaged.png"), 420, 520, damaged=True)


if __name__ == "__main__":
    main()
