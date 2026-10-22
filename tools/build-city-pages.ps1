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

# The checks below measure what a reader sees, the way Screaming Frog does, so
# entities have to come back to single characters first - "&amp;" is one "&",
# not five characters of heading.
function HtmlPlain([string]$s) {
  return $s -replace '&amp;','&' -replace '&rsquo;',"'" -replace '&lsquo;',"'" -replace '&ndash;','-' -replace '&mdash;','-' -replace '&nbsp;',' ' -replace '&lt;','<' -replace '&gt;','>'
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
  "garage-door-repair-englewood-fl"                = "Garage Door Repair Englewood FL | Same-Day Service 24/7"
  "garage-door-repair-fort-myers-fl"               = "Garage Door Repair Fort Myers FL | Hurricane Code Pros"
  "garage-door-repair-north-port-fl"               = "Garage Door Repair North Port FL | Same-Day Service 24/7"
  "garage-door-repair-sarasota-fl"                 = "Garage Door Repair Sarasota FL | Same-Day Emergency"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Garage Door Repair St. Pete & Clearwater FL | Coastal Pros"
  "garage-door-repair-tampa-fl"                    = "Garage Door Repair Tampa FL | Custom Doors & Repairs"
  "garage-door-repair-venice-fl"                   = "Garage Door Repair Venice FL | Same-Day Service 24/7"
}

# H1s lead with the exact query - "Garage Door Repair in <City>, FL" - not with
# an adjective. The supplied copy opened with Dependable / Coastal / Modern,
# which pushes the keyword and the city back and, on the home page, narrowed a
# page selling twelve services down to opener replacement. The angle moves to
# the end of the H1 and stays in the hero H2 under it.
$h1Overrides = @{
  "garage-door-repair-venice-fl"                   = "Garage Door Repair in Venice, FL - Same-Day Service"
  "garage-door-repair-englewood-fl"                = "Garage Door Repair in Englewood, FL - Coastal Rust Protection"
  "garage-door-repair-north-port-fl"               = "Garage Door Repair in North Port, FL - Smart Opener Installs"
  "garage-door-repair-fort-myers-fl"               = "Garage Door Repair in Fort Myers, FL - Wind-Code Doors"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Garage Door Repair in St. Pete & Clearwater, FL"
}
# The supplied descriptions sold one niche each and two had no call to action
# at all, which the spec asks for. These lead with the query and the city, name
# what we actually fix, and end on a reason to call. Phone comes from SITE so it
# cannot drift; the build fails if any of these pass 985px in the SERP font.
$descOverrides = @{
  "garage-door-repair-venice-fl"     = "Garage door repair in Venice, FL - springs, cables, openers and new doors. Licensed, insured, 24/7 emergency service. Free estimates, call $($SITE.phone_display)."
  "garage-door-repair-englewood-fl"  = "Garage door repair in Englewood, FL. Rust-resistant springs, cables and hardware built for salt air. Same-day service, free estimates, call $($SITE.phone_display)."
  "garage-door-repair-north-port-fl" = "Garage door repair in North Port, FL. Spring and cable fixes, smart opener installs, insulated doors. Same-day service, call $($SITE.phone_display)."
}

# The hero H2 sits directly under the H1, so repeating the H1 with a question
# mark wastes it. Each one leads with what that page's own copy says is
# different about the market - salt air, wind code, HOA rules, quiet motors -
# and names the place, which is what keeps all eleven distinct.
$heroH2Overrides = @{
  "garage-door-repair-brandon-fl"                  = "60-Minute Response Across Brandon, Parts Already on the Truck"
  "garage-door-repair-englewood-fl"                = "Rust-Resistant Hardware Built for Englewood&rsquo;s Salt Air"
  "garage-door-repair-fort-myers-fl"               = "Wind-Code Doors for Fort Myers and Lee County Homes"
  "garage-door-repair-north-port-fl"               = "Smartphone Openers and Same-Day Fixes in North Port"
  "garage-door-repair-port-charlotte-fl"           = "Straight Prices and Free On-Site Estimates in Port Charlotte"
  "garage-door-repair-ruskin-fl"                   = "HOA-Approved Doors Across Ruskin and SouthShore"
  "garage-door-repair-sarasota-fl"                 = "Broken Springs to Custom Doors, All Over Sarasota"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Salt-Proof Hardware for St. Pete and Clearwater Beaches"
  "garage-door-repair-tampa-fl"                    = "Carriage House to Modern Glass, Built for Tampa Homes"
  "garage-door-repair-venice-fl"                   = "Ultra-Quiet Openers and Senior Discounts in Venice"
}
$HOME_HERO_H2 = "Serving Southwest Florida and Tampa Bay, Day and Night"

# ------------------------------------------------------------- per-city copy
# Pages built from one template used to share 13 of their 14 H2s and every word
# of the Value Props, About and Expertise sections, with only the city name
# swapped. Google indexes the strongest page of a set like that and files the
# rest as "Crawled - currently not indexed", which is what Search Console
# reported on 2026-10-22: two of three pages indexed.
#
# So those sections are written per city. What differs is what is actually
# different about the market - salt air off Lemon Bay, 55+ communities on
# Venice Island, doors in North Port that cycle ten times a day - and the facts
# come from reference/, not from invention.
#
# A city with no entry here falls back to Get-CityCopy's defaults, which at
# least name the city in every heading. The build fails if two pages still
# share a content heading, so re-enabling a city means writing it an entry.
$COPY_KEYS = @(
  "h2_values","h2_badges","h2_services","h2_about","h2_expertise","h2_gallery","h2_brands",
  "vp1_h3","vp1_p","vp2_h3","vp2_p","vp3_h3","vp3_p",
  "about_kicker","about_quote1","about_quote2","about_closing","about_checks",
  "exp1_h3","exp1_p","exp2_h3","exp2_p"
)

