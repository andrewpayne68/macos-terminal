#!/usr/bin/env bash
#
# fix-fastfetch-position.sh
#
# One-off repair: moves the "fastfetch" call to the very top of ~/.zshrc,
# above Powerlevel10k's instant-prompt block. Safe to run any time,
# including after "p10k configure" has already run and inserted its own
# block at the top of the file.
#
set -euo pipefail

ZSHRC="${HOME}/.zshrc"

if [[ ! -f "${ZSHRC}" ]]; then
  echo "[FAIL] ${ZSHRC} not found." >&2
  exit 1
fi

cp "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
echo "[INFO] Backed up ${ZSHRC}"

TMP="$(mktemp)"
{
  echo "# >>> fastfetch-init >>>"
  echo "fastfetch"
  echo "# <<< fastfetch-init <<<"
  echo ""
  # Strip any previous fastfetch line(s)/comments/markers so nothing is duplicated.
  # NOTE: the range pattern is anchored to whole lines (^...$) rather than a
  # bare substring match, because a substring match would also match the
  # marker text embedded inside the self-heal function's own echo/sed lines
  # further down the file, causing sed to delete everything after that
  # point (no closing match exists for that false hit).
  sed \
    -e '/^# >>> fastfetch-init >>>$/,/^# <<< fastfetch-init <<<$/d' \
    -e '/^fastfetch$/d' \
    -e '/^# Run fastfetch on new terminal sessions/d' \
    -e '/^# top of \.zshrc - see Powerlevel10k instant prompt docs)/d' \
    "${ZSHRC}"
} > "${TMP}"
mv "${TMP}" "${ZSHRC}"

echo "[ OK ] fastfetch moved above everything else in ~/.zshrc, including Powerlevel10k's instant-prompt block."
echo "       Open a new Ghostty window/tab to see the fix take effect."
