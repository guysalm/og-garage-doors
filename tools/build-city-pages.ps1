<#
  Generates index.html and the city landing pages from tools/template.html.

  tools/template.html is the source of truth for layout, styling and the SITE
  defaults (phone, business name, rating...). This script:
    1. reads the SITE object out of the template,
    2. overrides the per-city values,
    3. substitutes every {{token}} at build time so the shipped pages contain
       final HTML rather than tokens a crawler has to run JS to resolve,
    4. swaps in the city title / description / canonical / H1 / JSON-LD,
    5. inserts a local content section and city FAQs.

  Edit tools/template.html, never the generated pages. Re-run after any change
  - including the phone number, which is baked into every generated page.

    powershell -File tools\build-city-pages.ps1
#>

$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot
$tplPath = Join-Path $PSScriptRoot "template.html"
$srcPath = Join-Path $root "reference\Uniqe Info for Folrida areas gemini-code-1788450139162.txt"

if (-not (Test-Path $srcPath)) { throw "City content file not found: $srcPath" }

$tpl = Get-Content $tplPath -Raw -Encoding UTF8
$raw = Get-Content $srcPath -Raw -Encoding UTF8

# ---------------------------------------------------------------- SITE values
$siteBlock = [regex]::Match($tpl, '(?s)var SITE = \{(.*?)\n\};').Groups[1].Value
$SITE = @{}
foreach ($m in [regex]::Matches($siteBlock, '(?m)^\s*([a-z_]+)\s*:\s*"(.*?)"\s*,?\s*$')) {
  $SITE[$m.Groups[1].Value] = $m.Groups[2].Value
}
Write-Host "SITE defaults read from tools/template.html ($($SITE.Count) keys)"

# The share dialog's links ship with a real share endpoint in href, not "#".
# A crawler reads raw HTML: href="#" resolves to the page itself, so those
# rel="nofollow" anchors counted as internal nofollow links to our own URLs.
$SITE["site_url_enc"] = [uri]::EscapeDataString($SITE.site_url)

function HtmlEscape([string]$s) {
  return $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
}

# ------------------------------------------------------- title pixel measuring
# Google truncates SERP titles on pixel width, not character count. Arial 20px
# with GenericTypographic matches a browser canvas measurement exactly, which is
# the same model the SEO Spider uses.
Add-Type -AssemblyName System.Drawing
$TITLE_LIMIT_PX = 561
$measureFont = New-Object System.Drawing.Font("Arial", 20, [System.Drawing.GraphicsUnit]::Pixel)
$measureBmp  = New-Object System.Drawing.Bitmap 1, 1
$measureGfx  = [System.Drawing.Graphics]::FromImage($measureBmp)
$measureFmt  = [System.Drawing.StringFormat]::GenericTypographic

$DESC_LIMIT_PX = 985
$descFont = New-Object System.Drawing.Font("Arial", 14, [System.Drawing.GraphicsUnit]::Pixel)

function MeasurePx([string]$s, $font) {
  $plain = $s -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>'
  return [math]::Round($measureGfx.MeasureString($plain, $font, [int]::MaxValue, $measureFmt).Width)
}
function TitlePx([string]$s) { return MeasurePx $s $measureFont }
function DescPx([string]$s)  { return MeasurePx $s $descFont }

# The supplied meta titles ran 562-621px, past the truncation point. These are
# trimmed versions; the keyword and city stay at the front either way.
$titleOverrides = @{
  "garage-door-repair-englewood-fl"                = "Garage Door Repair Englewood FL | Salt-Air Specialists"
  "garage-door-repair-fort-myers-fl"               = "Garage Door Repair Fort Myers FL | Hurricane Code Pros"
  "garage-door-repair-north-port-fl"               = "Garage Door Repair North Port FL | Fast Smart-Home Setup"
  "garage-door-repair-sarasota-fl"                 = "Garage Door Repair Sarasota FL | Same-Day Emergency"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Garage Door Repair St. Pete & Clearwater FL | Coastal Pros"
  "garage-door-repair-tampa-fl"                    = "Garage Door Repair Tampa FL | Custom Doors & Repairs"
  "garage-door-repair-venice-fl"                   = "Garage Door Repair Venice FL | Quiet & Reliable Service"
}

