<#
  Minimal static server for local preview.

  The site uses extensionless URLs (/garage-door-repair-sarasota-fl) because
  that is what Netlify serves. Opening the files directly with file:// cannot
  resolve those, so preview through this instead - it applies the same rule
  Netlify does: /page -> page.html, / -> index.html.

    powershell -File tools\serve.ps1
    powershell -File tools\serve.ps1 -Port 3000

  Ctrl+C to stop.
#>
param([int]$Port = 8080)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

$mime = @{
  ".html"="text/html; charset=utf-8"; ".css"="text/css"; ".js"="application/javascript"
  ".json"="application/json"; ".xml"="application/xml"; ".txt"="text/plain"
  ".jpg"="image/jpeg"; ".jpeg"="image/jpeg"; ".png"="image/png"; ".svg"="image/svg+xml"
  ".webp"="image/webp"; ".ico"="image/x-icon"; ".woff2"="font/woff2"
}

# Apply the generated _headers (the "/*" block) so local preview enforces the
# same Content-Security-Policy the deployed site will, and a policy that would
# break the page breaks it here first.
$extraHeaders = @{}
$headersFile = Join-Path $root "_headers"
if (Test-Path $headersFile) {
  $inGlobal = $false
  foreach ($line in Get-Content $headersFile) {
    if ($line -match '^\S') { $inGlobal = ($line.Trim() -eq '/*'); continue }
    if ($inGlobal -and $line -match '^\s+([A-Za-z-]+):\s*(.+)$') {
      $extraHeaders[$Matches[1]] = $Matches[2]
    }
  }
  Write-Host "Applying $($extraHeaders.Count) headers from _headers"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add("http://localhost:$Port/")
try { $listener.Start() }
catch { throw "Could not bind port $Port. Try: powershell -File tools\serve.ps1 -Port 3000" }

Write-Host "Serving $root"
Write-Host "  http://localhost:$Port/"
Write-Host "  http://localhost:$Port/garage-door-repair-sarasota-fl"
Write-Host "Ctrl+C to stop."

try {
  while ($listener.IsListening) {
    $ctx = $listener.GetContext()
    $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart("/")
    if ($rel -eq "") { $rel = "index.html" }

    $path = Join-Path $root $rel
    # same resolution order as Netlify: exact file, then .html, then dir index
    if (-not (Test-Path $path -PathType Leaf)) {
      if (Test-Path "$path.html" -PathType Leaf) { $path = "$path.html" }
      elseif (Test-Path (Join-Path $path "index.html") -PathType Leaf) { $path = Join-Path $path "index.html" }
    }

    # keep requests inside the site root
    $full = [System.IO.Path]::GetFullPath($path)
    if (-not $full.StartsWith([System.IO.Path]::GetFullPath($root))) {
      $ctx.Response.StatusCode = 403; $ctx.Response.Close(); continue
    }

    foreach ($h in $extraHeaders.Keys) {
      # HSTS over plain http is ignored by browsers anyway; skip it locally
      if ($h -eq "Strict-Transport-Security") { continue }
      try { $ctx.Response.Headers[$h] = $extraHeaders[$h] } catch {}
    }

    if (Test-Path $full -PathType Leaf) {
      $ext = [System.IO.Path]::GetExtension($full).ToLower()
      $ctx.Response.ContentType = if ($mime.ContainsKey($ext)) { $mime[$ext] } else { "application/octet-stream" }
      $bytes = [System.IO.File]::ReadAllBytes($full)
      $ctx.Response.ContentLength64 = $bytes.Length
      $ctx.Response.OutputStream.Write($bytes, 0, $bytes.Length)
      Write-Host ("200  /{0}" -f $rel)
    } else {
      $ctx.Response.StatusCode = 404
      $msg = [System.Text.Encoding]::UTF8.GetBytes("404 - /$rel not found")
      $ctx.Response.OutputStream.Write($msg, 0, $msg.Length)
      Write-Host ("404  /{0}" -f $rel) -ForegroundColor Yellow
    }
    $ctx.Response.Close()
  }
} finally {
  $listener.Stop(); $listener.Close()
}
