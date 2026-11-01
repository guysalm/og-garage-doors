# Renders the favicon set from the logo mark: the crimson tile with "OG" that
# is the left-hand group of assets/img/og-garage-doors-logo.svg.
#
# Why these are generated and not drawn by hand: a browser asks for
# /favicon.ico before it has parsed a single <link>, so the file has to exist
# at the root under that exact name or every page logs a 404 in the console.
# Checked-in binaries nobody can regenerate rot, so this script owns them.
#
# Outputs, all at the repo root because that is where a browser guesses:
#   favicon.ico            16 + 32 + 48, PNG-compressed inside the ICO
#   apple-touch-icon.png   180x180, what iOS saves for a home-screen bookmark
#
# Run from anywhere:  powershell -File tools\make-favicon.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$root = Split-Path -Parent $PSScriptRoot

# straight from the SVG, so the tile matches the header logo exactly
$CRIMSON = [System.Drawing.ColorTranslator]::FromHtml("#D22630")

function New-IconBitmap {
  param([int]$Size)

  $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  try {
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $g.Clear($CRIMSON)

    # No rounded corners: at 16px a 2px radius is one grey pixel per corner and
    # reads as a smudge. Every platform that wants a rounded icon rounds it
    # itself, and a square tile survives being masked.
    #
    # The letters are a glyph path scaled to their own measured ink bounds,
    # not DrawString into a box. DrawString has no way to fit text to a box:
    # pick the point size a shade too large and GDI+ either wraps "OG" into a
    # stacked O over G or, with NoWrap, trims it to a lone "O" - both of which
    # it does silently. Measuring the outline and scaling it is exact, and it
    # centres on the ink rather than on the line box, so there is no fudge
    # factor for the accent space above the cap height.
    #
    # Arial, not Roboto: this renders on whatever machine runs the script and
    # Roboto is not a Windows font, so naming it would fall back to something
    # arbitrary. Arial Bold is close enough to the logo's Roboto Black at 16px.
    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $fam  = New-Object System.Drawing.FontFamily("Arial")
    $fmt  = New-Object System.Drawing.StringFormat([System.Drawing.StringFormat]::GenericTypographic)
    try {
      # 100 is an arbitrary working size - everything is scaled from the bounds
      $path.AddString("OG", $fam, [int][System.Drawing.FontStyle]::Bold, 100,
                      (New-Object System.Drawing.PointF(0, 0)), $fmt)
      $ink = $path.GetBounds()

      # 0.80 of the tile across, with the height checked too so a future
      # two-line mark cannot overflow vertically
      $scale = [math]::Min(($Size * 0.80) / $ink.Width, ($Size * 0.66) / $ink.Height)

      $m = New-Object System.Drawing.Drawing2D.Matrix
      $order = [System.Drawing.Drawing2D.MatrixOrder]::Append
      $m.Translate(-($ink.X + $ink.Width / 2), -($ink.Y + $ink.Height / 2), $order)
      $m.Scale($scale, $scale, $order)
      $m.Translate($Size / 2, $Size / 2, $order)
      $path.Transform($m)
      $m.Dispose()

      $g.FillPath([System.Drawing.Brushes]::White, $path)
    } finally { $fmt.Dispose(); $fam.Dispose(); $path.Dispose() }
  } finally { $g.Dispose() }
  return $bmp
}

function Get-PngBytes {
  param([System.Drawing.Bitmap]$Bitmap)
  $ms = New-Object System.IO.MemoryStream
  try {
    $Bitmap.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
    return $ms.ToArray()
  } finally { $ms.Dispose() }
}

