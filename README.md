# OG Garage Doors

Garage door service website for Florida. Single-file, no build step, no
dependencies — hand-written HTML5 + CSS3 + vanilla ES6.

```
og-garage-doors/
├─ index.html      # the whole site (inline <style> + <script>)
├─ assets/img/     # SVG placeholders — see assets/README.md
├─ SPEC.md         # build spec (performance + SEO requirements)
└─ reference/      # source material, not deployed (gitignored)
```

Open it locally:

```bash
cmd.exe /c start "" "index.html"
```

## Page structure

`sticky header` → `hero (H1)` → `review platforms` → `Google reviews` →
`guarantee badges` → `Our Services (12 cards)` → `value props` → `About` →
`Our Expertise` → `Before & After` → `brands` → `FAQ` → `contact form` →
`footer` → `sticky mobile CTA bar`

## Dynamic SEO framework

Every SEO-relevant string is a `{{token}}` — meta title, meta description,
canonical, Open Graph, JSON-LD, the `<h1>`, body copy, image `alt` text,
`tel:` links, the WhatsApp link and the form's hidden routing fields.

Tokens:

| Token | Example |
|---|---|
| `{{business_name}}` | OG Garage Doors |
| `{{service_name}}` | Garage Door Repair |
| `{{location}}` | Sarasota, FL |
| `{{city}}` / `{{state}}` / `{{zip}}` | Sarasota / FL / 34232 |
| `{{service_area}}` | Sarasota, Manatee & Charlotte County |
| `{{phone_number}}` | `+19410000000` (tel: format) |
| `{{phone_display}}` | (941) 000-0000 |
| `{{whatsapp_number}}` | 19410000000 (digits only) |
| `{{email}}` / `{{site_url}}` | — |
| `{{rating}}` / `{{review_count}}` | 5.0 / 127 |
| `{{review_1..3_name|date|count|text}}` | — |

**Two ways to fill them:**

1. **Build time (production).** Run `index.html` through any templating step and
   substitute the tokens per service × city page. Crawlers then see final HTML.
   Delete the `fillPlaceholders()` call once this is in place.
2. **Local preview.** The `SITE` object at the bottom of `index.html` holds
   defaults and a small script replaces any remaining token in the DOM, `<title>`,
   meta tags and the JSON-LD block. Good enough to look at; not what you ship.

City copy for 10 Florida markets (Sarasota, Venice, Englewood, North Port,
Port Charlotte, Fort Myers, Brandon, Ruskin, Tampa, St. Pete/Clearwater) is in
`reference/` — meta titles, H1s, localized climate copy, zip codes and FAQs.

## Before launch

- [ ] Fill real values in `SITE` (phone, WhatsApp, email, domain, address).
- [x] Form posts to **Netlify Forms** (`name="contact"`). Nothing to configure in
      code — deploy to Netlify and submissions appear under Forms → contact.
- [ ] Replace the SVG placeholders in `assets/img/` with real WebP photos.
- [ ] Replace placeholder reviews with real Google reviews, and make
      `aggregateRating` in the JSON-LD match them.
- [ ] Swap the review-platform and manufacturer wordmarks for licensed logos.
- [ ] Add `robots.txt` + `sitemap.xml` once the city pages are generated.
