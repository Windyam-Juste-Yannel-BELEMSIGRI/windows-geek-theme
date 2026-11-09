# Step 08 - generated cyber wallpaper (3840x2160 PNG) applied for the current user. HKCU only.
$G = $global:Geek
Write-Step '08  Wallpaper (generated)'
$hex = '00ff9c'; if ($G.Accent -eq 'cyan') { $hex = '00e5ff' }
$img = Join-Path $env:USERPROFILE 'Pictures\windows-geek-theme\wallpaper.png'

if (Test-DryRun) { Write-Info "[dry-run] generate $img and apply it"; return }
Register-File $img
New-GeekWallpaper -Path $img -AccentHex $hex
Write-Ok "generated $img"

$d = 'HKCU:\Control Panel\Desktop'
[void](Set-RegValue $d 'Wallpaper' $img 'String')
[void](Set-RegValue $d 'WallpaperStyle' '10' 'String')   # Fill
[void](Set-RegValue $d 'TileWallpaper' '0' 'String')
Set-DesktopWallpaper $img
Write-Ok 'wallpaper applied'
