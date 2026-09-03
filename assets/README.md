# Image assets

`Real Photos/` holds the original job photos, untouched. Everything referenced by
`index.html` lives directly in `img/` and is either a **real photo** cropped from
that folder, or a **generated SVG placeholder** still waiting for one.

## Real photos in place

Centre-cropped to the exact display aspect ratio, saved as JPEG q82.

| File | Source | Shows |
|---|---|---|
| `hero-garage-door-repair.jpg` | `Hero background.jpg` | Florida home, double garage door, palm + sky |
| `contact-garage-door-background.jpg` | `LiftMaster cemmercial garage door opener.jpg` | Commercial operator (sits under a dark overlay) |
| `about-garage-door-service-home.jpg` | `Galvanized springs.jpg` | Residential door with window panels, from inside |
| `service-broken-spring-repair.jpg` | `Broken Spring 1.jpg` | Torsion spring + centre bracket on the header |
| `service-opener-repair-installation.jpg` | `Galvanized springs 2.jpg` | Residential garage, opener + rail overhead |
| `service-off-track-repair.jpg` | `Garage Door Off Track.jpg` | Door hanging off its track at a home |
| `service-roller-replacement.jpg` | `rellers.jpg` | Set of new nylon rollers |
| `service-panels-replacement.jpg` | `Panel replacment .jpg` | Door panels laid out on the driveway |
| `service-gate-repair-installation.jpg` | `Gate automatic opener 1.jpg` | Driveway gate + LiftMaster gate operator |
| `service-commercial-garage-door.jpg` | `Cemmercial Roll up door.jpg` | Green commercial roll-up door on a warehouse |
| `service-jackshaft-side-mount-openers.jpg` | `commercial garage door opener 2.jpg` | Jackshaft operator beside the torsion shaft |
| `expertise-residential-opener.jpg` | `Broken Spring 2.jpg` | Torsion spring + opener rail above the door |
| `expertise-garage-door-interior.jpg` | `chain hoist.jpg` | Chain hoist on a commercial roll-up door |

## Still placeholders

Replace with a real photo at the listed aspect ratio, then change the `src`
extension in `index.html` from `.svg` to `.jpg` (or `.webp`).

| File | Used for | Aspect / target size |
|---|---|---|
| `service-cable-drum-repair.svg` | Cable & drum card | 11:5 — 660×300 |
| `service-tune-up-maintenance.svg` | Tune-up card | 11:5 — 660×300 |
| `service-new-door-installation.svg` | New door install card | 11:5 — 660×300 |
| `service-sensor-repair.svg` | Sensor repair card | 11:5 — 660×300 |
| `before-after-1…8.svg` | Before & After slider | ~3:2 — 480×330 |
| `review-avatar-1…3.svg` | Reviewer avatars | 1:1 — 64×64 |
| `og-garage-doors-logo.svg` | Header + footer logo | keep as SVG |
| `icon-google-g.svg` | Google mark on review cards | keep as SVG |
| `reviews-*.svg` (5 files) | Facebook / Thumbtack / HomeAdvisor / Yelp / Google | height 66px |
| `badge-*.svg` (4 files) | Guarantee & discount badges | 1:1 — 200×200 |
| `brand-*.svg` (6 files) | Amarr / Hurricane Master / Clopay / LiftMaster / Genie / Chamberlain | height 44px |

**Four service cards to go**, then the whole services grid is real photography:
cable & drum, tune-up, new door installation, sensor repair.

## Named photos not yet used

| File | Why |
|---|---|
| `Gavlanized sprnings 2 .jpg` | Superseded — `Broken Spring 1.jpg` is a clearer spring shot |
| `commercial garage door opener 1.jpg` | Second angle of the same operator as `…opener 2.jpg` |
| `Gate automatin operner 2.jpg` | Second angle of the same gate job |
| `Rollup door before.jpg` | A "before" with no matching "after" |

The Before & After slider needs **pairs**. Supply the matching "after" for the
roll-up door and it can fill the first slot.

## Notes

- Every `<img>` uses `loading="lazy"`, carries a keyword + `{{location}}` alt, and
  declares its real intrinsic `width`/`height` so nothing shifts while loading.
  The hero and contact backgrounds are CSS `background-image`, so they are not
  lazy-loaded by design (above the fold / large decorative art).
- Alt text describes what is actually in each photo — when you swap an image,
  update its alt to match, or the alt becomes a lie to both users and crawlers.
- The review-platform and manufacturer files are **neutral wordmark placeholders**,
  not the real trademarks. Drop in logo files you are licensed to use before launch.
- Reviewer names and review text are placeholders in `SITE` (in `index.html`).
  Replace them with real Google reviews — the page also carries an
  `aggregateRating` in its JSON-LD, which must match real, verifiable reviews.
