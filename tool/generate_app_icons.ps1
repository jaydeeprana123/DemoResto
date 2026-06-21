Add-Type -AssemblyName System.Drawing

$SourcePath = Join-Path $PSScriptRoot '..\assets\images\logo.png'
$ForegroundOut = Join-Path $PSScriptRoot '..\assets\images\app_icon_foreground.png'
$LegacyOut = Join-Path $PSScriptRoot '..\assets\images\app_icon.png'
$CanvasSize = 1024
$FillRatio = 0.78
$BgR = 255; $BgG = 255; $BgB = 255

$src = [System.Drawing.Bitmap]::FromFile($SourcePath)
$w = $src.Width
$h = $src.Height
$maxScanY = [int]($h * 0.72)
$minX = $w
$minY = $h
$maxX = 0
$maxYFound = 0

for ($y = 0; $y -lt $maxScanY; $y++) {
  for ($x = 0; $x -lt $w; $x++) {
    $p = $src.GetPixel($x, $y)
    if ($p.A -gt 20) {
      if ($x -lt $minX) { $minX = $x }
      if ($y -lt $minY) { $minY = $y }
      if ($x -gt $maxX) { $maxX = $x }
      if ($y -gt $maxYFound) { $maxYFound = $y }
    }
  }
}

$cropW = $maxX - $minX + 1
$cropH = $maxYFound - $minY + 1
$crop = New-Object System.Drawing.Bitmap $cropW, $cropH
$gCrop = [System.Drawing.Graphics]::FromImage($crop)
$gCrop.DrawImage(
  $src,
  (New-Object System.Drawing.Rectangle 0, 0, $cropW, $cropH),
  (New-Object System.Drawing.Rectangle $minX, $minY, $cropW, $cropH),
  [System.Drawing.GraphicsUnit]::Pixel
)
$gCrop.Dispose()

$target = [int]($CanvasSize * $FillRatio)
$scale = [Math]::Min($target / $cropW, $target / $cropH)
$drawW = [int]($cropW * $scale)
$drawH = [int]($cropH * $scale)
$dx = [int](($CanvasSize - $drawW) / 2)
$dy = [int](($CanvasSize - $drawH) / 2)

$fg = New-Object System.Drawing.Bitmap $CanvasSize, $CanvasSize
$gFg = [System.Drawing.Graphics]::FromImage($fg)
$gFg.Clear([System.Drawing.Color]::Transparent)
$gFg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gFg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gFg.DrawImage($crop, $dx, $dy, $drawW, $drawH)
$gFg.Dispose()
$fg.Save($ForegroundOut, [System.Drawing.Imaging.ImageFormat]::Png)

$legacy = New-Object System.Drawing.Bitmap $CanvasSize, $CanvasSize
$gLeg = [System.Drawing.Graphics]::FromImage($legacy)
$gLeg.Clear([System.Drawing.Color]::FromArgb(255, $BgR, $BgG, $BgB))
$gLeg.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$gLeg.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
$gLeg.DrawImage($crop, $dx, $dy, $drawW, $drawH)
$gLeg.Dispose()
$legacy.Save($LegacyOut, [System.Drawing.Imaging.ImageFormat]::Png)

$src.Dispose()
$crop.Dispose()
$fg.Dispose()
$legacy.Dispose()

Write-Host "Created emblem-only icons (no app name):"
Write-Host "  $ForegroundOut"
Write-Host "  $LegacyOut"
