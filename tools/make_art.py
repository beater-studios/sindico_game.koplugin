import math
import os
import random

from PIL import Image, ImageDraw

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


def body(c, p):
    style = p.get("body", "shirt")
    fill = p.get("body_fill", MID)
    c.poly([(30, 300), (45, 245), (105, 222), (195, 222), (255, 245), (270, 300)], fill=fill)
    if style == "suit":
        c.poly([(150, 300), (118, 225), (182, 225)], fill=WHITE)
        c.poly([(150, 300), (138, 240), (150, 228), (162, 240)], fill=BLACK, width=SCALE)
    elif style == "uniform":
        c.line([(150, 226), (150, 300)])
        c.rect(180, 256, 222, 282, fill=WHITE, width=SCALE * 2)
        c.line([(188, 264), (214, 264)], width=SCALE * 2)
        c.line([(188, 273), (208, 273)], width=SCALE * 2)
    elif style == "collar":
        c.poly([(118, 224), (150, 256), (132, 272), (106, 232)], fill=WHITE)
        c.poly([(182, 224), (150, 256), (168, 272), (194, 232)], fill=WHITE)
    elif style == "apron":
        c.poly([(100, 300), (112, 240), (188, 240), (200, 300)], fill=WHITE)
        c.line([(112, 240), (120, 222)])
        c.line([(188, 240), (180, 222)])
    elif style == "tshirt":
        c.arc(116, 200, 184, 256, 20, 160)
    elif style == "dress":
        c.arc(106, 190, 194, 262, 20, 160)
        for x in (120, 150, 180):
            c.ellipse(x - 5, 268, x + 5, 278, fill=WHITE, width=SCALE * 2)


def face(c, p):
    x0, y0, x1, y1 = {
        "oval": (88, 62, 212, 226),
        "round": (80, 72, 220, 222),
        "long": (96, 52, 204, 230),
        "square": (84, 66, 216, 224),
    }[p.get("head", "oval")]
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


def facial_hair(c, kind):
    if kind == "mustache":
        c.poly([(150, 172), (118, 186), (112, 178), (134, 166), (166, 166), (188, 178), (182, 186)], fill=BLACK, outline=None)
    elif kind == "gray_mustache":
        c.poly([(150, 172), (116, 188), (110, 178), (134, 166), (166, 166), (190, 178), (184, 188)], fill=MID)
    elif kind == "stubble":
        rng = random.Random(7)
        for _ in range(70):
            x, y = rng.randint(100, 200), rng.randint(172, 218)
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


def hair_cap(c, p, box, fill, outline=BLACK):
    x0, y0, x1, y1 = box
    skin = p.get("skin", WHITE)
    c.draw.chord(c.s(x0 - 4, y0 - 14, x1 + 4, y0 + 108), 180, 360, fill=fill, outline=outline, width=LINE)
    rx = (x1 - x0) / 2 - 16
    cx = (x0 + x1) / 2
    top = y0 + 20
    c.ellipse(cx - rx, top, cx + rx, top + 90, fill=skin, outline=None)
    c.arc(cx - rx, top, cx + rx, top + 90, 190, 350)


