# Sky-blue wallpaper featuring the mascot (local desktop use only). ASCII comments.
Add-Type -AssemblyName System.Drawing
$dir = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not $dir) { $dir = "C:\Users\icecake\all-in-one" }

$W=1920; $H=1080
$wp = New-Object System.Drawing.Bitmap($W,$H)
$g = [System.Drawing.Graphics]::FromImage($wp)
$g.SmoothingMode='AntiAlias'; $g.InterpolationMode='HighQualityBicubic'

# sky-blue gradient
$rect = New-Object System.Drawing.RectangleF(0,0,$W,$H)
$sky = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, [System.Drawing.Color]::FromArgb(205,234,255), [System.Drawing.Color]::FromArgb(90,168,240), 90)
$g.FillRectangle($sky,0,0,$W,$H)

# clouds
$c = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(70,255,255,255))
$g.FillEllipse($c,160,150,360,120)
$g.FillEllipse($c,300,120,300,110)
$g.FillEllipse($c,1320,210,420,130)
$g.FillEllipse($c,1470,180,300,110)
$g.FillEllipse($c,780,90,260,90)
$g.FillEllipse($c,1050,860,360,110)

# mascot centered
$m = [System.Drawing.Image]::FromFile((Join-Path $dir 'mascot-trans.png'))
$targetH = 620.0
$scale = $targetH / $m.Height
$dw = $m.Width*$scale; $dh = $m.Height*$scale
# soft shadow
$sh = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(45,11,58,94))
$g.FillEllipse($sh, [single](($W-$dw*0.7)/2), [single](($H+$dh)/2 - 40), [single]($dw*0.7), [single]60)
$g.DrawImage($m, [single](($W-$dw)/2), [single](($H-$dh)/2 - 20), [single]$dw, [single]$dh)
$m.Dispose()

$wp.Save((Join-Path $dir 'wallpaper-mascot.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose(); $wp.Dispose()
Write-Host "WALLPAPER(mascot) created: wallpaper-mascot.png"
