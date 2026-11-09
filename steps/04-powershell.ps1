# Step 04 - PowerShell profile (managed block) + Oh My Posh theme. User files only.
$G = $global:Geek
Write-Step '04  PowerShell profile + Oh My Posh theme'

$ompDst = Join-Path $env:USERPROFILE '.config\ohmyposh\soc-matrix.omp.json'
Copy-GeekFile (Join-Path $G.Root 'config\oh-my-posh\soc-matrix.omp.json') $ompDst
Write-Ok "prompt theme -> $ompDst"

$docs = [Environment]::GetFolderPath('MyDocuments')
$block = [IO.File]::ReadAllText((Join-Path $G.Root 'config\powershell\profile.block.ps1'))
$targets = @(
    (Join-Path $docs 'PowerShell\Microsoft.PowerShell_profile.ps1'),         # PowerShell 7
    (Join-Path $docs 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1')   # Windows PowerShell 5.1
)
foreach ($t in $targets) { Set-ManagedBlock $t $block; Write-Ok "profile block -> $t" }
Write-Info 'Every tool in the profile is guarded (Get-Command / Get-Module): nothing breaks if a tool is missing.'
Write-Info 'Windows PowerShell 5.1 only loads profiles if its execution policy allows (default is Restricted). It is NOT changed by this project.'
