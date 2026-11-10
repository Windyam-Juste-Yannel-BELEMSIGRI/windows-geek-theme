<#
.SYNOPSIS
  (Run as ADMINISTRATOR) Make Windows start GlazeWM with HIGH CPU/IO priority and Zebar with ABOVE-NORMAL, on every launch.
.DESCRIPTION
  Uses the documented "PerfOptions" subkey of Image File Execution Options. This only sets CPU/IO priority classes:
  it does NOT set a Debugger value and does not redirect or wrap the executables.
    glazewm.exe : CpuPriorityClass = 3 (High)         IoPriority = 3 (High)
    zebar.exe   : CpuPriorityClass = 6 (AboveNormal)
  Real-time priority is deliberately NOT used (it can freeze the machine).
  Also raises the already-running glazewm/zebar processes right now.
.EXAMPLE
  pwsh -ExecutionPolicy Bypass -File .\set-geek-admin-priority.ps1            # apply
  pwsh -ExecutionPolicy Bypass -File .\set-geek-admin-priority.ps1 -Revert    # undo (removes the PerfOptions keys)
#>
param([switch]$Revert)
$ErrorActionPreference = 'Stop'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) { Write-Host 'Run this script from an ELEVATED terminal (Run as administrator).' -ForegroundColor Red; exit 1 }

$ifeo = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
$targets = @(
    @{ Exe = 'glazewm.exe'; Cpu = 3; Io = 3;    Proc = 'glazewm'; Live = 'High' },
    @{ Exe = 'zebar.exe';   Cpu = 6; Io = $null; Proc = 'zebar';  Live = 'AboveNormal' }
)

foreach ($t in $targets) {
    $perf = Join-Path (Join-Path $ifeo $t.Exe) 'PerfOptions'
    if ($Revert) {
        if (Test-Path $perf) { Remove-Item $perf -Force; Write-Host "[ok] removed $perf" -ForegroundColor Green }
        else { Write-Host "[--] nothing to remove for $($t.Exe)" }
        # remove the parent key only if we left it empty (never touch a Debugger value etc.)
        $parent = Join-Path $ifeo $t.Exe
        if ((Test-Path $parent) -and -not (Get-ChildItem $parent) -and -not (Get-Item $parent).GetValueNames()) { Remove-Item $parent -Force }
        foreach ($p in Get-Process $t.Proc -ErrorAction Ignore) { try { $p.PriorityClass = 'Normal' } catch {} }
        continue
    }
    $parent = Join-Path $ifeo $t.Exe
    if ((Test-Path $parent) -and ((Get-Item $parent).GetValueNames() -contains 'Debugger')) {
        Write-Host "[!] $($t.Exe) already has an IFEO Debugger value - leaving it alone and skipping." -ForegroundColor Yellow
        continue
    }
    New-Item -Path $perf -Force | Out-Null
    New-ItemProperty -Path $perf -Name CpuPriorityClass -Value $t.Cpu -PropertyType DWord -Force | Out-Null
    if ($null -ne $t.Io) { New-ItemProperty -Path $perf -Name IoPriority -Value $t.Io -PropertyType DWord -Force | Out-Null }
    $ioTxt = if ($null -ne $t.Io) { " IoPriority=$($t.Io)" } else { '' }
    Write-Host "[ok] $($t.Exe): CpuPriorityClass=$($t.Cpu)$ioTxt" -ForegroundColor Green
    foreach ($p in Get-Process $t.Proc -ErrorAction Ignore) {
        try { $p.PriorityClass = $t.Live; Write-Host "     running $($t.Proc) (pid $($p.Id)) -> $($t.Live)" } catch { Write-Host "     could not change pid $($p.Id): $($_.Exception.Message)" -ForegroundColor Yellow }
    }
}
Write-Host ''
Write-Host 'Current state:' -ForegroundColor Cyan
Get-Process glazewm, zebar -ErrorAction Ignore | Select-Object Name, Id, PriorityClass | Format-Table -AutoSize
if (-not $Revert) { Write-Host 'Takes effect on every future launch. Undo with: -Revert' -ForegroundColor Gray }
