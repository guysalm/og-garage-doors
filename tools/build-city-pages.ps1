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

# The token legend is a comment listing every {{token}} by name, which means
# substitution fills it in like any other occurrence: every shipped page was
# carrying a second copy of its own headings and body prose inside an HTML
# comment. Harmless to a crawler, but it is dead weight, and with the service
# cards and FAQ answers tokenised it had grown to about 3KB a page. Strip the
# legend before anything is substituted, so the built pages never see it.
$legendRe = '(?s)\n<!-- ={20,}\s*\r?\n\s+DYNAMIC SEO PLACEHOLDERS.*?={20,} -->\n'
if (-not [regex]::IsMatch($tpl, $legendRe)) {
  throw "token legend comment not found in template.html - its opening or closing rule changed"
}
$tpl = [regex]::Replace($tpl, $legendRe, "`n")

# ---------------------------------------------------------------- SITE values
$siteBlock = [regex]::Match($tpl, '(?s)var SITE = \{(.*?)\n\};').Groups[1].Value
$SITE = @{}
foreach ($m in [regex]::Matches($siteBlock, '(?m)^\s*([a-z_]+)\s*:\s*"(.*?)"\s*,?\s*$')) {
  $SITE[$m.Groups[1].Value] = $m.Groups[2].Value
}
Write-Host "SITE defaults read from tools/template.html ($($SITE.Count) keys)"

# site_host gates the analytics tag, and it is the one SITE value the tag
# compares against location.hostname rather than printing. If it drifts from
# site_url the tag goes quiet on the live site and nothing else breaks, so
# nobody notices until the property flatlines. Derive and compare instead.
$siteHostExpected = ([Uri]$SITE.site_url).Host
if ($SITE.site_host -ne $siteHostExpected) {
  throw "SITE.site_host is '$($SITE.site_host)' but site_url resolves to '$siteHostExpected' - the analytics guard would never match"
}

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
  "garage-door-repair-sarasota-fl"                 = "Garage Door Repair Sarasota FL | Same-Day Service 24/7"
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
  "garage-door-repair-sarasota-fl"                 = "Garage Door Repair in Sarasota, FL - HOA-Approved Doors"
  "garage-door-repair-fort-myers-fl"               = "Garage Door Repair in Fort Myers, FL - Wind-Load Hardware"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Garage Door Repair in St. Pete & Clearwater, FL"
}
# The supplied descriptions sold one niche each and two had no call to action
# at all, which the spec asks for. These lead with the query and the city, name
# what we actually fix, and end on a reason to call. Phone comes from SITE so it
# cannot drift; the build fails if any of these pass 985px in the SERP font.
$descOverrides = @{
  "garage-door-repair-venice-fl"     = "Garage door repair in Venice, FL - springs, cables, openers and panels. Licensed, insured, 24/7 emergency service. Free estimates, call $($SITE.phone_display)."
  "garage-door-repair-englewood-fl"  = "Garage door repair in Englewood, FL. Rust-resistant springs, cables and hardware built for salt air. Same-day service, free estimates, call $($SITE.phone_display)."
  "garage-door-repair-north-port-fl" = "Garage door repair in North Port, FL. Spring and cable fixes, smart opener installs, roller and track tune-ups. Same-day service, call $($SITE.phone_display)."
  "garage-door-repair-sarasota-fl"   = "Garage door repair in Sarasota, FL. Springs, cables and openers, plus HOA-approved doors for Lakewood Ranch and Palmer Ranch. Call $($SITE.phone_display)."
}

# The hero H2 sits directly under the H1, so repeating the H1 with a question
# mark wastes it. Each one leads with what that page's own copy says is
# different about the market - salt air, wind code, HOA rules, quiet motors -
# and names the place, which is what keeps all eleven distinct.
$heroH2Overrides = @{
  "garage-door-repair-brandon-fl"                  = "60-Minute Response Across Brandon, Parts Already on the Truck"
  "garage-door-repair-englewood-fl"                = "Rust-Resistant Hardware Built for Englewood&rsquo;s Salt Air"
  "garage-door-repair-fort-myers-fl"               = "Wind-Load Hardware and Storm-Ready Repairs in Fort Myers"
  "garage-door-repair-north-port-fl"               = "Smartphone Openers and Same-Day Fixes in North Port"
  "garage-door-repair-port-charlotte-fl"           = "Straight Prices and Free On-Site Estimates in Port Charlotte"
  "garage-door-repair-ruskin-fl"                   = "Straight Answers and Same-Day Repairs Across Ruskin"
  "garage-door-repair-sarasota-fl"                 = "Trucks on the I-75 Corridor, Same-Day Across Sarasota"
  "garage-door-repair-st-petersburg-clearwater-fl" = "Salt-Proof Hardware for St. Pete and Clearwater Beaches"
  "garage-door-repair-tampa-fl"                    = "Spring, Cable and Opener Repairs Across Tampa"
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
  "exp1_h3","exp1_p","exp2_h3","exp2_p",
  # the twelve service-card descriptions. Shared, they were the largest
  # duplicate block on the site: 333 words of body copy, byte-identical on
  # every page, more than the Value Props, About and Expertise sections put
  # together. The card headings stay shared - they are the service names, and
  # renaming "Broken Spring Repair" per city would cost the keyword.
  "svc_spring_p","svc_opener_p","svc_offtrack_p","svc_cable_p",
  "svc_jackshaft_p","svc_roller_p","svc_panels_p","svc_commercial_p",
  "svc_gate_p","svc_tuneup_p","svc_sensor_p","svc_smart_p",
  # the four shared FAQ answers. The questions stay shared: Add-CityFaqs
  # matches the "How fast can a technician get to my home?" wording to drop
  # it from a page that asks its own speed question, and throws if it moves.
  #
  # svc_newdoor_p, faq_windcode_a and faq_hoa_a are gone with the new-door
  # card and the two door-selling FAQs - see the note on door installation
  # below. Removed from the keys rather than left unused, because the
  # completeness check throws on a key no page fills.
  "faq_speed_a","faq_weekend_a","faq_springcost_a","faq_estimate_a"
)

