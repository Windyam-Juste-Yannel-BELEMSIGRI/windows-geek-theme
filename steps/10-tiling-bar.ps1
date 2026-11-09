# Step 10 - tiling window manager (GlazeWM) + floating top bar (Zebar). Needs confirmation.
# Why not move the native taskbar to the top? Windows 11 removed that option; the only ways are tools that inject
# into explorer.exe (Windhawk, ExplorerPatcher). Those are not used here. The native taskbar is auto-hidden instead.
$G = $global:Geek
Write-Step '10  Tiling (GlazeWM) + top bar (Zebar) + native taskbar auto-hide'
Write-Info 'GlazeWM (GPL-3.0) + Zebar: official glzr-io releases via winget. They use standard Win32 window APIs:'
Write-Info '  no explorer.exe injection, no system file patching. They DO move/resize your windows and capture ALT+key shortcuts.'
Write-Info 'Emergency exits: alt+shift+p (pause) / alt+shift+e (quit). Gaps: 12px between windows and to the edges;'
Write-Info '  fullscreen windows ignore gaps. GlazeWM will be added to your logon items (HKCU Run) and started now.'
if (-not (Confirm-Action 'Install/configure GlazeWM + Zebar, auto-hide the native taskbar and start GlazeWM now?')) { Write-Warn 'skipped'; return }

$gz = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\glazewm.exe'
$zb = Join-Path $env:ProgramFiles 'glzr.io\Zebar\zebar.exe'
if (-not (Test-DryRun)) {
    if (-not (Test-Path $gz)) { Install-WingetPackage 'glzr-io.glazewm' 'GlazeWM' }
    if (-not (Test-Path $zb)) { Install-WingetPackage 'glzr-io.zebar' 'Zebar' }
    if (-not (Test-Path $gz) -or -not (Test-Path $zb)) { throw 'GlazeWM/Zebar not found after install.' }
}

# --- configs ---
$glzr = Join-Path $env:USERPROFILE '.glzr'
Copy-GeekFile (Join-Path $G.Root 'config\glazewm\config.yaml') (Join-Path $glzr 'glazewm\config.yaml')
foreach ($f in 'zpack.json', 'bar.html', 'styles.css', 'icons.css') {
    Copy-GeekFile (Join-Path $G.Root "config\zebar\$f") (Join-Path $glzr "zebar\windows-geek-theme\$f")
}
$settings = '{' + "`n" + '  "$schema": "https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json",' + "`n" +
    '  "startupConfigs": [ { "pack": "windows-geek-theme", "widget": "bar", "preset": "default" } ]' + "`n" + '}' + "`n"
Write-GeekFile (Join-Path $glzr 'zebar\settings.json') $settings
Write-Ok 'GlazeWM config + Zebar widget pack written (originals backed up)'

if (Test-DryRun) { Write-Info '[dry-run] autohide taskbar, Run key, start GlazeWM'; return }

# --- logon item (HKCU, journaled) ---
[void](Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'GlazeWM' ('"' + $gz + '"') 'String')

# --- native taskbar: auto-hide (previous state journaled) ---
$old = Get-TaskbarState
if (@((Get-Journal).taskbarState | Where-Object { $_ }).Count -eq 0) { Add-JournalEntry 'taskbarState' ([pscustomobject]@{ state = [int]$old }) }
Set-TaskbarState ($old -bor 1)
Write-Ok 'native taskbar set to auto-hide (the Zebar bar replaces it)'

# --- start now ---
Get-Process glazewm, zebar -ErrorAction Ignore | Stop-Process -Force
Start-Process $gz
Wait-Process -Name glazewm -Timeout 6 -ErrorAction SilentlyContinue
if (Get-Process glazewm -ErrorAction Ignore) { Write-Ok 'GlazeWM is running (alt+shift+e to quit, alt+shift+p to pause)' }
else { Write-Warn 'GlazeWM did not stay running - see ~\.glzr\glazewm\errors.log' }
