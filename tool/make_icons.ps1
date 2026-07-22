Add-Type -AssemblyName System.Drawing

function New-Icon {
    param(
        [int]$Size = 1024,
        [bool]$Transparent = $false,   # transparent bg (adaptive foreground)
        [double]$Scale = 1.0,          # glyph scale relative to canvas
        [string]$Out
    )

    $bmp = New-Object System.Drawing.Bitmap($Size, $Size)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic

    $indigo = [System.Drawing.Color]::FromArgb(255, 55, 48, 163)   # #3730A3
    $indigoLt = [System.Drawing.Color]::FromArgb(255, 99, 102, 241) # #6366F1
    $amber  = [System.Drawing.Color]::FromArgb(255, 245, 158, 11)   # #F59E0B
    $white  = [System.Drawing.Color]::White

    if (-not $Transparent) {
        # Gradient indigo background
        $rect = New-Object System.Drawing.Rectangle(0, 0, $Size, $Size)
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $indigo, $indigoLt, 45.0)
        $g.FillRectangle($brush, $rect)
        $brush.Dispose()
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
    }

    # Glyph geometry: a rounded "calendar" card with an amber check.
    $c = $Size / 2.0
    $cardW = $Size * 0.52 * $Scale
    $cardH = $Size * 0.46 * $Scale
    $cardX = $c - $cardW / 2.0
    $cardY = $c - $cardH / 2.0 + $Size * 0.03 * $Scale
    $radius = $Size * 0.06 * $Scale

    function Get-RoundRect($x, $y, $w, $h, $r) {
        $path = New-Object System.Drawing.Drawing2D.GraphicsPath
        $d = $r * 2
        $path.AddArc($x, $y, $d, $d, 180, 90)
        $path.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
        $path.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
        $path.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
        $path.CloseFigure()
        return $path
    }

    # Calendar body (white)
    $whiteBrush = New-Object System.Drawing.SolidBrush($white)
    $card = Get-RoundRect $cardX $cardY $cardW $cardH $radius
    $g.FillPath($whiteBrush, $card)

    # Top header strip (indigo) inside the card
    $headerH = $cardH * 0.22
    $headerBrush = New-Object System.Drawing.SolidBrush($indigo)
    $header = Get-RoundRect $cardX $cardY $cardW $headerH $radius
    $g.FillPath($headerBrush, $header)
    # square off bottom of header
    $g.FillRectangle($headerBrush, [float]$cardX, [float]($cardY + $headerH/2), [float]$cardW, [float]($headerH/2))

    # Binder rings (amber)
    $ringBrush = New-Object System.Drawing.SolidBrush($amber)
    $ringW = $Size * 0.03 * $Scale
    $ringH = $Size * 0.09 * $Scale
    $ringY = $cardY - $ringH * 0.45
    $r1 = Get-RoundRect ($cardX + $cardW*0.30 - $ringW/2) $ringY $ringW $ringH ($ringW/2)
    $r2 = Get-RoundRect ($cardX + $cardW*0.70 - $ringW/2) $ringY $ringW $ringH ($ringW/2)
    $g.FillPath($ringBrush, $r1)
    $g.FillPath($ringBrush, $r2)

    # Amber check mark in the body
    $penW = $Size * 0.055 * $Scale
    $pen = New-Object System.Drawing.Pen($amber, $penW)
    $pen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round
    $pen.LineJoin = [System.Drawing.Drawing2D.LineJoin]::Round
    $bodyCx = $c
    $bodyCy = $cardY + $headerH + ($cardH - $headerH) * 0.55
    $p1 = New-Object System.Drawing.PointF([float]($bodyCx - $cardW*0.22), [float]($bodyCy))
    $p2 = New-Object System.Drawing.PointF([float]($bodyCx - $cardW*0.05), [float]($bodyCy + $cardH*0.17))
    $p3 = New-Object System.Drawing.PointF([float]($bodyCx + $cardW*0.26), [float]($bodyCy - $cardH*0.18))
    $g.DrawLines($pen, @($p1, $p2, $p3))

    $g.Dispose()
    $bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Output "wrote $Out"
}

$dir = "C:\Users\princ\Downloads\Attendence App\assets\icon"
New-Item -ItemType Directory -Force -Path $dir | Out-Null

New-Icon -Size 1024 -Transparent $false -Scale 1.0 -Out "$dir\icon.png"
# Bigger foreground glyph so the adaptive icon shows the calendar/check clearly
# instead of mostly the indigo background. Kept within the adaptive safe zone.
New-Icon -Size 1024 -Transparent $true  -Scale 0.92 -Out "$dir\icon_foreground.png"
New-Icon -Size 512  -Transparent $true  -Scale 0.9  -Out "$dir\splash_logo.png"
