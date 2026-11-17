<#
  Builds Mia's round chat avatar (assets/img/chat-mia.jpg) from assets/Mia.jpg.

  The chat shows her at up to 60px in a circle, so a 160px square crop around
  the face covers a 2x screen. The original stays out of git: the repo root is
  the publish root, and only the crop belongs on the site.

    powershell -File tools\make-chat-avatar.ps1
#>
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot
$src  = Join-Path $root "assets\Mia.jpg"
$dst  = Join-Path $root "assets\img\chat-mia.jpg"
$SIZE = 160

# Face centre as a fraction of width/height; square side as a fraction of the shorter side.
$cx = 0.47; $cy = 0.29; $frac = 0.64

if (-not (Test-Path $src)) { throw "Missing photo: $src" }
$img = [System.Drawing.Image]::FromFile($src)
try {
  $side = [int]([Math]::Min($img.Width, $img.Height) * $frac)
  $x = [int]([Math]::Max(0, [Math]::Min($img.Width  - $side, $img.Width  * $cx - $side / 2)))
  $y = [int]([Math]::Max(0, [Math]::Min($img.Height - $side, $img.Height * $cy - $side / 2)))

  $bmp = New-Object System.Drawing.Bitmap $SIZE, $SIZE
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $g.DrawImage($img, (New-Object System.Drawing.Rectangle 0, 0, $SIZE, $SIZE),
               (New-Object System.Drawing.Rectangle $x, $y, $side, $side),
               [System.Drawing.GraphicsUnit]::Pixel)
  $g.Dispose()

  $jpeg = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq "image/jpeg" }
  $params = New-Object System.Drawing.Imaging.EncoderParameters 1
  $params.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter ([System.Drawing.Imaging.Encoder]::Quality), 85
  $bmp.Save($dst, $jpeg, $params)
  $bmp.Dispose()
} finally {
  $img.Dispose()
}
Write-Host ("chat-mia.jpg written ({0} bytes)" -f (Get-Item $dst).Length)
