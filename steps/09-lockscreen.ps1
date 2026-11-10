# Step 09 - lock screen / sign-in image, per user, through the same Windows API the Settings app uses.
# (The "force lock screen image" policy is only honoured on Enterprise/Education, NOT on Pro - so it is not used.)
$G = $global:Geek
Write-Step '09  Lock screen + sign-in image  [per-user API; one optional HKLM policy for a sharp sign-in background]'
Write-Info 'Sets the lock screen picture with Windows.System.UserProfile.LockScreen.SetImageFileAsync (supported API),'
Write-Info 'and turns off Windows Spotlight rotation for the lock screen (HKCU ContentDeliveryManager, journaled).'
Write-Info 'The sign-in screen reuses this picture when "show lock screen background on sign-in" is on (default).'
Write-Info 'The picture is a still frame of the desktop network animation (a lock screen cannot be animated).'
Write-Info 'Sign-in screen: its blur is removed with the Group Policy "Show clear logon background" (HKLM, admin, journaled).'
Write-Info 'Not possible without hacks: recolouring the sign-in screen or changing its font.'

$hex = '00ff9c'; if ($G.Accent -eq 'cyan') { $hex = '00e5ff' }
$img = Join-Path $env:USERPROFILE 'Pictures\windows-geek-theme\lockscreen.png'
if (Test-DryRun) { Write-Info "[dry-run] generate $img ; SetImageFileAsync ; disable Spotlight rotation ; clean legacy policy"; return }

# --- one-time cleanup of the earlier (ineffective on Pro) HKLM policy written by a previous version of this step ---
$j = Get-Journal
foreach ($e in @($j.regValues | Where-Object { $_.path -like '*Policies\Microsoft\Windows\Personalization' -and $_.name -eq 'LockScreenImage' })) {
    if (Test-Admin) { if (Restore-RegValue $e) { Write-Ok 'removed legacy LockScreenImage policy' } }
    else { Write-Warn 'legacy LockScreenImage policy left in place (needs admin to remove; harmless on Pro)' }
}

# --- picture ---
Register-File $img
New-GeekWallpaper -Path $img -AccentHex $hex -Network -Prompt 'soc analyst // data engineer'
Write-Ok "generated $img (native resolution)"

# --- Spotlight off for the lock screen (otherwise it keeps overriding the picture) ---
$cdm = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
[void](Set-RegValue $cdm 'RotatingLockScreenEnabled' 0)
[void](Set-RegValue $cdm 'RotatingLockScreenOverlayEnabled' 0)

# --- WinRT call (Windows PowerShell 5.1) ---
try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    $null = [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime]
    $null = [Windows.System.UserProfile.LockScreen, Windows.System.UserProfile, ContentType = WindowsRuntime]
    $ext = [System.WindowsRuntimeSystemExtensions]
    $asOp = ($ext.GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' })[0]
    $asAct = ($ext.GetMethods() | Where-Object { $_.Name -eq 'AsTask' -and $_.GetParameters().Count -eq 1 -and $_.GetParameters()[0].ParameterType.Name -eq 'IAsyncAction' })[0]

    $t = $asOp.MakeGenericMethod([Windows.Storage.StorageFile]).Invoke($null, @([Windows.Storage.StorageFile]::GetFileFromPathAsync($img)))
    [void]$t.Wait(-1)
    $t2 = $asAct.Invoke($null, @([Windows.System.UserProfile.LockScreen]::SetImageFileAsync($t.Result)))
    [void]$t2.Wait(-1)
    $now = [Windows.System.UserProfile.LockScreen]::OriginalImageFile
    Write-Ok "lock screen picture set: $($now.LocalPath)"
} catch {
    Write-Warn "SetImageFileAsync failed: $($_.Exception.Message)"
    Write-Info "Fallback (manual): Settings > Personalization > Lock screen > Picture > Browse > $img"
}
# --- sign-in screen: show the picture sharp instead of blurred (official policy, Computer > System > Logon) ---
if (-not (Test-Admin)) { Write-Info 'not elevated: sign-in background stays blurred (policy needs admin)' }
elseif (Confirm-Action 'Remove the blur of the sign-in background (HKLM policy DisableAcrylicBackgroundOnLogon)?') {
    if (Set-RegValue 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'DisableAcrylicBackgroundOnLogon' 1) { Write-Ok 'sign-in background: blur disabled by policy' }
}
Write-Info 'Press Win+L to check. Previous lock screen was Windows Spotlight (re-enable it in Settings > Lock screen > Windows Spotlight).'
