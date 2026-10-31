# OG Garage Doors

Garage door service website for Florida. Hand-written HTML5 + CSS3 + vanilla ES6,
no dependencies and no bundler. One template generates the home page and the
city landing pages. Currently in **Venice-first mode** - see the last section.

```
og-garage-doors/
├─ index.html                              # GENERATED home page
├─ garage-door-repair-<city>-fl.html       # generated city pages (2 in Venice-first mode)
├─ sitemap.xml, robots.txt                 # generated
├─ netlify.toml                            # publish root, no build step
├─ tools/template.html                     # the source of truth — edit this
├─ tools/build-city-pages.ps1              # generates index.html + city pages
├─ tools/serve.ps1                         # local preview server
├─ assets/img/                             # photos + logos — see assets/README.md
├─ SPEC.md                                 # build spec (performance + SEO)
└─ reference/                              # source material, not deployed (gitignored)
```

Preview locally (the site uses extensionless URLs, so `file://` will not
resolve the city links — serve it instead):

```bash
powershell -File tools/serve.ps1     # then open http://localhost:8080/
```

## Page structure

`sticky header` → `hero (H1)` → `review platforms` → `Google reviews (rotating)` →
`guarantee badges` → `Our Services (12 cards)` → `value props` →
**`local section (city pages only)`** → `About` → `Our Expertise` →
`Before & After` → `brands` → `FAQ` → `contact form` → `footer` →
`sticky mobile CTA bar`

## City pages

Ten markets, each on its own URL with its own title, description, canonical, H1,
localized copy, service list, zip codes and FAQs:

| City | Page |
|---|---|
| Sarasota | `garage-door-repair-sarasota-fl.html` |
| Venice | `garage-door-repair-venice-fl.html` |
| Englewood | `garage-door-repair-englewood-fl.html` |
| North Port | `garage-door-repair-north-port-fl.html` |
| Port Charlotte | `garage-door-repair-port-charlotte-fl.html` |
| Fort Myers | `garage-door-repair-fort-myers-fl.html` |
| Brandon | `garage-door-repair-brandon-fl.html` |
| Ruskin | `garage-door-repair-ruskin-fl.html` |
| Tampa | `garage-door-repair-tampa-fl.html` |
| St. Pete & Clearwater | `garage-door-repair-st-petersburg-clearwater-fl.html` |

All pages are **generated, not hand-edited**. Which cities are built is set by `$ACTIVE_CITIES` (see Venice-first mode). Edit `tools/template.html`
(or the content file in
`reference/`) and re-run:

```powershell
powershell -File tools\build-city-pages.ps1
```

The generator reads the `SITE` object out of the template, overrides the per-city
values, substitutes every `{{token}}` at build time — so the shipped pages contain
final HTML rather than tokens a crawler has to execute JS to resolve — then swaps
in the city head tags, H1 and JSON-LD, inserts the local content section, and puts
the city's FAQs above the shared ones. It also writes `sitemap.xml` and
`robots.txt`.

**Re-run it after any change to `tools/template.html`**, including the phone number, since
those values are baked into the generated pages.

## Per-city copy

One template plus a swapped city name is not three pages — it is one page
restated three times, and Google treats it that way. On 2026-10-22 Search
Console had two of the three live pages indexed; the pages shared 13 of their 14
H2s and every word of the Value Props, About and Expertise sections, and prose
vocabulary overlap between any two was 72–74%.

So those sections are written **per city**, in `$cityCopy` in the generator, and
reach the template through tokens (`{{h2_about}}`, `{{exp1_p}}`,
`{{about_checks}}`…). What differs is what is actually different about the
market — salt air off Lemon Bay, 55+ communities on Venice Island, doors in
North Port that cycle ten times a day. Facts come from `reference/`, not from
invention.

That first pass left two blocks still identical everywhere, and measured by
shared six-word sequences they were most of what remained: the **twelve
service-card descriptions** (333 words of body copy, the single largest
duplicate block on the site) and the **FAQ**, where `reference/` gives one
question per city against the template's seven shared ones.

Both are now per city as well:

- **Card descriptions** are twelve more `$cityCopy` tokens
  (`{{svc_spring_p}}` … `{{svc_sensor_p}}`). The card *headings* stay shared,
  because they are the service names and renaming "Broken Spring Repair" per
  city would cost the keyword.
- **City questions** come from `$cityFaqs`, where an entry replaces that
  city's reference question outright.
- **The six shared answers** are six more `$cityCopy` tokens
  (`{{faq_speed_a}}` … `{{faq_hoa_a}}`). The shared *questions* stay shared,
  and deliberately: `Add-CityFaqs` matches the exact wording of "How fast can
  a technician get to my home?" to drop it from a page that already asks its
  own speed question, and throws if that text moves. Keep the local detail in
  the answers.

| pair | at the start | cards + city FAQs | + shared answers |
|---|---|---|---|
| North Port vs Englewood | 60.4% | 46.3% | **34.3%** |
| home (Venice) vs North Port | 60.4% | 46.5% | **34.3%** |
| Englewood vs Sarasota | 59.6% | 47.1% | **35.2%** |

