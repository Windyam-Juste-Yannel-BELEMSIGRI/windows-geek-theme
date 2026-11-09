# Step 07 - WSL2 Debian + same prompt. Needs confirmation. Never deletes a distro.
$G = $global:Geek
Write-Step '07  WSL2 Debian + shell tooling'
Write-Info 'Installs the Debian distro (wsl --install), then as root: apt packages (fzf bat ripgrep jq zoxide eza git curl).'
Write-Info 'As your Linux user: downloads the oh-my-posh binary from the official GitHub release and adds a marked block to ~/.bashrc.'
if (-not (Confirm-Action 'Proceed with WSL Debian install + configuration?')) { Write-Warn 'skipped'; return }
if (Test-DryRun) { Write-Info '[dry-run] wsl --install -d Debian --no-launch ; setup-root.sh ; setup-user.sh apply'; return }

function ToWslPath($p) { $p = $p -replace '\\', '/'; if ($p -match '^([A-Za-z]):(.*)$') { return '/mnt/' + $Matches[1].ToLower() + $Matches[2] }; return $p }
function Get-WslList { return ((& wsl.exe -l -q | Out-String) -replace "`0", '') }

if ((Get-WslList) -notmatch '(?m)^Debian\s*$') {
    Write-Info 'installing Debian ...'
    & wsl.exe --install -d Debian --no-launch
    Add-JournalEntry 'wsl' ([pscustomobject]@{ distro = 'Debian'; installedByUs = $true })
}

# is the distro initialised (a normal Linux user exists)?
$lx = Get-ChildItem 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss' -ErrorAction SilentlyContinue |
    Where-Object { (Get-ItemProperty $_.PSPath).DistributionName -eq 'Debian' }
$uid = $null; if ($lx) { $uid = (Get-ItemProperty $lx.PSPath).DefaultUid }
if (-not $lx -or $uid -eq 0) {
    Write-Warn 'Debian is not initialised yet (no Linux user).'
    Write-Info 'Run `debian` once from the Start menu / terminal, create your user, then re-run:  .\install.ps1 -Steps 7'
    return
}

$cfg = Join-Path $G.Root 'config\wsl'
& wsl.exe -d Debian -u root -- bash (ToWslPath (Join-Path $cfg 'setup-root.sh'))
& wsl.exe -d Debian -- bash (ToWslPath (Join-Path $cfg 'setup-user.sh')) apply (ToWslPath (Join-Path $G.Root 'config\oh-my-posh\soc-matrix.omp.json'))
Add-JournalEntry 'wsl' ([pscustomobject]@{ distro = 'Debian'; configured = $true })
Write-Ok 'Debian configured. Open "SOC // Debian" in Windows Terminal.'
