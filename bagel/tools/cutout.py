"""写真のベーグルを背景から切り抜いて、ページに反映するスクリプト。

使い方:
    pip install "rembg[cpu]" pillow
    python tools/cutout.py

  assets/raw/<key>.jpg|png|webp  → 背景を除去して assets/cutout/<key>.png に保存
  assets/photo/scene.jpg         → 「穴からひらく」セクションの背景写真（切り抜きなし）

  <key> はページ内のスロット名:
    hero, roll, plain, sesame, blueberry, choco, cinnamon, matcha

最後に assets/manifest.js を書き換えるので、ブラウザを再読み込みすれば反映されます。
"""
import json
from pathlib import Path

from PIL import Image
from rembg import new_session, remove

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "assets" / "raw"
OUT = ROOT / "assets" / "cutout"
PHOTO = ROOT / "assets" / "photo"
EXTS = {".jpg", ".jpeg", ".png", ".webp"}
MAX_SIDE = 1200


def cut(src: Path, session) -> Path:
    img = Image.open(src).convert("RGB")
    img.thumbnail((2400, 2400))
    out = remove(img, session=session, post_process_mask=True)
    bbox = out.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    if bbox:
        out = out.crop(bbox)
    # 正方形キャンバスの中央に配置（ページ側のレイアウトが崩れないように）
    side = max(out.size)
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(out, ((side - out.width) // 2, (side - out.height) // 2))
    canvas.thumbnail((MAX_SIDE, MAX_SIDE))
    dst = OUT / f"{src.stem}.png"
    canvas.save(dst, optimize=True)
    return dst


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    session = new_session("isnet-general-use")
    cutouts = {}
    for src in sorted(RAW.iterdir()):
        if src.suffix.lower() not in EXTS:
            continue
        dst = cut(src, session)
        cutouts[src.stem] = dst.relative_to(ROOT).as_posix()
        print(f"cutout: {src.name} -> {cutouts[src.stem]}")

    photos = {
        p.stem: p.relative_to(ROOT).as_posix()
        for p in sorted(PHOTO.iterdir())
        if p.suffix.lower() in EXTS
    }

    manifest = ROOT / "assets" / "manifest.js"
    manifest.write_text(
        "// tools/cutout.py が自動生成します。手で編集しても OK。\n"
        "// 登録されていないキーは SVG のベーグルグラフィックで表示されます。\n"
        "window.BAGEL_ASSETS = "
        + json.dumps({"cutouts": cutouts, "photos": photos}, ensure_ascii=False, indent=2)
        + ";\n",
        encoding="utf-8",
    )
    print(f"manifest updated: {len(cutouts)} cutouts, {len(photos)} photos")


if __name__ == "__main__":
    main()