function Get-DibBytes {
  # One ICO payload in the classic BMP form: a BITMAPINFOHEADER, 32bpp BGRA
  # pixels bottom-up, then the 1bpp AND mask.
  #
  # Not PNG-in-ICO, which is the obvious choice and is what this wrote first:
  # browsers read it, but System.Drawing's own Icon.ToBitmap() throws
  # "Requested range extends past the end of the array" on a PNG entry, and
  # Windows shell surfaces go through that same GDI+ reader. An icon that the
  # host OS cannot render is not worth the ~13KB saved.
  param([System.Drawing.Bitmap]$Bitmap)

  $w = $Bitmap.Width; $h = $Bitmap.Height
  # the AND mask is 1 bit per pixel, each row padded to 4 bytes
  $maskStride = [int](([math]::Floor(($w + 31) / 32)) * 4)

  $ms = New-Object System.IO.MemoryStream
  $bw = New-Object System.IO.BinaryWriter($ms)
  try {
    $bw.Write([uint32]40)                        # biSize
    $bw.Write([int32]$w)                         # biWidth
    $bw.Write([int32]($h * 2))                   # biHeight: colour + mask stacked
    $bw.Write([uint16]1)                         # biPlanes
    $bw.Write([uint16]32)                        # biBitCount
    $bw.Write([uint32]0)                         # biCompression = BI_RGB
    $bw.Write([uint32]($w * $h * 4 + $maskStride * $h))   # biSizeImage
    $bw.Write([int32]0); $bw.Write([int32]0)     # pixels-per-metre, unused
    $bw.Write([uint32]0); $bw.Write([uint32]0)   # palette counts, unused

    # bottom-up, and BGRA rather than RGBA. Built a row at a time and written
    # with the three-argument overload, for the reason given at the ICO write.
    $row = New-Object byte[] ($w * 4)
    for ($y = $h - 1; $y -ge 0; $y--) {
      for ($x = 0; $x -lt $w; $x++) {
        $c = $Bitmap.GetPixel($x, $y)
        $i = $x * 4
        $row[$i]     = $c.B
        $row[$i + 1] = $c.G
        $row[$i + 2] = $c.R
        $row[$i + 3] = $c.A
      }
      $bw.Write($row, 0, $row.Length)
    }
    # every pixel is opaque, so the mask is all zeros - but it must be present
    # or readers fall back to treating the colour rows as half the image
    $zeroRow = New-Object byte[] $maskStride
    for ($y = 0; $y -lt $h; $y++) { $bw.Write($zeroRow, 0, $zeroRow.Length) }

    $bw.Flush()
    return $ms.ToArray()
  } finally { $bw.Dispose(); $ms.Dispose() }
}

# ------------------------------------------------------------------ favicon.ico
# An ICO is a 6-byte directory header, one 16-byte entry per size, then the
# image payloads. 16 is the tab strip, 32 the bookmark bar and most retina
# tabs, 48 what Windows uses for a pinned shortcut.
$sizes    = @(16, 32, 48)
$payloads = @()
foreach ($s in $sizes) {
  $bmp = New-IconBitmap -Size $s
  try { $payloads += ,(Get-DibBytes -Bitmap $bmp) } finally { $bmp.Dispose() }
}

$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
try {
  $bw.Write([uint16]0)               # reserved
  $bw.Write([uint16]1)               # 1 = icon
  $bw.Write([uint16]$sizes.Count)

  # offsets follow the directory, so the first payload starts after every entry
  $offset = 6 + (16 * $sizes.Count)
  for ($i = 0; $i -lt $sizes.Count; $i++) {
    $bw.Write([byte]$sizes[$i])      # width  (0 would mean 256)
    $bw.Write([byte]$sizes[$i])      # height
    $bw.Write([byte]0)               # palette size, 0 for truecolour
    $bw.Write([byte]0)               # reserved
    $bw.Write([uint16]1)             # colour planes
    $bw.Write([uint16]32)            # bits per pixel
    $bw.Write([uint32]$payloads[$i].Length)
    $bw.Write([uint32]$offset)
    $offset += $payloads[$i].Length
  }
  # Write($p) alone binds to the Write(bool) overload, which coerces a non-empty
  # array to $true and writes a single 0x01 - a 57-byte ICO with a valid
  # directory pointing at nothing. The three-argument form is unambiguous.
  foreach ($p in $payloads) { $bw.Write($p, 0, $p.Length) }

  $bw.Flush()
  $icoPath = Join-Path $root "favicon.ico"
  [System.IO.File]::WriteAllBytes($icoPath, $ms.ToArray())
  Write-Host "favicon.ico written ($($sizes -join '+') px, $([math]::Round((Get-Item $icoPath).Length / 1KB, 1))KB)"
} finally { $bw.Dispose(); $ms.Dispose() }

# --------------------------------------------------------- apple-touch-icon.png
# 180x180 is the current iPhone size and iOS downscales it for everything else.
# At the root as well, because Safari requests /apple-touch-icon.png by guess
# when a page has no link for it.
$bmp = New-IconBitmap -Size 180
try {
  $atiPath = Join-Path $root "apple-touch-icon.png"
  [System.IO.File]::WriteAllBytes($atiPath, (Get-PngBytes -Bitmap $bmp))
  Write-Host "apple-touch-icon.png written (180px, $([math]::Round((Get-Item $atiPath).Length / 1KB, 1))KB)"
} finally { $bmp.Dispose() }
