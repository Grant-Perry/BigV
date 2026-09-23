#!/usr/bin/env python3
"""Compose App Store screenshots from real BigVelo product shots."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path("/Users/gp./Xcode/BigV")
ASSETS = ROOT / "web" / "assets"
OUT = ROOT / "asc" / "screenshots"
FONT_DISPLAY = ROOT / "BigV" / "Design" / "Fonts" / "Outfit-ExtraBold.ttf"
HELV = Path("/System/Library/Fonts/Helvetica.ttc")

SIZES = {
    "iphone-6.9": (1290, 2796),
    "iphone-6.5": (1284, 2778),
    "iphone-6.3": (1206, 2622),
    "ipad-13": (2064, 2752),
}

GOLD = (240, 196, 138, 255)
CREAM = (255, 248, 230, 255)
INK = (255, 255, 255, 255)
INK_DIM = (255, 255, 255, 190)
VOID = (4, 4, 5, 255)
EMBER = (255, 122, 31, 255)


def font(path: Path, size: int, index: int = 0) -> ImageFont.FreeTypeFont:
    if path.suffix == ".ttc":
        return ImageFont.truetype(str(path), size=size, index=index)
    return ImageFont.truetype(str(path), size=size)


def cover(src: Image.Image, size: tuple[int, int]) -> Image.Image:
    tw, th = size
    sw, sh = src.size
    scale = max(tw / sw, th / sh)
    nw, nh = int(sw * scale), int(sh * scale)
    im = src.resize((nw, nh), Image.Resampling.LANCZOS)
    left = (nw - tw) // 2
    top = (nh - th) // 2
    return im.crop((left, top, left + tw, top + th))


def fit_width(src: Image.Image, width: int) -> Image.Image:
    scale = width / src.size[0]
    return src.resize((width, int(src.size[1] * scale)), Image.Resampling.LANCZOS)


def rounded(im: Image.Image, radius: int) -> Image.Image:
    im = im.convert("RGBA")
    mask = Image.new("L", im.size, 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle((0, 0, im.size[0], im.size[1]), radius=radius, fill=255)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    out.paste(im, mask=mask)
    return out


def plate_canvas(plate: Path, size: tuple[int, int], dark: float = 0.55) -> Image.Image:
    base = cover(Image.open(plate).convert("RGB"), size).convert("RGBA")
    wash = Image.new("RGBA", size, (4, 4, 5, int(255 * dark)))
    base = Image.alpha_composite(base, wash)
    vignette = Image.new("RGBA", size, (0, 0, 0, 0))
    vd = ImageDraw.Draw(vignette)
    for i in range(18):
        a = int(10 + i * 4)
        inset = int(min(size) * 0.01 * i)
        vd.rectangle((inset, inset, size[0] - inset, size[1] - inset), outline=(0, 0, 0, a), width=max(8, size[0] // 80))
    return Image.alpha_composite(base, vignette.filter(ImageFilter.GaussianBlur(24)))


def draw_wordmark(draw: ImageDraw.ImageDraw, xy: tuple[int, int], size: int) -> None:
    f = font(FONT_DISPLAY, size)
    draw.text(xy, "BigVelo", font=f, fill=GOLD)


def framed_phone(
    canvas: Image.Image,
    shot: Image.Image,
    *,
    top: int,
    width: int,
    radius: int,
) -> None:
    phone = fit_width(shot.convert("RGBA"), width)
    phone = rounded(phone, radius)
    shadow = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    x = (canvas.size[0] - phone.size[0]) // 2
    pad = max(18, width // 40)
    sd.rounded_rectangle(
        (x - 4, top + 16, x + phone.size[0] + 4, top + phone.size[1] + 28),
        radius=radius + 8,
        fill=(0, 0, 0, 140),
    )
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas.alpha_composite(shadow)
    bezel = Image.new("RGBA", (phone.size[0] + pad * 2, phone.size[1] + pad * 2), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bezel)
    bd.rounded_rectangle((0, 0, bezel.size[0] - 1, bezel.size[1] - 1), radius=radius + pad, fill=(18, 18, 20, 255))
    canvas.paste(bezel, (x - pad, top - pad), bezel)
    canvas.paste(phone, (x, top), phone)


def compose_phone(kind: str, w: int, h: int, spec: dict) -> Image.Image:
    canvas = plate_canvas(ASSETS / spec["plate"], (w, h), dark=spec.get("dark", 0.58))
    draw = ImageDraw.Draw(canvas)
    mark = max(54, int(w * 0.072))
    title = max(36, int(w * 0.048))
    draw_wordmark(draw, (int(w * 0.07), int(h * 0.045)), mark)
    tf = font(FONT_DISPLAY, title)
    # wrap caption
    caption = spec["caption"]
    draw.text((int(w * 0.07), int(h * 0.045) + mark + int(h * 0.008)), caption, font=tf, fill=CREAM)

    phone_w = int(w * spec.get("phone_w", 0.78))
    header = int(h * 0.045) + mark + title + int(h * 0.045)
    framed_phone(
        canvas,
        Image.open(ASSETS / spec["shot"]),
        top=header,
        width=phone_w,
        radius=max(36, phone_w // 16),
    )
    return canvas.convert("RGB")


def compose_hero(w: int, h: int) -> Image.Image:
    hero = ROOT / "asc" / "hero-splash.png"
    splash = Image.open(hero if hero.exists() else ASSETS / "onboard/splash.jpg").convert("RGB")
    return cover(splash, (w, h)).convert("RGB")


def compose_watch(src: Path, size: tuple[int, int]) -> Image.Image:
    im = cover(Image.open(src).convert("RGB"), size)
    return im


def compose_app_clip() -> Image.Image:
    w, h = 1800, 1200
    splash = cover(Image.open(ASSETS / "onboard/splash.jpg").convert("RGB"), (w, h)).convert("RGBA")
    fade = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fade)
    for i in range(h):
        a = int(160 * (i / h))
        fd.line((0, i, w, i), fill=(4, 4, 5, a))
    canvas = Image.alpha_composite(splash, fade)
    draw = ImageDraw.Draw(canvas)
    draw_wordmark(draw, (80, 820), 96)
    draw.text((80, 930), "The cockpit that rides with you.", font=font(FONT_DISPLAY, 42), fill=CREAM)
    return canvas.convert("RGB")


PHONE_SPECS = [
    {
        "slug": "02-radar-tape",
        "shot": "shots/dash-tape.jpg",
        "plate": "plates/radar-golden.jpg",
        "caption": "Cars land on the tape.",
        "dark": 0.62,
    },
    {
        "slug": "03-radar-alert",
        "shot": "shots/dash-radar.jpg",
        "plate": "plates/ember.jpg",
        "caption": "Feel the close.",
        "dark": 0.60,
    },
    {
        "slug": "04-day-glass",
        "shot": "shots/dash-speed.jpg",
        "plate": "plates/dawn.jpg",
        "caption": "Noon glass. Ice numbers.",
        "dark": 0.42,
        "phone_w": 0.80,
    },
    {
        "slug": "05-ride-to",
        "shot": "shots/route-rideto.jpg",
        "plate": "plates/lupine.jpg",
        "caption": "Ride To. Speak the turns.",
        "dark": 0.58,
    },
    {
        "slug": "06-the-ride-after",
        "shot": "shots/story-map.jpg",
        "plate": "plates/pine.jpg",
        "caption": "The ride after.",
        "dark": 0.58,
    },
    {
        "slug": "07-history",
        "shot": "shots/rides-list.jpg",
        "plate": "plates/olive.jpg",
        "caption": "History stays yours.",
        "dark": 0.58,
    },
]


def main() -> None:
    for folder in list(SIZES) + ["watch", "app-clip"]:
        (OUT / folder).mkdir(parents=True, exist_ok=True)

    for name, (w, h) in SIZES.items():
        hero = compose_hero(w, h)
        dest = OUT / name / f"01-on-the-bars.png"
        hero.save(dest, "PNG", optimize=True)
        print("wrote", dest)

        for spec in PHONE_SPECS:
            if name == "ipad-13":
                spec = {**spec, "phone_w": 0.46}
            im = compose_phone(name, w, h, spec)
            dest = OUT / name / f"{spec['slug']}.png"
            im.save(dest, "PNG", optimize=True)
            print("wrote", dest)

        # Keep BigVelo paywall — already a real-sized still of the offer
        paywall = ROOT / "asc" / "BigVeloPlus-review-screenshot.png"
        if paywall.exists():
            spec = {
                "slug": "08-keep-bigvelo",
                "shot": None,
                "plate": "plates/singletrack.jpg",
                "caption": "Thirty days. Then keep it.",
                "dark": 0.62,
                "phone_w": 0.46 if name == "ipad-13" else 0.78,
            }
            canvas = plate_canvas(ASSETS / spec["plate"], (w, h), dark=spec["dark"])
            draw = ImageDraw.Draw(canvas)
            mark = max(54, int(w * 0.072))
            title = max(36, int(w * 0.048))
            draw_wordmark(draw, (int(w * 0.07), int(h * 0.045)), mark)
            draw.text(
                (int(w * 0.07), int(h * 0.045) + mark + int(h * 0.008)),
                spec["caption"],
                font=font(FONT_DISPLAY, title),
                fill=CREAM,
            )
            header = int(h * 0.045) + mark + title + int(h * 0.045)
            framed_phone(
                canvas,
                Image.open(paywall),
                top=header,
                width=int(w * spec["phone_w"]),
                radius=max(36, int(w * spec["phone_w"]) // 16),
            )
            dest = OUT / name / "08-keep-bigvelo.png"
            canvas.convert("RGB").save(dest, "PNG", optimize=True)
            print("wrote", dest)

    watch_size = (416, 496)
    compose_watch(ASSETS / "shots/watch-live.jpg", watch_size).save(
        OUT / "watch" / "01-recording.png", "PNG", optimize=True
    )
    compose_watch(ASSETS / "shots/watch-ultra-product.jpg", watch_size).save(
        OUT / "watch" / "02-wrist.png", "PNG", optimize=True
    )
    print("wrote watch")

    compose_app_clip().save(OUT / "app-clip" / "card-1800x1200.png", "PNG", optimize=True)
    print("wrote app clip card")


if __name__ == "__main__":
    main()
