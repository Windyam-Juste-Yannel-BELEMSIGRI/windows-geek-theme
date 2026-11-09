# Step 06 - VS Code: built-in dark theme + palette overrides + monospace Nerd Font. No extension installed.
$G = $global:Geek
Write-Step '06  VS Code settings'

$hex = '00ff9c'; if ($G.Accent -eq 'cyan') { $hex = '00e5ff' }
$path = Join-Path $env:APPDATA 'Code\User\settings.json'

$obj = [pscustomobject]@{}
if (Test-Path $path) {
    $raw = [IO.File]::ReadAllText($path)
    $clean = [regex]::Replace($raw, '(?m)^\s*//.*$', '')
    $clean = [regex]::Replace($clean, ',(\s*[}\]])', '$1')
    try { if ($clean.Trim().Length -gt 0) { $obj = $clean | ConvertFrom-Json } }
    catch {
        Write-Warn "settings.json has comments/syntax that cannot be merged safely - skipped. Merge config\vscode\settings.snippet.json by hand."
        return
    }
}
function Put($o, $k, $v) { $o | Add-Member -NotePropertyName $k -NotePropertyValue $v -Force }

Put $obj 'workbench.colorTheme' 'Default Dark Modern'
Put $obj 'editor.fontFamily' "'JetBrainsMono Nerd Font', 'Cascadia Code', Consolas, monospace"
Put $obj 'editor.fontLigatures' $true
Put $obj 'editor.fontSize' 14
Put $obj 'terminal.integrated.fontFamily' "'JetBrainsMono Nerd Font', 'Cascadia Code'"
Put $obj 'editor.cursorBlinking' 'smooth'
Put $obj 'editor.minimap.enabled' $false
Put $obj 'window.titleBarStyle' 'custom'

$cc = $null
if ($obj.PSObject.Properties.Name -contains 'workbench.colorCustomizations') { $cc = $obj.'workbench.colorCustomizations' }
if (-not $cc) { $cc = [pscustomobject]@{} }
$colors = [ordered]@{
    'editor.background'             = '#0b0f14'
    'sideBar.background'            = '#080b0f'
    'activityBar.background'        = '#080b0f'
    'activityBar.foreground'        = "#$hex"
    'titleBar.activeBackground'     = '#080b0f'
    'statusBar.background'          = '#080b0f'
    'statusBar.foreground'          = "#$hex"
    'panel.background'              = '#0b0f14'
    'terminal.background'           = '#0b0f14'
    'tab.activeBorderTop'           = "#$hex"
    'editorCursor.foreground'       = "#$hex"
    'focusBorder'                   = "#$hex"
    'list.activeSelectionBackground' = '#12332b'
}
foreach ($k in $colors.Keys) { Put $cc $k $colors[$k] }
Put $obj 'workbench.colorCustomizations' $cc

if (Test-DryRun) { Write-Info '[dry-run] would write VS Code settings.json'; return }
Write-GeekFile $path ($obj | ConvertTo-Json -Depth 10)
Write-Ok "VS Code settings -> $path (original backed up)"