# -------------------------------------------------- NO DOOR INSTALLATION
# The site must not offer, imply or illustrate garage door installation or
# supply. The BBB asked for a contractor licence to back the claim on
# 2026-11-04 and we do not hold one; repair, parts replacement and opener,
# gate and hardware work are all unaffected and stay.
#
# That is wider than deleting one service card. Door SALES copy had reached
# the page titles, the meta descriptions, the Expertise sections, the
# per-city service lists that come from reference/, the brand strip, the
# before/after gallery and a customer review. $BANNED_CLAIMS fails the build
# if any of it comes back - including from reference/, which is not ours to
# edit and still lists doors for sale.
#
# If the licence is granted, this is one revert: git log for the commit
# that removed it.
#
# The patterns are claim-shaped on purpose - a verb we do, next to a door.
# Naming a door is fine and has to stay fine: the spring-price answer has to
# be able to say an impact-rated door weighs more than a single-skin one,
# because that is why the spring costs what it does. What may not appear is
# us installing, fitting, supplying, selling, carrying or stocking one.
$BANNED_CLAIMS = @(
  '(?i)\bnew (garage )?doors? install'
  '(?i)\bgarage doors? install\b'
  # the noun exclusion keeps the parts we DO fit out of it - "we stock the
  # spring sizes Venice doors use" is a spring claim that happens to end in
  # the word doors
  '(?i)\bwe (install|fit|supply|sell|carry|stock|order)\b(?:(?!spring|opener|roller|cable|panel|seal|strut|track|hinge|gasket|motor|operator|keypad)[^.<]){0,60}?\b(garage )?doors?\b'
  '(?i)\bdoors? (installed|fitted|supplied)\b'
  '(?i)\breplacement garage doors?\b'
  '(?i)\bgarage doors? dealer\b'
  '(?i)\bdoor upgrades?\b'
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
  h2_brands    = "Door and opener brands we service in Venice"

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

  # Angle: quiet motors in 55+ streets, the price agreed before work starts.
  svc_spring_p     = "Spring let go overnight? We stock the spring sizes Venice doors use and fit it same day."
  svc_opener_p     = "Motor loud enough to wake the neighbors? We fit quiet belt-drive openers."
  svc_offtrack_p   = "Door jumped the rail? We straighten the track and reset it safely, not forcefully."
  svc_cable_p      = "Frayed or slack cable? We replace both sides and rebalance the door before we leave."
  svc_jackshaft_p  = "Golf cart lift or storage overhead? A wall-mounted jackshaft opener clears the ceiling."
  svc_roller_p     = "Rattling door on a quiet street? Nylon rollers run close to silent on the track."
  svc_panels_p     = "One dented section does not mean a new door. We match the panel and replace it."
  svc_commercial_p = "Storefronts and units off Jacaranda Blvd &ndash; roll-ups, operators and loading doors."
  svc_gate_p       = "Community or driveway gate stuck? We repair the operator and reset the limits."
  svc_tuneup_p     = "A 25-point tune-up finds the spring and cable wear before it strands you."
  svc_sensor_p     = "Door reversing halfway? Photo-eye alignment or replacement, tested while you watch."
  svc_smart_p      = "Phone control fitted and shown to you properly, keypad code set before we go."

  # The speed question survives here: Venice's own FAQs do not ask it.
  faq_speed_a      = "We keep trucks working both the island and the mainland side of Venice, so a dead door is normally a same-day visit &mdash; most calls see a technician inside 60 to 90 minutes, and someone answers the phone out of hours."
  faq_weekend_a    = "No. The rate is the same seven days a week, holidays included, and the senior and veteran discount applies on a Sunday exactly as it does on a Tuesday. Emergency cover runs 24/7."
  faq_springcost_a = "The spring is sized to the door it lifts, so the door sets the price, not the spring. Width and height, what the panels are made of, whether it is insulated, whether it carries window sections, and whether it is standard wind-load or impact-rated all change what the door weighs and how much spring capacity it needs. A single-car residential door in Venice usually lands in the few-hundred range; a commercial door can reach the thousands. So we measure the door and read the spring already on it before quoting &mdash; that is the only way to give a real number instead of a guess. The visit and the estimate are free, and the full price is agreed before anyone starts work."
  faq_estimate_a   = "Yes. We price the job before anyone picks up a tool, and the figure we give you is the figure you pay &mdash; no hidden fees and nothing added at the end. Decide against it and the visit has cost you nothing."
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
  h2_brands    = "Door and opener brands we service in Englewood"

  vp1_h3 = "Corrosion-Rated Parts On Board"
  vp1_p  = "Galvanized springs and stainless cable ride on the truck, so a rusted-out door is fixed on the first visit."
  vp2_h3 = "Technicians Who Know Salt Air"
  vp2_p  = "We can tell pitted hardware from a bad adjustment, which is the difference between a repair and a repeat call."
  vp3_h3 = "Local and Family Run"
  vp3_p  = "Family owned, more than $($SITE.years_experience) years in the trade, working Manasota Key and the Lemon Bay area all year."

  about_kicker = "Springs pitted, cable fraying, bottom seal gone hard? Coastal hardware fails early and it rarely gives notice. Tell us what you are seeing and we will quote the fix."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving Englewood. Salt-driven wind off the Gulf is what we build around here: high-grade galvanized springs, stainless steel cable, and weather seals meant for coastal exposure rather than whatever shipped with the door."
  about_quote2 = "Hardware on the coast fails suddenly. A cable that looked sound in April lets go in September, usually on the one morning you are already late. That is why we answer out of hours."
  about_closing = "We have worked on doors from Manasota Key and the Lemon Bay waterfront back to the ranch homes off McCall Rd and Dearborn St. Rust-resistant spring replacement, stainless cable and track restoration, coastal bottom weather-stripping, and wind-load struts with a storm-readiness inspection."
  about_checks = @(
    "Galvanized and Coated Spring Options"
    "Stainless Steel Cable and Track Restoration"
    "Coastal Bottom Weather-Stripping"
    "Emergency Service 24/7"
  )

  exp1_h3 = "Corrosion-Resistant Hardware"
  exp1_p  = "Standard steel hinges, cable and springs pit in Englewood air and then let go without warning. We replace them with high-grade galvanized springs and stainless cable, re-grease the bearings, and seal the bottom of the door so wind-driven moisture stops getting underneath it."
  exp2_h3 = "Wind-Load Reinforcement"
  exp2_p  = "The garage door is the largest opening in the wall and the first thing a storm tests. We add wind-load struts, reinforce the track and replace hardware that has started to pit, and we inspect the door you already have so you know where it stands before a storm rather than during one."

  # Angle: salt air off Lemon Bay, so every answer is about corrosion.
  svc_spring_p     = "Salt air pits springs years early here. We fit galvanized replacements same-day."
  svc_opener_p     = "Corroded board or a motor straining? We repair it or fit a sealed replacement."
  svc_offtrack_p   = "Seized roller pulled the door off the rail? We realign it and replace what bound up."
  svc_cable_p      = "Cables rust from the bottom strand up near the water. We replace both and rebalance."
  svc_jackshaft_p  = "Low ceiling in an older coastal garage? A wall-mounted opener frees the whole span."
  svc_roller_p     = "Salt-bitten rollers grind and shake the door. Sealed nylon runs quiet and resists it."
  svc_panels_p     = "Bottom section rusting through? We replace that panel rather than the whole door."
  svc_commercial_p = "Commercial roll-ups close to the water, where hardware corrodes first. Fully insured."
  svc_gate_p       = "Gate operator seized in the salt? We service the motor and reset the safety limits."
  svc_tuneup_p     = "On Manasota Key a tune-up is corrosion control: lubricate, re-torque, check fixings."
  svc_sensor_p     = "Sensors fail early in damp salt air. We realign or replace them and test the reverse."
  svc_smart_p      = "WiFi openers and weather-sealed keypads that survive a Gulf-facing wall."

  # The speed question survives here: Englewood's own FAQ is about rust.
  faq_speed_a      = "We run trucks through Englewood daily, so most calls here are same-day and emergency dispatch normally arrives inside 60 to 90 minutes. Manasota Key included &mdash; crossing the bridge does not change the appointment."
  faq_weekend_a    = "No. Same rate seven days a week, holidays included. A cable that lets go on a Saturday costs what it would have cost on a Monday, and emergency cover runs 24/7."
  faq_springcost_a = "A spring is matched to the weight of the door it has to lift, so what the door is decides the cost: how wide and tall it is, the material, whether it is insulated, whether it has window sections, and whether it is standard wind-load or impact-rated. Coastal doors add one more factor &mdash; a galvanized spring costs more than plain steel and lasts far longer in Englewood air, so we quote the one that will actually survive here rather than the cheapest one that fits. A single-car residential door is usually a few hundred dollars; a commercial door can run into the thousands. We measure the door and read the existing spring before giving a price. The visit and the estimate are free, and you get the full figure before any work starts."
  faq_estimate_a   = "Yes. The technician looks at the door, tells you the price, and that is the price. No call-out fee, and no charge at all if you decide not to go ahead."
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
  h2_brands    = "Door and opener brands we service in North Port"

  vp1_h3 = "Same-Day Slots Held Back"
  vp1_p  = "A spring that goes at 7am should not cost you the whole day, so we keep room in the schedule for it."
  vp2_h3 = "Smart Opener Installers"
  vp2_p  = "WiFi and app-controlled motors fitted and paired properly, camera and alert setup included."
  vp3_h3 = "Family Owned, Local Trucks"
  vp3_p  = "Family owned, more than $($SITE.years_experience) years in the trade, stocked for the doors already on the street here."

  about_kicker = "Door dead on the school run? Spring snapped overnight? Tell us what happened and we will give you a time and a price on the call."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving North Port. In one of the fastest-growing cities in Florida the doors here cycle far more than average, so our trucks carry heavy-duty high-cycle springs rather than a like-for-like builder-grade part."
  about_quote2 = "A door that will not open is not a minor inconvenience when there is a school run and a commute down Price Blvd waiting on it. That is the call we try hardest to clear the same day."
  about_closing = "We cover the neighborhoods off Price Blvd, Sumter Blvd, Toledo Blade Blvd and the Tamiami Trail. High-cycle spring replacement, cable, roller and track tune-ups, smart opener installation, and weather seals that keep the heat and the driving rain out."
  about_checks = @(
    "High-Cycle Springs for Heavy Daily Use"
    "WiFi and App-Controlled Opener Installs"
    "Insulated, Energy-Efficient Doors"
    "Same Day Service"
  )

  exp1_h3 = "Smart Opener Installation"
  exp1_p  = "We fit openers with built-in WiFi so you can open, close and get an alert from your phone wherever you are. Camera models are set up and tested with you, app pairing and alert rules included, so it is working before we leave the driveway."
  exp2_h3 = "Track and Roller Wear"
  exp2_p  = "A door opening ten times a day wears its track, rollers and hinges far faster than the average. We re-seat bent track, swap cheap steel rollers for sealed nylon and reset the hinges, which is what takes the rattle out and stops the next part failing early."

  # Angle: doors that cycle far more than average, so wear is the theme.
  svc_spring_p     = "Doors here cycle far more than average. We fit heavy-duty high-cycle springs."
  svc_opener_p     = "Opener worn out from ten cycles a day? We repair it or fit a WiFi model."
  svc_offtrack_p   = "Off the rail before the school run? We reset it and find what pulled it over."
  svc_cable_p      = "High-cycle doors shed a cable first. We replace both sides and rebalance the door."
  svc_jackshaft_p  = "Shelving or a lift overhead? A side-mount jackshaft opener clears the ceiling."
  svc_roller_p     = "Ten cycles a day finishes cheap rollers. Sealed bearings last on a busy door."
  svc_panels_p     = "Builder-grade panel dented? We replace the section and match the existing finish."
  svc_commercial_p = "Commercial doors off Toledo Blade and Sumter Blvd, repaired and fully insured."
  svc_gate_p       = "Gate motor failing under daily traffic? We repair or replace the operator."
  svc_tuneup_p     = "On a high-use door a tune-up is maintenance, not an upsell. Twenty-five points."
  svc_sensor_p     = "Sensor knocked out of line by a bike or a bin? Realigned and tested the same visit."
  svc_smart_p      = "Keypad for the kids, phone alert for you, on a door that runs all day."

  # No faq_speed_a: North Port asks its own speed question, so Add-CityFaqs
  # drops the shared one and the default value never reaches a page.
  faq_weekend_a    = "No. The rate does not move for a weekend or a holiday. A spring that goes on a Saturday morning is quoted at the weekday price, and there is someone on the phone 24/7."
  faq_springcost_a = "A spring is sized to the door it has to lift, so the door sets the price rather than the spring: how wide and tall it is, what it is made of, whether it is insulated, whether it has window sections, and whether it is standard wind-load or impact-rated. On a North Port door there is a second decision &mdash; a builder-grade spring is rated for about 10,000 cycles, and a heavy-duty high-cycle spring costs more up front but lasts years longer on a door opening ten times a day. A single-car residential door is usually a few hundred dollars; a commercial door can run into the thousands. That is why we measure the door and read the spring on it before quoting. The visit and the estimate are free, and the full price comes before any work."
  faq_estimate_a   = "Yes. You get a clear price before work starts and it holds &mdash; no fees appearing at the end. If you would rather think it over, the visit costs you nothing."
}

