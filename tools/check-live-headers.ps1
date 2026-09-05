<#
  Verifies the deployed site really returns the headers _headers declares.

  _headers being correct is not the same as the crawler seeing it: the domain
  is proxied through Cloudflare, and /assets/* is cached for 7 days, so a copy
  cached before a header change keeps being served without the new headers
  until it expires or the cache is purged. Screaming Frog then reports every
  image as missing X-Content-Type-Options while the origin is set up fine.

  This checks every URL a crawler reaches - the sitemap pages, robots.txt,
  sitemap.xml, every referenced asset, and a 404 - and separates the two
  causes: a header missing on the cache-busted request too is a config fault,
  a header that appears only on the cache-busted request is a stale edge copy.

  It also checks the Content-Type matches the file, because nosniff only helps
  if the type the server states is the right one.

    powershell -File tools\check-live-headers.ps1
    powershell -File tools\check-live-headers.ps1 -Base https://preview.netlify.app
#>
param([string]$Base = "https://oggaragedoors.com")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$required = @(
  "Content-Security-Policy"
  "X-Content-Type-Options"
  "Referrer-Policy"
  "Strict-Transport-Security"
  "X-Frame-Options"
)

# what the served Content-Type must start with, per extension
$mime = @{
  ".html"="text/html"; ".xml"="application/xml"; ".txt"="text/plain"
  ".png"="image/png"; ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"
  ".svg"="image/svg+xml"; ".webp"="image/webp"; ".ico"="image/x-icon"
  ".css"="text/css"; ".js"="application/javascript"; ".woff2"="font/woff2"
}

function Get-Response([string]$url) {
  try {
    $r = Invoke-WebRequest -Uri $url -UseBasicParsing -MaximumRedirection 0 -TimeoutSec 30
    return @{ Status = [int]$r.StatusCode; Headers = $r.Headers }
  } catch [System.Net.WebException] {
    $resp = $_.Exception.Response
    if (-not $resp) { throw }
    $h = @{}
    foreach ($k in $resp.Headers.AllKeys) { $h[$k] = $resp.Headers[$k] }
    $out = @{ Status = [int]$resp.StatusCode; Headers = $h }
    $resp.Close()
    return $out
  }
}

function Get-Header($headers, [string]$name) {
  foreach ($k in $headers.Keys) {
    if ($k -ieq $name) { return ($headers[$k] -join ", ") }
  }
  return $null
}

# ------------------------------------------------------------------ URL list
# every URL a crawler reaches, not just the HTML - the images are where a
# stale edge copy hides
$urls = New-Object System.Collections.Generic.List[string]
[void]$urls.Add("/")
foreach ($m in [regex]::Matches((Get-Content (Join-Path $root "sitemap.xml") -Raw), '<loc>(.*?)</loc>')) {
  $path = $m.Groups[1].Value -replace '^https?://[^/]+', ''
  if ($path -and -not $urls.Contains($path)) { [void]$urls.Add($path) }
}
[void]$urls.Add("/robots.txt")
[void]$urls.Add("/sitemap.xml")

$assets = New-Object System.Collections.Generic.SortedSet[string]
foreach ($f in Get-ChildItem $root -Filter *.html) {
  foreach ($m in [regex]::Matches((Get-Content $f.FullName -Raw), 'assets/[A-Za-z0-9._/%-]+\.[A-Za-z0-9]+')) {
    [void]$assets.Add("/" + $m.Value)
  }
}
foreach ($a in $assets) { [void]$urls.Add($a) }
[void]$urls.Add("/this-url-should-404")

Write-Host "Checking $($urls.Count) URLs on $Base`n"

$missing = 0   # origin is not sending the header
$stale   = 0   # edge is serving a copy from before the header change
$badType = 0

foreach ($u in $urls) {
  $r = Get-Response "$Base$u"
  $absent = @($required | Where-Object { -not (Get-Header $r.Headers $_) })

  if ($absent.Count) {
    # same URL, cache-busted: if the headers are there, the origin is fine and
    # what we hit was a cached copy
    $r2 = Get-Response "$Base$u`?cachebust=$([guid]::NewGuid().ToString('N'))"
    $stillAbsent = @($required | Where-Object { -not (Get-Header $r2.Headers $_) })
    if ($stillAbsent.Count) {
      Write-Host ("MISSING  {0}  ->  {1}" -f $u, ($stillAbsent -join ", ")) -ForegroundColor Red
      $missing++
    } else {
      Write-Host ("STALE    {0}  (edge copy, age $(Get-Header $r.Headers 'Age')s, missing $($absent -join ', '))" -f $u) -ForegroundColor Yellow
      $stale++
    }
  }

  # Content-Type has to be right for nosniff to mean anything
  $ext = [System.IO.Path]::GetExtension(($u -split '\?')[0]).ToLower()
  if (-not $ext) { $ext = ".html" }
  if ($mime.ContainsKey($ext) -and $r.Status -eq 200) {
    $ct = (Get-Header $r.Headers "Content-Type")
    if ($ct -and -not $ct.StartsWith($mime[$ext], "OrdinalIgnoreCase")) {
      Write-Host ("TYPE     {0}  ->  {1}, expected {2}" -f $u, $ct, $mime[$ext]) -ForegroundColor Red
      $badType++
    }
  }
}

$ok = $urls.Count - $missing - $stale
Write-Host "`n$ok/$($urls.Count) URLs carry all $($required.Count) security headers."
if ($badType) { Write-Host "$badType URLs state the wrong Content-Type." -ForegroundColor Red }
if ($stale) {
  Write-Host "$stale URLs are served from an edge copy cached before the last header change." -ForegroundColor Yellow
  Write-Host "The origin is set up correctly - purge the Cloudflare cache (Caching > Configuration > Purge Everything), then re-run." -ForegroundColor Yellow
}
if ($missing -or $badType) { exit 1 }
