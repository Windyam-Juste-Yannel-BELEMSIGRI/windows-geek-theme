# Managed by windows-geek-theme - removed automatically by revert.ps1
if ($Host.Name -eq 'ConsoleHost') {
    $esc = [char]27
    function _fg($r, $g, $b) { "$esc[38;2;${r};${g};${b}m" }

    # --- PSReadLine ---
    if (Get-Module -ListAvailable -Name PSReadLine) {
        Import-Module PSReadLine -ErrorAction SilentlyContinue
        try { Set-PSReadLineOption -PredictionSource HistoryAndPlugin -PredictionViewStyle ListView } catch { try { Set-PSReadLineOption -PredictionSource History } catch {} }
        try { Set-PSReadLineOption -BellStyle None -HistorySearchCursorMovesToEnd } catch {}
        try {
            Set-PSReadLineOption -Colors @{
                Command = (_fg 0 255 156); Parameter = (_fg 0 229 255); String = (_fg 255 176 0)
                Variable = (_fg 0 229 255); Comment = (_fg 92 107 122); Keyword = (_fg 179 136 255)
                Operator = (_fg 197 209 222); Number = (_fg 255 176 0); Type = (_fg 0 229 255)
                Error = (_fg 255 83 112); InlinePrediction = (_fg 74 90 106)
            }
        } catch {}
        try {
            Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
            Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
        } catch {}
        # Ctrl+R -> fuzzy history search with fzf
        if (Get-Command fzf -ErrorAction SilentlyContinue) {
            Set-PSReadLineKeyHandler -Chord 'Ctrl+r' -ScriptBlock {
                $hp = (Get-PSReadLineOption).HistorySavePath
                if (-not (Test-Path $hp)) { return }
                $lines = Get-Content $hp | Where-Object { $_ } | Select-Object -Unique
                [array]::Reverse($lines)
                $sel = $lines | fzf --height 40% --reverse --prompt 'history> '
                if ($sel) {
                    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
                    [Microsoft.PowerShell.PSConsoleReadLine]::Insert($sel)
                }
            }
        }
    }

    # --- icons, prompt, smart cd ---
    if (Get-Module -ListAvailable -Name Terminal-Icons) { Import-Module Terminal-Icons -ErrorAction SilentlyContinue }
    $omp = Join-Path $HOME '.config\ohmyposh\soc-matrix.omp.json'
    if ((Get-Command oh-my-posh -ErrorAction SilentlyContinue) -and (Test-Path $omp)) {
        oh-my-posh init pwsh --config $omp | Invoke-Expression
    }
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { (zoxide init powershell | Out-String) })
    }

    # --- modern CLI helpers (original ls/cat/cd are left untouched) ---
    if (Get-Command eza -ErrorAction SilentlyContinue) {
        function ll { eza -lh --icons --git --group-directories-first @args }
        function la { eza -lha --icons --git --group-directories-first @args }
        function lt { eza --tree --level=2 --icons @args }
    }
    $bt = Get-Command btop, btop4win -ErrorAction Ignore | Select-Object -First 1
    if ($bt) { Set-Alias -Name top -Value $bt.Source }
}
