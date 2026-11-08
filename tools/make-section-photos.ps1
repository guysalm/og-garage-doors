<#
  Crops and compresses job photos from "assets/img/Real Photos" into the
  900x600 section photos the service pages use (assets/img/photo-*.jpg).

    powershell -File tools\make-section-photos.ps1

  Each entry names the source file, the output name and where the crop sits
  vertically (0 = top of the photo, 0.5 = centre, 1 = bottom), because most of
  these are portrait phone shots and a 3:2 crop keeps only a band of them.
  JPEG quality steps down until the file is under the build's 100KB limit.
  The phone's EXIF orientation is applied first, or portrait shots come out
  sideways.
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "assets\img\Real Photos"
$dst  = Join-Path $root "assets\img"

$photos = @(
  ,@("Broken Spring 1.jpg",        "photo-broken-torsion-spring",    0.5)
  ,@("Broken Spring 2.jpg",        "photo-torsion-spring-shaft",     0.45)
  ,@("Galvanized springs.jpg",     "photo-galvanized-springs-fitted",0.18)
  ,@("Gavlanized sprnings 2 .jpg", "photo-galvanized-spring-below",  0.35)
  ,@("Galvanized springs 2.jpg",   "photo-spring-job-in-progress",   0.5)
  ,@("Cable and Drum.jpg",         "photo-cable-drum",               0.48)
  ,@("1 Before.jpg",               "photo-broken-spring-outside",    0.3)
  ,@("1 After.jpg",                "photo-door-after-repair",        0.25)
  ,@("Garage Door Off Track.jpg",  "photo-door-off-track",           0.5)
  ,@("rellers.jpg",                "photo-nylon-rollers",            0.5)
  ,@("Sensoe.jpg",                 "photo-safety-sensor",            0.3)
  ,@("Panel replacment .jpg",      "photo-matching-sections",        0.55)
  ,@("Kepad.jpg",                  "photo-wall-keypad",              0.5)
)

$jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
$W = 900; $H = 600

foreach ($p in $photos) {
  $img = [System.Drawing.Image]::FromFile((Join-Path $src $p[0]))
  if ($img.PropertyIdList -contains 0x0112) {
    switch ([int]$img.GetPropertyItem(0x0112).Value[0]) {
      3 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate180FlipNone) }
      6 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate90FlipNone) }
      8 { $img.RotateFlip([System.Drawing.RotateFlipType]::Rotate270FlipNone) }
    }
  }
  # largest 3:2 box that fits, placed by the focus value
  $cw = $img.Width; $ch = [int]($cw * $H / $W)
  if ($ch -gt $img.Height) { $ch = $img.Height; $cw = [int]($ch * $W / $H) }
  $cx = [int](($img.Width - $cw) / 2)
  $cy = [int](($img.Height - $ch) * $p[2])

  $bmp = New-Object System.Drawing.Bitmap $W, $H
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $W, $H), (New-Object System.Drawing.Rectangle $cx, $cy, $cw, $ch), [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose(); $img.Dispose()

  $out = Join-Path $dst "$($p[1]).jpg"
  foreach ($q in 82, 76, 70, 64, 58, 52) {
    $ep = New-Object System.Drawing.Imaging.EncoderParameters 1
    $ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), ([long]$q)
    $bmp.Save($out, $jpeg, $ep)
    if ((Get-Item $out).Length -lt 95KB) { break }
  }
  $bmp.Dispose()
  "{0,-38} {1,4} KB" -f "$($p[1]).jpg", [int]((Get-Item $out).Length / 1KB)
}
