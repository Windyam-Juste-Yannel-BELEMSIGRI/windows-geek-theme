# Step 11 - wofi-style launcher (alt+d): fzf in a floating, acrylic Windows Terminal window. User files only.
$G = $global:Geek
Write-Step '11  Launcher (alt+d, wofi-like)'
Write-Info 'Installs ~\.config\geek-launcher\launcher.ps1 and refreshes the GlazeWM config (alt+d binding + floating rule).'
Write-Info 'Needs: PowerShell 7, fzf, Windows Terminal (step 03), GlazeWM (step 10).'

Copy-GeekFile (Join-Path $G.Root 'config\launcher\launcher.ps1') (Join-Path $env:USERPROFILE '.config\geek-launcher\launcher.ps1')
Copy-GeekFile (Join-Path $G.Root 'config\glazewm\config.yaml') (Join-Path $env:USERPROFILE '.glzr\glazewm\config.yaml')
Write-Ok 'launcher script + GlazeWM config written (originals backed up)'

if (Test-DryRun) { Write-Info '[dry-run] wm-reload-config'; return }
$cli = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\cli\glazewm.exe'
if ((Test-Path $cli) -and (Get-Process glazewm -ErrorAction Ignore)) {
    & $cli command wm-reload-config | Out-Null
    Write-Ok 'GlazeWM config reloaded - press alt+d to open the launcher'
} else { Write-Warn 'GlazeWM is not running: start it (or sign in again), then press alt+d' }