$cityCopy = @{

# ----------------------------------------------------------------- Venice
# Angle from reference/: quiet motors, 55+ communities, senior and veteran
# discounts, pricing agreed before the work starts.
"garage-door-repair-venice-fl" = @{
  h2_values    = "Why Venice homeowners keep our number"
  h2_badges    = "Venice guarantees, discounts and American-made parts"
  h2_services  = "Garage Door Services Across Venice"
  h2_about     = "Looking for garage door repair near Venice Island?"
  h2_expertise = "Quiet Openers and Springs Rated for Daily Use"
  h2_gallery   = "Venice Repairs, Before and After"
  h2_brands    = "Door and opener brands we fit in Venice"

  vp1_h3 = "Quiet by Default"
  vp1_p  = "Belt-drive and direct-drive motors, so an early start does not wake the house."
  vp2_h3 = "Unhurried, Explained Work"
  vp2_p  = "We show you the worn part, price it, and only then pick up a tool."
  vp3_h3 = "Senior &amp; Veteran Pricing"
  vp3_p  = "Family owned, more than $($SITE.years_experience) years in the trade, with a standing discount for seniors and veterans in Venice."

  about_kicker = "Snapped cable, grinding motor, or a door that will not clear the opening? Tell us what it is doing and we will tell you what it costs to fix."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company based in Venice. We bring more than $($SITE.years_experience) years of experience to every call, and on Venice Island that usually means a quieter motor, a spring rated for daily use, and a price agreed before anything is opened up."
  about_quote2 = "Most of our Venice customers would rather not wrestle a dead door open by hand. Call it in and we will lift it, secure it, and tell you honestly whether it needs a part or an adjustment."
  about_closing = "We have repaired garage doors from Venice Island and South Venice out along Jacaranda Blvd, Venice Ave and the Tamiami Trail. Rollers, cables, springs, weather seal, safety sensors and full opener replacements, all quoted up front."
  about_checks = @(
    "Ultra-Quiet Belt and Direct Drive Motors"
    "Battery Backup and Easy Wireless Keypads"
    "Senior and Veteran Discounts"
    "55+ Community Access Rules Respected"
  )

  exp1_h3 = "Ultra-Quiet Opener Upgrades"
  exp1_p  = "Old chain drives send noise and vibration straight through the house. We fit belt-drive and direct-drive motors with battery backup and a wireless keypad, which takes out most of the noise and all of the heavy lifting. Swapping steel rollers for sealed nylon removes the rest."
  exp2_h3 = "High-Cycle Spring Replacement"
  exp2_p  = "A standard spring is rated for roughly 10,000 cycles, which on a door used several times a day is only a few years. We fit high-cycle springs instead, replace both sides so the door stays balanced, and test it by hand before we leave."
}

# -------------------------------------------------------------- Englewood
# Angle from reference/: salt air off the Gulf, Manasota Key and Lemon Bay,
# galvanized springs, stainless cable, impact-rated doors and wind load.
"garage-door-repair-englewood-fl" = @{
  h2_values    = "Why Englewood homeowners call a coastal specialist"
  h2_badges    = "Englewood guarantees, discounts and coastal-grade parts"
  h2_services  = "Garage Door Services Across Englewood"
  h2_about     = "Looking for garage door repair near Manasota Key?"
  h2_expertise = "Rust Protection and Wind-Load Work"
  h2_gallery   = "Englewood Repairs, Before and After"
  h2_brands    = "Door and opener brands we fit in Englewood"

  vp1_h3 = "Corrosion-Rated Parts On Board"
  vp1_p  = "Galvanized springs and stainless cable ride on the truck, so a rusted-out door is fixed on the first visit."
  vp2_h3 = "Technicians Who Know Salt Air"
  vp2_p  = "We can tell pitted hardware from a bad adjustment, which is the difference between a repair and a repeat call."
  vp3_h3 = "Local and Family Run"
  vp3_p  = "Family owned, more than $($SITE.years_experience) years in the trade, working Manasota Key and the Lemon Bay area all year."

  about_kicker = "Springs pitted, cable fraying, bottom seal gone hard? Coastal hardware fails early and it rarely gives notice. Tell us what you are seeing and we will quote the fix."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving Englewood. Salt-driven wind off the Gulf is what we build around here: high-grade galvanized springs, stainless steel cable, and weather seals meant for coastal exposure rather than whatever shipped with the door."
  about_quote2 = "Hardware on the coast fails suddenly. A cable that looked sound in April lets go in September, usually on the one morning you are already late. That is why we answer out of hours."
  about_closing = "We have worked on doors from Manasota Key and the Lemon Bay waterfront back to the ranch homes off McCall Rd and Dearborn St. Rust-resistant spring replacement, stainless cable and track restoration, coastal bottom weather-stripping, and impact-rated upgrades with a wind-load inspection."
  about_checks = @(
    "Galvanized and Coated Spring Options"
    "Stainless Steel Cable and Track Restoration"
    "Coastal Bottom Weather-Stripping"
    "Emergency Service 24/7"
  )

  exp1_h3 = "Corrosion-Resistant Hardware"
  exp1_p  = "Standard steel hinges, cable and springs pit in Englewood air and then let go without warning. We replace them with high-grade galvanized springs and stainless cable, re-grease the bearings, and seal the bottom of the door so wind-driven moisture stops getting underneath it."
  exp2_h3 = "Impact-Rated Door Upgrades"
  exp2_p  = "The garage door is the largest opening in the wall and the first thing a storm tests. We fit impact-rated doors, add wind-load struts and reinforce the track on existing doors, and inspect what you already have so you know where it stands before a storm rather than during one."
}

# ------------------------------------------------------------- North Port
# Angle from reference/: fast-growing city, doors under heavy daily use,
# smart openers, insulated doors, same-day spring work.
"garage-door-repair-north-port-fl" = @{
  h2_values    = "Why North Port families book us for the same day"
  h2_badges    = "North Port guarantees, discounts and parts we back"
  h2_services  = "Garage Door Services Across North Port"
  h2_about     = "Looking for same-day garage door repair in North Port?"
  h2_expertise = "Smart Openers and High-Cycle Hardware"
  h2_gallery   = "North Port Repairs, Before and After"
  h2_brands    = "Door and opener brands we fit in North Port"

  vp1_h3 = "Same-Day Slots Held Back"
  vp1_p  = "A spring that goes at 7am should not cost you the whole day, so we keep room in the schedule for it."
  vp2_h3 = "Smart Opener Installers"
  vp2_p  = "WiFi and app-controlled motors fitted and paired properly, camera and alert setup included."
  vp3_h3 = "Family Owned, Local Trucks"
  vp3_p  = "Family owned, more than $($SITE.years_experience) years in the trade, stocked for the doors going into North Port now."

  about_kicker = "Door dead on the school run? Spring snapped overnight? Tell us what happened and we will give you a time and a price on the call."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving North Port. In one of the fastest-growing cities in Florida the doors here cycle far more than average, so our trucks carry heavy-duty high-cycle springs rather than a like-for-like builder-grade part."
  about_quote2 = "A door that will not open is not a minor inconvenience when there is a school run and a commute down Price Blvd waiting on it. That is the call we try hardest to clear the same day."
  about_closing = "We cover the neighborhoods off Price Blvd, Sumter Blvd, Toledo Blade Blvd and the Tamiami Trail. High-cycle spring replacement, cable, roller and track tune-ups, smart opener installation, and insulated doors that take some of the load off the air conditioning."
  about_checks = @(
    "High-Cycle Springs for Heavy Daily Use"
    "WiFi and App-Controlled Opener Installs"
    "Insulated, Energy-Efficient Doors"
    "Same Day Service"
  )

  exp1_h3 = "Smart Opener Installation"
  exp1_p  = "We fit openers with built-in WiFi so you can open, close and get an alert from your phone wherever you are. Camera models are set up and tested with you, app pairing and alert rules included, so it is working before we leave the driveway."
  exp2_h3 = "Insulated Door Replacement"
  exp2_p  = "An uninsulated door on a west-facing garage turns the room into a heat store and leaves the air conditioning to fight it. An insulated replacement holds the heat out, runs quieter on the track, and seals the opening better than the builder-grade panel it replaces."
}

# ----------------------------------------------------- region-level home page
# Used when HOME_CITY is "" and the home page sells the whole footprint rather
# than one city. It must not read like any single city page.
"_region" = @{
  h2_values    = "Why Southwest Florida homeowners choose us"
  h2_badges    = "Our guarantees, discounts and American-made parts"
  h2_services  = "Our Garage Door Services"
  h2_about     = "Looking for a garage door company near you?"
  h2_expertise = "Our Expertise"
  h2_gallery   = "Before and After, Across Our Service Area"
  h2_brands    = "Door and opener brands we install and service"

  vp1_h3 = "Fast Response"
  vp1_p  = "Same-day appointments across Southwest Florida and Tampa Bay, and someone on the phone out of hours."
  vp2_h3 = "Experienced Technicians"
  vp2_p  = "Licensed and insured crews who carry parts for every major door and opener brand."
  vp3_h3 = "Family Owned and Local"
  vp3_p  = "A family owned company with more than $($SITE.years_experience) years of experience on every job."

  about_kicker = "Need to replace a broken garage door spring? Tell us what the door is doing and we will quote the repair before we start."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door repair company serving Southwest Florida and Tampa Bay. We bring more than $($SITE.years_experience) years of experience to every call, and we price the work before we start it."
  about_quote2 = "We understand the frustration of not being able to get your car out in the morning, or coming home to a jammed door after work."
  about_closing = "From broken rollers to full spring and opener replacements, our technicians handle every kind of garage door fault, on residential and commercial doors alike, at a price agreed up front."
  about_checks = @(
    "Weekend Service Available"
    "Friendly Professional Service"
    "Emergency Service 24/7"
    "Same Day Service"
  )

  exp1_h3 = "Residential Garage Door Repair"
  exp1_p  = "Opener installation and repair, inspections and tune-ups. Whatever your residential door needs, $($SITE.business_name) delivers it quickly and at a fair price, and we do not leave until the door runs properly by hand as well as on the motor."
  exp2_h3 = "Commercial and Emergency Work"
  exp2_p  = "Roll-up doors, chain hoist operators and loading-bay doors, repaired out of hours when a closed door means a closed business. Call for a free estimate or just to talk through what the door is doing."
}

}

