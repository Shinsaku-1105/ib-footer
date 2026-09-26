# 繋ぐベーグル — ベーグル紹介ページ

`index.html` をブラウザで開くだけで動きます（ビルド不要）。

## 演出
- **Hero**: SVG ブロブが変形、回転するリングテキスト、マウス追従のパララックス、クリックでベーグルが回転しゴマが飛び散る
- **Marquee**: 傾いた帯で味の名前とベーグルが流れる
- **Roll**: スクロールに合わせてベーグルが床を転がり、コピーが切り替わる
- **Hole**: ベーグル型にくり抜いたマスクが広がり、穴のむこうに写真がひらく
- **Process**: 線画アイコンが描かれていく
- **Lineup**: カードの 3D チルト、ホバーでベーグルがくるっと回る

## 写真を入れる（切り抜き）
写真が無い間は SVG で描いたベーグルが表示されます。

1. ベーグル写真を `assets/raw/<スロット名>.jpg` に置く
   - スロット名: `hero`, `roll`, `plain`, `sesame`, `blueberry`, `choco`, `cinnamon`, `matcha`
2. 店内などの背景写真を `assets/photo/scene.jpg` に置く（切り抜きなし）
3. 実行:
   ```sh
   pip install "rembg[cpu]" pillow
   python tools/cutout.py
   ```
   背景を除去した PNG が `assets/cutout/` に出力され、`assets/manifest.js` が更新されます。
