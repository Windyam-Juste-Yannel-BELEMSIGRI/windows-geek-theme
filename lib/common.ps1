# common.ps1 - shared helpers. PowerShell 5.1 compatible, ASCII only.
# Expects $global:Geek = @{ Root; DryRun; Yes; Accent; Taskbar }

function Write-Step($m) { Write-Host ""; Write-Host "== $m" -ForegroundColor Green }
function Write-Info($m) { Write-Host "   $m" -ForegroundColor Gray }
function Write-Ok($m)   { Write-Host "   [ok] $m" -ForegroundColor Green }
function Write-Warn($m) { Write-Host "   [!] $m" -ForegroundColor Yellow }
function Test-DryRun    { return [bool]$global:Geek.DryRun }
function Test-Admin {
    $p = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}
function Confirm-Action($Message) {
    if ($global:Geek.DryRun -or $global:Geek.Yes) { return $true }
    $a = Read-Host "   ?? $Message [y/N]"
    return ($a -match '^(y|yes|o|oui)$')
}
function Update-SessionPath {
    $env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
}

# ---------- journal (what we changed, with previous values) ----------
function Get-JournalPath { return (Join-Path $global:Geek.Root 'backup\journal.json') }
function Get-Journal {
    $p = Get-JournalPath
    if (Test-Path $p) { return (Get-Content $p -Raw | ConvertFrom-Json) }
    return [pscustomobject]@{ created = (Get-Date).ToString('s'); regValues = @(); files = @(); blocks = @(); packages = @(); modules = @(); wsl = @() }
}
function Save-Journal($j) {
    $p = Get-JournalPath
    New-Item -ItemType Directory -Force -Path (Split-Path $p) | Out-Null
    [IO.File]::WriteAllText($p, ($j | ConvertTo-Json -Depth 8), (New-Object Text.UTF8Encoding $false))
}
function Add-JournalEntry($Kind, $Entry) {
    if (Test-DryRun) { return }
    $j = Get-Journal
    if (-not ($j.PSObject.Properties.Name -contains $Kind)) { $j | Add-Member -NotePropertyName $Kind -NotePropertyValue @() }
    $cur = @($j.$Kind | Where-Object { $_ -ne $null })
    $j.$Kind = @($cur) + @($Entry)
    Save-Journal $j
}

# ---------- registry ----------
function Set-RegValue {
    param([string]$Path, [string]$Name, $Value, [ValidateSet('DWord', 'String', 'Binary', 'ExpandString')][string]$Type = 'DWord')
    if (Test-DryRun) { Write-Info "[dry-run] reg set $Path :: $Name"; return $true }
    $j = Get-Journal
    $known = @($j.regValues | Where-Object { $_.path -eq $Path -and $_.name -eq $Name })
    $keyExisted = Test-Path $Path
    if ($known.Count -eq 0) {
        $existed = $false; $old = $null; $oldType = $null
        if ($keyExisted) {
            $k = Get-Item $Path
            if ($k.GetValueNames() -contains $Name) {
                $existed = $true
                $oldType = $k.GetValueKind($Name).ToString()
                $old = $k.GetValue($Name, $null, 'DoNotExpandEnvironmentNames')
            }
        }
        Add-JournalEntry 'regValues' ([pscustomobject]@{ path = $Path; name = $Name; existed = $existed; type = $oldType; old = $old; keyCreated = (-not $keyExisted) })
    }
    try {
        if (-not $keyExisted) { New-Item -Path $Path -Force | Out-Null }
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        return $true
    } catch {
        Write-Warn "Could not set $Path\$Name : $($_.Exception.Message)"
        return $false
    }
}
function Restore-RegValue($e) {
    try {
        if ($e.existed) {
            $val = $e.old
            if ($e.type -eq 'Binary') { $val = [byte[]]@($e.old) }
            elseif ($e.type -eq 'DWord') { $val = [int]$e.old }
            if (-not (Test-Path $e.path)) { New-Item -Path $e.path -Force | Out-Null }
            New-ItemProperty -Path $e.path -Name $e.name -Value $val -PropertyType $e.type -Force -ErrorAction Stop | Out-Null
        } else {
            if (Test-Path $e.path) { Remove-ItemProperty -Path $e.path -Name $e.name -ErrorAction SilentlyContinue }
            if ($e.keyCreated -and (Test-Path $e.path)) {
                $k = Get-Item $e.path
                if ($k.ValueCount -eq 0 -and $k.SubKeyCount -eq 0) { Remove-Item $e.path -ErrorAction SilentlyContinue }
            }
        }
        return $true
    } catch { Write-Warn "Restore failed for $($e.path)\$($e.name): $($_.Exception.Message)"; return $false }
}
function Export-RegKey($Key, $OutFile) {
    if (Test-Path $OutFile) { return }   # keep the FIRST (original) export
    $psKey = $Key -replace '^(HKCU|HKLM)\\', '$1:\'
    if (-not (Test-Path -LiteralPath $psKey)) { return }   # key absent: nothing to back up
    cmd /c "reg export `"$Key`" `"$OutFile`" /y >nul 2>&1"
}