# Fills every copy token for one city: the hand-written entry above where there
# is one, otherwise a default that at least carries the city name into each
# heading. $c may be the synthetic "_region" object for a region-level home.
function Get-CityCopy($c) {
  $city = $c.City
  $copy = @{
    h2_values    = "Why $city homeowners choose us"
    h2_badges    = "$city guarantees and discounts"
    h2_services  = "Garage Door Services Across $city"
    # braced: PowerShell counts "?" as a variable-name character, so "$city?"
    # interpolates a variable called "city?" and silently drops both
    h2_about     = "Looking for garage door repair in ${city}?"
    h2_expertise = "Our Expertise in $city"
    h2_gallery   = "$city Repairs, Before and After"
    h2_brands    = "Door and opener brands we fit in $city"

    vp1_h3 = "Fast Response"
    vp1_p  = "Same-day appointments across $city, and someone on the phone out of hours."
    vp2_h3 = "Experienced Technicians"
    vp2_p  = "Licensed and insured crews who carry parts for every major door and opener brand."
    vp3_h3 = "Family Owned and Local"
    vp3_p  = "A family owned company serving $city, with more than $($SITE.years_experience) years of experience on every job."

    about_kicker = "Tell us what the door is doing and we will quote the repair before we start."
    about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving $city. We bring more than $($SITE.years_experience) years of experience to every call, and we price the work before we start it."
    about_quote2 = "We understand the frustration of not being able to get your car out in the morning, or coming home to a jammed door after work."
    about_closing = "From broken rollers to full spring and opener replacements, our technicians handle every kind of garage door fault in $city, at a price agreed up front."
    about_checks = @(
      "Weekend Service Available"
      "Friendly Professional Service"
      "Emergency Service 24/7"
      "Same Day Service"
    )

    exp1_h3 = "Residential Garage Door Repair"
    exp1_p  = "Opener installation and repair, inspections and tune-ups for homes across $city. We do not leave until the door runs properly by hand as well as on the motor."
    exp2_h3 = "Commercial and Emergency Work"
    exp2_p  = "Roll-up doors, chain hoist operators and loading-bay doors, repaired out of hours when a closed door means a closed business."
  }

  if ($cityCopy.ContainsKey($c.Slug)) {
    foreach ($k in $cityCopy[$c.Slug].Keys) { $copy[$k] = $cityCopy[$c.Slug][$k] }
  } else {
    Write-Host "  note: $($c.Slug) is on default copy - write it a `$cityCopy entry" -ForegroundColor Yellow
  }

  # the check list is written as an array for readability and ships as <li>s
  if ($copy["about_checks"] -is [array]) {
    $copy["about_checks"] = ($copy["about_checks"] | ForEach-Object { "            <li>$_</li>" }) -join "`n"
  }

  foreach ($k in $COPY_KEYS) {
    if (-not $copy.ContainsKey($k) -or -not $copy[$k]) { throw "$($c.Slug): nothing written for {{$k}}" }
  }
  foreach ($k in $copy.Keys) {
    if ($COPY_KEYS -notcontains $k) { throw "$($c.Slug): '$k' is not a copy token - typo, or add it to `$COPY_KEYS" }
  }
  return $copy
}