def hair(c, p, box):
    kind = p.get("hair")
    fill = p.get("hair_fill", BLACK)
    x0, y0, x1, y1 = box
    top = y0
    if kind == "bun":
        c.ellipse(116, 18, 184, 76, fill=fill)
        hair_cap(c, p, box, fill)
    elif kind == "balding":
        c.draw.chord(c.s(x0 - 6, 90, x0 + 44, 170), 90, 270, fill=fill, outline=BLACK, width=LINE)
        c.draw.chord(c.s(x1 - 44, 90, x1 + 6, 170), 270, 90, fill=fill, outline=BLACK, width=LINE)
    elif kind == "short":
        hair_cap(c, p, box, fill)
    elif kind == "slick":
        hair_cap(c, p, box, fill)
        for dx in (0, 22, 44):
            c.line([(x0 + 24 + dx, top + 2), (x0 + 44 + dx, top + 20)], fill=MID, width=SCALE * 2)
    elif kind == "side":
        hair_cap(c, p, box, fill)
        c.line([(x0 + 40, top - 8), (x0 + 30, top + 26)], width=SCALE * 3)
    elif kind == "bob":
        c.draw.chord(c.s(x0 - 16, top - 14, x1 + 16, 236), 150, 390, fill=fill, outline=BLACK, width=LINE)
    elif kind == "long":
        c.rect(x0 - 16, top + 40, x0 + 22, 258, fill=fill, radius=16)
        c.rect(x1 - 22, top + 40, x1 + 16, 258, fill=fill, radius=16)
        c.draw.chord(c.s(x0 - 16, top - 14, x1 + 16, 170), 180, 360, fill=fill, outline=BLACK, width=LINE)
    elif kind == "ponytail":
        c.ellipse(x1 - 6, 60, x1 + 42, 186, fill=fill)
        c.draw.chord(c.s(x0 - 4, top - 12, x1 + 4, 146), 180, 360, fill=fill, outline=BLACK, width=LINE)
    elif kind == "curly":
        for cx, cy in [(92, 96), (116, 62), (150, 48), (184, 62), (208, 96), (84, 128), (216, 128)]:
            c.ellipse(cx - 26, cy - 26, cx + 26, cy + 26, fill=fill)
        c.ellipse(96, 68, 204, 122, fill=fill, outline=None)
    elif kind == "afro":
        c.ellipse(52, 22, 248, 172, fill=fill)
    elif kind == "messy":
        for i, x in enumerate(range(int(x0), int(x1), 18)):
            c.poly([(x, top + 34), (x + 8, top - 18 - (i % 2) * 10), (x + 22, top + 34)], fill=fill)
        c.draw.chord(c.s(x0 - 2, top - 4, x1 + 2, 130), 180, 360, fill=fill, outline=None)
    elif kind == "gray_wave":
        for cx, cy in [(100, 96), (126, 66), (156, 56), (186, 68), (204, 98)]:
            c.ellipse(cx - 24, cy - 22, cx + 24, cy + 22, fill=LIGHT)
        c.ellipse(100, 74, 200, 118, fill=LIGHT, outline=None)


def headwear(c, kind):
    if kind == "cap":
        c.draw.chord(c.s(82, 34, 218, 134), 180, 360, fill=DARK, outline=BLACK, width=LINE)
        c.poly([(82, 86), (218, 86), (248, 100), (82, 100)], fill=BLACK)
    elif kind == "helmet":
        c.draw.chord(c.s(72, 26, 228, 144), 180, 360, fill=WHITE, outline=BLACK, width=LINE)
        c.rect(58, 84, 242, 102, fill=WHITE, radius=8)
        c.rect(136, 28, 164, 84, fill=MID, radius=4)
    elif kind == "hardhat":
        c.draw.chord(c.s(78, 30, 222, 136), 180, 360, fill=LIGHT, outline=BLACK, width=LINE)
        c.rect(66, 84, 234, 100, fill=LIGHT, radius=8)
        c.line([(150, 30), (150, 84)])
    elif kind == "headphones":
        c.arc(72, 30, 228, 200, 180, 360, width=SCALE * 8)
        c.rect(62, 118, 94, 176, fill=BLACK, radius=12)
        c.rect(206, 118, 238, 176, fill=BLACK, radius=12)


