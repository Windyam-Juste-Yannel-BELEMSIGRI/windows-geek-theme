# Step 05 - Windows Terminal: colour scheme + SOC profiles via the official "fragment extension" mechanism.
$G = $global:Geek
Write-Step '05  Windows Terminal (fragment: scheme + acrylic profiles)'

$frag = Join-Path $env:LOCALAPPDATA 'Microsoft\Windows Terminal\Fragments\windows-geek-theme\soc.json'
Copy-GeekFile (Join-Path $G.Root 'config\windows-terminal\fragment.json') $frag
Write-Ok "fragment -> $frag (non-destructive: your settings.json profiles are untouched)"

# default profile: only edit the single defaultProfile line, with backup
$settings = Join-Path $env:LOCALAPPDATA 'Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json'
$guidPwsh = '{5d3f2c10-8a4e-4b1c-9f6a-0b7e1c2d3a41}'
$guidWinPs = '{a7c1e4d2-3b6f-4e08-8d95-1f2a6b9c0e72}'
if (-not (Test-Path $settings)) { Write-Warn 'settings.json not found - open Windows Terminal once, then re-run step 5'; return }
Update-SessionPath
$want = $guidWinPs; if (Get-Command pwsh -ErrorAction SilentlyContinue) { $want = $guidPwsh }
if (Test-DryRun) { Write-Info "[dry-run] defaultProfile -> $want"; return }
Register-File $settings
$text = [IO.File]::ReadAllText($settings)
$rx = '"defaultProfile"\s*:\s*"\{[0-9a-fA-F-]+\}"'
if ($text -match $rx) {
    $new = [regex]::Replace($text, $rx, '"defaultProfile": "' + $want + '"')
    [IO.File]::WriteAllText($settings, $new, (New-Object Text.UTF8Encoding $false))
    if ($want -eq $guidPwsh) { Write-Ok 'default profile = SOC // PowerShell 7' }
    else { Write-Ok 'default profile = SOC // Windows PowerShell (re-run step 5 after installing PowerShell 7 to switch)' }
} else { Write-Warn 'no defaultProfile line found - pick "SOC // ..." in the Terminal dropdown manually' }
