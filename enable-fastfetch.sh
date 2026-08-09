#!/usr/bin/env bash
#
# enable-fastfetch.sh
#
# Optional: makes fastfetch run automatically every time you open a new
# terminal, by inserting "fastfetch" as the very first line of ~/.zshrc.
#
# Run this any time after setup-ghostty-terminal.sh has finished - ideally
# after Powerlevel10k's "p10k configure" wizard has already run once (it
# launches automatically the first time you open Ghostty). That way nothing
# gets inserted above fastfetch afterward, and it stays at the top for good.
#
set -euo pipefail

ZSHRC="${HOME}/.zshrc"

if [[ ! -f "${ZSHRC}" ]]; then
  echo "[FAIL] ${ZSHRC} not found." >&2
  exit 1
fi

if [[ "$(head -n 1 "${ZSHRC}")" == "fastfetch" ]]; then
  echo "[INFO] fastfetch is already the first line of ~/.zshrc - nothing to do."
  exit 0
fi

cp "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
echo "[INFO] Backed up ${ZSHRC}"

TMP="$(mktemp)"
{
  echo "fastfetch"
  echo ""
  cat "${ZSHRC}"
} > "${TMP}"
mv "${TMP}" "${ZSHRC}"

echo "[ OK ] Added fastfetch to the top of ~/.zshrc."
echo "       Open a new Ghostty window/tab to see it run."