What is left is the lead form's labels and dropdown (~180 words, which Google
discounts as chrome) and the service cards' four-item check lists, which are
service names again.

Two answers on the same page must not restate each other either: Sarasota
asks its own ARC question, so that page's shared HOA answer covers styles,
panel profiles and colour matching instead of approval.

North Port got the FAQ work first because it was the page Search Console would
not index, and its one "local" question never named the city — it asked about
phone control of an opener, which is true everywhere we work. It now has three
questions that only make sense in North Port. Asking a speed question there
also drops the shared *"How fast can a technician get to my home?"* from that
page, which `Add-CityFaqs` has always done for Venice and Sarasota.

Two guards hold it there:

- **`$COPY_KEYS`** — every token must be written for every city, and a key that
  is not in the list is a typo rather than a new field. Either throws.
- **the content-H2 assertion** — the build fails if two pages ship the same H2.
  Four chrome headings are exempt (`Frequently Asked Questions`, the contact
  heading, `Share`, `Get a free quote`); they say nothing about the subject.

A city with no `$cityCopy` entry falls back to defaults that at least carry its
name into each heading, and the build prints a note naming it. The service-card
and FAQ-answer defaults are the original shared template sentences, so a city
on defaults is carrying the duplicate blocks the per-city versions exist to
break up. That is enough to pass the H2 assertion but not enough to earn an
index slot, so **write the entry before re-enabling a city** — `$cityFaqs`
too, since a city with no entry there ships one reference question against
seven shared ones.

The token legend at the top of `tools/template.html` lists every `{{token}}`
by name, so substitution used to fill it in like any other occurrence and
every page shipped a second copy of its own prose inside an HTML comment.
The build strips the legend before substituting anything, and throws if it
cannot find it — about 3KB a page by the time the cards and answers were
tokenised.

## Dynamic SEO framework

Every SEO-relevant string in the template is a `{{token}}` — meta title, meta
description, canonical, Open Graph, JSON-LD, the `<h1>`, body copy, image `alt`
text, `tel:` links, the WhatsApp link and the form's hidden routing fields.

| Token | Example |
|---|---|
| `{{business_name}}` | OG Garage Doors |
| `{{service_name}}` | Garage Door Repair |
| `{{location}}` | Sarasota, FL |
| `{{city}}` / `{{state}}` / `{{zip}}` | Sarasota / FL / 34231 |
| `{{service_area}}` | Sarasota and the surrounding area |
| `{{phone_number}}` | `+19410000000` (tel: format) |
| `{{phone_display}}` | (941) 000-0000 |
| `{{whatsapp_number}}` | 19410000000 (digits only) |
| `{{email}}` | — |
| `{{site_url}}` | site root — logo link, og:image, sharing |
| `{{page_url}}` | this page — canonical, og:url, form field |
| `{{rating}}` / `{{review_count}}` | 5.0 / 127 |
| `{{facebook_url}}` / `{{bbb_url}}` | the business profiles |

The two profile URLs are used twice each and must stay in step: the footer's
*Find us* links on every page, and the `sameAs` array in the home page's
`LocalBusiness`. `sameAs` is what tells Google the Facebook page, the BBB
listing and this site are one business, and it only works if the URL in the
schema is the URL in the link. Both are followed links, not `nofollow` —
they are our own profiles, which is the whole point. City pages carry no
`sameAs`, because they carry no `LocalBusiness`.

The Facebook URL is the canonical `/people/…` form the `profile.php?id=…`
link redirects to, so neither use costs a redirect hop.

Review cards are **not** tokenised — they render from the `REVIEWS` array in the
script at the bottom of the template.

**No deployed page contains a token.** The template keeps them and a runtime
script fills them from `SITE`, but that is a fallback for editing the template
directly — every page the generator writes has final HTML. This matters: crawlers
read raw HTML on the first pass, and an unrendered
`<link rel="canonical" href="{{page_url}}">` resolves to a different URL, which
reports as *"canonicalised to a different URL"*.

## URL shape

Netlify serves `page.html` at `/page`. So canonicals, internal links and
`sitemap.xml` all use the **extensionless, root-relative** form
(`/garage-door-repair-sarasota-fl`). Anything else produces a redirect hop and a
canonical that disagrees with the crawled URL.

Netlify keeps serving `page.html` at 200 as well, so without help every page
answers on two URLs. The canonical tag points the right way and Google honours
it, but it still has to crawl and compare both. The build therefore generates
`_redirects` with a forced 301 from each `.html` path to its extensionless
form — one line per page it built, so the file cannot fall behind the site:

    /garage-door-repair-englewood-fl.html    /garage-door-repair-englewood-fl    301!

This does not loop. The rules match the **requested** path, and a request for
`/page` never matches `/page.html`; Netlify's extensionless resolution happens
after the redirect table. `netlify.toml` separately 301s `/tools/*` to `/`,
because the publish root is the repo root and the build tooling would otherwise
be downloadable.

## Security headers

