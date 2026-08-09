#!/usr/bin/env bash
#
# setup-ghostty-terminal.sh
#
# Bootstraps a brand-new Mac with:
#   - Homebrew (+ PATH/shellenv setup)
#   - Ghostty terminal (installed via Homebrew cask)
#   - Ghostty config using the "Kitty Default" example config from
#     https://github.com/andrewpayne68/macos-terminal-oh-my-ghostty
#   - Oh My Zsh
#   - Powerlevel10k theme (installed via Homebrew)
#   - Fastfetch
#
# Deliberately NOT installed: bat, eza, zoxide (per request)
#
# Usage:
#   chmod +x setup-ghostty-terminal.sh
#   ./setup-ghostty-terminal.sh
#
set -euo pipefail

info()  { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()    { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()  { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err()   { printf '\033[1;31m[FAIL]\033[0m %s\n' "$1" >&2; }
step()  { printf '\n\033[1;36m===> Step %s/6: %s\033[0m\n' "$1" "$2"; }

if [[ "$(uname)" != "Darwin" ]]; then
  err "This script only runs on macOS."
  exit 1
fi

# ---------------------------------------------------------------------------
# 0. Cache admin credentials (needed for the unattended CLT install below)
# ---------------------------------------------------------------------------
info "This script needs admin rights to install Command Line Tools unattended."
sudo -v
# Keep the sudo timestamp alive in the background until this script exits.
( while true; do sudo -n true; sleep 60; kill -0 "$$" 2>/dev/null || exit; done ) &
SUDO_KEEPALIVE_PID=$!
trap 'kill "${SUDO_KEEPALIVE_PID}" &>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools (Homebrew requires these)
# ---------------------------------------------------------------------------
step 1 "Xcode Command Line Tools"
if ! xcode-select -p &>/dev/null; then
  info "Installing Xcode Command Line Tools (unattended, no popup)..."

  CLT_PLACEHOLDER="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  sudo touch "${CLT_PLACEHOLDER}"

  CLT_PACKAGE="$(softwareupdate -l 2>/dev/null \
    | grep "\*.*Command Line Tools" \
    | tail -n 1 \
    | sed 's/^[^C]*C/C/' \
    | sed 's/[[:space:]]*$//')"

  if [[ -n "${CLT_PACKAGE}" ]]; then
    info "Found package via softwareupdate: ${CLT_PACKAGE}"
    sudo softwareupdate -i "${CLT_PACKAGE}" --verbose
  else
    warn "Could not auto-detect the CLT package via softwareupdate."
    warn "Falling back to xcode-select --install (a system dialog will appear - click Install)."
    sudo rm -f "${CLT_PLACEHOLDER}"
    xcode-select --install || true
  fi

  sudo rm -f "${CLT_PLACEHOLDER}"

  info "Waiting for Xcode Command Line Tools installation to finish..."
  until xcode-select -p &>/dev/null; do
    sleep 5
  done
  ok "Xcode Command Line Tools installed."
else
  ok "Xcode Command Line Tools already installed."
fi

# ---------------------------------------------------------------------------
# 2. Homebrew
# ---------------------------------------------------------------------------
step 2 "Homebrew"
if ! command -v brew &>/dev/null; then
  info "Installing Homebrew (verbose)..."
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  ok "Homebrew already installed."
fi

# Homebrew lives in different places on Apple Silicon vs Intel Macs.
if [[ -d /opt/homebrew/bin ]]; then
  BREW_PATH="/opt/homebrew/bin/brew"
elif [[ -d /usr/local/bin ]] && [[ -x /usr/local/bin/brew ]]; then
  BREW_PATH="/usr/local/bin/brew"
else
  # Fall back to whatever the installer just set up
  BREW_PATH="$(command -v brew || true)"
fi

if [[ -z "${BREW_PATH}" ]]; then
  err "Could not locate the brew binary after installation."
  exit 1
fi

# Load brew into the current shell session
eval "$("${BREW_PATH}" shellenv)"

# Persist brew's PATH/shellenv setup into .zprofile, as Homebrew's own
# post-install instructions recommend, so it's available in every new shell.
ZPROFILE="${HOME}/.zprofile"
touch "${ZPROFILE}"
SHELLENV_LINE="eval \"\$(${BREW_PATH} shellenv)\""
if ! grep -qF "${SHELLENV_LINE}" "${ZPROFILE}" 2>/dev/null; then
  echo "" >> "${ZPROFILE}"
  echo "# Homebrew" >> "${ZPROFILE}"
  echo "${SHELLENV_LINE}" >> "${ZPROFILE}"
  ok "Added Homebrew shellenv to ${ZPROFILE}"
else
  ok "Homebrew shellenv already present in ${ZPROFILE}"
fi

info "Updating Homebrew (verbose)..."
brew update --verbose

# ---------------------------------------------------------------------------
# 3. Ghostty
# ---------------------------------------------------------------------------
step 3 "Ghostty"
if ! brew list --cask ghostty &>/dev/null; then
  info "Installing Ghostty (verbose)..."
  brew install --cask ghostty --verbose
else
  ok "Ghostty already installed."
fi

# Ghostty config: use the "Kitty Default" example config from the README
GHOSTTY_CONFIG_DIR="${HOME}/.config/ghostty"
GHOSTTY_CONFIG_FILE="${GHOSTTY_CONFIG_DIR}/config"
mkdir -p "${GHOSTTY_CONFIG_DIR}"

if [[ -f "${GHOSTTY_CONFIG_FILE}" ]]; then
  cp "${GHOSTTY_CONFIG_FILE}" "${GHOSTTY_CONFIG_FILE}.bak.$(date +%Y%m%d%H%M%S)"
  warn "Existing Ghostty config backed up."
fi

cat > "${GHOSTTY_CONFIG_FILE}" <<'EOF'
theme = Kitty Default
font-size = 14
window-width = 111
window-height = 41
background-opacity = 0.9
background = #000000
keybind = option+backspace=text:\x1b\x7f
shell-integration-features = ssh-terminfo,ssh-env
confirm-close-surface = false
EOF
ok "Wrote Ghostty config to ${GHOSTTY_CONFIG_FILE} (Kitty Default theme)."

# ---------------------------------------------------------------------------
# 4. Oh My Zsh
# ---------------------------------------------------------------------------
step 4 "Oh My Zsh"
if [[ ! -d "${HOME}/.oh-my-zsh" ]]; then
  info "Installing Oh My Zsh (verbose)..."
  # KEEP_ZSHRC=yes: don't overwrite an existing .zshrc
  # CHSH=no / RUNZSH=no: don't touch login shell or drop into a new zsh
  #                      session in the middle of this script
  KEEP_ZSHRC=yes CHSH=no RUNZSH=no \
    sh -c "$(curl -fL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
else
  ok "Oh My Zsh already installed."
fi

ZSHRC="${HOME}/.zshrc"
touch "${ZSHRC}"
cp "${ZSHRC}" "${ZSHRC}.bak.$(date +%Y%m%d%H%M%S)"
info "Backed up existing .zshrc"

# ---------------------------------------------------------------------------
# 5. Powerlevel10k (installed via Homebrew, per the README)
# ---------------------------------------------------------------------------
step 5 "Powerlevel10k"
if ! brew list powerlevel10k &>/dev/null; then
  info "Installing Powerlevel10k (verbose)..."
  brew install powerlevel10k --verbose
else
  ok "Powerlevel10k already installed."
fi

P10K_SOURCE_LINE="source $(brew --prefix)/share/powerlevel10k/powerlevel10k.zsh-theme"

if ! grep -qF "powerlevel10k.zsh-theme" "${ZSHRC}"; then
  echo "" >> "${ZSHRC}"
  echo "# Powerlevel10k theme" >> "${ZSHRC}"
  echo "${P10K_SOURCE_LINE}" >> "${ZSHRC}"
  ok "Added Powerlevel10k source line to .zshrc"
else
  ok "Powerlevel10k source line already present in .zshrc"
fi

# Make sure Oh My Zsh's own ZSH_THEME setting doesn't fight with p10k.
# We disable it (set to "") since powerlevel10k is sourced directly instead.
if grep -q '^ZSH_THEME=' "${ZSHRC}"; then
  sed -i '' 's/^ZSH_THEME=.*/ZSH_THEME=""/' "${ZSHRC}"
else
  echo 'ZSH_THEME=""' >> "${ZSHRC}"
fi
ok "Set ZSH_THEME=\"\" in .zshrc so Powerlevel10k controls the prompt."

# ---------------------------------------------------------------------------
# 6. Fastfetch
# ---------------------------------------------------------------------------
step 6 "Fastfetch"
if ! brew list fastfetch &>/dev/null; then
  info "Installing Fastfetch (verbose)..."
  brew install fastfetch --verbose
else
  ok "Fastfetch already installed."
fi

if ! grep -qF "fastfetch-init" "${ZSHRC}"; then
  # fastfetch must run before anything else in .zshrc (including Oh My Zsh /
  # Powerlevel10k's instant prompt), otherwise its console output triggers
  # Powerlevel10k's "console output during zsh initialization detected"
  # warning. So it's prepended to the very top of the file, not appended.
  TMP_ZSHRC="$(mktemp)"
  {
    echo "# >>> fastfetch-init >>>"
    echo "fastfetch"
    echo "# <<< fastfetch-init <<<"
    echo ""
    cat "${ZSHRC}"
  } > "${TMP_ZSHRC}"
  mv "${TMP_ZSHRC}" "${ZSHRC}"
  ok "Added fastfetch to the top of .zshrc so it runs on new shell sessions."
else
  ok "fastfetch already referenced in .zshrc"
fi

# Powerlevel10k's first-run "p10k configure" wizard (triggered automatically
# the first time Ghostty opens with no ~/.p10k.zsh yet) inserts its own
# instant-prompt block at the very top of .zshrc - ABOVE the fastfetch line
# added above, undoing that ordering and re-triggering the "console output
# during zsh initialization detected" warning. This self-healing hook defers
# the repair to a precmd hook, which only fires once .zshrc has fully
# finished sourcing and the shell is about to show its first prompt - it is
# NOT safe to rewrite .zshrc while it is still being actively read/executed
# (that corrupts the file), so the fix must happen after sourcing completes,
# not inline during it. It does nothing until ~/.p10k.zsh appears (i.e.
# until configure has actually run), then re-positions fastfetch above
# everything exactly once and never touches the file again after that.
if ! grep -qF "fastfetch-position-fix" "${ZSHRC}"; then
  cat >> "${ZSHRC}" <<'ZSHRC_SNIPPET'

# >>> fastfetch-position-fix >>>
if [[ -f "${HOME}/.p10k.zsh" && ! -f "${HOME}/.cache/.p10k-fastfetch-fixed" ]]; then
  __fastfetch_position_fix() {
    mkdir -p "${HOME}/.cache"
    local __ff_zshrc="${HOME}/.zshrc"
    local __ff_tmp
    __ff_tmp="$(mktemp)"
    {
      echo "# >>> fastfetch-init >>>"
      echo "fastfetch"
      echo "# <<< fastfetch-init <<<"
      echo ""
      sed '/^# >>> fastfetch-init >>>$/,/^# <<< fastfetch-init <<<$/d' "${__ff_zshrc}"
    } > "${__ff_tmp}"
    mv "${__ff_tmp}" "${__ff_zshrc}"
    touch "${HOME}/.cache/.p10k-fastfetch-fixed"
    precmd_functions=(${precmd_functions:#__fastfetch_position_fix})
    unfunction __fastfetch_position_fix
  }
  precmd_functions+=(__fastfetch_position_fix)
fi
# <<< fastfetch-position-fix <<<
ZSHRC_SNIPPET
  ok "Added a one-time self-heal hook that re-fixes fastfetch's position after p10k configure runs."
else
  ok "fastfetch self-heal hook already present in .zshrc"
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo ""
ok "Setup complete!"
echo ""
echo "Next steps:"
echo "  1. Quit and reopen Ghostty (or open it for the first time) to pick up the new config."
echo "  2. Open a new Ghostty terminal - Powerlevel10k's configuration wizard"
echo "     will launch automatically the first time. Run 'p10k configure' any"
echo "     time afterward to redo it."
echo "  3. Your previous .zshrc and Ghostty config (if any) were backed up"
echo "     with a timestamp suffix in the same directory."
echo ""
echo "Not installed (as requested): bat, eza, zoxide"
