# OG Garage Doors — Build Spec

Garage door service website, Florida. Single-file / no-build, vanilla HTML5 + CSS3 + ES6.

## 1. Performance
- Clean, minimal code. No Bootstrap, no jQuery, no heavy libraries. Keep file size small.
- `loading="lazy"` on every below-the-fold image.
- Light image formats: SVG for icons + logo, WebP for photos.
- No render-blocking scripts: scripts at end of `<body>`, or `defer` / `async`.

## 2. On-page SEO structure
- Exactly one `<h1>`, in the hero, containing the primary keyword + location.
- Hierarchical `<h2>` / `<h3>` for sections: Services, Testimonials, About, FAQ.
- Meta tags:
  - `title` + `description` with keywords, service area, and a CTA.
  - `viewport` for responsive mobile.
  - `robots: index, follow`.
- Descriptive keyword-rich `alt="..."` on every image.
- Outbound links: `target="_blank"` + `rel="noopener"`; `rel="nofollow"` on external/sponsored links where appropriate.

## 3. Dynamic SEO framework
- All tags built with placeholders so hundreds of service/location landing pages can be generated:
  `{{service_name}}`, `{{location}}`, `{{phone_number}}`, etc.
- Placeholders used in: titles, meta, headings, alt text, forms, and `tel:` call links.

## Open items (awaiting instructions)
- Services list, service areas / cities
- Phone number, business address, hours
- Branding: colors, logo, fonts
- Page set (single landing page vs. multi-page)
- Photos / assets

---

## Decisions (2026-09-03)

**Palette — Graphite + Crimson** (replaces the reference's navy/green/orange):

| Token | Hex | Use |
|---|---|---|
| `--ink` | `#14181D` | header, footer, review band |
| `--ink-2` | `#1C222A` | raised graphite (mobile nav) |
| `--crimson` | `#D22630` | primary CTA, checkmarks, accents |
| `--crimson-2` | `#F04E58` | CTA hover, light crimson |
| `--crimson-3` | `#A81C25` | crimson text on white (AA contrast) |
| `--steel` | `#8A939E` | borders on dark, muted marks |
| `--bg` / `--bg-alt` | `#FFFFFF` / `#F4F5F7` | sections |
| `--text` / `--muted` | `#14181D` / `#5A6270` | body copy |

Typography: Roboto 400/500/700/900, loaded non-blocking (`media="print"` +
`onload`), with a system-font fallback stack.

**Scope of this pass:** homepage only (`index.html`), built as the master
template. City landing pages come next, from `reference/` city copy.

## Delivered

- Semantic HTML5: `header` / `nav` / `main` / `section` / `article` / `footer`
- One `<h1>` in the hero; h2 sections; h3 subsections (no skipped levels)
- Meta title, description, canonical, Open Graph, `robots: index, follow`
- `LocalBusiness` JSON-LD with address, `areaServed`, 24/7 hours,
  `aggregateRating` and an `OfferCatalog` of services
- Every `<img>` has descriptive keyword + location `alt` and `loading="lazy"`
- Outbound WhatsApp link: `target="_blank" rel="noopener nofollow"`
- Zero libraries; one deferred inline `<script>` at end of `body`
- Sticky desktop header + sticky mobile CTA bar (Call / WhatsApp / Free Quote)
- Quick lead form: Full Name, Zip, Phone, Email, Service `<select>`, Message,
  Submit + hidden `page_location` / `page_service` / `page_url` routing fields
- FAQ with `<details>` accordion
- Focus-visible outlines, skip link, `prefers-reduced-motion` support
