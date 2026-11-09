#!/usr/bin/env bash
# Usage: setup-user.sh apply <path-to-omp-json>   |   setup-user.sh revert
# Idempotent. Only touches ~/.bashrc (marked block), ~/.config/ohmyposh and ~/.local/bin/oh-my-posh.
set -u
MARK="windows-geek-theme"
RC="$HOME/.bashrc"

strip_block() { sed -i "/# >>> $MARK >>>/,/# <<< $MARK <<</d" "$RC" 2>/dev/null || true; }

case "${1:-}" in
  apply)
    THEME="${2:?theme path required}"
    mkdir -p "$HOME/.local/bin" "$HOME/.config/ohmyposh"
    if [ ! -x "$HOME/.local/bin/oh-my-posh" ]; then
      case "$(uname -m)" in aarch64) A=arm64 ;; *) A=amd64 ;; esac
      curl -fsSL -o "$HOME/.local/bin/oh-my-posh" \
        "https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/posh-linux-$A" \
        && chmod +x "$HOME/.local/bin/oh-my-posh" || echo "[!] oh-my-posh download failed"
    fi
    cp "$THEME" "$HOME/.config/ohmyposh/soc-matrix.omp.json"
    touch "$RC"; strip_block
    cat >> "$RC" <<'EOF'
# >>> windows-geek-theme >>>
export PATH="$HOME/.local/bin:$PATH"
if command -v oh-my-posh >/dev/null 2>&1; then
  eval "$(oh-my-posh init bash --config "$HOME/.config/ohmyposh/soc-matrix.omp.json")"
fi
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init bash)"
[ -f /usr/share/doc/fzf/examples/key-bindings.bash ] && . /usr/share/doc/fzf/examples/key-bindings.bash
command -v batcat >/dev/null 2>&1 && alias bat='batcat'
if command -v eza >/dev/null 2>&1; then
  alias ll='eza -lh --icons --git --group-directories-first'
  alias la='eza -lha --icons --git --group-directories-first'
  alias lt='eza --tree --level=2 --icons'
fi
# <<< windows-geek-theme <<<
EOF
    echo "[ok] Debian shell configured"
    ;;
  revert)
    strip_block
    rm -f "$HOME/.config/ohmyposh/soc-matrix.omp.json" "$HOME/.local/bin/oh-my-posh"
    echo "[ok] Debian shell reverted (apt packages left installed)"
    ;;
  *) echo "usage: $0 apply <theme.json> | revert"; exit 1 ;;
esac
