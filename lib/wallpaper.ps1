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
    # -Network draws a still frame of the animated network graph (for surfaces that cannot be animated, like the
    # lock screen); -Prompt adds two terminal lines in the lower right corner.
    param([string]$Path, [string]$AccentHex = '00ff9c', [int]$W = 0, [int]$H = 0, [switch]$Network, [string]$Prompt = '')
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

    # network graph: same rules as config\zebar\net-canvas.js (links under a distance, a few packets on the links)
    if ($Network) {
        $rnd = New-Object System.Random 1337           # fixed seed: the picture is reproducible
        $s = $u * 1.5                                  # the animation is tuned in CSS px (150 % scaling at 1600 px)
        $count = [int][Math]::Min(110, ($W * $H) / (16000 * $s * $s) * 1.6)
        $link = 150.0 * $s
        $pts = @()
        for ($n = 0; $n -lt $count; $n++) {
            $pts += , @([double]($rnd.NextDouble() * $W), [double]($rnd.NextDouble() * $H), [double](($rnd.NextDouble() * 1.6 + 0.8) * $s))
        }
        $packet = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(230, 0, 229, 255))
        for ($a = 0; $a -lt $count; $a++) {
            for ($c = $a + 1; $c -lt $count; $c++) {
                $dx = $pts[$a][0] - $pts[$c][0]; $dy = $pts[$a][1] - $pts[$c][1]
                $d = [Math]::Sqrt($dx * $dx + $dy * $dy)
                if ($d -ge $link) { continue }
                $alpha = [int]((1 - $d / $link) * 150)
                $pen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb($alpha, 125, 136, 152)), ([single][Math]::Max(1, 0.9 * $s))
                $gfx.DrawLine($pen, [single]$pts[$a][0], [single]$pts[$a][1], [single]$pts[$c][0], [single]$pts[$c][1])
                $pen.Dispose()
                if ($rnd.NextDouble() -lt 0.12) {
                    $t = $rnd.NextDouble(); $pr = 2.2 * $s
                    $gfx.FillEllipse($packet, [single]($pts[$a][0] - $dx * $t - $pr), [single]($pts[$a][1] - $dy * $t - $pr), [single](2 * $pr), [single](2 * $pr))
                }
            }
        }
        $node = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(190, 125, 136, 152))
        $hot = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, $r, $g, $b))
        for ($n = 0; $n -lt $count; $n++) {
            $br = $node; $rad = $pts[$n][2]
            if ($n % 17 -eq 0) { $br = $hot; $rad += $s }
            $gfx.FillEllipse($br, [single]($pts[$n][0] - $rad), [single]($pts[$n][1] - $rad), [single](2 * $rad), [single](2 * $rad))
        }
    }

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

    # terminal prompt, lower right (right-aligned inside the HUD corner)
    if ($Prompt) {
        try {
            $face = 'Cascadia Mono'
            if ((New-Object System.Drawing.Text.InstalledFontCollection).Families.Name -contains 'JetBrainsMono NF') { $face = 'JetBrainsMono NF' }
            $pf = New-Object System.Drawing.Font $face, ([single](17 * $u))
            $right = New-Object System.Drawing.StringFormat; $right.Alignment = 'Far'
            $acc = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(210, $r, $g, $b))
            $txt = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 197, 209, 222))
            $x = [single]($W - $m - 16); $lh = [single](34 * $u)
            $gfx.DrawString('$ whoami', $pf, $acc, $x, [single]($H - $m - 84 * $u - $lh), $right)
            $gfx.DrawString("> $Prompt", $pf, $txt, $x, [single]($H - $m - 84 * $u), $right)
        } catch { }
    }

    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    $gfx.Dispose(); $bmp.Dispose()
}
