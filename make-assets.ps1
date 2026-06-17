# Generate gavel icon (.ico) and sky-blue wallpaper (.png) using GDI+ (ASCII-only to avoid PS5.1 encoding issues)
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Stop'

$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $dir) { $dir = "C:\Users\icecake\all-in-one" }

# Rounded-rectangle GraphicsPath helper
function New-RoundRect([float]$x,[float]$y,[float]$w,[float]$h,[float]$r){
  $maxR = ([Math]::Min($w, $h) / 2) - 0.01
  if ($r -gt $maxR) { $r = $maxR }
  if ($r -lt 0.5) { $r = 0.5 }
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $d = $r * 2
  [void]$p.AddArc($x, $y, $d, $d, 180, 90)
  [void]$p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
  [void]$p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
  [void]$p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
  [void]$p.CloseFigure()
  ,$p
}

# Build a gavel bitmap at the given square size
function New-GavelBitmap([int]$S){
  $bmp = New-Object System.Drawing.Bitmap($S, $S)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.InterpolationMode = 'HighQualityBicubic'
  $f = [float]$S

  # Sky-blue rounded background
  $bgRect = New-Object System.Drawing.RectangleF(0,0,$f,$f)
  $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($bgRect, [System.Drawing.Color]::FromArgb(56,148,224), [System.Drawing.Color]::FromArgb(16,84,158), 90)
  $bgPath = New-RoundRect 0 0 $f $f ($f*0.2)
  $g.FillPath($bg, $bgPath)

  # Clouds
  $cloud = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(90,255,255,255))
  $g.FillEllipse($cloud, $f*0.10, $f*0.16, $f*0.40, $f*0.16)
  $g.FillEllipse($cloud, $f*0.55, $f*0.12, $f*0.30, $f*0.12)

  # Wood brushes
  $woodDark = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF(0,0,$f,$f)), [System.Drawing.Color]::FromArgb(199,147,85), [System.Drawing.Color]::FromArgb(122,74,31), 45)
  $woodLite = New-Object System.Drawing.Drawing2D.LinearGradientBrush((New-Object System.Drawing.RectangleF(0,0,$f,$f)), [System.Drawing.Color]::FromArgb(224,180,120), [System.Drawing.Color]::FromArgb(138,90,40), 45)

  # Base block (no rotation)
  $base1 = New-RoundRect ($f*0.22) ($f*0.78) ($f*0.56) ($f*0.11) ($f*0.055)
  $g.FillPath($woodDark, $base1)
  $base2 = New-RoundRect ($f*0.30) ($f*0.70) ($f*0.40) ($f*0.09) ($f*0.045)
  $g.FillPath($woodLite, $base2)

  # Head + handle, rotated 40deg around center
  $state = $g.Save()
  $g.TranslateTransform($f*0.5, $f*0.46)
  $g.RotateTransform(40)

  $handle = New-RoundRect (-$f*0.045) (-$f*0.02) ($f*0.09) ($f*0.46) ($f*0.04)
  $g.FillPath($woodDark, $handle)
  $head = New-RoundRect (-$f*0.26) (-$f*0.22) ($f*0.52) ($f*0.22) ($f*0.10)
  $g.FillPath($woodLite, $head)
  $bandBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(120,107,66,32))
  $bandL = New-RoundRect (-$f*0.26) (-$f*0.22) ($f*0.06) ($f*0.22) ($f*0.025)
  $g.FillPath($bandBrush, $bandL)
  $bandR = New-RoundRect ($f*0.20) (-$f*0.22) ($f*0.06) ($f*0.22) ($f*0.025)
  $g.FillPath($bandBrush, $bandR)

  $g.Restore($state)
  $g.Dispose()
  return $bmp
}

# ----- Generate PNGs at multiple sizes then assemble .ico -----
$sizes = @(256,64,48,32,16)
$pngList = @()
foreach($s in $sizes){
  $b = New-GavelBitmap $s
  $ms = New-Object System.IO.MemoryStream
  $b.Save($ms, [System.Drawing.Imaging.ImageFormat]::Png)
  $pngList += ,($ms.ToArray())
  $b.Dispose(); $ms.Dispose()
}

$icoPath = Join-Path $dir 'gavel.ico'
$fs = New-Object System.IO.FileStream($icoPath, [System.IO.FileMode]::Create)
$bw = New-Object System.IO.BinaryWriter($fs)
$bw.Write([UInt16]0); $bw.Write([UInt16]1); $bw.Write([UInt16]$sizes.Count)
$offset = 6 + (16 * $sizes.Count)
for($i=0;$i -lt $sizes.Count;$i++){
  $s = $sizes[$i]; $len = $pngList[$i].Length
  if ($s -ge 256) { $dim = 0 } else { $dim = $s }
  $bw.Write([Byte]$dim); $bw.Write([Byte]$dim)
  $bw.Write([Byte]0); $bw.Write([Byte]0)
  $bw.Write([UInt16]1); $bw.Write([UInt16]32)
  $bw.Write([UInt32]$len); $bw.Write([UInt32]$offset)
  $offset += $len
}
foreach($png in $pngList){ $bw.Write($png) }
$bw.Flush(); $bw.Close(); $fs.Close()
Write-Host "ICON created: $icoPath"

# 256px PNG preview
$big = New-GavelBitmap 256
$big.Save((Join-Path $dir 'gavel-icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$big.Dispose()
Write-Host "PNG preview created: gavel-icon.png"

# ----- Sky-blue wallpaper 1920x1080 -----
$W=1920; $H=1080
$wp = New-Object System.Drawing.Bitmap($W,$H)
$wg = [System.Drawing.Graphics]::FromImage($wp)
$wg.SmoothingMode='AntiAlias'
$wg.InterpolationMode='HighQualityBicubic'
$skyRect = New-Object System.Drawing.RectangleF(0,0,$W,$H)
$sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush($skyRect, [System.Drawing.Color]::FromArgb(205,234,255), [System.Drawing.Color]::FromArgb(90,168,240), 90)
$wg.FillRectangle($sky,0,0,$W,$H)
$c = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,255,255,255))
$wg.FillEllipse($c,180,150,360,120)
$wg.FillEllipse($c,300,120,300,110)
$wg.FillEllipse($c,1300,220,420,130)
$wg.FillEllipse($c,1450,190,300,110)
$wg.FillEllipse($c,800,90,260,90)
$gv = New-GavelBitmap 520
$wg.DrawImage($gv, [int](($W-520)/2), [int](($H-520)/2 - 30), 520, 520)
$gv.Dispose()
$wp.Save((Join-Path $dir 'wallpaper-skyblue.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$wg.Dispose(); $wp.Dispose()
Write-Host "WALLPAPER created: wallpaper-skyblue.png"

Get-ChildItem $dir | Select-Object Name, Length