# ---------------------------------------------------------------- what ships
# TEMPORARY Venice-first setup. Restore the full site with:
#     $HOME_CITY = ""   and   $ACTIVE_CITIES = $null   and   $SERVED_CITIES = $null
# then re-run. Nothing is lost by switching: the city copy, FAQs and zip codes
# are read from reference/, and every page not built here is in git history.
# Write each re-enabled city a $cityCopy entry first, though: the build fails
# if two pages share a content heading, and the defaults only swap the name.
$HOME_CITY     = "garage-door-repair-venice-fl"   # "" = region-level home page
$ACTIVE_CITIES = @(                               # $null = build all ten
  "garage-door-repair-englewood-fl",
  "garage-door-repair-north-port-fl"
)
$SERVED_CITIES = @(                               # footer + areaServed; $null = all ten
  "garage-door-repair-venice-fl",
  "garage-door-repair-englewood-fl",
  "garage-door-repair-north-port-fl"
)

# Which cities each page points at. Two clusters that do not overlap: the
# Sarasota-to-Fort-Myers coast, and Tampa Bay. Linking a Venice customer to
# Brandon, 60 miles away, helps nobody - the footer should read like a local
# map. The home page keeps all ten, so every city page is still one click from
# the crawl entry point and the sitemap lists them all either way.
$neighbours = @{
  "garage-door-repair-sarasota-fl"                 = @("garage-door-repair-venice-fl","garage-door-repair-north-port-fl","garage-door-repair-englewood-fl")
  "garage-door-repair-venice-fl"                   = @("garage-door-repair-sarasota-fl","garage-door-repair-englewood-fl","garage-door-repair-north-port-fl")
  "garage-door-repair-englewood-fl"                = @("garage-door-repair-venice-fl","garage-door-repair-north-port-fl","garage-door-repair-port-charlotte-fl")
  "garage-door-repair-north-port-fl"               = @("garage-door-repair-port-charlotte-fl","garage-door-repair-venice-fl","garage-door-repair-sarasota-fl")
  "garage-door-repair-port-charlotte-fl"           = @("garage-door-repair-north-port-fl","garage-door-repair-englewood-fl","garage-door-repair-fort-myers-fl")
  "garage-door-repair-fort-myers-fl"               = @("garage-door-repair-port-charlotte-fl","garage-door-repair-north-port-fl")
  "garage-door-repair-tampa-fl"                    = @("garage-door-repair-brandon-fl","garage-door-repair-st-petersburg-clearwater-fl","garage-door-repair-ruskin-fl")
  "garage-door-repair-brandon-fl"                  = @("garage-door-repair-tampa-fl","garage-door-repair-ruskin-fl","garage-door-repair-st-petersburg-clearwater-fl")
  "garage-door-repair-ruskin-fl"                   = @("garage-door-repair-brandon-fl","garage-door-repair-tampa-fl","garage-door-repair-st-petersburg-clearwater-fl")
  "garage-door-repair-st-petersburg-clearwater-fl" = @("garage-door-repair-tampa-fl","garage-door-repair-brandon-fl","garage-door-repair-ruskin-fl")
}

