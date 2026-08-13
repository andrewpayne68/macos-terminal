#!/usr/bin/env bash
#
# enable-fastfetch.sh
#
# Optional add-on to setup-ghostty-terminal.sh:
#   1. Installs fastfetch via Homebrew if it isn't already installed.
#   2. Extracts the bundled Apple-themed fastfetch config (config.jsonc +
#      assets/, including apple.png) to ~/.config/fastfetch/ - this is
#      fastfetch's default config location, so no extra flags are needed.
#   3. Makes fastfetch run automatically every time you open a new terminal,
#      by inserting "fastfetch" as the very first line of ~/.zshrc.
#
# Run this any time after setup-ghostty-terminal.sh has finished - ideally
# after Powerlevel10k's "p10k configure" wizard has already run once (it
# launches automatically the first time you open Ghostty). That way nothing
# gets inserted above fastfetch afterward, and it stays at the top for good.
#
# Must be run from the same folder as fastfetch-apple.tar.gz (or that file
# just won't be found - fastfetch will still work, using its default theme).
#
set -euo pipefail

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err()   { printf '\033[1;31m[FAIL]\033[0m %s\n' "$1" >&2; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ZSHRC="${HOME}/.zshrc"
FASTFETCH_CONFIG_DIR="${HOME}/.config/fastfetch"
FASTFETCH_ARCHIVE="${SCRIPT_DIR}/fastfetch-apple.tar.gz"

# ---------------------------------------------------------------------------
# 1. Install fastfetch if missing
# ---------------------------------------------------------------------------
if ! command -v fastfetch &>/dev/null; then
  if ! command -v brew &>/dev/null; then
    err "Homebrew not found - install Homebrew first (see setup-ghostty-terminal.sh)."
    exit 1
  fi
  info "Installing fastfetch..."
  brew install fastfetch --verbose
else
  ok "fastfetch already installed."
fi

# ---------------------------------------------------------------------------
# 2. Extract the Apple-themed config + assets (including apple.png)
# ---------------------------------------------------------------------------
if [[ -f "${FASTFETCH_ARCHIVE}" ]]; then
  info "Installing Apple-themed fastfetch config to ${FASTFETCH_CONFIG_DIR}..."
  mkdir -p "${FASTFETCH_CONFIG_DIR}"

  if [[ -f "${FASTFETCH_CONFIG_DIR}/config.jsonc" ]]; then
    cp "${FASTFETCH_CONFIG_DIR}/config.jsonc" "${FASTFETCH_CONFIG_DIR}/config.jsonc.bak.$(date +%Y%m%d%H%M%S)"
    info "Backed up existing config.jsonc"
  fi

  tar -xzf "${FASTFETCH_ARCHIVE}" -C "${FASTFETCH_CONFIG_DIR}" 2>/dev/null
  ok "Extracted config.jsonc and assets/ (including apple.png) to ${FASTFETCH_CONFIG_DIR}"
else
  warn "fastfetch-apple.tar.gz not found next to this script - skipping custom config."
  warn "fastfetch will use its default theme instead."
fi

# ---------------------------------------------------------------------------
# 3. Add fastfetch to the top of .zshrc
# ---------------------------------------------------------------------------
if [[ ! -f "${ZSHRC}" ]]; then
  err "${ZSHRC} not found."
  exit 1
fi

if [[ "$(head -n 1 "${ZSHRC}")" == "fastfetch" ]]; then
  ok "fastfetch is already the first line of ~/.zshrc - nothing to do."
else
  cp "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
  info "Backed up ${ZSHRC}"

  TMP="$(mktemp)"
  {
    echo "fastfetch"
    echo ""
    cat "${ZSHRC}"
  } > "${TMP}"
  mv "${TMP}" "${ZSHRC}"
  ok "Added fastfetch to the top of ~/.zshrc."
fi

echo ""
ok "Done. Open a new Ghostty window/tab to see it run."
