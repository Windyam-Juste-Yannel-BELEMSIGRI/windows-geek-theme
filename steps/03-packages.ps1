# Step 03 - software install via winget (official source) + PowerShell modules. Needs confirmation.
Write-Step '03  Packages (winget) + PowerShell modules'

$core = @(
    @('Microsoft.PowerShell',            'PowerShell 7'),
    @('JanDeDobbeleer.OhMyPosh',         'Oh My Posh (prompt)'),
    @('DEVCOM.JetBrainsMonoNerdFont',    'JetBrainsMono Nerd Font'),
    @('ajeetdsouza.zoxide',              'zoxide'),
    @('junegunn.fzf',                    'fzf'),
    @('sharkdp.bat',                     'bat'),
    @('eza-community.eza',               'eza'),
    @('BurntSushi.ripgrep.MSVC',         'ripgrep'),
    @('aristocratos.btop4win',           'btop4win (btop for Windows)'),
    @('jqlang.jq',                       'jq'),
    @('DuckDB.cli',                      'DuckDB CLI')
)
$soc = @(
    @('WiresharkFoundation.Wireshark',   'Wireshark (installs the Npcap capture driver)'),
    # The winget-repo manifest of the Suite often fails its hash check (Microsoft updates the zip in place);
    # the official Microsoft Store listing is used instead. The hash check is never bypassed.
    @('9P7KNL5RWT25',                    'Sysinternals Suite (Microsoft Store)', 'msstore')
)

Write-Info 'Core set (sources: winget community repo / official project GitHub releases):'
$core | ForEach-Object { Write-Info "  - $($_[1])  [$($_[0])]" }
if (Confirm-Action 'Install the core set above?') {
    foreach ($p in $core) { Install-WingetPackage $p[0] $p[1] }
} else { Write-Warn 'core set skipped' }

Write-Info 'SOC set:'
$soc | ForEach-Object { Write-Info "  - $($_[1])  [$($_[0])]" }
Write-Info 'Note: Wireshark bundles Npcap, a kernel packet-capture driver (Npcap is installed by the Wireshark installer).'
if (Confirm-Action 'Install the SOC set (Wireshark + Sysinternals)?') {
    foreach ($p in $soc) { Install-WingetPackage $p[0] $p[1] $p[2] }
} else { Write-Warn 'SOC set skipped' }

# PowerShell modules (PSGallery, CurrentUser scope, no admin)
if (-not (Test-DryRun)) { Update-SessionPath }
$pw = Get-Command pwsh -ErrorAction SilentlyContinue
if (Confirm-Action 'Install PowerShell modules Terminal-Icons + PSReadLine (PSGallery, CurrentUser)?') {
    if (Test-DryRun) { Write-Info '[dry-run] Install-Module Terminal-Icons, PSReadLine' }
    elseif ($pw) {
        & $pw.Source -NoProfile -Command "Install-Module Terminal-Icons -Scope CurrentUser -Force -Repository PSGallery; Install-Module PSReadLine -Scope CurrentUser -Force -Repository PSGallery"
        Add-JournalEntry 'modules' 'Terminal-Icons'
        Write-Ok 'modules installed for PowerShell 7'
    } else { Write-Warn 'pwsh not found yet (open a new shell, then re-run: .\install.ps1 -Steps 3)' }
}

# font check
if (-not (Test-DryRun)) {
    $hit = Get-ChildItem 'C:\Windows\Fonts', "$env:LOCALAPPDATA\Microsoft\Windows\Fonts" -Filter 'JetBrainsMono*NerdFont*' -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($hit) { Write-Ok 'JetBrainsMono Nerd Font is installed' }
    else { Write-Warn 'Nerd Font not found - install may have failed' }
}
Write-Info 'Open a NEW terminal so the updated PATH is picked up.'