# ---------- files ----------
function Register-File($Path) {
    if (Test-DryRun) { return }
    $j = Get-Journal
    if (@($j.files | Where-Object { $_.path -eq $Path }).Count -gt 0) { return }
    $bk = $null
    if (Test-Path $Path) {
        $dir = Join-Path $global:Geek.Root 'backup\files'
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        $bk = Join-Path $dir ([guid]::NewGuid().ToString('N') + '_' + (Split-Path $Path -Leaf))
        Copy-Item $Path $bk
    }
    Add-JournalEntry 'files' ([pscustomobject]@{ path = $Path; backup = $bk })
}
function Write-GeekFile($Path, $Content) {
    if (Test-DryRun) { Write-Info "[dry-run] write $Path"; return }
    Register-File $Path
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding $false))
}
function Copy-GeekFile($Src, $Dst) { Write-GeekFile $Dst ([IO.File]::ReadAllText($Src)) }

function Set-ManagedBlock($Path, $Block, $Marker = 'windows-geek-theme') {
    if (Test-DryRun) { Write-Info "[dry-run] managed block in $Path"; return }
    $begin = "# >>> $Marker >>>"; $end = "# <<< $Marker <<<"
    $created = -not (Test-Path $Path)
    $text = ''
    if (-not $created) {
        $text = [IO.File]::ReadAllText($Path)
        $pat = "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?"
        $text = ([regex]::Replace($text, $pat, '')).TrimEnd()
    }
    $new = ($text + "`r`n`r`n" + $begin + "`r`n" + $Block.Trim() + "`r`n" + $end + "`r`n").TrimStart()
    New-Item -ItemType Directory -Force -Path (Split-Path $Path) | Out-Null
    [IO.File]::WriteAllText($Path, $new, (New-Object Text.UTF8Encoding $false))
    $j = Get-Journal
    if (@($j.blocks | Where-Object { $_.file -eq $Path -and $_.marker -eq $Marker }).Count -eq 0) {
        Add-JournalEntry 'blocks' ([pscustomobject]@{ file = $Path; marker = $Marker; created = $created })
    }
}
function Remove-ManagedBlock($Path, $Marker, $Created) {
    if (-not (Test-Path $Path)) { return }
    $begin = "# >>> $Marker >>>"; $end = "# <<< $Marker <<<"
    $t = [IO.File]::ReadAllText($Path)
    $pat = "(?s)\r?\n?" + [regex]::Escape($begin) + ".*?" + [regex]::Escape($end) + "\r?\n?"
    $t = [regex]::Replace($t, $pat, '').TrimEnd()
    if ($Created -and $t.Trim().Length -eq 0) { Remove-Item $Path -Force }
    else { [IO.File]::WriteAllText($Path, $t + "`r`n", (New-Object Text.UTF8Encoding $false)) }
}

# ---------- winget ----------
function Install-WingetPackage($Id, $Name, $Source = $null) {
    if (Test-DryRun) { Write-Info "[dry-run] winget install $Id"; return }
    $listed = (winget list --id $Id -e --accept-source-agreements | Out-String)
    if ($listed -match [regex]::Escape($Id)) { Write-Ok "$Name already installed"; return }
    Write-Info "installing $Name ($Id) ..."
    $extra = @(); if ($Source) { $extra = @('--source', $Source) }
    winget install --id $Id -e @extra --silent --accept-package-agreements --accept-source-agreements --disable-interactivity | Out-Null
    if ($LASTEXITCODE -eq 0) { Add-JournalEntry 'packages' $Id; Write-Ok "$Name installed" }
    else { Write-Warn "$Name ($Id) failed with exit code $LASTEXITCODE - continuing" }
}

