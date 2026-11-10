# Step 10 - tiling window manager (GlazeWM) + floating top bar and animated desktop HUD (Zebar). Needs confirmation.
# Why not move the native taskbar to the top? Windows 11 removed that option; the only ways are tools that inject
# into explorer.exe (Windhawk, ExplorerPatcher). Those are not used here. The native taskbar is auto-hidden instead.
$G = $global:Geek
Write-Step '10  Tiling (GlazeWM) + top bar and desktop HUD (Zebar) + native taskbar auto-hide'
Write-Info 'GlazeWM (GPL-3.0) + Zebar: official glzr-io releases via winget. They use standard Win32 window APIs:'
Write-Info '  no explorer.exe injection, no system file patching. They DO move/resize your windows and capture ALT+key shortcuts.'
Write-Info 'Emergency exits: alt+shift+p (pause) / alt+shift+e (quit). Gaps: 12px between windows and to the edges;'
Write-Info '  fullscreen windows ignore gaps. Windows are slightly translucent (alt+shift+o makes the focused one opaque).'
Write-Info 'GlazeWM is started at logon by a Task Scheduler task (current user, not elevated) and started now.'
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
$pack = Join-Path $glzr 'zebar\windows-geek-theme'
Copy-GeekFile (Join-Path $G.Root 'config\glazewm\config.yaml') (Join-Path $glzr 'glazewm\config.yaml')
foreach ($f in Get-ChildItem (Join-Path $G.Root 'config\zebar') -File) {
    Copy-GeekFile $f.FullName (Join-Path $pack $f.Name)
}
$settings = '{' + "`n" + '  "$schema": "https://github.com/glzr-io/zebar/raw/v3.3.1/resources/settings-schema.json",' + "`n" +
    '  "startupConfigs": [' + "`n" +
    '    { "pack": "windows-geek-theme", "widget": "hud", "preset": "default" },' + "`n" +
    '    { "pack": "windows-geek-theme", "widget": "bar", "preset": "default" }' + "`n" +
    '  ]' + "`n" + '}' + "`n"
Write-GeekFile (Join-Path $glzr 'zebar\settings.json') $settings
Write-Ok 'GlazeWM config + Zebar widget pack (bar + hud) written (originals backed up)'

# --- Zebar client library: local, pinned copy ---
# The widgets used to import it from esm.sh on every cold start, so the bar waited for the network at logon.
# The library is GPL-3.0: it is downloaded here (hash-checked) instead of being committed to this MIT repository.
$libUrl = 'https://esm.sh/zebar@3.0.3/es2022/zebar.bundle.mjs'
$libSha = '2D89B44CBB26DE22503A464EEE39F0324C73C8E64A278F2FB6BEDEE8BC622E14'
$lib = Join-Path $pack 'vendor\zebar.mjs'
if (Test-DryRun) { Write-Info "[dry-run] download $libUrl -> $lib" }
elseif ((Test-Path $lib) -and (Get-FileHash $lib -Algorithm SHA256).Hash -eq $libSha) { Write-Ok 'Zebar client library already present (hash ok)' }
elseif (Get-VerifiedDownload $libUrl $libSha $lib) { Write-Ok 'Zebar client library downloaded (zebar@3.0.3, SHA-256 verified)' }
else { Write-Warn 'Zebar client library not available locally: the widgets will load it from esm.sh at startup (slower).' }

if (Test-DryRun) { Write-Info '[dry-run] logon task, process priorities, autohide taskbar, start GlazeWM'; return }

# --- start at logon: scheduled task (fast) instead of the Run key (delayed by Explorer) ---
$run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
# glazewm.exe is a uiAccess binary: Task Scheduler cannot start it directly (CreateProcess fails with "elevation
# required", error 740). It has to go through ShellExecute, which is what the documented ShellExec_RunDLL entry point does.
$viaTask = Register-GeekLogonTask 'GlazeWM' (Join-Path $env:SystemRoot 'System32\rundll32.exe') ('shell32.dll,ShellExec_RunDLL "' + $gz + '"')
if ($viaTask) {
    Remove-ItemProperty -Path $run -Name 'GlazeWM', 'GeekBootPriority' -ErrorAction SilentlyContinue
    Write-Ok 'GlazeWM starts at logon through Task Scheduler (\windows-geek-theme\GlazeWM)'
} else {
    [void](Set-RegValue $run 'GlazeWM' ('"' + $gz + '"') 'String')
    Write-Warn 'Fallback: GlazeWM registered in the HKCU Run key (starts later after logon)'
}

# --- process priorities (admin only): GlazeWM high, Zebar above normal, through the documented PerfOptions key ---
if (Test-Admin) {
    & (Join-Path $G.Root 'config\boot-priority\set-geek-admin-priority.ps1') | Out-Null
    if (@((Get-Journal).perfOptions | Where-Object { $_ }).Count -eq 0) { Add-JournalEntry 'perfOptions' $true }
    Write-Ok 'launch priorities set (glazewm.exe: high, zebar.exe: above normal)'
} else { Write-Info 'not elevated: launch priorities left unchanged (optional, see config\boot-priority)' }

# --- native taskbar: auto-hide (previous state journaled) ---
$old = Get-TaskbarState
if (@((Get-Journal).taskbarState | Where-Object { $_ }).Count -eq 0) { Add-JournalEntry 'taskbarState' ([pscustomobject]@{ state = [int]$old }) }
Set-TaskbarState ($old -bor 1)
Write-Ok 'native taskbar set to auto-hide (the Zebar bar replaces it)'

# --- start now (through the task when possible, so GlazeWM never inherits an elevated token from this shell) ---
Stop-GeekWm
if ($viaTask) { Start-GeekLogonTask 'GlazeWM' } else { Start-Process $gz }
$deadline = (Get-Date).AddSeconds(8)
while ((Get-Date) -lt $deadline -and -not (Get-Process glazewm -ErrorAction Ignore)) { Start-Sleep -Milliseconds 250 }
if (Get-Process glazewm -ErrorAction Ignore) { Write-Ok 'GlazeWM is running (alt+shift+e to quit, alt+shift+p to pause)' }
else { Write-Warn 'GlazeWM did not stay running - see ~\.glzr\glazewm\errors.log' }
