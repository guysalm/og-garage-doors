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
| `service-cable-drum-repair.jpg` | `Cable and Drum.jpg` | Cable drum with the lift cable wound on the shaft |
| `service-sensor-repair.jpg` | `Sensoe.jpg` | Safety sensor on the track, indicator lit |
| `expertise-residential-opener.jpg` | `Broken Spring 2.jpg` | Torsion spring + opener rail above the door |
| `expertise-garage-door-interior.jpg` | `chain hoist.jpg` | Chain hoist on a commercial roll-up door |
| `ba-panel-replacement-before/-after.jpg` | `1 Before.jpg` / `1 After.jpg` | Damaged top panel, then replaced |
| `ba-off-track-before/-after.jpg` | `2 beore.jpg` / `2 After.jpg` | Door off its tracks, then reset |
| `ba-commercial-rollup-before/-after.jpg` | `commercial door before/after.jpg` | Old commercial roll-up out, new one in |
| `brand-*.png` (6 files) | `assets/Logos/` | Amarr, C.H.I., Clopay, LiftMaster, Genie, Chamberlain |

## Still placeholders

Replace with a real photo at the listed aspect ratio, then change the `src`
extension in `index.html` from `.svg` to `.jpg` (or `.webp`).

| File | Used for | Aspect / target size |
|---|---|---|
| `service-tune-up-maintenance.svg` | Tune-up card | 11:5 — 660×300 |
| `service-new-door-installation.svg` | New door install card | 11:5 — 660×300 |
| `review-avatar-1…3.svg` | Reviewer avatars | 1:1 — 64×64 |
| `og-garage-doors-logo.svg` | Header + footer logo | keep as SVG |
| `icon-google-g.svg` | Google mark on review cards | keep as SVG |
| `reviews-*.svg` (5 files) | Facebook / Thumbtack / HomeAdvisor / Yelp / Google | height 66px |
| `badge-*.svg` (4 files) | Guarantee & discount badges | 1:1 — 200×200 |

**Two service cards to go** — tune-up & maintenance and new door installation —
then the whole services grid is real photography.

## Named photos not yet used

| File | Why |
|---|---|
| `Gavlanized sprnings 2 .jpg` | Superseded — `Broken Spring 1.jpg` is a clearer spring shot |
| `commercial garage door opener 1.jpg` | Second angle of the same operator as `…opener 2.jpg` |
| `Gate automatin operner 2.jpg` | Second angle of the same gate job |

The Before & After section now runs on three real pairs. To add another, drop in
a `<job> before.jpg` / `<job> after.jpg` pair and add one more `.ba-card`.

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
- The **review-platform files are still neutral placeholders** — not the real Facebook,
  Thumbtack, HomeAdvisor, Yelp or Google marks. Confirm you are licensed to display
  every logo on the page before launch.
- Reviewer names and review text are placeholders in `SITE` (in `index.html`).
  Replace them with real Google reviews — the page also carries an
  `aggregateRating` in its JSON-LD, which must match real, verifiable reviews.