# ---------- logon tasks ----------
# A Task Scheduler "at logon" task starts a few seconds after sign-in. Entries of the HKCU\...\Run key are started by
# Explorer only once the shell is idle, one after the other: on this kind of machine that is 40+ seconds later.
# The task runs as the current user, NOT elevated, with normal priority (tasks default to low priority).
function Get-GeekTaskPath { return '\windows-geek-theme\' }
function Register-GeekLogonTask($Name, $Exe, $Arguments = $null, $DelaySeconds = 2) {
    if (Test-DryRun) { Write-Info "[dry-run] logon task $(Get-GeekTaskPath)$Name -> $Exe"; return $true }
    try {
        $user = [Security.Principal.WindowsIdentity]::GetCurrent().Name
        $actArgs = @{ Execute = $Exe }; if ($Arguments) { $actArgs.Argument = $Arguments }
        $action = New-ScheduledTaskAction @actArgs
        $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
        $trigger.Delay = "PT${DelaySeconds}S"
        $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -Priority 4 `
            -ExecutionTimeLimit ([TimeSpan]::Zero) -MultipleInstances IgnoreNew
        Register-ScheduledTask -TaskPath (Get-GeekTaskPath) -TaskName $Name -Action $action -Trigger $trigger `
            -Principal $principal -Settings $settings -Force -ErrorAction Stop | Out-Null
        $j = Get-Journal
        if (@($j.tasks | Where-Object { $_ -eq $Name }).Count -eq 0) { Add-JournalEntry 'tasks' $Name }
        return $true
    } catch {
        Write-Warn "Could not register logon task '$Name': $($_.Exception.Message)"
        return $false
    }
}
function Unregister-GeekLogonTask($Name) {
    try {
        Unregister-ScheduledTask -TaskPath (Get-GeekTaskPath) -TaskName $Name -Confirm:$false -ErrorAction Stop
        # drop our (now empty) task folder; ignored if something else is still in it
        $svc = New-Object -ComObject Schedule.Service; $svc.Connect()
        try { $svc.GetFolder('\').DeleteFolder((Get-GeekTaskPath).Trim('\'), 0) } catch { }
        return $true
    } catch { Write-Warn "Could not remove logon task '$Name': $($_.Exception.Message)"; return $false }
}
function Start-GeekLogonTask($Name) { Start-ScheduledTask -TaskPath (Get-GeekTaskPath) -TaskName $Name -ErrorAction Stop }

# Stop GlazeWM cleanly: "wm-exit" lets it un-hide the windows of other workspaces, reset opacity and close Zebar.
# Killing it is only the fallback (its watcher process then restores the windows).
function Stop-GeekWm {
    if (-not (Get-Process glazewm -ErrorAction Ignore)) { Get-Process zebar -ErrorAction Ignore | Stop-Process -Force; return }
    $cli = Join-Path $env:ProgramFiles 'glzr.io\GlazeWM\cli\glazewm.exe'
    if (Test-Path $cli) { & $cli command wm-exit 2>&1 | Out-Null }
    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline -and (Get-Process glazewm -ErrorAction Ignore)) { Start-Sleep -Milliseconds 200 }
    Get-Process glazewm -ErrorAction Ignore | Stop-Process -Force
    Start-Sleep -Milliseconds 600
    Get-Process zebar -ErrorAction Ignore | Stop-Process -Force
}

# ---------- downloads ----------
# Download a file and keep it only if its SHA-256 matches the pinned value.
function Get-VerifiedDownload($Url, $Sha256, $Destination) {
    $tmp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString('N') + '.tmp')
    try {
        Invoke-WebRequest -Uri $Url -OutFile $tmp -UseBasicParsing -ErrorAction Stop
        $hash = (Get-FileHash $tmp -Algorithm SHA256).Hash
        if ($hash -ne $Sha256) { Write-Warn "hash mismatch for $Url (got $hash) - file discarded"; return $false }
        Register-File $Destination
        New-Item -ItemType Directory -Force -Path (Split-Path $Destination) | Out-Null
        Move-Item $tmp $Destination -Force
        return $true
    } catch { Write-Warn "download failed for $Url : $($_.Exception.Message)"; return $false }
    finally { if (Test-Path $tmp) { Remove-Item $tmp -Force } }
}

# ---------- native helpers ----------
if (-not ('GeekNative' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GeekNative {
    [DllImport("user32.dll", SetLastError=true, CharSet=CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam, uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern bool SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
'@
}
function Send-SettingsChange {
    $r = [UIntPtr]::Zero
    [void][GeekNative]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'ImmersiveColorSet', 2, 5000, [ref]$r)
    [void][GeekNative]::SendMessageTimeout([IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'TraySettings', 2, 5000, [ref]$r)
}
function Set-DesktopWallpaper($Path) { [void][GeekNative]::SystemParametersInfo(20, 0, $Path, 3) }

# Native taskbar auto-hide through the documented appbar API (ABM_GETSTATE / ABM_SETSTATE), no registry hack.
if (-not ('GeekAppBar' -as [type])) {
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public class GeekAppBar {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int left, top, right, bottom; }
    [StructLayout(LayoutKind.Sequential)] public struct APPBARDATA {
        public int cbSize; public IntPtr hWnd; public uint uCallbackMessage; public uint uEdge; public RECT rc; public IntPtr lParam;
    }
    [DllImport("shell32.dll")] static extern UIntPtr SHAppBarMessage(uint dwMessage, ref APPBARDATA pData);
    [DllImport("user32.dll", CharSet=CharSet.Auto)] static extern IntPtr FindWindow(string cls, string title);
    static APPBARDATA New() { var d = new APPBARDATA(); d.cbSize = Marshal.SizeOf(typeof(APPBARDATA)); d.hWnd = FindWindow("Shell_TrayWnd", null); return d; }
    public static int GetState() { var d = New(); return (int)SHAppBarMessage(4, ref d); }
    public static void SetState(int state) { var d = New(); d.lParam = (IntPtr)state; SHAppBarMessage(10, ref d); }
}
'@
}
function Get-TaskbarState { return [GeekAppBar]::GetState() }          # bit 0 = auto-hide, bit 1 = always on top
function Set-TaskbarState([int]$State) { [GeekAppBar]::SetState($State) }
