<#
.SYNOPSIS
  windows-geek-theme - dark "SOC analyst / data engineer" setup for Windows 11.
.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -DryRun        # show the plan, change nothing
  powershell -ExecutionPolicy Bypass -File .\install.ps1                # all steps, asks before risky ones
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Steps 1,2,8   # selected steps (00 always runs first)
  powershell -ExecutionPolicy Bypass -File .\install.ps1 -Accent cyan -Taskbar center -Yes
#>
[CmdletBinding()]
param(
    [string[]]$Steps = @('all'),
    [ValidateSet('green', 'cyan')][string]$Accent = 'green',
    [ValidateSet('left', 'center')][string]$Taskbar = 'left',
    [switch]$Yes,      # auto-answer yes to confirmations (unattended)
    [switch]$DryRun    # print what would happen, change nothing
)
$ErrorActionPreference = 'Stop'
$global:Geek = @{ Root = $PSScriptRoot; DryRun = [bool]$DryRun; Yes = [bool]$Yes; Accent = $Accent; Taskbar = $Taskbar }
. (Join-Path $PSScriptRoot 'lib\common.ps1')
. (Join-Path $PSScriptRoot 'lib\wallpaper.ps1')

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $logDir | Out-Null
    Start-Transcript -Path (Join-Path $logDir ("install-{0:yyyyMMdd-HHmmss}.log" -f (Get-Date))) | Out-Null
}

Write-Host ''
Write-Host '  windows-geek-theme  //  SOC + data-engineer dark setup' -ForegroundColor Green
Write-Host "  accent=$Accent  taskbar=$Taskbar  dry-run=$DryRun  admin=$(Test-Admin)" -ForegroundColor DarkGray

$Steps = @($Steps | ForEach-Object { $_ -split ',' } | Where-Object { $_ })
$all = Get-ChildItem (Join-Path $PSScriptRoot 'steps') -Filter '*.ps1' | Sort-Object Name
if ($Steps -contains 'all') { $sel = $all }
else {
    $nums = @($Steps | ForEach-Object { [int]$_ })
    $sel = $all | Where-Object { $_.Name -like '00*' -or ($nums -contains [int]$_.Name.Substring(0, 2)) }
}

$failed = @()
foreach ($s in $sel) {
    try { & $s.FullName }
    catch {
        Write-Host "   [x] $($s.Name): $($_.Exception.Message)" -ForegroundColor Red
        $failed += $s.Name
        if ($s.Name -like '00*') { Write-Host '   Safety step failed - nothing else was run.' -ForegroundColor Red; break }
    }
}

Write-Host ''
Write-Host '== Summary' -ForegroundColor Green
if ($DryRun) { Write-Host '   Dry run only: nothing was changed.' }
else {
    $j = Get-Journal
    Write-Host ("   registry values changed : {0}" -f @($j.regValues).Count)
    Write-Host ("   files written/backed up : {0}" -f @($j.files).Count)
    Write-Host ("   profile blocks          : {0}" -f @($j.blocks).Count)
    Write-Host ("   packages installed      : {0}" -f @($j.packages).Count)
    Write-Host '   Sign out/in recommended (taskbar alignment, accent). Restart only if WSL/Npcap installers ask for it.'
    Write-Host '   Undo everything:  powershell -ExecutionPolicy Bypass -File .\revert.ps1'
    Stop-Transcript | Out-Null
}
if ($failed.Count -gt 0) { Write-Host "   Failed steps: $($failed -join ', ')" -ForegroundColor Yellow; exit 1 }