def extras(c, p):
    for kind in p.get("extras", []):
        if kind == "earrings":
            c.ellipse(78, 168, 94, 186, fill=WHITE, width=SCALE * 3)
            c.ellipse(206, 168, 222, 186, fill=WHITE, width=SCALE * 3)
        elif kind == "necklace":
            c.arc(106, 196, 194, 262, 25, 155, width=SCALE * 3)
            c.ellipse(142, 252, 158, 268, fill=BLACK, outline=None)
        elif kind == "wrinkles":
            c.line([(112, 112), (140, 110)], width=SCALE * 2)
            c.line([(160, 110), (188, 112)], width=SCALE * 2)
        elif kind == "freckles":
            for x, y in [(110, 166), (120, 172), (130, 166), (170, 166), (180, 172), (190, 166)]:
                c.ellipse(x - 2, y - 2, x + 2, y + 2, fill=BLACK, outline=None)
        elif kind == "pencil":
            c.line([(208, 96), (232, 150)], width=SCALE * 5)
        elif kind == "phone":
            c.rect(216, 196, 268, 288, fill=BLACK, radius=8)
            c.rect(222, 206, 262, 276, fill=LIGHT, width=SCALE)
        elif kind == "key":
            c.ellipse(36, 250, 62, 276, fill=None, width=SCALE * 4)
            c.line([(58, 266), (90, 290)], width=SCALE * 4)
        elif kind == "wrench":
            c.line([(232, 296), (272, 216)], width=SCALE * 8)
            c.ellipse(258, 196, 292, 230, fill=None, width=SCALE * 5)
        elif kind == "calculator":
            c.rect(30, 214, 88, 296, fill=WHITE, radius=6)
            c.rect(38, 224, 80, 242, fill=LIGHT, width=SCALE)
            for y in (254, 272):
                for x in (42, 58, 74):
                    c.ellipse(x - 4, y - 4, x + 4, y + 4, fill=BLACK, outline=None)
        elif kind == "cake":
            c.rect(30, 256, 96, 296, fill=WHITE, radius=4)
            c.draw.chord(c.s(26, 236, 100, 276), 180, 360, fill=LIGHT, outline=BLACK, width=LINE)
        elif kind == "fork":
            c.line([(248, 296), (248, 200)], width=SCALE * 5)
            for x in (238, 248, 258):
                c.line([(x, 200), (x, 172)], width=SCALE * 3)
            c.line([(238, 200), (258, 200)], width=SCALE * 4)
        elif kind == "notes":
            c.ellipse(26, 60, 46, 78, fill=BLACK, outline=None)
            c.line([(44, 68), (44, 22), (66, 30)], width=SCALE * 3)
            c.ellipse(246, 80, 266, 98, fill=BLACK, outline=None)
            c.line([(264, 88), (264, 44), (284, 52)], width=SCALE * 3)
        elif kind == "clipboard":
            c.rect(24, 212, 92, 298, fill=WHITE, radius=4)
            c.rect(46, 204, 70, 220, fill=BLACK, width=SCALE)
            for y in (236, 254, 272):
                c.line([(36, y), (80, y)], width=SCALE * 2)
        elif kind == "suitcase":
            c.rect(218, 240, 284, 296, fill=DARK, radius=6)
            c.arc(236, 222, 266, 256, 180, 360, width=SCALE * 4)


def portrait(key, p):
    c = Canvas(PORTRAIT, PORTRAIT)
    background(c, p.get("bg"))
    if p.get("hair") in ("afro", "long", "ponytail", "bob"):
        box = {"oval": (88, 62, 212, 226), "round": (80, 72, 220, 222), "long": (96, 52, 204, 230), "square": (84, 66, 216, 224)}[p.get("head", "oval")]
        hair(c, p, box)
    body(c, p)
    box = face(c, p)
    if p.get("hair") not in ("afro", "long", "ponytail", "bob"):
        hair(c, p, box)
    elif p.get("hair") in ("long", "bob", "ponytail"):
        hair_cap(c, p, box, p.get("hair_fill", BLACK))
    elif p.get("hair") == "afro":
        hair_cap(c, p, box, p.get("hair_fill", BLACK), outline=None)
    headwear(c, p.get("hat"))
    eyes(c, p)
    glasses(c, p.get("glasses"))
    if p.get("facial") == "beard":
        full_beard(c, box)
    c.arc(140, 150, 160, 176, 40, 160, width=SCALE * 3)
    mouth(c, p)
    facial_hair(c, p.get("facial"))
    extras(c, p)
    c.rect(1, 1, PORTRAIT - 2, PORTRAIT - 2, fill=None, width=SCALE * 3)
    c.save(os.path.join(ASSETS, "portraits", key + ".png"))


