#!/usr/bin/env bash
# Run as root inside Debian. Installs CLI tools from Debian's own repositories.
set -u
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
for p in curl ca-certificates git unzip fzf bat ripgrep jq zoxide eza; do
  apt-get install -y --no-install-recommends "$p" || echo "[skip] $p not available in this Debian release"
done