# slug -> footer label, read out of the template's own list so the labels are
# written in one place only
$areaLabels = @{}
foreach ($m in [regex]::Matches($tpl, '<li><a href="/([a-z0-9-]+)">([^<]+)</a></li>')) {
  $areaLabels[$m.Groups[1].Value] = $m.Groups[2].Value
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
    Desc     = $(if ($descOverrides.ContainsKey($slug)) { $descOverrides[$slug] } else { Field '\[META DESCRIPTION\]:\s*(.+)' })
    H1       = $(if ($h1Overrides.ContainsKey($slug)) { $h1Overrides[$slug] } else { Field '\[H1\]:\s*(.+)' })
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

# ---------------------------------------------------------- page-part builders
# Shared by the home page and the city pages, so the two cannot drift apart.
function Build-LocalSection($c, $vals) {
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
  foreach ($s in $c.Services) {
    # the supplied copy still lists remote programming, which we do not offer
    $s = $s -replace 'Remote Control Programming', 'Keypad Programming'
    [void]$sb.Append("            <li>$(HtmlEscape $s)</li>`n")
  }
  [void]$sb.Append("          </ul>`n")
  [void]$sb.Append("          <h3>Local Service Area</h3>`n")
  [void]$sb.Append("          <p>$(HtmlEscape $c.AreaText)</p>`n")
  if ($c.Zips) { [void]$sb.Append("          <p class=""local__zips""><strong>Zip codes served:</strong> $(HtmlEscape $c.Zips)</p>`n") }
  [void]$sb.Append("          <p><a class=""btn btn--call"" href=""tel:$($vals.phone_number)"" data-cta=""local-call"">Call $(HtmlEscape $vals.phone_display)</a></p>`n")
  [void]$sb.Append("        </aside>`n      </div>`n    </div>`n  </section>`n")
  return $sb.ToString()
}

function Add-CityFaqs([string]$page, $c) {
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

  # if the city already answers "how fast can you get here", drop the generic
  # version rather than asking near-identical questions twice
  $asksSpeed = $false
  foreach ($f in $c.Faqs) { if ($f[0] -match '(?i)how (quickly|fast|soon)|reach my home') { $asksSpeed = $true } }
  if ($asksSpeed) {
    # matched on the template's exact wording, so fail loudly if that wording
    # changes - otherwise the duplicate question silently comes back
    $speedRe = '(?s)\s*<details>\s*<summary>How fast can a technician get to my home\?</summary>.*?</details>'
    if (-not [regex]::IsMatch($page, $speedRe)) { throw "$($c.Slug): shared 'how fast' FAQ not found to de-duplicate - its template wording changed" }
    $page = [regex]::Replace($page, $speedRe, '')
  }
  return $page
}
function Build-AreaLinks($list, $currentSlug) {
  # only link to pages that are actually generated: the current page is not a
  # link to itself, and an area with no page of its own is named in plain text
  $items = ($list | ForEach-Object {
    $slug  = $_.Slug
    $label = if ($areaLabels.ContainsKey($slug)) { $areaLabels[$slug] } else { $_.City }
    if ($slug -eq $currentSlug) { "          <li class=""area-plain"" aria-current=""page"">$label</li>" }
    elseif ($slug -eq $HOME_CITY) { "          <li><a href=""/"">$label</a></li>" }
    elseif ($null -eq $ACTIVE_CITIES -or $ACTIVE_CITIES -contains $slug) { "          <li><a href=""/$slug"">$label</a></li>" }
    else { "          <li class=""area-plain"">$label</li>" }
  }) -join "`n"
  return "<h3 id=""footer-areas"">Service Areas</h3>`n        <ul class=""footer-links"">`n$items`n        </ul>"
}
# ----------------------------------------------------------------- home page
# The template must never ship as-is: Screaming Frog and Googlebot's first pass
# read raw HTML, and an unrendered <link rel="canonical" href="{{page_url}}">
# resolves to a different URL, which is exactly the "canonicalised" report.
$homeCity = $null
if ($HOME_CITY) {
  $homeCity = $cities | Where-Object { $_.Slug -eq $HOME_CITY } | Select-Object -First 1
  if (-not $homeCity) { throw "HOME_CITY '$HOME_CITY' is not in the city content file" }
}

# the areas named in the footer and in areaServed
$servedCities = if ($null -eq $SERVED_CITIES) { $cities } else {
  $SERVED_CITIES | ForEach-Object {
    $sl  = $_
    $hit = $cities | Where-Object { $_.Slug -eq $sl } | Select-Object -First 1
    if (-not $hit) { throw "SERVED_CITIES lists '$sl', which is not in the city content file" }
    $hit
  }
}

$homePage = $tpl
$homeVals = @{}
foreach ($k in $SITE.Keys) { $homeVals[$k] = $SITE[$k] }
$homeVals["page_url"] = $SITE.site_url          # the home page is the site root
$homeVals["hero_h2"]  = $HOME_HERO_H2
if ($homeCity) {
  # the home page IS this city's page, so no separate city page competes with it
  $homeVals["location"]     = "$($homeCity.City), FL"
  $homeVals["zip"]          = $homeCity.FirstZip
  $homeVals["service_area"] = (($servedCities | ForEach-Object { $_.City }) -join ", ")
  if ($heroH2Overrides.ContainsKey($homeCity.Slug)) { $homeVals["hero_h2"] = $heroH2Overrides[$homeCity.Slug] }
}

# section headings and body prose: this city's own, or the region set when the
# home page is not a city page
$homeCopyFor = if ($homeCity) { $homeCity } else {
  [pscustomobject]@{ Slug = "_region"; City = $SITE.location }
}
$homeCopy = Get-CityCopy $homeCopyFor
foreach ($k in $homeCopy.Keys) { $homeVals[$k] = $homeCopy[$k] }

foreach ($k in $homeVals.Keys) { $homePage = $homePage.Replace("{{$k}}", $homeVals[$k]) }
$homePage = [regex]::Replace($homePage, '(?m)^(\s*page_url\s*:\s*")(.*?)(")', { param($m) $m.Groups[1].Value + $SITE.site_url + $m.Groups[3].Value })

# keep the runtime SITE object in step with the tokens
$newHomeSite = $siteBlock
foreach ($k in @("location","zip","page_url","service_area")) {
  $newHomeSite = [regex]::Replace($newHomeSite, "(?m)^(\s*$k\s*:\s*"")(.*?)("")", { param($m) $m.Groups[1].Value + $homeVals[$k] + $m.Groups[3].Value })
}
$homePage = $homePage.Replace($siteBlock, $newHomeSite)

if ($homeCity) {
  $homeTitle = HtmlEscape $homeCity.Title
  $homeDesc  = HtmlEscape $homeCity.Desc
} else {
  # a region-level home page must not compete with any single city page
  $homeTitle = "Garage Door Repair SW Florida &amp; Tampa Bay | 24/7 Service"
  $homeDesc  = "Same-day garage door repair across Southwest Florida and Tampa Bay. Licensed &amp; insured, 24/7 emergency service, free estimates. Call $($SITE.phone_display)."
}
$homePage = [regex]::Replace($homePage, '(?s)<title>.*?</title>', "<title>$homeTitle</title>")
$homePage = [regex]::Replace($homePage, '<meta name="description" content=".*?">', "<meta name=""description"" content=""$homeDesc"">")
$homePage = [regex]::Replace($homePage, '<meta property="og:title" content=".*?">', "<meta property=""og:title"" content=""$homeTitle"">")
$homePage = [regex]::Replace($homePage, '<meta property="og:description" content=".*?">', "<meta property=""og:description"" content=""$homeDesc"">")

if ($homeCity) {
  $homePage = [regex]::Replace($homePage, '(?s)(<h1 id="hero-title">).*?(</h1>)', "`${1}$(HtmlEscape $homeCity.H1)`${2}")
  $homeAbout = '  <!-- ==================== ABOUT ==================== -->'
  $homePage  = $homePage.Replace($homeAbout, (Build-LocalSection $homeCity $homeVals) + "`n" + $homeAbout)
  $homePage  = Add-CityFaqs $homePage $homeCity
}

# a region is not a schema.org City, so list the markets actually served
$areaList = ($servedCities | ForEach-Object { "      { ""@type"": ""City"", ""name"": ""$($_.City), FL"" }" }) -join ",`n"
$homePage = [regex]::Replace($homePage,
  '"areaServed": \{ "@type": "City", "name": "[^"]*" \},',
  """areaServed"": [`n$areaList`n  ],")

$homeAreas = Build-AreaLinks $servedCities $HOME_CITY
$homePage  = [regex]::Replace($homePage, '(?s)<h3 id="footer-areas">.*?</ul>', { param($m) $homeAreas })

$leftover = [regex]::Matches($homePage, '\{\{\w+\}\}')
if ($leftover.Count) { throw "Home page still has unresolved tokens: $(($leftover | ForEach-Object { $_.Value } | Select-Object -Unique) -join ', ')" }

[System.IO.File]::WriteAllText((Join-Path $root "index.html"), $homePage, (New-Object System.Text.UTF8Encoding $false))
Write-Host "index.html                                     $([int]((Get-Item (Join-Path $root 'index.html')).Length/1KB)) KB   (home page, rendered)"

# ---------------------------------------------------------------- build pages
$built = @()

foreach ($c in $cities) {
  if ($null -ne $ACTIVE_CITIES -and $ACTIVE_CITIES -notcontains $c.Slug) { continue }
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
  # falls back to the old wording if a city is added without an angle written
  $vals["hero_h2"]      = $(if ($heroH2Overrides.ContainsKey($c.Slug)) { $heroH2Overrides[$c.Slug] } else { "Need $($SITE.service_name) in $loc?" })

  # section headings and body prose written for this city, so no two pages ship
  # the same Value Props, About or Expertise text with a swapped city name
  $copy = Get-CityCopy $c
  foreach ($k in $copy.Keys) { $vals[$k] = $copy[$k] }

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

  # 5. footer service areas
  if ($null -ne $SERVED_CITIES) {
    $areasBlock = Build-AreaLinks $servedCities $c.Slug
  } else {
    $near = $neighbours[$c.Slug]
    if (-not $near) { throw "No neighbouring cities listed for $($c.Slug)" }
    $items = ($near | ForEach-Object {
      if (-not $areaLabels.ContainsKey($_)) { throw "No footer label for $_" }
      "          <li><a href=""/$_"">$($areaLabels[$_])</a></li>"
    }) -join "`n"
    $areasBlock = "<h3 id=""footer-areas"">Nearby Service Areas</h3>`n" +
                  "        <ul class=""footer-links"">`n$items`n        </ul>"
  }
  $page = [regex]::Replace($page, '(?s)<h3 id="footer-areas">.*?</ul>', { param($m) $areasBlock })



  # 6. schema: a city page describes the service in that city and points at the
  # single business entity, which lives on the home page. Eleven copies of the
  # same LocalBusiness - one @id, eleven urls, the same phone, email and rating
  # in each - is one business described eleven contradictory ways. The
  # business entity lives on the home page; provider references it by @id.
  $catalog = [regex]::Match($page, '(?s)"hasOfferCatalog":\s*\{.*?\n  \}').Value
  if (-not $catalog) { throw "Could not read hasOfferCatalog out of $($c.Slug)" }
  $serviceLd = @"
<script type="application/ld+json">
{
  "@context": "https://schema.org",
  "@type": "Service",
  "@id": "$url#service",
  "name": "$($SITE.service_name) in $loc",
  "serviceType": "$($SITE.service_name)",
  "url": "$url",
  "areaServed": { "@type": "City", "name": "$loc" },
  "provider": {
    "@type": "LocalBusiness",
    "@id": "$($SITE.site_url)#localbusiness",
    "name": "$($SITE.business_name)",
    "url": "$($SITE.site_url)"
  },
  $catalog
}
</script>
"@
  $page = [regex]::Replace($page, '(?s)<script type="application/ld\+json">.*?</script>', { param($m) $serviceLd })

  # 7. no way out: these pages exist to produce a call or a form, so the logo
  # stops being a link home. The home page still links to every city, and the
  # sitemap lists them, so nothing becomes uncrawlable.
  $page = [regex]::Replace($page, '(?s)<a class="brand" href="/"[^>]*>(.*?)</a>',
    { param($m) '<span class="brand">' + $m.Groups[1].Value + '</span>' })
  # 8. local content section, inserted before About
  $aboutMarker = '  <!-- ==================== ABOUT ==================== -->'
  $page = $page.Replace($aboutMarker, (Build-LocalSection $c $vals) + "`n" + $aboutMarker)

  # 7. FAQ - city questions first, then the shared ones, de-duplicated
  $page = Add-CityFaqs $page $c


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
# a here-string drops the final newline; text files should end with one
[System.IO.File]::WriteAllText((Join-Path $root "_headers"), $headers + "`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host "_headers written (CSP with $($inlineHashes.script.Count) script + $($inlineHashes.style.Count) style hash)"

# ---------------------------------------------------------------- _redirects
# Netlify resolves /page from page.html, but it also keeps serving page.html
# itself at 200, so every page answers on two URLs. The canonical tag points
# the right way and Google honours it, but it still has to crawl and compare
# both. A 301 removes the duplicate instead of explaining it. Forced (301!)
# because a static file at that path would otherwise win.
#
# No loop: the rules match the requested path, and a request for /page never
# matches /page.html - Netlify's extensionless resolution happens after this.
$redir = New-Object System.Text.StringBuilder
[void]$redir.Append("# generated by tools/build-city-pages.ps1 - do not edit`n")
[void]$redir.Append("/index.html    /    301!`n")
foreach ($c in $built) {
  [void]$redir.Append("/$($c.Slug).html    /$($c.Slug)    301!`n")
}
[System.IO.File]::WriteAllText((Join-Path $root "_redirects"), $redir.ToString(), (New-Object System.Text.UTF8Encoding $false))
Write-Host "_redirects written ($($built.Count + 1) .html -> extensionless 301s)"

$robots = "User-agent: *`nAllow: /`nDisallow: /tools/`n`nSitemap: $base/sitemap.xml`n"
[System.IO.File]::WriteAllText((Join-Path $root "robots.txt"), $robots, (New-Object System.Text.UTF8Encoding $false))

# ------------------------------------------------------------------- verify
# Every deployed page must carry a self-referencing canonical and no leftover
# tokens, or search engines are told to consolidate it somewhere else.
# PowerShell's ConvertFrom-Json accepts JSON-LD with a raw line break inside a
# string; Google does not, and drops the whole block. Scan for it directly.
function Test-JsonControlChars([string]$json) {
  $inStr = $false; $esc = $false
  foreach ($ch in $json.ToCharArray()) {
    if ($inStr) {
      if ($esc) { $esc = $false; continue }
      if ($ch -eq [char]92) { $esc = $true; continue }
      if ($ch -eq [char]34) { $inStr = $false; continue }
      if ([int]$ch -lt 32) { return ('a raw 0x{0:X2} character' -f [int]$ch) }
    } elseif ($ch -eq [char]34) { $inStr = $true }
  }
  return $null
}
$problems = @()
$firstH2 = @{}
$h2sByPage = @{}
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
  # the Venice unit is a real, staffed location, so every page publishes the same
  # NAP: once in the footer for people, once as PostalAddress for crawlers. The
  # street must match SITE exactly - a footer and a schema that disagree is worse
  # than either alone, and Google reads the pair as two different businesses.
  if ($t -notmatch '<address[\s>]') { $problems += "$name has no <address> block in the footer" }
  # the LocalBusiness entity is defined once, on the home page; city pages carry a
  # Service that references it by @id, so only the home page states the address in
  # schema. Both kinds state it in the footer.
  if ($name -eq 'index.html') {
    if ($t -notmatch '"@type":\s*"PostalAddress"') { $problems += "$name has no PostalAddress in the JSON-LD" }
  } elseif ($t -match '"@type":\s*"PostalAddress"') {
    $problems += "$name repeats the PostalAddress - the business entity belongs on the home page only"
  }
  foreach ($bit in @($SITE.address_locality, $SITE.address_region, $SITE.postal_code)) {
    if ($t -notmatch [regex]::Escape($bit)) { $problems += "$name is missing '$bit' from the published address" }
  }
  if ($t -match 'Remote Control Programming') { $problems += "$name lists remote programming, a service we do not offer" }

  foreach ($ldm in [regex]::Matches($t, '(?s)<script type="application/ld\+json">(.*?)</script>')) {
    $bad = Test-JsonControlChars $ldm.Groups[1].Value
    if ($bad) { $problems += "$name JSON-LD has $bad inside a string - invalid JSON" }
  }

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
  # a link to a page we no longer build is a 404 in the footer of every page
  foreach ($lnk in [regex]::Matches($t, 'href="(/[^"#?]*)"')) {
    $target = $lnk.Groups[1].Value
    if ($target -eq "/") { continue }
    if (-not (Test-Path (Join-Path $root (($target.TrimStart('/') -replace '/','\') + ".html")))) {
      $problems += "$name links to $target, which is not generated"
    }
  }

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
    $alt = HtmlPlain $a.Groups[1].Value
    if ($alt.Length -gt $ALT_LIMIT) {
      $problems += "$name has a $($alt.Length)-char alt (limit $ALT_LIMIT): '$alt'"
    }
  }

  # Screaming Frog compares the first H2 across pages. Eleven pages built from
  # one template share every structural heading; the first one has to say what
  # this page is about, or all eleven report as duplicates of each other.
  $h2 = [regex]::Match($t, '(?s)<h2[^>]*>(.*?)</h2>').Groups[1].Value -replace '<[^>]*>',' '
  $firstH2[$name] = (HtmlPlain ($h2 -replace '\s+',' ')).Trim()

  # Multiple H2s are fine - HTML allows them - but the outline has to hold up:
  # one H1, no jump from H2 straight to H4, and no heading text repeated on the
  # page (two "Our Services" H2s is what put the footer nav at content rank).
  # Screaming Frog flags an H1 or H2 over 70 characters as too long to be useful.
  $H1_LIMIT = 70
  $H2_LIMIT = 70
  $levels = [regex]::Matches($t, '<h([1-6])[^>]*>(.*?)</h[1-6]>', 'Singleline')
  $h1Count = @($levels | Where-Object { $_.Groups[1].Value -eq '1' }).Count
  if ($h1Count -ne 1) { $problems += "$name has $h1Count H1s, expected exactly 1" }
  $prev = 0
  $texts = @{}
  $h2sByPage[$name] = @()
  foreach ($h in $levels) {
    $lvl  = [int]$h.Groups[1].Value
    $text = (HtmlPlain (($h.Groups[2].Value -replace '<[^>]*>',' ') -replace '\s+',' ')).Trim()
    if ($lvl -eq 2) { $h2sByPage[$name] += $text }
    if ($prev -and $lvl -gt $prev + 1) { $problems += "$name skips from H$prev to H${lvl} at '$text'" }
    if ($lvl -eq 1 -and $text.Length -gt $H1_LIMIT) {
      $problems += "$name has a $($text.Length)-char H1 (limit $H1_LIMIT): '$text'"
    }
    if ($lvl -eq 2 -and $text.Length -gt $H2_LIMIT) {
      $problems += "$name has a $($text.Length)-char H2 (limit $H2_LIMIT): '$text'"
    }
    if ($texts.ContainsKey($text)) { $problems += "$name repeats the heading '$text' (H$($texts[$text]) and H$lvl)" }
    else { $texts[$text] = $lvl }
    $prev = $lvl
  }
}

# The first H2 has to differ page to page, the same way the title and H1 do.
foreach ($g in $firstH2.GetEnumerator() | Group-Object -Property Value | Where-Object { $_.Count -gt 1 }) {
  $pages = ($g.Group | ForEach-Object { $_.Key }) -join ', '
  $problems += "$($g.Count) pages share the first H2 '$($g.Name)': $pages"
}

# ...and so does every other content H2. These pages shared 13 of their 14 and
# Google indexed two of three, filing the rest as "Crawled - currently not
# indexed": it reads a set like that as one page restated with the city swapped.
# The four below are chrome - the FAQ wrapper, the lead form, the share dialog -
# and say nothing about the subject, so they are allowed to repeat.
$CHROME_H2 = @(
  "Frequently Asked Questions"
  "Don't Hesitate To Contact Us For More Information And Services"
  "Share"
  "Get a free quote"
)
$h2Pages = @{}
foreach ($pg in $h2sByPage.GetEnumerator()) {
  foreach ($text in ($pg.Value | Select-Object -Unique)) {
    if ($CHROME_H2 -contains $text) { continue }
    if (-not $h2Pages.ContainsKey($text)) { $h2Pages[$text] = @() }
    $h2Pages[$text] += $pg.Key
  }
}
foreach ($e in $h2Pages.GetEnumerator()) {
  if ($e.Value.Count -le 1) { continue }
  $problems += "$($e.Value.Count) pages share the content H2 '$($e.Key)': $(($e.Value | Sort-Object) -join ', ') - write it per city in `$cityCopy"
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