CHARACTERS = {
    "neide": dict(bg="dots", head="round", skin=WHITE, hair="bun", hair_fill=MID, eyes="narrow", brows="raised", glasses="half", mouth="smirk", body="dress", body_fill=LIGHT, extras=["necklace", "wrinkles"]),
    "valdir": dict(bg="bricks", head="square", skin=LIGHT, hair="balding", hair_fill=MID, eyes="tired", brows="sad", mouth="flat", facial="gray_mustache", body="uniform", body_fill=MID, extras=["key", "wrinkles"]),
    "marcia": dict(bg="grid", head="long", skin=WHITE, hair="bob", hair_fill=BLACK, eyes="lash", brows="raised", mouth="smirk", body="suit", body_fill=DARK, extras=["earrings", "clipboard"]),
    "rogerio": dict(bg="lines", head="long", skin=WHITE, hair="slick", hair_fill=BLACK, eyes="narrow", brows="raised", glasses="square", mouth="flat", body="suit", body_fill=BLACK),
    "kleber": dict(bg="bricks", head="round", skin=MID, hair=None, hat="cap", eyes="wide", mouth="grin", body="uniform", body_fill=DARK),
    "pri": dict(bg="gray", head="oval", skin=LIGHT, hair="ponytail", hair_fill=BLACK, eyes="tired", brows="sad", mouth="flat", body="uniform", body_fill=DARK, extras=["freckles"]),
    "jessica": dict(bg="sun", head="oval", skin=WHITE, hair="long", hair_fill=DARK, eyes="lash", mouth="grin", body="tshirt", body_fill=LIGHT, extras=["earrings", "phone"]),
    "ademir": dict(bg="grid", head="square", skin=WHITE, hair="side", hair_fill=LIGHT, eyes="narrow", brows="angry", mouth="frown", facial="mustache", body="collar", body_fill=LIGHT, extras=["wrinkles"]),
    "lurdes": dict(bg="dots", head="round", skin=MID, hair="curly", hair_fill=DARK, eyes="dot", mouth="smile", body="apron", body_fill=MID, extras=["cake", "earrings"]),
    "pedro": dict(bg="lines", head="oval", skin=WHITE, hair="messy", hair_fill=BLACK, eyes="tired", mouth="flat", body="tshirt", body_fill=DARK, hat="headphones", extras=["freckles"]),
    "carmem": dict(bg="dots", head="long", skin=LIGHT, hair="gray_wave", eyes="narrow", brows="angry", glasses="round", mouth="frown", body="dress", body_fill=DARK, extras=["necklace", "wrinkles"]),
    "rafael": dict(bg="sun", head="oval", skin=LIGHT, hair="slick", hair_fill=DARK, eyes="dot", brows="raised", mouth="grin", body="collar", body_fill=WHITE, extras=["suitcase"], facial="stubble"),
    "nelson": dict(bg="bricks", head="round", skin=LIGHT, hair=None, hat="hardhat", eyes="dot", mouth="smile", body="uniform", body_fill=MID, facial="mustache", extras=["wrench"]),
    "renata": dict(bg="grid", head="square", skin=MID, hair=None, hat="helmet", eyes="narrow", brows="angry", mouth="flat", body="uniform", body_fill=BLACK, extras=["clipboard"]),
    "osmar": dict(bg="grid", head="long", skin=WHITE, hair="balding", hair_fill=DARK, eyes="wide", brows="sad", glasses="round", mouth="frown", body="suit", body_fill=MID, extras=["calculator", "pencil"]),
    "yara": dict(bg="lines", head="oval", skin=DARK, hair="afro", hair_fill=BLACK, eyes="lash", mouth="smile", body="collar", body_fill=LIGHT, extras=["notes", "earrings"]),
    "beto": dict(bg="bricks", head="round", skin=LIGHT, hair="short", hair_fill=BLACK, eyes="dot", brows="thick", mouth="grin", facial="beard", body="apron", body_fill=DARK, extras=["fork"]),
}


def cat():
    c = Canvas(PORTRAIT, PORTRAIT)
    background(c, "dots")
    c.ellipse(40, 214, 260, 360, fill=DARK)
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
    c.rect(96, 232, 204, 250, fill=BLACK, radius=8)
    c.ellipse(138, 244, 162, 268, fill=LIGHT, width=SCALE * 2)
    c.rect(1, 1, PORTRAIT - 2, PORTRAIT - 2, fill=None, width=SCALE * 3)
    c.save(os.path.join(ASSETS, "portraits", "almirante.png"))


def building(path, width, height, damaged=False, seed=3):
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
    c.save(path)


def main():
    for key, params in CHARACTERS.items():
        portrait(key, params)
    cat()
    building(os.path.join(ASSETS, "building.png"), 420, 520)
    building(os.path.join(ASSETS, "building_damaged.png"), 420, 520, damaged=True)


if __name__ == "__main__":
    main()
