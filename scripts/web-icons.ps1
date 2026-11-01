# Genera los iconos de la versión web (web/icons y web/favicon.png).
#
# Es el icono genérico de la skin personalizada (ic_mesa de Android): arriba
# morado con un «20» girado, abajo verde con otro «20» y en medio la barra
# oscura con tres puntos. En la web el icono no cambia con la skin, así que
# siempre es este. Las medidas son las del lienzo de 432 px del icono
# adaptativo de Android; las cifras van en Verdana negrita, la más parecida.
#
#   powershell -ExecutionPolicy Bypass -File scripts\web-icons.ps1
param([string]$WebDir = (Join-Path $PSScriptRoot '..\web'))

Add-Type -AssemblyName System.Drawing

function Get-TextPath([string]$text) {
  $p = [System.Drawing.Drawing2D.GraphicsPath]::new()
  $p.AddString($text, [System.Drawing.FontFamily]::new('Verdana'), 1, 100,
    [System.Drawing.PointF]::new(0, 0), [System.Drawing.StringFormat]::GenericTypographic)
  # Encaja las cifras en la caja medida en ic_mesa: x 162-269, y 262-333.
  $b = $p.GetBounds()
  $m = [System.Drawing.Drawing2D.Matrix]::new()
  $m.Translate(162, 262)
  $m.Scale(107 / $b.Width, 71 / $b.Height)
  $m.Translate(-$b.X, -$b.Y)
  $p.Transform($m)
  return $p
}

# $view: el trozo del lienzo de 432 que se ve. 432 es todo, para los maskable
# (Android recorta lo que quiere); 288 son los 72 dp del centro, como el icono
# normal de Android.
function Save-Icon([int]$size, [int]$view, [string]$path) {
  $bmp = [System.Drawing.Bitmap]::new($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $s = $size / $view
  $g.ScaleTransform($s, $s)
  $g.TranslateTransform(-(432 - $view) / 2, -(432 - $view) / 2)

  $g.FillRectangle([System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(103, 58, 183)), 0, 0, 432, 216)
  $g.FillRectangle([System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(76, 175, 80)), 0, 216, 432, 216)
  $g.FillRectangle([System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(42, 42, 46)), 0, 200, 432, 32)
  $dot = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(232, 232, 234))
  foreach ($x in 172, 216, 260) { $g.FillEllipse($dot, $x - 6.5, 209.5, 13, 13) }

  $white = [System.Drawing.Brushes]::White
  $text = Get-TextPath '20'
  $g.FillPath($white, $text)
  # El de arriba, girado 180º alrededor del centro.
  $flip = [System.Drawing.Drawing2D.Matrix]::new()
  $flip.RotateAt(180, [System.Drawing.PointF]::new(216, 216))
  $text.Transform($flip)
  $g.FillPath($white, $text)

  $g.Dispose()
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}

$icons = Join-Path $WebDir 'icons'
New-Item -ItemType Directory -Force $icons | Out-Null
Save-Icon 512 288 (Join-Path $icons 'Icon-512.png')
Save-Icon 192 288 (Join-Path $icons 'Icon-192.png')
# El del iPhone va cuadrado y sin transparencia: iOS le redondea las esquinas.
Save-Icon 180 288 (Join-Path $icons 'apple-touch-icon.png')
Save-Icon 512 432 (Join-Path $icons 'Icon-maskable-512.png')
Save-Icon 192 432 (Join-Path $icons 'Icon-maskable-192.png')
Save-Icon 32 288 (Join-Path $WebDir 'favicon.png')