`_headers` is generated by the build (Netlify reads it from the publish root)
and carries a **hash-based Content-Security-Policy** — no `unsafe-inline`. Each
page embeds its own `SITE` values, so its inline script hashes differently; the
build hashes all eleven and lists every hash in `script-src`. That is why the
template has no inline `on*` handlers or `style=""` attributes.

Also set: `X-Content-Type-Options`, `Referrer-Policy`, `Permissions-Policy`,
`Strict-Transport-Security`, `X-Frame-Options`.

## Google Analytics

GA4, measurement ID in the `ga_id` key of `SITE`, so the tag and the config
call both read from one place. The loader comes from `googletagmanager.com`
and the bootstrap is inline — the build hashes it like any other inline
script, so no `unsafe-inline` is needed and the ID is not duplicated.

The CSP needs three hosts, and they are not interchangeable: `gtag.js` is
served from `googletagmanager.com` while the beacons go to
`google-analytics.com`, so a tag allowed in `script-src` but unreachable in
`connect-src` loads and then silently sends nothing. GA4 beacons by `fetch`
and falls back to an image, which is why the analytics hosts are in `img-src`
too.

Only inline scripts are hashed. A `src=` script is covered by its host in
`script-src`, so hashing its empty body would just add a hash that permits
an empty inline script.

`tools/serve.ps1` reads the generated `_headers`, so a CSP that would block
the tag live blocks it in local preview first — which also means local
preview sends real page views to the property.

`tools/serve.ps1` applies the same headers locally, so a policy that would break
the live site breaks it in preview first.

`_headers` being right is not the same as the crawler seeing the headers. The
domain is proxied through **Cloudflare** and `/assets/*` is cached for 7 days,
so images cached before a header change keep being served without it — which
Screaming Frog reports as every image missing `X-Content-Type-Options` while
the origin is set up correctly. **After any header change, purge the Cloudflare
cache** (Caching → Configuration → Purge Everything).

`tools/check-live-headers.ps1` checks the deployed site rather than the config
— every URL a crawler reaches, images included — and separates the two causes:
a header still absent on a cache-busted request is a config fault, one that
appears only on the cache-busted request is a stale edge copy. It also checks
each `Content-Type` matches the file, since `nosniff` only helps if the stated
type is the right one.

    powershell -File tools\check-live-headers.ps1

The build asserts every page has a self-referencing canonical, that no served
image exceeds 100KB, and that no
title exceeds 561px or description 985px when measured in the SERP font
(Arial 20px / 14px) — Google truncates on pixel width, not character count.
It also asserts that **no two pages share a content H2** (see *Per-city copy*
below); only four chrome headings are allowed to repeat.
It also asserts the address: a footer `<address>` carrying the street, city,
state and zip from `SITE` on every page, `PostalAddress` in the home page's
JSON-LD, and **no** `PostalAddress` on a city page - those carry a `Service`
that points at the business by @id, so repeating the entity would describe one
business three contradictory ways.

## Before launch

- [x] Real values filled in `SITE` (phone, email, domain, address), generator
      re-run. The Venice unit is a staffed location, so the NAP is published:
      the footer `<address>` on every page, and `PostalAddress` in the home
      page's `LocalBusiness`. The site NAP and the Google Business Profile must
      stay identical, character for character.
- [x] Form posts to **Netlify Forms** (`name="contact"`). Deploy to Netlify and
      submissions appear under Forms → contact.
- [x] `robots.txt` + `sitemap.xml` generated for every page that ships.
- [ ] Replace the remaining SVG placeholders in `assets/img/` (avatars, guarantee
      badges, the OG logo) — see `assets/README.md`.
- [ ] Confirm the ten reviews are genuine, then add `Review` + a corrected
      `AggregateRating` to the JSON-LD. The current `5.0 / 127` is placeholder.
- [ ] Confirm you are licensed to display every third-party logo on the page.

## Temporary: Venice-first mode

Four pages ship: the **home page is the Venice page**, plus Englewood, North Port
and Sarasota. The service area is those four, in the footer and in the schema's
`areaServed`.

Set at the top of `tools/build-city-pages.ps1`:

```powershell
$HOME_CITY     = "garage-door-repair-venice-fl"   # the home page IS this city's page
$ACTIVE_CITIES = @("garage-door-repair-englewood-fl", "garage-door-repair-north-port-fl", "garage-door-repair-sarasota-fl")
$SERVED_CITIES = @("garage-door-repair-venice-fl", "garage-door-repair-englewood-fl", "garage-door-repair-north-port-fl", "garage-door-repair-sarasota-fl")
```

There is no separate Venice page: the home page targets Venice, so a second
Venice URL would compete with it for the same searches.

**To restore all eleven pages**, set those three to:

```powershell
$HOME_CITY     = ""
$ACTIVE_CITIES = $null
$SERVED_CITIES = $null
```

then re-run the generator. Nothing is lost in the meantime — every city's copy,
FAQs and zip codes are read from `reference/`, and the pages removed here stay
in git history.

Write each restored city a `$cityCopy` entry first (see *Per-city copy*). Only
Venice, Englewood, North Port and Sarasota have one; the other six would fall
back to default copy, which is the duplication that cost an index slot in the
first place. The build prints a note for every city still on defaults.