# ---------------------------------------------------------------- Sarasota
# Angle from reference/: Architectural Review Committees in Lakewood Ranch and
# Palmer Ranch, trucks staged on the I-75 corridor, and Gulf humidity on the
# hardware. The coastal note is deliberately secondary - Englewood owns salt air
# on this site, and two pages arguing the same thing is how one of them stops
# being indexed.
"garage-door-repair-sarasota-fl" = @{
  h2_values    = "Why Sarasota homeowners get past their ARC"
  h2_badges    = "Sarasota guarantees, discounts and approved styles"
  h2_services  = "Garage Door Services Across Sarasota"
  h2_about     = "Looking for garage door repair near Lakewood Ranch?"
  h2_expertise = "Panel Matching and Coastal-Grade Hardware"
  h2_gallery   = "Sarasota Doors, Before and After"
  h2_brands    = "Door and opener brands we service in Sarasota"

  vp1_h3 = "Staged Near I-75"
  vp1_p  = "Our trucks run the Fruitville and Bee Ridge corridors, so same-day across Sarasota is routine rather than a favour."
  vp2_h3 = "We Know the Committee"
  vp2_p  = "Lakewood Ranch and Palmer Ranch have design rules. We quote from what they already approve."
  vp3_h3 = "Built for Gulf Air"
  vp3_p  = "Galvanized springs and sealed nylon rollers as standard, because Sarasota humidity is hard on plain steel."

  about_kicker = "Door stuck, spring gone, or a board that will not approve the replacement you actually want? Tell us which it is and we will quote it."
  about_quote1 = "$($SITE.business_name) is a family owned, full-service garage door company serving Sarasota. Two things decide most jobs here: what the Gulf air has done to the hardware, and what the Architectural Review Committee will sign off on. We work to both, with more than $($SITE.years_experience) years behind it."
  about_quote2 = "A failed door in a gated community is not only a repair, it is a form. We bring the approved styles and the spec sheet to the estimate so the submission goes in once instead of twice."
  about_closing = "We cover Sarasota from the Fruitville Rd and Bee Ridge Rd neighborhoods out to University Pkwy and the I-75 corridor, and on to Palmer Ranch, Lakewood Ranch and the Siesta Key waterfront. Springs, cables, off-track doors, ultra-quiet belt drives with MyQ, and panel matching on review-committee streets."
  about_checks = @(
    "Torsion and Extension Spring Replacement"
    "Ultra-Quiet Belt Drive Openers with MyQ"
    "Off-Track Realignment and Cable Repair"
    "Hurricane-Impact Rated Upgrades"
  )

  exp1_h3 = "Panel Matching for ARC Streets"
  exp1_p  = "When one section is damaged we match the panel profile and the factory color to the rest of the door, so a repair on an ARC street does not turn into a fresh submission. We bring the spec sheet to the estimate, so if your committee does want paperwork you submit once rather than twice."
  exp2_h3 = "Coastal Spring and Roller Work"
  exp2_p  = "Gulf humidity and salt pit plain steel springs and rollers years early, and a pitted spring lets go without warning. We fit galvanized springs and sealed nylon rollers, balance the door by hand afterwards, and leave it running quieter than it was."

  # Angle: ARC approvals, the I-75 corridor, and Gulf humidity on hardware.
  svc_spring_p     = "Trucks stage on the I-75 corridor, so a snapped spring is still a same-day call."
  svc_opener_p     = "Opener dead or the app offline? We repair, replace and pair it before we leave."
  svc_offtrack_p   = "Door off the rail in a Palmer Ranch garage? Realigned and re-tensioned safely."
  svc_cable_p      = "Humidity frays cable strands early. We replace both sides and rebalance the door."
  svc_jackshaft_p  = "Ceiling needed clear for storage or a lift? Side-mount openers do that."
  svc_roller_p     = "Noisy door on a close-built Bee Ridge street? Nylon rollers quiet it right down."
  svc_panels_p     = "One damaged section on an approved door? We match the panel and swap it out."
  svc_commercial_p = "Commercial and storefront doors along the I-75 corridor, fully insured."
  svc_gate_p       = "Community gate at a standstill? We repair operators, loops and safety edges."
  svc_tuneup_p     = "Gulf humidity works on hardware year-round. A tune-up catches it before it binds."
  svc_sensor_p     = "Door refusing to close? Photo-eye realignment or replacement, tested with you."
  svc_smart_p      = "MyQ paired, camera models configured, keypad mounted where the car stops."

  # No faq_speed_a: Sarasota asks its own speed question, so Add-CityFaqs
  # drops the shared one and the default never reaches the page.
  faq_weekend_a    = "No. One rate, seven days a week, holidays included &mdash; no weekend surcharge and no after-hours premium. Emergency cover runs 24/7."
  faq_springcost_a = "A spring is sized to the door it lifts, so the door decides the price, not the spring: width and height, the material, whether it is insulated, whether it carries window sections, and whether it is standard wind-load or impact-rated. That matters more than usual in Sarasota, because an impact-rated door with glass sections weighs considerably more than a plain single-skin panel and needs the spring capacity to match. A single-car residential door is usually a few hundred dollars; a commercial door can run into the thousands. We measure the door and read the spring already on it before quoting, because that is the only way to give a real number. The visit and the estimate are free, and the price is agreed before work starts."
  faq_estimate_a   = "Yes. A free on-site estimate, the price agreed before work starts, and nothing added afterwards. Decline it and you owe us nothing."
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
  h2_brands    = "Door and opener brands we service"

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

# ------------------------------------------------------------- per-city FAQs
# reference/ supplies one question per city, and the template supplies seven
# shared ones, so a city page's FAQ block is six-sevenths boilerplate. Worse,
# North Port's single question never said "North Port" - it asked about phone
# control of an opener, which is true of every city we serve, so the one block
# meant to be local read as generic.
#
# An entry here REPLACES the reference questions for that slug. Anything not
# listed keeps whatever reference/ holds, so this stays opt-in.
#
# Asking a speed question here also removes the shared "How fast can a
# technician get to my home?" from that page - see Add-CityFaqs. That is the
# point: a city-specific answer in place of a shared one is a net gain, where
# adding one beside it would just repeat the question.
# ----------------------------------------------------- reference/ rewrites
# The Local section - its lead, its highlight bullets, its paragraphs and the
# "Services We Provide in <city>" list - is read verbatim from reference/,
# which sells doors in all four of them. reference/ is source material we do
# not edit, so the swaps live here, keyed by slug, as literal before/after
# text. If a reference file is reworded the swap stops matching and
# $BANNED_CLAIMS fails the build, which is the intended failure: it surfaces
# the new wording instead of quietly shipping it.
$refSwaps = @{
  "garage-door-repair-englewood-fl" = @(
    ,@("Hurricane Impact Door Specialists",
       "Storm-Season Hardware Checks")
    ,@("Impact-Rated Door Upgrades & Wind-Load Inspections",
       "Wind-Load Struts & Storm-Readiness Inspections")
  )
  "garage-door-repair-north-port-fl" = @(
    ,@("Energy-Efficient Insulated Doors",
       "Energy-Efficient Weather Sealing")
    ,@("Insulated Replacement Garage Doors",
       "Weather Seal & Bottom Gasket Replacement")
    ,@("Additionally, we install insulated, energy-efficient garage doors that help lower cooling costs in large modern homes",
       "Additionally, we fit energy-efficient weather seals and insulation kits that help cut cooling losses in large modern homes")
  )
  # Fort Myers and St. Pete are not built in Venice-first mode, but their
  # reference copy is the most door-sales-heavy of the ten and the guard
  # fails on it the moment they are re-enabled. Swapped now so the restore
  # path stays clean rather than breaking for whoever runs it next.
  "garage-door-repair-fort-myers-fl" = @(
    ,@("We offer emergency garage door repairs and wind-code compliant door installations throughout Fort Myers and Lee County.",
       "We offer emergency garage door repairs, wind-load struts and track reinforcement throughout Fort Myers and Lee County.")
    ,@("We specialize in retrofitting and installing hurricane-impact garage doors that meet or exceed Lee County wind-load specifications.",
       "We specialize in retrofitting the door you already have with wind-load struts and reinforced track, to the standards Lee County sets.")
    ,@("Impact-Rated Garage Door Upgrades & Retrofitting",
       "Storm-Season Door Inspections & Retrofitting")
    ,@("Are all new garage doors installed in Fort Myers required to be hurricane-rated?",
       "Does my Fort Myers garage door have to meet the hurricane code?")
    ,@("Yes, Lee County building codes mandate that replacement garage doors meet specific wind-borne debris and structural load standards. We handle all permits and code compliance for you.",
       "Lee County sets wind-borne debris and structural load standards for garage doors. We inspect yours against them and reinforce the track and add struts where that closes the gap - and where a door cannot be brought up to standard, we say so plainly rather than sell you around it.")
  )
  "garage-door-repair-st-petersburg-clearwater-fl" = @(
    ,@("Pinellas County Impact-Rated Door Upgrades",
       "Pinellas County Wind-Load Inspections")
  )
  "garage-door-repair-sarasota-fl" = @(
    ,@("From broken springs to complete custom door installations",
       "From broken springs to off-track doors and worn cables")
    ,@("we ensure all replacement doors meet your local HOA design standards and wind-code requirements",
       "we match repaired sections to your local HOA design standards, so the door still reads as the one your committee approved")
    ,@("Hurricane-Impact Rated Garage Door Upgrades",
       "Panel Matching & Section Replacement")
  )
}

function Apply-RefSwaps([string]$slug, [string]$text) {
  if (-not $refSwaps.ContainsKey($slug)) { return $text }
  foreach ($pair in $refSwaps[$slug]) { $text = $text.Replace($pair[0], $pair[1]) }
  return $text
}

# ------------------------------------------- smart opener card photo
# The card that replaced the new-door one wants its own picture. Until that
# file exists the opener photo stands in, so the card ships either way and
# nobody has to remember to rebuild: drop the picture at $SMART_IMG and the
# next build picks it up. The 100KB image limit applies to it like any other.
# .jpg, not .webp like its neighbours: there is no WebP encoder on this
# machine (no cwebp, no ImageMagick, and GDI+ has never had one), and a
# 39KB JPEG is well inside the 100KB limit. Worth re-encoding to WebP if a
# converter ever turns up - the file name is the only thing to change.
$SMART_IMG = "assets/img/service-smart-opener-keypad.jpg"
if (Test-Path (Join-Path $root ($SMART_IMG -replace '/','\'))) {
  $smartImg = $SMART_IMG
  $smartAlt = "Chamberlain myQ wireless keypad mounted on the wall beside a garage door"
} else {
  $smartImg = "assets/img/service-opener-repair-installation.webp"
  $smartAlt = "Garage door opener and rail on the ceiling of a garage, ready for a smart upgrade"
  Write-Host "note: no $SMART_IMG yet - smart opener card is using the opener photo" -ForegroundColor Yellow
}

$cityFaqs = @{

"garage-door-repair-north-port-fl" = @(
  ,@("How quickly can you reach my home in North Port?",
     "We hold same-day slots back for broken springs and doors that will not open at all. Calls from the neighborhoods off Price Blvd, Sumter Blvd and Toledo Blade Blvd normally get a technician the same day, and someone answers the phone out of hours.")
  ,@("Why did my garage door spring break after only a few years?",
     "A builder-grade torsion spring is rated for roughly 10,000 cycles. A North Port door that opens and closes ten times a day works through that in under three years, which is why so many doors here fail early. We fit heavy-duty high-cycle springs instead, so the replacement outlasts the one that broke.")
  ,@("Can I open my North Port garage door from my phone?",
     "Yes. We install smart openers with built-in WiFi, so you can open, close and get an alert from anywhere. We pair the app, set up the alerts and test them with you before we leave the driveway, and camera models are configured the same way.")
)

# Sarasota's reference question was "Do you offer garage doors approved by
# local HOAs in Lakewood Ranch?", answered "we carry a wide range of Carriage
# House and Modern Glass garage doors" - a door-supply claim, so it is
# replaced rather than reworded. The speed question is the reference wording,
# kept so Add-CityFaqs still drops the shared one.
"garage-door-repair-sarasota-fl" = @(
  ,@("How quickly can a technician reach my home in Sarasota?",
     "Our local service trucks are staged near I-75 and Fruitville Rd, allowing us to offer same-day appointments and emergency dispatch within 45-60 minutes.")
  ,@("My door is on an ARC street and one section is damaged. Can you match it?",
     "Usually, yes. We match the panel profile and the factory color to the sections already on the door, so the repair reads as the door you had rather than a patch, and the committee has nothing new to review. We bring the spec sheet to the estimate in case yours wants the paperwork anyway.")
)

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
    h2_brands    = "Door and opener brands we service in $city"

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

    # the original template wording, kept as the fallback. A city on these is
    # carrying the duplicate block the per-city versions exist to break up.
    svc_spring_p     = "Door won&rsquo;t open or slams shut? We replace broken springs safely and same-day."
    svc_opener_p     = "Opener won&rsquo;t work or makes noise? We repair or replace it fast and affordably."
    svc_offtrack_p   = "Door came off the track? We realign it safely and get it back on track today."
    svc_cable_p      = "Snapped or frayed cables? We replace them quickly to restore safe door movement."
    svc_jackshaft_p  = "Low ceiling or storage overhead? We install wall-mounted jackshaft openers that free up the whole ceiling."
    svc_roller_p     = "Door shaking or noisy? We replace damaged rollers and realign the track properly."
    svc_panels_p     = "Dents or damaged panels? We repair or replace panels for a clean door look."
    svc_commercial_p = "We service all commercial garage doors &ndash; fast, reliable and fully insured."
    svc_gate_p       = "Gate won&rsquo;t open or wheels stuck? We repair or install automatic gates."
    svc_tuneup_p     = "Door too loud or uneven? We lubricate, adjust and balance for smooth operation."
    svc_sensor_p     = "Door won&rsquo;t close or sensors blink? We adjust or replace garage door sensors."
    svc_smart_p      = "Smart openers and keypads installed, paired to your phone and tested with you."

    # the original shared answers, kept as the fallback. {{location}} is gone
    # from them on purpose: token substitution walks an unordered hashtable,
    # so a {{location}} planted by another token may or may not still be
    # waiting its turn - and the leftover-token assertion would catch it.
    faq_speed_a      = "Our service trucks are staged throughout $city, so we offer same-day appointments and emergency dispatch, typically within 60&ndash;90 minutes of your call."
    faq_weekend_a    = "No. We charge the same rate seven days a week &mdash; there is no extra charge on weekends or holidays, and emergency service is available 24/7."
    faq_springcost_a = "A spring is sized to the door it has to lift, so the price depends on the door rather than on the spring itself: how wide and tall it is, what it is made of, whether it is insulated, whether it has window sections, and whether it is standard wind-load or impact-rated. All of that changes what the door weighs and how much spring capacity it needs. A single-car residential door is usually a few hundred dollars; a commercial door can run into the thousands. That is why we look at the door before we quote &mdash; measuring it and reading the spring already on it is the only way to give you a real price instead of a guess. The visit and the estimate are free, and you get the full price before any work starts."
    faq_estimate_a   = "Yes. We give you a clear, upfront price before any work begins, with no hidden fees. If you decide not to proceed, the estimate costs you nothing."
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
  "garage-door-repair-north-port-fl",
  "garage-door-repair-sarasota-fl"
)
$SERVED_CITIES = @(                               # footer + areaServed; $null = all ten
  "garage-door-repair-venice-fl",
  "garage-door-repair-englewood-fl",
  "garage-door-repair-north-port-fl",
  "garage-door-repair-sarasota-fl"
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
  # a hand-written set replaces the reference question entirely
  if ($cityFaqs.ContainsKey($slug)) { $faqs = $cityFaqs[$slug] }

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
  [void]$sb.Append("          <p class=""local__lead"">$(HtmlEscape (Apply-RefSwaps $c.Slug $c.HeroPara))</p>`n")
  if ($c.HeroBul.Count) {
    [void]$sb.Append("          <ul class=""checks local__highlights"">`n")
    foreach ($h in $c.HeroBul) { [void]$sb.Append("            <li>$(HtmlEscape (Apply-RefSwaps $c.Slug $h))</li>`n") }
    [void]$sb.Append("          </ul>`n")
  }
  foreach ($p in $c.LocalP) { [void]$sb.Append("          <p>$(HtmlEscape (Apply-RefSwaps $c.Slug $p))</p>`n") }
  [void]$sb.Append("        </div>`n`n        <aside class=""local__aside"">`n")
  [void]$sb.Append("          <h3>Services We Provide in $(HtmlEscape $c.City)</h3>`n          <ul class=""checks"">`n")
  foreach ($s in $c.Services) {
    # the supplied copy still lists remote programming, which we do not offer
    $s = $s -replace 'Remote Control Programming', 'Keypad Programming'
    [void]$sb.Append("            <li>$(HtmlEscape (Apply-RefSwaps $c.Slug $s))</li>`n")
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
    # swapped here too: the reference FAQs sell doors as readily as the rest
    # of the file, and a hand-written $cityFaqs entry simply matches nothing
    [void]$fb.Append("          <summary>$(HtmlEscape (Apply-RefSwaps $c.Slug $f[0]))</summary>`n")
    [void]$fb.Append("          <p>$(HtmlEscape (Apply-RefSwaps $c.Slug $f[1]))</p>`n")
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
$homeVals["svc_smart_img"] = $smartImg
$homeVals["svc_smart_alt"] = $smartAlt
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
  $vals["svc_smart_img"] = $smartImg
  $vals["svc_smart_alt"] = $smartAlt
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
  # Only executable inline scripts: application/ld+json is data and is never
  # run, and a src= script is covered by its host in script-src, not by a
  # hash - hashing its empty body just adds a hash that allows "".
  foreach ($m in [regex]::Matches($html, '(?s)<script(?![^>]*type=)(?![^>]*\ssrc=)[^>]*>(.*?)</script>')) {
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
  # Both analytics tags split their script host from their beacon host, and a
  # tag allowed in script-src but unreachable in connect-src loads and then
  # silently sends nothing:
  #   GA4        gtag.js from googletagmanager -> beacons to google-analytics
  #   Cloudflare beacon.min.js from static.cloudflareinsights.com
  #              -> beacons to cloudflareinsights.com/cdn-cgi/rum
  # The Cloudflare beacon is injected at the edge by Web Analytics, so it is
  # in no file here and only ever shows up as a console error. GA4 beacons by
  # fetch and falls back to an image, hence the analytics hosts in img-src.
  #
  # Google Ads is a third set again, and the widest: gtag.js fetches the
  # conversion half of itself from googleadservices, then records the
  # conversion as a pixel on google.com and doubleclick rather than as a
  # beacon, so those two belong in img-src. The frame-src entry is for the
  # conversion iframe gtag still falls back to when the pixel is blocked -
  # without it default-src 'self' blocks the frame and the conversion is
  # simply never recorded, with nothing in the console to say so.
  "connect-src 'self' https://*.google-analytics.com https://*.analytics.google.com https://*.googletagmanager.com https://cloudflareinsights.com https://*.google.com https://www.googleadservices.com"
  "img-src 'self' data: https://*.google-analytics.com https://*.googletagmanager.com https://*.google.com https://www.googleadservices.com https://*.doubleclick.net"   # data: covers the CSS check-mark mask
  "script-src 'self' https://www.googletagmanager.com https://static.cloudflareinsights.com https://www.googleadservices.com https://*.doubleclick.net $($inlineHashes.script -join ' ')"
  "frame-src 'self' https://*.doubleclick.net https://www.googleadservices.com"
  "style-src 'self' $($inlineHashes.style -join ' ') https://fonts.googleapis.com"
  "font-src 'self' https://fonts.gstatic.com"
  "upgrade-insecure-requests"
) -join '; '

# The icon rules below cover /favicon.ico and /apple-touch-icon.png, which are
# generated by tools/make-favicon.ps1 and sit at the root rather than under
# /assets, so the /assets/* rule does not reach them.
#
# interest-cohort is deliberately absent from Permissions-Policy. It opted the
# site out of FLoC, Chrome abandoned FLoC in 2022, and the feature name went
# with it - so every browser that still reads this header logs "Error with
# Permissions-Policy header: Unrecognized feature: interest-cohort" to the
# console on every page load. An unrecognised feature is ignored, so the
# directive was only ever noise. Topics, which replaced FLoC, has no header
# opt-out to put in its place: a site stays out of it by not calling the API.
$headers = @"
/*
  Content-Security-Policy: $csp
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin
  Permissions-Policy: geolocation=(), camera=(), microphone=(), payment=()
  Strict-Transport-Security: max-age=31536000; includeSubDomains
  X-Frame-Options: DENY

/assets/*
  Cache-Control: public, max-age=604800

/favicon.ico
  Cache-Control: public, max-age=604800

/apple-touch-icon.png
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

  # Door installation is a licensing matter, not a wording preference - see
  # the NO DOOR INSTALLATION note above. Checked on the rendered page so it
  # catches copy from reference/ as well as copy written here.
  foreach ($bc in $BANNED_CLAIMS) {
    foreach ($hit in [regex]::Matches($t, $bc)) {
      $problems += "$name offers door installation: '$(($hit.Value -replace '\s+',' ').Trim())' - we are not licensed for it"
    }
  }

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
    $rel = $target.TrimStart('/') -replace '/','\'
    # An extensionless link is a generated page, so it is the .html behind it
    # that has to exist. A link that names a file - /favicon.ico and
    # /apple-touch-icon.png are the ones here - is checked as itself, so the
    # guard still fires if the icons are deleted and never regenerated.
    if ([System.IO.Path]::GetExtension($rel) -eq "") { $rel += ".html" }
    if (-not (Test-Path (Join-Path $root $rel))) {
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
