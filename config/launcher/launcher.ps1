# geek-launcher - wofi/dmenu-style launcher for Windows (PowerShell 7 + fzf, runs in a floating Windows Terminal window).
#   <text>      fuzzy-find an installed app and launch it with Enter
#   >command    run a command in a new PowerShell terminal
#   ?terms      web search (DuckDuckGo) in the default browser
#   Esc         close
$ErrorActionPreference = 'SilentlyContinue'
# GlazeWM may have been started before the tools were installed: re-read PATH from the registry.
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine') + ';' + [Environment]::GetEnvironmentVariable('Path', 'User')
if (-not (Get-Command fzf -ErrorAction Ignore)) { Write-Host 'fzf not found (winget install junegunn.fzf)'; Start-Sleep 3; exit 0 }

# every Start-menu / UWP app, via the shell AppsFolder (fast, no module import)
$items = (New-Object -ComObject Shell.Application).NameSpace('shell:AppsFolder').Items()
$lines = $items | Where-Object { $_.Name } | ForEach-Object { '{0}{1}{2}' -f $_.Name, "`t", $_.Path } | Sort-Object -Unique

$colors = 'bg:-1,bg+:#12332b,fg:#c5d1de,fg+:#00ff9c,hl:#00e5ff,hl+:#00e5ff,pointer:#00ff9c,prompt:#00ff9c,' +
          'info:#5c6b7a,border:#1b3a33,header:#ffb000,gutter:-1,spinner:#00e5ff,marker:#ffb000'
$out = $lines | fzf --delimiter "`t" --with-nth 1 --layout reverse --height 100% --border rounded `
    --prompt ([string][char]0x276F + ' ') --pointer ([string][char]0x25B6) --info inline-right --no-scrollbar `
    --header 'wofi // run    >cmd  ?web  esc' --header-first `
    --color $colors --print-query
$code = $LASTEXITCODE
if ($code -eq 130) { exit 0 }

$res = @($out)
$query = ''; $sel = $null
if ($res.Count -ge 1) { $query = [string]$res[0] }
if ($code -eq 0 -and $res.Count -ge 2) { $sel = [string]$res[1] }

if ($sel) {
    $id = ($sel -split "`t", 2)[1]
    if ($id) { Start-Process explorer.exe "shell:AppsFolder\$id" }
}
elseif ($query.StartsWith('>')) {
    $cmd = $query.Substring(1).Trim()
    if ($cmd) { Start-Process wt.exe -ArgumentList @('new-tab', '-p', 'SOC // PowerShell 7', 'pwsh.exe', '-NoLogo', '-NoExit', '-Command', $cmd) }
}
elseif ($query.StartsWith('?')) {
    $q = $query.Substring(1).Trim()
    if ($q) { Start-Process ('https://duckduckgo.com/?q=' + [uri]::EscapeDataString($q)) }
}
elseif ($query -match '^(https?://|www\.)\S+$') {
    Start-Process $query
}
exit 0
