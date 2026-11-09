# Step 01 - system theme: dark mode, accent colour, transparency. HKCU only, no confirmation needed.
$G = $global:Geek
Write-Step '01  Windows theme (dark + accent + transparency)  [HKCU]'

$hex = '00ff9c'; if ($G.Accent -eq 'cyan') { $hex = '00e5ff' }
$r = [Convert]::ToInt32($hex.Substring(0, 2), 16)
$g = [Convert]::ToInt32($hex.Substring(2, 2), 16)
$b = [Convert]::ToInt32($hex.Substring(4, 2), 16)
function ToAbgr($r, $g, $b) { return ((255 -shl 24) -bor ($b -shl 16) -bor ($g -shl 8) -bor $r) }
function Mix($c, $target, $f) { return [int]($c + ($target - $c) * $f) }

# 8-entry palette (RGBA, A=0): 3 lights, base, 3 darks, spare
$bytes = New-Object System.Collections.Generic.List[byte]
foreach ($f in 0.6, 0.4, 0.2) { $bytes.AddRange([byte[]]@((Mix $r 255 $f), (Mix $g 255 $f), (Mix $b 255 $f), 0)) }
$bytes.AddRange([byte[]]@($r, $g, $b, 0))
foreach ($f in 0.2, 0.4, 0.6) { $bytes.AddRange([byte[]]@((Mix $r 0 $f), (Mix $g 0 $f), (Mix $b 0 $f), 0)) }
$bytes.AddRange([byte[]]@(247, 99, 12, 0))
$abgr = ToAbgr $r $g $b
$abgrDark = ToAbgr (Mix $r 0 0.4) (Mix $g 0 0.4) (Mix $b 0 0.4)

$pers = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
[void](Set-RegValue $pers 'AppsUseLightTheme' 0)
[void](Set-RegValue $pers 'SystemUsesLightTheme' 0)
[void](Set-RegValue $pers 'EnableTransparency' 1)
# keep taskbar/Start dark (a bright accent on the taskbar would hurt legibility)
[void](Set-RegValue $pers 'ColorPrevalence' 0)

$acc = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent'
[void](Set-RegValue $acc 'AccentPalette' ([byte[]]$bytes.ToArray()) 'Binary')
[void](Set-RegValue $acc 'AccentColorMenu' $abgr)
[void](Set-RegValue $acc 'StartColorMenu' $abgrDark)

$dwm = 'HKCU:\Software\Microsoft\Windows\DWM'
[void](Set-RegValue $dwm 'AccentColor' $abgr)
[void](Set-RegValue $dwm 'ColorPrevalence' 0)

if (-not (Test-DryRun)) { Send-SettingsChange }
Write-Ok "dark mode + transparency on, accent #$hex"
Write-Info 'Mica/Acrylic is applied by Windows itself (Settings, Start, Explorer title bars). Sign out/in for full effect.'