# ------------------------------------------------------------- parse the file
# The "N. CITY, FL" heading sits between two rule lines, so capture the heading
# and the block that follows it together rather than splitting on the rules.
$blockRe = '(?ms)^-{80}\s*\r?\n\s*(\d+)\.\s*(.+?)\s*\r?\n-{80}\s*\r?\n(.*?)(?=^-{80}|\z)'
$cities = @()

foreach ($bm in [regex]::Matches($raw, $blockRe)) {
  $heading = $bm.Groups[2].Value          # e.g. "SARASOTA, FL"
  $b       = $bm.Groups[3].Value
  if ($b -notmatch '\[URL\]') { continue }
  function Field($pattern) {
    $m = [regex]::Match($b, $pattern)
    if ($m.Success) { return $m.Groups[1].Value.Trim() } else { return "" }
  }

  $slug = (Field '\[URL\]:\s*domain\.com/(.+)') -replace '\s',''
  if (-not $slug) { continue }

  # hero: the paragraph, then the "* " bullets
  $heroRaw   = Field '(?s)\[HERO SECTION\]\s*(.*?)\r?\n\s*\r?\n\['
  $heroLines = $heroRaw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  $heroPara  = ($heroLines | Where-Object { $_ -notmatch '^\*' }) -join ' '
  $heroBul   = @($heroLines | Where-Object { $_ -match '^\*' } | ForEach-Object { $_ -replace '^\*\s*','' })

  $localRaw  = Field '(?s)\[LOCALIZED CONTENT[^\]]*\]\s*(.*?)\r?\n\s*\r?\n\['
  $localPara = @($localRaw -split "`r?`n`r?`n" | ForEach-Object { ($_ -split "`r?`n" | ForEach-Object { $_.Trim() }) -join ' ' } | Where-Object { $_ })

  $svcRaw    = Field '(?s)\[SERVICES OFFERED IN [^\]]*\]\s*(.*?)\r?\n\s*\r?\n\['
  $services  = @($svcRaw -split "`r?`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -match '^\*' } | ForEach-Object { $_ -replace '^\*\s*','' })

  $areaRaw   = Field '(?s)\[LOCAL SERVICE AREA & LANDMARKS\]\s*(.*?)\r?\n\s*\r?\n\['
  $area      = ($areaRaw -split "`r?`n" | ForEach-Object { $_.Trim() }) -join ' '

  $faqRaw    = Field '(?s)\[FAQ SECTION\]\s*(.*)$'
  $faqs = @()
  foreach ($fm in [regex]::Matches($faqRaw, '(?s)Q:\s*(.*?)\r?\nA:\s*(.*?)(?=\r?\n\s*\r?\nQ:|\s*$)')) {
    $faqs += ,@( ($fm.Groups[1].Value -replace '\s+',' ').Trim(), ($fm.Groups[2].Value -replace '\s+',' ').Trim() )
  }

  # zips out of the service-area line
  $zips = ""
  $zm = [regex]::Match($area, 'Servicing Zip Codes:\s*([0-9,\s]+)')
  if ($zm.Success) { $zips = $zm.Groups[1].Value.Trim().TrimEnd('.') }
  $areaText = ($area -replace 'Servicing Zip Codes:.*$','').Trim()
  $firstZip = ($zips -split ',' | ForEach-Object { $_.Trim() } | Select-Object -First 1)

  # "SARASOTA, FL" -> "Sarasota";  "ST. PETERSBURG / CLEARWATER, FL" -> "St. Petersburg & Clearwater"
  $ti = (Get-Culture).TextInfo
  $cityName = ($heading -replace ',\s*FL\s*$','').Trim()
  $cityName = $ti.ToTitleCase($cityName.ToLower())
  # spell out the slash: this value is substituted into HTML, JSON-LD and JS,
  # so keeping it free of characters that need escaping avoids three-way pain
  $cityName = $cityName -replace '\s*/\s*',' and '
  if (-not $cityName) { throw "Could not read a city name from heading: '$heading'" }

  $cities += [pscustomobject]@{
    Slug     = $slug
    City     = $cityName
    Title    = $(if ($titleOverrides.ContainsKey($slug)) { $titleOverrides[$slug] } else { Field '\[META TITLE\]:\s*(.+)' })
    Desc     = Field '\[META DESCRIPTION\]:\s*(.+)'
    H1       = Field '\[H1\]:\s*(.+)'
    HeroPara = $heroPara
    HeroBul  = $heroBul
    LocalP   = $localPara
    Services = $services
    AreaText = $areaText
    Zips     = $zips
    FirstZip = $firstZip
    Faqs     = $faqs
  }
}

Write-Host "Parsed $($cities.Count) cities"

# ----------------------------------------------------------------- home page
# The template must never ship as-is: Screaming Frog and Googlebot's first pass
# read raw HTML, and an unrendered <link rel="canonical" href="{{page_url}}">
# resolves to a different URL, which is exactly the "canonicalised" report.
$homePage = $tpl
$homeVals = @{}
foreach ($k in $SITE.Keys) { $homeVals[$k] = $SITE[$k] }
$homeVals["page_url"] = $SITE.site_url          # the home page is the site root
foreach ($k in $homeVals.Keys) { $homePage = $homePage.Replace("{{$k}}", $homeVals[$k]) }
$homePage = [regex]::Replace($homePage, '(?m)^(\s*page_url\s*:\s*")(.*?)(")', { param($m) $m.Groups[1].Value + $SITE.site_url + $m.Groups[3].Value })

# The home page must not compete with the Sarasota page for "garage door repair
# Sarasota". It targets the region; each city page owns its own city. The
# postal address stays Sarasota because that is where the business actually is.
$homeTitle = "Garage Door Repair SW Florida &amp; Tampa Bay | 24/7 Service"
$homeDesc  = "Same-day garage door repair across Southwest Florida and Tampa Bay. Licensed &amp; insured, 24/7 emergency service, free estimates. Call $($SITE.phone_display)."
$homePage = [regex]::Replace($homePage, '(?s)<title>.*?</title>', "<title>$homeTitle</title>")
$homePage = [regex]::Replace($homePage, '<meta name="description" content=".*?">', "<meta name=""description"" content=""$homeDesc"">")
$homePage = [regex]::Replace($homePage, '<meta property="og:title" content=".*?">', "<meta property=""og:title"" content=""$homeTitle"">")
$homePage = [regex]::Replace($homePage, '<meta property="og:description" content=".*?">', "<meta property=""og:description"" content=""$homeDesc"">")

# a region is not a schema.org City, so list the markets actually served
$areaList = ($cities | ForEach-Object { "      { ""@type"": ""City"", ""name"": ""$($_.City), FL"" }" }) -join ",`n"
$homePage = [regex]::Replace($homePage,
  '"areaServed": \{ "@type": "City", "name": "[^"]*" \},',
  """areaServed"": [`n$areaList`n  ],")

$leftover = [regex]::Matches($homePage, '\{\{\w+\}\}')
if ($leftover.Count) { throw "Home page still has unresolved tokens: $(($leftover | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', ')" }

[System.IO.File]::WriteAllText((Join-Path $root "index.html"), $homePage, (New-Object System.Text.UTF8Encoding $false))
Write-Host "index.html                                     $([int]((Get-Item (Join-Path $root 'index.html')).Length/1KB)) KB   (home page, rendered)"

# ---------------------------------------------------------------- build pages
$built = @()

foreach ($c in $cities) {
  $loc = "$($c.City), FL"
  # extensionless: Netlify serves page.html at /page and 301s /page.html -> /page,
  # so canonicals and internal links must use the extensionless form or every
  # page reports as "canonicalised to a different URL"
  $url = $SITE.site_url.TrimEnd("/") + "/" + $c.Slug

  # per-city SITE overrides, everything else inherited from index.html
  $vals = @{}
  foreach ($k in $SITE.Keys) { $vals[$k] = $SITE[$k] }
  $vals["location"]     = $loc
  $vals["zip"]          = $c.FirstZip
  # page_url is this page; site_url stays the site root, otherwise the logo
  # link, og:image and the share dialog all end up pointing at the city page
  $vals["page_url"]     = $url
  $vals["service_area"] = "$($c.City) and the surrounding area"

  $page = $tpl

  # 1. substitute every token at build time
  foreach ($k in $vals.Keys) { $page = $page.Replace("{{$k}}", $vals[$k]) }

  # 2. keep the runtime SITE object in step (the review cards read it)
  $newSite = $siteBlock
  foreach ($k in @("location","zip","page_url","service_area")) {
    $newSite = [regex]::Replace($newSite, "(?m)^(\s*$k\s*:\s*"")(.*?)("")", { param($m) $m.Groups[1].Value + $vals[$k] + $m.Groups[3].Value })
  }
  $page = $page.Replace($siteBlock, $newSite)

  # 3. head: title, description, canonical, Open Graph
  $page = [regex]::Replace($page, '(?s)<title>.*?</title>', "<title>$(HtmlEscape $c.Title)</title>")
  $page = [regex]::Replace($page, '<meta name="description" content=".*?">', "<meta name=""description"" content=""$(HtmlEscape $c.Desc)"">")
  $page = [regex]::Replace($page, '<meta property="og:title" content=".*?">', "<meta property=""og:title"" content=""$(HtmlEscape $c.Title)"">")
  $page = [regex]::Replace($page, '<meta property="og:description" content=".*?">', "<meta property=""og:description"" content=""$(HtmlEscape $c.Desc)"">")

  # 4. H1
  $page = [regex]::Replace($page, '(?s)(<h1 id="hero-title">).*?(</h1>)', "`${1}$(HtmlEscape $c.H1)`${2}")


  # 6. local content section, inserted before About
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.Append("`n  <!-- ==================== LOCAL: $($c.City.ToUpper()) ==================== -->`n")
  [void]$sb.Append("  <section class=""section local"" id=""local"" aria-labelledby=""local-title"">`n")
  [void]$sb.Append("    <div class=""wrap"">`n")
  [void]$sb.Append("      <h2 class=""section-title section-title--rule"" id=""local-title"">Garage Door Repair in $(HtmlEscape $c.City), FL</h2>`n")
  [void]$sb.Append("      <div class=""local__grid"">`n        <div>`n")
  [void]$sb.Append("          <p class=""local__lead"">$(HtmlEscape $c.HeroPara)</p>`n")
  if ($c.HeroBul.Count) {
    [void]$sb.Append("          <ul class=""checks local__highlights"">`n")
    foreach ($h in $c.HeroBul) { [void]$sb.Append("            <li>$(HtmlEscape $h)</li>`n") }
    [void]$sb.Append("          </ul>`n")
  }
  foreach ($p in $c.LocalP) { [void]$sb.Append("          <p>$(HtmlEscape $p)</p>`n") }
  [void]$sb.Append("        </div>`n`n        <aside class=""local__aside"">`n")
  [void]$sb.Append("          <h3>Services We Provide in $(HtmlEscape $c.City)</h3>`n          <ul class=""checks"">`n")
  foreach ($s in $c.Services) { [void]$sb.Append("            <li>$(HtmlEscape $s)</li>`n") }
  [void]$sb.Append("          </ul>`n")
  [void]$sb.Append("          <h3>Local Service Area</h3>`n")
  [void]$sb.Append("          <p>$(HtmlEscape $c.AreaText)</p>`n")
  if ($c.Zips) { [void]$sb.Append("          <p class=""local__zips""><strong>Zip codes served:</strong> $(HtmlEscape $c.Zips)</p>`n") }
  [void]$sb.Append("          <p><a class=""btn btn--call"" href=""tel:$($vals.phone_number)"" data-cta=""local-call"">Call $(HtmlEscape $vals.phone_display)</a></p>`n")
  [void]$sb.Append("        </aside>`n      </div>`n    </div>`n  </section>`n")

  $aboutMarker = '  <!-- ==================== ABOUT ==================== -->'
  $page = $page.Replace($aboutMarker, $sb.ToString() + "`n" + $aboutMarker)

  # 7. FAQ - city questions first, then the shared ones
  $fb = New-Object System.Text.StringBuilder
  $first = $true
  foreach ($f in $c.Faqs) {
    $open = if ($first) { " open" } else { "" }
    $first = $false
    [void]$fb.Append("        <details$open>`n")
    [void]$fb.Append("          <summary>$(HtmlEscape $f[0])</summary>`n")
    [void]$fb.Append("          <p>$(HtmlEscape $f[1])</p>`n")
    [void]$fb.Append("        </details>`n")
  }
  $faqStart = '      <div class="faq">'
  $idx = $page.IndexOf($faqStart)
  if ($idx -ge 0) {
    $after = $page.Substring($idx + $faqStart.Length)
    # drop the "open" on the first shared question so only the city one starts open
    $after = [regex]::Replace($after, '^\s*\r?\n\s*<details open>', "`n        <details>", 1)
    $page = $page.Substring(0, $idx + $faqStart.Length) + "`n" + $fb.ToString() + $after
  }

  # 7b. if the city already answers "how fast can you get here", drop the
  #     generic version rather than asking near-identical questions twice
  $asksSpeed = $false
  foreach ($f in $c.Faqs) { if ($f[0] -match '(?i)how (quickly|fast|soon)|reach my home') { $asksSpeed = $true } }
  if ($asksSpeed) {
    $page = [regex]::Replace($page,
      '(?s)\s*<details>\s*<summary>How fast can a technician reach my home.*?</details>', '', 1)
  }

  # 8. one-off copy fix: we do not do remote programming
  $page = $page.Replace("Safety Sensor Alignment &amp; Remote Control Programming", "Safety Sensor Alignment &amp; Keypad Programming")

  # 9. this city's own footer link should not point at itself
  $page = $page.Replace("<a href=""/$($c.Slug)"">", "<a href=""/$($c.Slug)"" aria-current=""page"">")

  $out = Join-Path $root "$($c.Slug).html"
  [System.IO.File]::WriteAllText($out, $page, (New-Object System.Text.UTF8Encoding $false))
  $built += $c
  "{0,-46} {1,6} KB   {2} FAQs, {3} services" -f ($c.Slug + ".html"), [int]((Get-Item $out).Length/1KB), $c.Faqs.Count, $c.Services.Count
}

# ------------------------------------------------------------------- sitemap
$today = (Get-Date).ToString("yyyy-MM-dd")
$base  = $SITE.site_url.TrimEnd('/')
$sm = New-Object System.Text.StringBuilder
[void]$sm.Append("<?xml version=""1.0"" encoding=""UTF-8""?>`n")
[void]$sm.Append("<urlset xmlns=""http://www.sitemaps.org/schemas/sitemap/0.9"">`n")
[void]$sm.Append("  <url>`n    <loc>$base/</loc>`n    <lastmod>$today</lastmod>`n    <priority>1.0</priority>`n  </url>`n")
foreach ($c in $built) {
  [void]$sm.Append("  <url>`n    <loc>$base/$($c.Slug)</loc>`n    <lastmod>$today</lastmod>`n    <priority>0.8</priority>`n  </url>`n")
}
[void]$sm.Append("</urlset>`n")
[System.IO.File]::WriteAllText((Join-Path $root "sitemap.xml"), $sm.ToString(), (New-Object System.Text.UTF8Encoding $false))

# ------------------------------------------------------------------ _headers
# Netlify reads _headers from the publish root. The CSP is hash-based: the
# inline <style> and <script> blocks are hashed here so no 'unsafe-inline' is
# needed. Every page is generated from one template, so the hashes are
# identical across all 11 and are recomputed on every build.
function Sha256B64([string]$s) {
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try   { return [Convert]::ToBase64String($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($s))) }
  finally { $sha.Dispose() }
}

# Hash every generated page, not just the home page: each city page embeds its
# own SITE values, so its inline script hashes differently. Missing one blocks
# all JS on that page.
$styleHashes  = New-Object System.Collections.Generic.HashSet[string]
$scriptHashes = New-Object System.Collections.Generic.HashSet[string]

$generated = @(Join-Path $root "index.html") + ($built | ForEach-Object { Join-Path $root "$($_.Slug).html" })
foreach ($file in $generated) {
  $html = [System.IO.File]::ReadAllText($file)
  foreach ($m in [regex]::Matches($html, '(?s)<style>(.*?)</style>')) {
    [void]$styleHashes.Add("'sha256-$(Sha256B64 $m.Groups[1].Value)'")
  }
  # only executable scripts - application/ld+json is data and is never run
  foreach ($m in [regex]::Matches($html, '(?s)<script(?![^>]*type=)[^>]*>(.*?)</script>')) {
    [void]$scriptHashes.Add("'sha256-$(Sha256B64 $m.Groups[1].Value)'")
  }
}
if (-not $scriptHashes.Count) { throw "No inline scripts hashed - the CSP would block the page." }
if (-not $styleHashes.Count)  { throw "No inline styles hashed - the CSP would block all styling." }

$inlineHashes = @{ style = @($styleHashes); script = @($scriptHashes) }

$csp = @(
  "default-src 'self'"
  "base-uri 'self'"
  "object-src 'none'"
  "frame-ancestors 'none'"
  "form-action 'self'"
  "connect-src 'self'"
  "img-src 'self' data:"                                    # data: covers the CSS check-mark mask
  "script-src 'self' $($inlineHashes.script -join ' ')"
  "style-src 'self' $($inlineHashes.style -join ' ') https://fonts.googleapis.com"
  "font-src 'self' https://fonts.gstatic.com"
  "upgrade-insecure-requests"
) -join '; '

$headers = @"
/*
  Content-Security-Policy: $csp
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=(), interest-cohort=()
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  X-Frame-Options: DENY

/assets/*
  Cache-Control: public, max-age=604800

/index.html
  Cache-Control: public, max-age=0, must-revalidate
"@
[System.IO.File]::WriteAllText((Join-Path $root "_headers"), $headers, (New-Object System.Text.UTF8Encoding $false))
Write-Host "_headers written (CSP with $($inlineHashes.script.Count) script + $($inlineHashes.style.Count) style hash)"

$robots = "User-agent: *`nAllow: /`nDisallow: /tools/`n`nSitemap: $base/sitemap.xml`n"
[System.IO.File]::WriteAllText((Join-Path $root "robots.txt"), $robots, (New-Object System.Text.UTF8Encoding $false))

# ------------------------------------------------------------------- verify
# Every deployed page must carry a self-referencing canonical and no leftover
# tokens, or search engines are told to consolidate it somewhere else.
$problems = @()
$firstH2 = @{}
$titleWidths = @()
$checks = @{ (Join-Path $root "index.html") = $base + "/" }
foreach ($c in $built) { $checks[(Join-Path $root "$($c.Slug).html")] = "$base/$($c.Slug)" }

foreach ($file in $checks.Keys) {
  $t    = [System.IO.File]::ReadAllText($file)
  $name = Split-Path $file -Leaf
  $can  = [regex]::Match($t, '<link rel="canonical" href="([^"]*)"').Groups[1].Value
  $ogu  = [regex]::Match($t, 'og:url" content="([^"]*)"').Groups[1].Value
  if ($can -ne $checks[$file]) { $problems += "$name canonical is '$can', expected '$($checks[$file])'" }
  if ($ogu -ne $checks[$file]) { $problems += "$name og:url is '$ogu', expected '$($checks[$file])'" }
  if ($t -match '\{\{\w+\}\}')  { $problems += "$name still contains template tokens" }

  $title = [regex]::Match($t, '(?s)<title>(.*?)</title>').Groups[1].Value
  $px = TitlePx $title
  if ($px -gt $TITLE_LIMIT_PX) {
    $problems += "$name title is ${px}px, over the ${TITLE_LIMIT_PX}px SERP limit: '$title'"
  } else {
    $titleWidths += "  {0,4}px  {1}" -f $px, $title
  }

  $desc = [regex]::Match($t, '<meta name="description" content="([^"]*)"').Groups[1].Value
  $dpx = DescPx $desc
  if ($dpx -gt $DESC_LIMIT_PX) {
    $problems += "$name description is ${dpx}px, over the ${DESC_LIMIT_PX}px SERP limit"
  }
  if ($t -match '\.htmlassets') { $problems += "$name has a malformed asset URL" }
  if ($t -match 'href="/[a-z0-9-]+\.html"') { $problems += "$name links to a .html URL (should be extensionless)" }

  # rel="nofollow" belongs on outbound links only. On an internal link it tells
  # search engines not to follow a URL of ours - and href="#" is internal, it
  # resolves to the page itself, which is what put the share links in Screaming
  # Frog's "Internal Nofollow Outlinks" report.
  foreach ($a in [regex]::Matches($t, '<a\s[^>]*>')) {
    if ($a.Value -notmatch 'rel="[^"]*nofollow') { continue }
    $href = [regex]::Match($a.Value, 'href="([^"]*)"').Groups[1].Value
    if ($href -match '^(mailto:|tel:)') { continue }
    $isExternal = ($href -match '^(https?:)?//') -and ($href -notlike "$base/*")
    if (-not $isExternal) { $problems += "$name has an internal nofollow link: href=""$href""" }
  }

  # Cloudflare's Email Address Obfuscation (Scrape Shield) rewrites every
  # mailto: in the served HTML to /cdn-cgi/l/email-protection#<hex>. That URL
  # 404s for anything that does not run the decoder script, so a mailto: link
  # ships as a broken internal link on every page. Fill mail links in from JS,
  # or turn the feature off in Cloudflare first.
  if ($t -match 'href="mailto:') { $problems += "$name has a mailto: link - Cloudflare rewrites it to a 404 /cdn-cgi/l/email-protection URL" }

  # Screaming Frog flags any alt over 100 characters. Long alt text is nearly
  # always the location or the business name appended to a description that
  # already reads fine without it, which is what "keyword stuffing" looks like.
  $ALT_LIMIT = 100
  foreach ($a in [regex]::Matches($t, 'alt="([^"]*)"')) {
    $alt = $a.Groups[1].Value
    if ($alt.Length -gt $ALT_LIMIT) {
      $problems += "$name has a $($alt.Length)-char alt (limit $ALT_LIMIT): '$alt'"
    }
  }

  # Screaming Frog compares the first H2 across pages. Eleven pages built from
  # one template share every structural heading; the first one has to say what
  # this page is about, or all eleven report as duplicates of each other.
  $h2 = [regex]::Match($t, '(?s)<h2[^>]*>(.*?)</h2>').Groups[1].Value -replace '<[^>]*>',' '
  $firstH2[$name] = ($h2 -replace '\s+',' ').Trim()
}

