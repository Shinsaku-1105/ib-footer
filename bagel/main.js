(() => {
  const reduceMotion = matchMedia('(prefers-reduced-motion: reduce)').matches;
  const assets = window.BAGEL_ASSETS || { cutouts: {}, photos: {} };
  const clamp = (v, a = 0, b = 1) => Math.min(b, Math.max(a, v));
  const lerp = (a, b, t) => a + (b - a) * t;
  const easeInOut = t => (t < .5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2);

  /* ------------------------------------------------------------
   * 1. SVG ベーグル生成（写真が無いときのグラフィック）
   * ---------------------------------------------------------- */
  const PALETTES = {
    plain:     { light: '#F6CD92', mid: '#DE9A52', dark: '#A65A22' },
    sesame:    { light: '#F4C98C', mid: '#D8914A', dark: '#9E5520', topping: 'seed' },
    blueberry: { light: '#EFCBA3', mid: '#CF9565', dark: '#8E5634', topping: 'berry' },
    choco:     { light: '#9B6343', mid: '#6E3E25', dark: '#3E2012', topping: 'chip' },
    cinnamon:  { light: '#EDB67E', mid: '#C77E42', dark: '#86461C', topping: 'swirl' },
    matcha:    { light: '#D6DFA2', mid: '#A9BB6C', dark: '#6A7C3C', topping: 'bean' },
  };

  function rng(seed) {
    return () => {
      seed |= 0; seed = seed + 0x6D2B79F5 | 0;
      let t = Math.imul(seed ^ seed >>> 15, 1 | seed);
      t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t;
      return ((t ^ t >>> 14) >>> 0) / 4294967296;
    };
  }

  // 手でまるめた感じの、少しいびつな円
  function wobblyCircle(r, amp, rand, n = 64) {
    const k1 = rand() * 6, k2 = rand() * 6;
    let d = '';
    for (let i = 0; i <= n; i++) {
      const a = (i / n) * Math.PI * 2;
      const rr = r + Math.sin(a * 3 + k1) * amp + Math.sin(a * 5 + k2) * amp * .5;
      d += (i ? 'L' : 'M') + (Math.cos(a) * rr).toFixed(2) + ',' + (Math.sin(a) * rr).toFixed(2);
    }
    return d + 'Z';
  }

  let uid = 0;
  function bagelSVG(kind) {
    const p = PALETTES[kind] || PALETTES.plain;
    const id = 'bg' + (++uid);
    const rand = rng(kind.length * 997 + uid * 31);
    const outer = wobblyCircle(96, 3, rand);
    const inner = wobblyCircle(25, 2, rand);

    let top = '';
    const inRing = () => {
      const a = rand() * Math.PI * 2, r = 40 + rand() * 46;
      return [Math.cos(a) * r, Math.sin(a) * r, a];
    };
    if (p.topping === 'seed') {
      for (let i = 0; i < 90; i++) {
        const [x, y] = inRing();
        top += `<ellipse cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" rx="3.4" ry="1.7" transform="rotate(${(rand() * 180).toFixed(0)} ${x.toFixed(1)} ${y.toFixed(1)})" fill="#FFF4DA" stroke="#C78A4B" stroke-width=".5"/>`;
      }
    } else if (p.topping === 'berry') {
      for (let i = 0; i < 18; i++) {
        const [x, y] = inRing();
        top += `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${(4 + rand() * 3).toFixed(1)}" fill="#5B3A78" opacity=".85"/>`;
      }
    } else if (p.topping === 'chip') {
      for (let i = 0; i < 26; i++) {
        const [x, y] = inRing();
        top += `<rect x="${(x - 3).toFixed(1)}" y="${(y - 3).toFixed(1)}" width="6" height="6" rx="1.5" transform="rotate(${(rand() * 90).toFixed(0)} ${x.toFixed(1)} ${y.toFixed(1)})" fill="#24110A"/>`;
      }
    } else if (p.topping === 'swirl') {
      for (let i = 0; i < 7; i++) {
        const a = (i / 7) * Math.PI * 2 + rand() * .3;
        const x1 = Math.cos(a) * 44, y1 = Math.sin(a) * 44;
        const x2 = Math.cos(a + .7) * 82, y2 = Math.sin(a + .7) * 82;
        const cx = Math.cos(a + .1) * 78, cy = Math.sin(a + .1) * 78;
        top += `<path d="M${x1.toFixed(1)},${y1.toFixed(1)} Q${cx.toFixed(1)},${cy.toFixed(1)} ${x2.toFixed(1)},${y2.toFixed(1)}" stroke="#7A3A14" stroke-width="4" fill="none" stroke-linecap="round" opacity=".7"/>`;
      }
      for (let i = 0; i < 10; i++) {
        const [x, y] = inRing();
        top += `<ellipse cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" rx="4.5" ry="3" fill="#4A2412"/>`;
      }
    } else if (p.topping === 'bean') {
      for (let i = 0; i < 14; i++) {
        const [x, y] = inRing();
        top += `<ellipse cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" rx="4" ry="3" fill="#F6EFD8" opacity=".9"/>`;
      }
    }

    return `<svg viewBox="-110 -110 220 220" aria-hidden="true">
      <defs>
        <radialGradient id="${id}r" cx="0" cy="0" r="96" gradientUnits="userSpaceOnUse">
          <stop offset=".26" stop-color="${p.dark}"/>
          <stop offset=".42" stop-color="${p.mid}"/>
          <stop offset=".62" stop-color="${p.light}"/>
          <stop offset=".86" stop-color="${p.mid}"/>
          <stop offset="1" stop-color="${p.dark}"/>
        </radialGradient>
        <linearGradient id="${id}l" x1="-1" y1="-1" x2="1" y2="1" gradientUnits="objectBoundingBox">
          <stop offset="0" stop-color="#fff" stop-opacity=".35"/>
          <stop offset=".55" stop-color="#fff" stop-opacity="0"/>
          <stop offset="1" stop-color="#000" stop-opacity=".18"/>
        </linearGradient>
        <filter id="${id}b"><feGaussianBlur stdDeviation="4"/></filter>
      </defs>
      <path d="${outer} ${inner}" fill-rule="evenodd" fill="url(#${id}r)"/>
      <path d="${outer} ${inner}" fill-rule="evenodd" fill="url(#${id}l)"/>
      <path d="M-50,-40 A64,64 0 0 1 20,-62" stroke="#fff" stroke-opacity=".45" stroke-width="9" fill="none" stroke-linecap="round" filter="url(#${id}b)"/>
      ${top}
    </svg>`;
  }

  // 写真の切り抜き（assets/manifest.js に登録されたもの）があれば差し替え、無ければ SVG
  document.querySelectorAll('img.cutout').forEach(img => {
    const src = assets.cutouts && assets.cutouts[img.dataset.cutout];
    if (src) {
      img.src = src;
      img.removeAttribute('data-bagel');
      return;
    }
    const span = document.createElement('span');
    span.dataset.bagel = img.dataset.bagel || 'plain';
    span.setAttribute('role', 'img');
    span.setAttribute('aria-label', img.alt || '');
    span.style.width = '100%';
    span.style.aspectRatio = '1';
    img.replaceWith(span);
  });
  document.querySelectorAll('[data-bagel]').forEach(el => {
    if (el.tagName === 'IMG') return;
    el.innerHTML = bagelSVG(el.dataset.bagel);
  });

  // 背景写真
  const holePhoto = document.getElementById('holePhoto');
  const scene = assets.photos && assets.photos.scene;
  if (scene) {
    holePhoto.querySelector('img').src = scene;
    holePhoto.classList.add('has-photo');
  }

  // CTA のベーグルリング
  document.querySelectorAll('.cta-ring span').forEach((s, i) => s.style.setProperty('--i', i));

  requestAnimationFrame(() => document.body.classList.add('is-loaded'));

  /* ------------------------------------------------------------
   * 2. ヒーロー: マウスでパララックス & クリックでポップ
   * ---------------------------------------------------------- */
  const stage = document.getElementById('heroStage');
  const layers = [...stage.querySelectorAll('.parallax')];
  let mx = 0, my = 0, cx = 0, cy = 0;
  if (!reduceMotion) {
    window.addEventListener('pointermove', e => {
      mx = e.clientX / innerWidth - .5;
      my = e.clientY / innerHeight - .5;
    });
  }
  const heroBagel = stage.querySelector('.hero-bagel');
  stage.addEventListener('click', () => {
    heroBagel.classList.remove('pop');
    void heroBagel.offsetWidth;
    heroBagel.classList.add('pop');
  });

  /* ------------------------------------------------------------
   * 3. クリックでゴマが飛び散る
   * ---------------------------------------------------------- */
  const canvas = document.getElementById('seeds');
  const ctx = canvas.getContext('2d');
  let dpr = 1, parts = [];
  function resize() {
    dpr = Math.min(2, devicePixelRatio || 1);
    canvas.width = innerWidth * dpr;
    canvas.height = innerHeight * dpr;
  }
  resize();
  addEventListener('resize', resize);

  const COLORS = ['#FFF4DA', '#FFF4DA', '#F6A265', '#E0752F', '#3B2A20'];
  function burst(x, y, n = 28) {
    if (reduceMotion) return;
    for (let i = 0; i < n; i++) {
      const a = Math.random() * Math.PI * 2;
      const s = 4 + Math.random() * 9;
      parts.push({
        x, y,
        vx: Math.cos(a) * s,
        vy: Math.sin(a) * s - 6,
        r: Math.random() * Math.PI,
        vr: (Math.random() - .5) * .4,
        life: 1,
        c: COLORS[(Math.random() * COLORS.length) | 0],
        seed: Math.random() < .6,
      });
    }
  }
  addEventListener('click', e => {
    if (e.target.closest('a, button')) return;
    burst(e.clientX, e.clientY, e.target.closest('#heroStage') ? 48 : 22);
  });

  function drawParts() {
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, innerWidth, innerHeight);
    parts = parts.filter(p => p.life > 0 && p.y < innerHeight + 40);
    for (const p of parts) {
      p.vy += .45; p.vx *= .985;
      p.x += p.vx; p.y += p.vy; p.r += p.vr;
      p.life -= .008;
      ctx.save();
      ctx.globalAlpha = clamp(p.life * 1.5);
      ctx.translate(p.x, p.y);
      ctx.rotate(p.r);
      ctx.fillStyle = p.c;
      ctx.beginPath();
      if (p.seed) {
        ctx.ellipse(0, 0, 6, 3, 0, 0, Math.PI * 2);
        ctx.fill();
        ctx.strokeStyle = 'rgba(160, 90, 40, .6)';
        ctx.lineWidth = 1;
        ctx.stroke();
      } else {
        ctx.arc(0, 0, 3.5, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.restore();
    }
  }

  /* ------------------------------------------------------------
   * 4. スクロール連動: 転がるベーグル / 穴から写真がひらく
   * ---------------------------------------------------------- */
  const roll = document.getElementById('roll');
  const rollBagel = document.getElementById('rollBagel');
  const rollShadow = document.getElementById('rollShadow');
  const rollBar = document.getElementById('rollBar');
  const words = [...roll.querySelectorAll('.rw')];
  const hole = document.getElementById('hole');
  const holeCopy = document.getElementById('holeCopy');

  function sectionProgress(el) {
    const r = el.getBoundingClientRect();
    return clamp(-r.top / (r.height - innerHeight));
  }

  function onScroll() {
    // roll
    const p = sectionProgress(roll);
    const w = rollBagel.offsetWidth;
    const x = lerp(-w * 1.1, innerWidth + w * .1, p);
    const deg = (x / (w / 2)) * (180 / Math.PI);
    const hop = Math.abs(Math.sin(p * Math.PI * 6)) * -18;
    rollBagel.style.transform = `translate3d(${x}px, ${hop}px, 0) rotate(${deg}deg)`;
    rollShadow.style.transform = `translate3d(${x}px,0,0) scaleX(${1 + hop / 60})`;
    rollBar.style.transform = `scaleX(${p})`;
    words.forEach((el, i) => {
      const at = +el.dataset.at;
      const next = words[i + 1] ? +words[i + 1].dataset.at : 2;
      el.classList.toggle('on', p >= at && p < next);
      el.classList.toggle('gone', p >= next);
    });

    // hole
    const h = sectionProgress(hole);
    const t = easeInOut(clamp(h / .75));
    const vmax = Math.max(innerWidth, innerHeight) / 100;
    holePhoto.style.setProperty('--outer', lerp(22, 90, t) * vmax + 'px');
    holePhoto.style.setProperty('--inner', lerp(8, 0, clamp(t * 1.4)) * vmax + 'px');
    holePhoto.style.setProperty('--zoom', lerp(1.25, 1, t));
    holeCopy.classList.toggle('on', h > .62);
  }
  addEventListener('scroll', onScroll, { passive: true });
  addEventListener('resize', onScroll);
  onScroll();

  function tick() {
    cx += (mx - cx) * .08;
    cy += (my - cy) * .08;
    for (const l of layers) {
      const d = +l.dataset.depth;
      l.style.transform = `translate3d(${cx * d}px, ${cy * d}px, 0)`;
    }
    if (parts.length) drawParts();
    else ctx.clearRect(0, 0, canvas.width, canvas.height);
    requestAnimationFrame(tick);
  }
  tick();

  /* ------------------------------------------------------------
   * 5. 表示アニメーション & カードの 3D チルト
   * ---------------------------------------------------------- */
  const io = new IntersectionObserver(entries => {
    entries.forEach(en => {
      if (en.isIntersecting) {
        en.target.classList.add('in');
        io.unobserve(en.target);
      }
    });
  }, { threshold: .25 });
  document.querySelectorAll('.step, .card, section:not(.hero) .reveal').forEach(el => io.observe(el));

  document.querySelectorAll('.card').forEach(card => {
    card.addEventListener('pointermove', e => {
      const r = card.getBoundingClientRect();
      const px = (e.clientX - r.left) / r.width - .5;
      const py = (e.clientY - r.top) / r.height - .5;
      card.style.setProperty('--ry', px * 14 + 'deg');
      card.style.setProperty('--rx', -py * 14 + 'deg');
    });
    card.addEventListener('pointerleave', () => {
      card.style.setProperty('--ry', '0deg');
      card.style.setProperty('--rx', '0deg');
    });
  });
})();
