<#
  Generates the city landing pages from index.html + the city content file.

  index.html is the single source of truth for layout, styling and the SITE
  defaults (phone, business name, rating...). This script:
    1. reads the SITE object out of index.html,
    2. overrides the per-city values,
    3. substitutes every {{token}} at build time so the shipped pages contain
       final HTML rather than tokens a crawler has to run JS to resolve,
    4. swaps in the city title / description / canonical / H1 / JSON-LD,
    5. inserts a local content section and city FAQs.

  Re-run it after changing anything in index.html — including the phone
  number, which is baked into the generated pages.

    powershell -File tools\build-city-pages.ps1
#>

$ErrorActionPreference = "Stop"
$root    = Split-Path -Parent $PSScriptRoot
$tplPath = Join-Path $root "index.html"
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
Write-Host "SITE defaults read from index.html ($($SITE.Count) keys)"

function HtmlEscape([string]$s) {
  return $s -replace '&','&amp;' -replace '<','&lt;' -replace '>','&gt;'
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
    Title    = Field '\[META TITLE\]:\s*(.+)'
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

# ---------------------------------------------------------------- build pages
$built = @()

foreach ($c in $cities) {
  $loc = "$($c.City), FL"
  $url = $SITE.site_url.TrimEnd('/') + "/" + $c.Slug + ".html"

  # per-city SITE overrides, everything else inherited from index.html
  $vals = @{}
  foreach ($k in $SITE.Keys) { $vals[$k] = $SITE[$k] }
  $vals["location"]     = $loc
  $vals["city"]         = $c.City
  $vals["state"]        = "FL"
  $vals["zip"]          = $c.FirstZip
  $vals["site_url"]     = $url
  $vals["service_area"] = "$($c.City) and the surrounding area"

  $page = $tpl

  # 1. substitute every token at build time
  foreach ($k in $vals.Keys) { $page = $page.Replace("{{$k}}", $vals[$k]) }

  # 2. keep the runtime SITE object in step (the review cards read it)
  $newSite = $siteBlock
  foreach ($k in @("location","city","state","zip","site_url","service_area")) {
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

  # 5. JSON-LD: postal code, and a single locality for the postal address
  #    (areaServed keeps the combined name, a PostalAddress cannot)
  $primaryCity = ($c.City -split ' and ')[0]
  $page = [regex]::Replace($page, '"postalCode": "[^"]*"', """postalCode"": ""$($c.FirstZip)""")
  $page = [regex]::Replace($page, '"addressLocality": "[^"]*"', """addressLocality"": ""$primaryCity""")

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

  # 7. FAQ — city questions first, then the shared ones
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
  $page = $page.Replace("<a href=""$($c.Slug).html"">", "<a href=""$($c.Slug).html"" aria-current=""page"">")

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
  [void]$sm.Append("  <url>`n    <loc>$base/$($c.Slug).html</loc>`n    <lastmod>$today</lastmod>`n    <priority>0.8</priority>`n  </url>`n")
}
[void]$sm.Append("</urlset>`n")
[System.IO.File]::WriteAllText((Join-Path $root "sitemap.xml"), $sm.ToString(), (New-Object System.Text.UTF8Encoding $false))

$robots = "User-agent: *`nAllow: /`n`nSitemap: $base/sitemap.xml`n"
[System.IO.File]::WriteAllText((Join-Path $root "robots.txt"), $robots, (New-Object System.Text.UTF8Encoding $false))

Write-Host ""
Write-Host "Built $($built.Count) city pages + sitemap.xml + robots.txt"
