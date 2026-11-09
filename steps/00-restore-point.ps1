# Step 00 - safety net: restore point + registry exports. Runs before anything else.
$G = $global:Geek
Write-Step '00  Restore point + registry backups'
Write-Info 'Creates a System Restore point and exports every registry key this project may touch to backup\reg\.'

# --- registry exports (first export = original state, never overwritten) ---
$keys = @(
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize',
    'HKCU\Software\Microsoft\Windows\DWM',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Accent',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Search',
    'HKCU\Software\Microsoft\Windows\CurrentVersion\Run',
    'HKCU\Control Panel\Desktop',
    'HKLM\SOFTWARE\Policies\Microsoft\Windows\Personalization',
    'HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System',
    'HKLM\SOFTWARE\Policies\Microsoft\Dsh'
)
if (Test-DryRun) {
    $keys | ForEach-Object { Write-Info "[dry-run] reg export $_" }
} else {
    $dir = Join-Path $G.Root 'backup\reg'
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
    foreach ($k in $keys) {
        if ($k.StartsWith('HKLM') -and -not (Test-Admin)) { Write-Warn "skip $k (not admin)"; continue }
        Export-RegKey $k (Join-Path $dir (($k -replace '[\\ :]', '_') + '.reg'))
    }
    Write-Ok "registry exports in $dir"
}

# --- restore point ---
$desc = 'windows-geek-theme (before changes)'
if (Test-DryRun) { Write-Info "[dry-run] Checkpoint-Computer '$desc'"; return }
if (-not (Test-Admin)) { throw 'Administrator rights are required to create a restore point. Re-run from an elevated shell.' }

$already = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.Description -eq $desc }
if ($already) { Write-Ok 'restore point already exists - skipped'; return }

# Windows limits restore points to one per 24h by default; lift the limit only for this call.
$p = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore'
$name = 'SystemRestorePointCreationFrequency'
$old = (Get-ItemProperty $p -ErrorAction SilentlyContinue).$name
try {
    Set-ItemProperty -Path $p -Name $name -Value 0 -Type DWord
    Checkpoint-Computer -Description $desc -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
} finally {
    if ($null -eq $old) { Remove-ItemProperty -Path $p -Name $name -ErrorAction SilentlyContinue }
    else { Set-ItemProperty -Path $p -Name $name -Value $old -Type DWord }
}
$check = Get-ComputerRestorePoint -ErrorAction SilentlyContinue | Where-Object { $_.Description -eq $desc }
if (-not $check) { throw 'Restore point was not created (is System Protection enabled on C:?). Aborting for safety.' }
Write-Ok "restore point created: $desc"
