# Step 02 - taskbar: clean, left-aligned (or centered), widgets off. HKCU only.
$G = $global:Geek
Write-Step '02  Taskbar  [HKCU]'

$adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
$align = 0; if ($G.Taskbar -eq 'center') { $align = 1 }
[void](Set-RegValue $adv 'TaskbarAl' $align)
[void](Set-RegValue $adv 'ShowTaskViewButton' 0)
[void](Set-RegValue $adv 'TaskbarMn' 0)                     # Chat/Teams button
$okW = Set-RegValue $adv 'TaskbarDa' 0                      # Widgets (may be protected by Windows)
[void](Set-RegValue 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 1)   # search = icon only

if (-not (Test-DryRun)) {
    Send-SettingsChange
    $now = (Get-ItemProperty $adv -ErrorAction SilentlyContinue).TaskbarDa
    if ($now -ne 0) {
        Write-Warn 'Widgets toggle is protected by Windows 11 (cannot be written per-user).'
        Write-Info 'Step 09 offers the supported policy (HKLM) to disable it, or use Settings > Personalization > Taskbar.'
    }
}
Write-Ok "taskbar alignment: $($G.Taskbar), task view/chat hidden, search as icon"
Write-Info 'Sign out/in (or restart explorer.exe) to see alignment changes.'
