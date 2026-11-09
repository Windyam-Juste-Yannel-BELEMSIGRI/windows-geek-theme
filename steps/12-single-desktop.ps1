# Step 12 - single virtual desktop. GlazeWM does not manage Windows virtual desktops: windows on other desktops
# are never tiled and the Zebar bar only exists on desktop 1. GlazeWM workspaces (alt+1..9) replace them.
# Closing a virtual desktop makes Windows move its windows to the previous desktop (nothing is closed or lost).
# Not auto-reversible: recreate desktops with Win+Ctrl+D if you ever want them back.
$G = $global:Geek
Write-Step '12  Single virtual desktop (use GlazeWM workspaces instead)'

function Get-DesktopCount {
    $ids = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VirtualDesktops' -ErrorAction Ignore).VirtualDesktopIDs
    if ($ids) { return [int]($ids.Length / 16) } else { return 1 }
}
$n = Get-DesktopCount
Write-Info "virtual desktops now: $n"
if ($n -le 1) { Write-Ok 'already a single desktop'; return }
Write-Info "Will close desktops 2..$n (their windows move to the previous desktop, ending on desktop 1)."
if (-not (Confirm-Action 'Close the extra virtual desktops?')) { Write-Warn 'skipped'; return }
if (Test-DryRun) { Write-Info '[dry-run] Win+Ctrl+Right x(n-1), Win+Ctrl+F4 x(n-1)'; return }

if (-not ('GeekKeys' -as [type])) {
    Add-Type @'
using System; using System.Runtime.InteropServices;
public class GeekKeys {
    [DllImport("user32.dll")] static extern void keybd_event(byte vk, byte scan, uint flags, UIntPtr extra);
    public static void Chord(byte mod1, byte mod2, byte key, bool extended) {
        uint e = extended ? 1u : 0u;
        keybd_event(mod1, mod1, 1, UIntPtr.Zero); keybd_event(mod2, mod2, 0, UIntPtr.Zero);
        keybd_event(key, 0, e, UIntPtr.Zero); keybd_event(key, 0, e | 2, UIntPtr.Zero);
        keybd_event(mod2, mod2, 2, UIntPtr.Zero); keybd_event(mod1, mod1, 3, UIntPtr.Zero);
    }
}
'@
}
$LWIN = 0x5B; $CTRL = 0x11; $RIGHT = 0x27; $F4 = 0x73
# go to the last desktop...
for ($i = 1; $i -lt $n; $i++) { [GeekKeys]::Chord($LWIN, $CTRL, $RIGHT, $true); Wait-Process -Name nonexistent -Timeout 1 -ErrorAction SilentlyContinue }
# ...then close desktops from the end; each close lands on the previous desktop and carries the windows along
for ($i = 1; $i -lt $n; $i++) { [GeekKeys]::Chord($LWIN, $CTRL, $F4, $false); Wait-Process -Name nonexistent -Timeout 2 -ErrorAction SilentlyContinue }
$now = Get-DesktopCount
if ($now -le 1) { Write-Ok 'single desktop; all windows are on desktop 1' }
else { Write-Warn "still $now desktops - close the rest with Win+Ctrl+F4" }
