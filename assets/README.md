# Image assets

Every file in `img/` is a **generated SVG placeholder** so the page renders complete
before real photography exists. Replace each one with a real image at the same
aspect ratio, then update the `src` in `index.html` (or keep the `.svg` name).

Recommended: export as **WebP** (quality ~78) and keep the `width`/`height`
attributes already on each `<img>` so nothing shifts while loading.

| File | Used for | Aspect / target size |
|---|---|---|
| `hero-garage-door-repair.svg` | Hero background (CSS) | 16:9 — 1600×900 |
| `contact-garage-door-background.svg` | Contact section background (CSS) | ~16:7 — 1600×700 |
| `about-garage-door-service-home.svg` | About section photo | ~11:10 — 900×820 |
| `expertise-residential-opener.svg` | Expertise photo (top) | ~2:1 — 900×440 |
| `expertise-garage-door-interior.svg` | Expertise photo (bottom) | ~2:1 — 900×440 |
| `service-*.svg` (12 files) | Service card thumbnails | 11:5 — 660×300 |
| `before-after-1…8.svg` | Before & After slider | ~3:2 — 480×330 |
| `og-garage-doors-logo.svg` | Header + footer logo | keep as SVG |
| `icon-google-g.svg` | Google mark on review cards | keep as SVG |
| `review-avatar-1…3.svg` | Reviewer avatars | 1:1 — 64×64 |
| `reviews-*.svg` (5 files) | Facebook / Thumbtack / HomeAdvisor / Yelp / Google badges | height 66px |
| `badge-*.svg` (4 files) | Guarantee & discount badges | 1:1 — 200×200 |
| `brand-*.svg` (6 files) | Amarr / Hurricane Master / Clopay / LiftMaster / Genie / Chamberlain | height 44px |

## Notes

- The review-platform and manufacturer files are **neutral wordmark placeholders**,
  not the real trademarks. Drop in the official logo files you are licensed to use
  before launch.
- Reviewer names and review text are placeholders in `SITE` (in `index.html`).
  Replace them with real Google reviews — the page also carries an
  `aggregateRating` in its JSON-LD, which must match real, verifiable reviews.
- The hero and contact backgrounds are loaded via CSS `background-image`, so they
  are **not** lazy-loaded (they are above the fold / large decorative art).
  Every `<img>` in the document uses `loading="lazy"`.
