Add-Type -AssemblyName System.Drawing

$w = 1024; $h = 1024
$bmp = New-Object System.Drawing.Bitmap($w, $h)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
$g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

# Background: dark + subtle vertical gradient
$bgTop = [System.Drawing.Color]::FromArgb(255, 13, 14, 16)
$bgBot = [System.Drawing.Color]::FromArgb(255, 8, 9, 10)
$rect = New-Object System.Drawing.Rectangle(0, 0, $w, $h)
$lgBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $bgTop, $bgBot, 90)
$g.FillRectangle($lgBrush, $rect)

function Add-Glow([System.Drawing.Graphics] $g, [System.Drawing.Drawing2D.GraphicsPath] $p, [int] $width, [int] $alpha, [System.Drawing.Color] $c) {
  $pen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb($alpha, $c.R, $c.G, $c.B), $width)
  $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
  $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
  $pen.EndCap   = [System.Drawing.Drawing2D.LineCap]::Round
  $g.DrawPath($pen, $p)
  $pen.Dispose()
}

$amber = [System.Drawing.Color]::FromArgb(255, 246, 182, 13)

function New-Curve([int] $dx, [int] $dy) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddBezier(150 + $dx, 760 + $dy, 380 + $dx, 700 + $dy, 470 + $dx, 520 + $dy, 640 + $dx, 470 + $dy)
  $p.AddBezier(640 + $dx, 470 + $dy, 800 + $dx, 420 + $dy, 820 + $dx, 330 + $dy, 890 + $dx, 300 + $dy)
  return $p
}

# back streams (dimmer)
$back2 = New-Curve 96 108
Add-Glow $g $back2 18 40 $amber
Add-Glow $g $back2 8 90 $amber
$back1 = New-Curve 48 54
Add-Glow $g $back1 18 55 $amber
Add-Glow $g $back1 9 120 $amber

# front stream: wide soft glow + core
$front = New-Curve 0 0
Add-Glow $g $front 92 26 $amber
Add-Glow $g $front 52 60 $amber
Add-Glow $g $front 22 130 $amber
Add-Glow $g $front 13 255 $amber

# pulse dot at the front stream end (live tick)
$ringPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(70, 246, 182, 13), 10)
$g.DrawEllipse($ringPen, 812, 222, 130, 130)
$halo = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(40, 246, 182, 13))
$g.FillEllipse($halo, 830, 240, 94, 94)
$core = New-Object System.Drawing.SolidBrush($amber)
$g.FillEllipse($core, 848, 258, 58, 58)

$halo.Dispose(); $core.Dispose(); $ringPen.Dispose()
$front.Dispose(); $back1.Dispose(); $back2.Dispose()
$lgBrush.Dispose(); $g.Dispose()

$bmp.Save((Join-Path (Split-Path $PSCommandPath) 'icon.png'), [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
"drawing saved"