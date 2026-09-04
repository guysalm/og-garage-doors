# Image assets

`Real Photos/` holds the original job photos, untouched. Everything referenced by
`index.html` lives directly in `img/` and is either a **real photo** cropped from
that folder, or a **generated SVG placeholder** still waiting for one.

## Real photos in place

Centre-cropped to the exact display aspect ratio, then encoded as WebP (q0.80;
the hero at q0.62 since it sits under a 65% dark overlay). No image exceeds
100KB and the build fails if one does.

| File | Source | Shows |
|---|---|---|
| `hero-garage-door-repair.webp` | `Hero background.webp` | Florida home, double garage door, palm + sky |
| `contact-garage-door-background.webp` | `LiftMaster cemmercial garage door opener.webp` | Commercial operator (sits under a dark overlay) |
| `about-garage-door-service-home.webp` | `Galvanized springs.webp` | Residential door with window panels, from inside |
| `service-broken-spring-repair.webp` | `Broken Spring 1.webp` | Torsion spring + centre bracket on the header |
| `service-opener-repair-installation.webp` | `Galvanized springs 2.webp` | Residential garage, opener + rail overhead |
| `service-off-track-repair.webp` | `Garage Door Off Track.webp` | Door hanging off its track at a home |
| `service-roller-replacement.webp` | `rellers.webp` | Set of new nylon rollers |
| `service-panels-replacement.webp` | `Panel replacment .webp` | Door panels laid out on the driveway |
| `service-gate-repair-installation.webp` | `Gate automatic opener 1.webp` | Driveway gate + LiftMaster gate operator |
| `service-commercial-garage-door.webp` | `Cemmercial Roll up door.webp` | Green commercial roll-up door on a warehouse |
| `service-jackshaft-side-mount-openers.webp` | `commercial garage door opener 2.webp` | Jackshaft operator beside the torsion shaft |
| `service-cable-drum-repair.webp` | `Cable and Drum.webp` | Cable drum with the lift cable wound on the shaft |
| `service-sensor-repair.webp` | `Sensoe.webp` | Safety sensor on the track, indicator lit |
| `service-new-door-installation.webp` | `Garage door installation.png` | Two techs fitting a windowed top section |
| `service-tune-up-maintenance.webp` | `Garage door tuneup.png` | Tech servicing door hardware with a hand tool |
| `expertise-residential-opener.webp` | `Broken Spring 2.webp` | Torsion spring + opener rail above the door |
| `expertise-garage-door-interior.webp` | `chain hoist.webp` | Chain hoist on a commercial roll-up door |
| `ba-panel-replacement-before/-after.webp` | `1 Before.webp` / `1 After.webp` | Damaged top panel, then replaced |
| `ba-off-track-before/-after.webp` | `2 beore.webp` / `2 After.webp` | Door off its tracks, then reset |
| `ba-commercial-rollup-before/-after.webp` | `commercial door before/after.webp` | Old commercial roll-up out, new one in |
| `brand-*.png` (6 files) | `assets/Logos/` | Amarr, C.H.I., Clopay, LiftMaster, Genie, Chamberlain |
| `reviews-google-5-star.png` | `cbd59134…png` | Google 5.0 with five stars |
| `reviews-facebook-5-star.png` | `fts-reviews-1.png` | Facebook 5-star tile |
| `reviews-yelp-5-star.png` | `yelp_logos.zip` (Light bg / RGB) | Yelp wordmark + burst |
| `reviews-thumbtack-5-star.png` | `thumbtack-vector-logo.zip` | Thumbtack wordmark + shield |
| `reviews-homeadvisor-top-rated.png` | `homeadvisor-top_rated (1).svg` | HomeAdvisor Top Rated shield badge |
| `payments-credit-cards.png` | `credit-cards-color-logo-pack.zip` | Visa, MasterCard, Amex, Discover |

## Still placeholders

Replace with a real photo at the listed aspect ratio, then change the `src`
extension in `index.html` from `.svg` to `.webp` (or `.webp`).

| File | Used for | Aspect / target size |
|---|---|---|
| `review-avatar-1…3.svg` | Reviewer avatars | 1:1 — 64×64 |
| `og-garage-doors-logo.svg` | Header + footer logo | keep as SVG |
| `icon-google-g.svg` | Google mark on review cards | keep as SVG |
| `badge-*.svg` (4 files) | Guarantee & discount badges | 1:1 — 200×200 |

**All 12 service cards now use real photography.**


## Named photos not yet used

| File | Why |
|---|---|
| `Gavlanized sprnings 2 .webp` | Superseded — `Broken Spring 1.webp` is a clearer spring shot |
| `commercial garage door opener 1.webp` | Second angle of the same operator as `…opener 2.webp` |
| `Gate automatin operner 2.webp` | Second angle of the same gate job |

The Before & After section now runs on three real pairs. To add another, drop in
a `<job> before.webp` / `<job> after.webp` pair and add one more `.ba-card`.

## Notes

- Every `<img>` uses `loading="lazy"`, carries a keyword + `{{location}}` alt, and
  declares its real intrinsic `width`/`height` so nothing shifts while loading.
  The hero and contact backgrounds are CSS `background-image`, so they are not
  lazy-loaded by design (above the fold / large decorative art).
- Alt text describes what is actually in each photo — when you swap an image,
  update its alt to match, or the alt becomes a lie to both users and crawlers.
- Manufacturer logos are the **real marks, shown in full colour**, trimmed from
  `assets/Logos/` to 88px-tall transparent PNGs (2× the 44px display height). They
  render inside a fixed 158×54 box with `object-fit:contain`, so a 9:1 wordmark
  (Chamberlain) and a 2.7:1 mark (Amarr) sit optically even.
- Review-platform badges are the **real marks** too, at 132px tall (2× the 66px
  display height). The Facebook file is a designed tile, so it keeps its own padding;
  the transparent marks are trimmed to their ink bounds. Thumbtack and HomeAdvisor
  were rendered from SVG via headless Chrome, then trimmed.
- **Confirm you are licensed to display every third-party logo on the page** — and
  that the Google/Facebook/Yelp/HomeAdvisor/Thumbtack badges reflect ratings the
  business actually holds — before launch.
- Reviewer names and review text are placeholders in the `REVIEWS` array (in `index.html`).
  Replace them with real Google reviews — the page also carries an
  `aggregateRating` in its JSON-LD, which must match real, verifiable reviews.
