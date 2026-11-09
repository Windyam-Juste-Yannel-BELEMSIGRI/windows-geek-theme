# wallpaper.ps1 - generates the cyber wallpaper (dark gradient + grid + HUD corners). No download.
function Get-PrimaryScreenSize {
    # Real pixel size of the primary monitor (DPI-aware), so the image matches the aspect ratio exactly.
    Add-Type -AssemblyName System.Windows.Forms
    if (-not ('GeekDpi' -as [type])) {
        Add-Type @'
using System.Runtime.InteropServices;
public class GeekDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
    }
    [void][GeekDpi]::SetProcessDPIAware()
    $b = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    return @{ W = [int]$b.Width; H = [int]$b.Height }
}

function New-GeekWallpaper {
    param([string]$Path, [string]$AccentHex = '00ff9c', [int]$W = 0, [int]$H = 0)
    Add-Type -AssemblyName System.Drawing
    if ($W -le 0 -or $H -le 0) { $sz = Get-PrimaryScreenSize; $W = $sz.W; $H = $sz.H }
    $u = [double]$H / 1600.0    # all sizes below are scaled from a 1600px-high reference
    $r = [Convert]::ToInt32($AccentHex.Substring(0, 2), 16)
    $g = [Convert]::ToInt32($AccentHex.Substring(2, 2), 16)
    $b = [Convert]::ToInt32($AccentHex.Substring(4, 2), 16)
    $bmp = New-Object System.Drawing.Bitmap $W, $H
    $gfx = [System.Drawing.Graphics]::FromImage($bmp)
    $gfx.SmoothingMode = 'AntiAlias'
    $gfx.TextRenderingHint = 'AntiAliasGridFit'

    # background gradient #0d1319 -> #05080b
    $rect = New-Object System.Drawing.Rectangle 0, 0, $W, $H
    $c1 = [System.Drawing.Color]::FromArgb(255, 13, 19, 25)
    $c2 = [System.Drawing.Color]::FromArgb(255, 5, 8, 11)
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush $rect, $c1, $c2, 45.0
    $gfx.FillRectangle($bg, $rect)

    # soft accent glow, lower right
    $glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
    $glowPath.AddEllipse([int]($W * 0.45), [int]($H * 0.30), [int]($W * 0.75), [int]($H * 0.95))
    $pg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
    $pg.CenterColor = [System.Drawing.Color]::FromArgb(34, $r, $g, $b)
    $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, $r, $g, $b))
    $gfx.FillPath($pg, $glowPath)

    # grid
    $minor = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(14, $r, $g, $b)), 1
    $major = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(30, $r, $g, $b)), ([single][Math]::Max(1, 2 * $u))
    $step = [int](40 * $u)
    $i = 0
    for ($x = 0; $x -le $W; $x += $step) { $p = $minor; if ($i % 5 -eq 0) { $p = $major }; $gfx.DrawLine($p, $x, 0, $x, $H); $i++ }
    $i = 0
    for ($y = 0; $y -le $H; $y += $step) { $p = $minor; if ($i % 5 -eq 0) { $p = $major }; $gfx.DrawLine($p, 0, $y, $W, $y); $i++ }

    # amber HUD corners (kept well inside the edges)
    $amber = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(170, 255, 176, 0)), ([single][Math]::Max(2, 3 * $u))
    $m = [int](70 * $u); $l = [int](90 * $u)
    $gfx.DrawLine($amber, $m, $m, $m + $l, $m);           $gfx.DrawLine($amber, $m, $m, $m, $m + $l)
    $gfx.DrawLine($amber, $W - $m, $m, $W - $m - $l, $m); $gfx.DrawLine($amber, $W - $m, $m, $W - $m, $m + $l)
    $gfx.DrawLine($amber, $m, $H - $m, $m + $l, $H - $m); $gfx.DrawLine($amber, $m, $H - $m, $m, $H - $m - $l)
    $gfx.DrawLine($amber, $W - $m, $H - $m, $W - $m - $l, $H - $m); $gfx.DrawLine($amber, $W - $m, $H - $m, $W - $m, $H - $m - $l)

    # discreet status text
    try {
        $font = New-Object System.Drawing.Font 'Cascadia Mono', ([single](15 * $u))
        $tb = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(110, $r, $g, $b))
        $gfx.DrawString('SOC // ONLINE   data-pipeline: nominal', $font, $tb, $m + 16, $H - $m - [int](48 * $u))
    } catch { }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose(); $bmp.Dispose()
}
