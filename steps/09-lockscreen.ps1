# Step 09 - lock screen / sign-in image, per user, through the same Windows API the Settings app uses.
# (The "force lock screen image" policy is only honoured on Enterprise/Education, NOT on Pro - so it is not used.)
$G = $global:Geek
Write-Step '09  Lock screen + sign-in image  [per-user API, no HKLM, no admin]'
Write-Info 'Sets the lock screen picture with Windows.System.UserProfile.LockScreen.SetImageFileAsync (supported API),'
Write-Info 'and turns off Windows Spotlight rotation for the lock screen (HKCU ContentDeliveryManager, journaled).'
Write-Info 'The sign-in screen reuses this picture when "show lock screen background on sign-in" is on (default).'
Write-Info 'Not possible without hacks: recolouring/removing the blur of the sign-in screen itself.'

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
New-GeekWallpaper -Path $img -AccentHex $hex
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
Write-Info 'Press Win+L to check. Previous lock screen was Windows Spotlight (re-enable it in Settings > Lock screen > Windows Spotlight).'
