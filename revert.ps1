<#
.SYNOPSIS
  Undo everything install.ps1 did, using backup\journal.json (previous registry values, file backups, profile blocks).
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\revert.ps1
  powershell -ExecutionPolicy Bypass -File .\revert.ps1 -RemovePackages   # also offers to uninstall winget packages we installed
#>
[CmdletBinding()]
param([switch]$Yes, [switch]$RemovePackages, [switch]$DryRun)
$ErrorActionPreference = 'Continue'
$global:Geek = @{ Root = $PSScriptRoot; DryRun = [bool]$DryRun; Yes = [bool]$Yes; Accent = 'green'; Taskbar = 'left' }
. (Join-Path $PSScriptRoot 'lib\common.ps1')

$jp = Get-JournalPath
if (-not (Test-Path $jp)) { Write-Host 'No journal found: nothing to revert.'; return }
$j = Get-Journal
Write-Step 'REVERT'
Write-Info 'Alternative safety net: System Restore point "windows-geek-theme (before changes)" + originals in backup\reg\*.reg'
if (-not (Confirm-Action 'Revert all recorded changes?')) { return }

# 0. stop the tiling WM + bar, give the native taskbar back
if (-not (Test-DryRun)) { Stop-GeekWm }
foreach ($t in @($j.tasks | Where-Object { $_ })) {
    if (Test-DryRun) { Write-Info "[dry-run] remove logon task $t"; continue }
    if (Unregister-GeekLogonTask $t) { Write-Ok "logon task removed: $t" }
}
if (@($j.perfOptions | Where-Object { $_ }).Count -gt 0) {
    if (Test-DryRun) { Write-Info '[dry-run] remove launch priorities (PerfOptions)' }
    elseif (Test-Admin) { & (Join-Path $PSScriptRoot 'config\boot-priority\set-geek-admin-priority.ps1') -Revert | Out-Null; Write-Ok 'launch priorities removed' }
    else { Write-Warn 'launch priorities kept (needs admin): run config\boot-priority\set-geek-admin-priority.ps1 -Revert elevated' }
}
foreach ($t in @($j.taskbarState | Where-Object { $_ })) {
    if (Test-DryRun) { Write-Info '[dry-run] restore native taskbar state'; continue }
    Set-TaskbarState ([int]$t.state); Write-Ok 'native taskbar state restored'
}

# 1. registry (reverse order)
$vals = @($j.regValues); [array]::Reverse($vals)
foreach ($e in $vals) {
    if ($e.path -like 'HKLM:*' -and -not (Test-Admin)) { Write-Warn "skip $($e.path)\$($e.name) (needs admin)"; continue }
    if (Test-DryRun) { Write-Info "[dry-run] restore $($e.path)\$($e.name)"; continue }
    if (Restore-RegValue $e) { Write-Ok "restored $($e.path)\$($e.name)" }
}

# 2. managed blocks in profiles
foreach ($b in @($j.blocks)) {
    if (Test-DryRun) { Write-Info "[dry-run] remove block from $($b.file)"; continue }
    Remove-ManagedBlock $b.file $b.marker $b.created; Write-Ok "block removed: $($b.file)"
}

# 3. files (restore original or delete what we created)
$files = @($j.files); [array]::Reverse($files)
foreach ($f in $files) {
    if (Test-DryRun) { Write-Info "[dry-run] restore/delete $($f.path)"; continue }
    try {
        if ($f.backup -and (Test-Path $f.backup)) { Copy-Item $f.backup $f.path -Force; Write-Ok "restored $($f.path)" }
        elseif (Test-Path $f.path) { Remove-Item $f.path -Force; Write-Ok "deleted $($f.path)" }
    } catch { Write-Warn "could not restore $($f.path): $($_.Exception.Message)" }
}
foreach ($d in (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\windows-geek-theme'), (Join-Path $env:USERPROFILE '.glzr\zebar\windows-geek-theme\vendor'), (Join-Path $env:USERPROFILE '.glzr\zebar\windows-geek-theme')) {
    if ((-not (Test-DryRun)) -and (Test-Path $d) -and -not (Get-ChildItem $d)) { Remove-Item $d -Force }
}

# 4. WSL shell (never unregisters the distro)
if (@($j.wsl | Where-Object { $_.configured }).Count -gt 0 -and -not (Test-DryRun)) {
    $p = (Join-Path $PSScriptRoot 'config\wsl\setup-user.sh') -replace '\\', '/'
    if ($p -match '^([A-Za-z]):(.*)$') { $p = '/mnt/' + $Matches[1].ToLower() + $Matches[2] }
    & wsl.exe -d Debian -- bash $p revert
}
if (@($j.wsl | Where-Object { $_.installedByUs }).Count -gt 0) {
    Write-Warn 'Debian distro left in place (removing it destroys its data). To remove it yourself: wsl --unregister Debian'
}

# 5. refresh wallpaper + shell
if (-not (Test-DryRun)) {
    $wp = (Get-ItemProperty 'HKCU:\Control Panel\Desktop' -ErrorAction SilentlyContinue).Wallpaper
    if ($wp) { Set-DesktopWallpaper $wp }
    Send-SettingsChange
}

# 6. packages (opt-in)
if ($RemovePackages) {
    foreach ($id in @($j.packages)) {
        if (Confirm-Action "Uninstall $id ?") { if (-not (Test-DryRun)) { winget uninstall --id $id -e --silent | Out-Null; Write-Ok "uninstalled $id" } }
    }
} elseif (@($j.packages).Count -gt 0) {
    Write-Info ('Packages installed by this project were kept: ' + (@($j.packages) -join ', '))
    Write-Info 'Remove them with: .\revert.ps1 -RemovePackages'
}
if (@($j.modules).Count -gt 0) { Write-Info 'PowerShell modules kept (Uninstall-Module Terminal-Icons to remove).' }

if (-not (Test-DryRun)) {
    Move-Item $jp ($jp -replace '\.json$', ("-reverted-{0:yyyyMMdd-HHmmss}.json" -f (Get-Date))) -Force
    Write-Ok 'Reverted. Sign out/in to refresh the taskbar and accent colour.'
}