# The first H2 has to differ page to page, the same way the title and H1 do.
foreach ($g in $firstH2.GetEnumerator() | Group-Object -Property Value | Where-Object { $_.Count -gt 1 }) {
  $pages = ($g.Group | ForEach-Object { $_.Key }) -join ', '
  $problems += "$($g.Count) pages share the first H2 '$($g.Name)': $pages"
}

# Screaming Frog flags served images over 100KB; keep every one under it.
$IMG_LIMIT_KB = 100
$imgGlob = Join-Path $root "assets\img\*"   # -Include needs a wildcard path or it matches nothing
foreach ($img in Get-ChildItem $imgGlob -File -Include *.webp,*.png,*.jpg,*.jpeg) {
  $kb = [math]::Round($img.Length / 1KB, 1)
  if ($kb -gt $IMG_LIMIT_KB) { $problems += "assets/img/$($img.Name) is ${kb}KB, over the ${IMG_LIMIT_KB}KB limit" }
}

if ($problems.Count) {
  $problems | ForEach-Object { Write-Host "  FAIL  $_" -ForegroundColor Red }
  throw "$($problems.Count) canonical/link problem(s) - fix before deploying."
}

Write-Host ""
Write-Host "Built $($built.Count) city pages + index.html + sitemap.xml + robots.txt"
Write-Host "Verified: $($checks.Count) pages, all self-canonical, no tokens, no .html links" -ForegroundColor Green
Write-Host "Title widths (Arial 20px, limit ${TITLE_LIMIT_PX}px):"
$titleWidths | Sort-Object | ForEach-Object { Write-Host $_ }
