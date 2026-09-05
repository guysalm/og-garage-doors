<#
  Builds the round review avatars from the supplied photos.

  assets/img/Real Photos/People holds full-size originals - a 2048px portrait,
  a 200px snapshot, a selfie with two people in it. The cards show them at 40px
  in a circle, so each one needs its own crop: a centre point on the face and a
  square around it, both as a fraction of the image, then a resize to 96px (the
  40px circle on a 2x screen, with room to spare).

  Re-run after replacing a photo, then rebuild the pages.

    powershell -File tools\make-avatars.ps1
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "assets\img\Real Photos\People"
$out  = Join-Path $root "assets\img"
$SIZE = 96

# cx/cy: where the face sits, as a fraction of width/height.
# frac:  side of the square crop, as a fraction of the shorter side.
$crops = @(
  @{ file="Michael.jpg"; name="michael"; cx=0.54; cy=0.27; frac=0.32 }  # 199px source, figure is small - crop to head and shoulders
  @{ file="Sarah.jpg";   name="sarah";   cx=0.43; cy=0.32; frac=0.52 }
  @{ file="David.jpg";   name="david";   cx=0.47; cy=0.28; frac=0.42 }
  @{ file="Robert.jpg";  name="robert";  cx=0.47; cy=0.36; frac=0.78 }
  @{ file="James.jpg";   name="james";   cx=0.52; cy=0.52; frac=0.86 }
  @{ file="Lisa.jpg";    name="lisa";    cx=0.69; cy=0.36; frac=0.62 }  # she is on the right of the selfie
)

# JPEG at 85 - a 96px photo lands around 5KB, well under the 100KB build limit
$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$params = New-Object System.Drawing.Imaging.EncoderParameters 1
$params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 85

foreach ($c in $crops) {
  $path = Join-Path $src $c.file
  if (-not (Test-Path $path)) { throw "Missing photo: $path" }

  $img = [System.Drawing.Image]::FromFile($path)
  try {
    $side = [int]([Math]::Min($img.Width, $img.Height) * $c.frac)
    $x = [int]($img.Width  * $c.cx - $side / 2)
    $y = [int]($img.Height * $c.cy - $side / 2)
    # keep the square inside the photo
    $x = [Math]::Max(0, [Math]::Min($x, $img.Width  - $side))
    $y = [Math]::Max(0, [Math]::Min($y, $img.Height - $side))

    $bmp = New-Object System.Drawing.Bitmap $SIZE, $SIZE
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode  = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode    = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.SmoothingMode      = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
    $g.DrawImage($img,
      (New-Object System.Drawing.Rectangle 0, 0, $SIZE, $SIZE),
      (New-Object System.Drawing.Rectangle $x, $y, $side, $side),
      [System.Drawing.GraphicsUnit]::Pixel)

    $dest = Join-Path $out "review-avatar-$($c.name).jpg"
    $bmp.Save($dest, $jpeg, $params)
    $g.Dispose(); $bmp.Dispose()
    "{0,-28} {1}x{2} crop at {3},{4} -> {5}px, {6:N1} KB" -f "review-avatar-$($c.name).jpg", $side, $side, $x, $y, $SIZE, ((Get-Item $dest).Length / 1KB)
  } finally { $img.Dispose() }
}
