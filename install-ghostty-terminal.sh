#!/usr/bin/env bash
#
# install-ghostty-terminal.sh
#
# One-shot installer for a complete Ghostty terminal setup on macOS:
#
#   Step 1  Ghostty + Oh My Zsh + Powerlevel10k
#           (Xcode tools, Homebrew, Ghostty, Oh My Zsh, Powerlevel10k, Fastfetch)
#   Step 2  Restore a saved Powerlevel10k config (~/.p10k.zsh) so the
#           first-run configuration wizard is skipped
#   Step 3  Apple-logo fastfetch theme
#           (extracts fastfetch-apple.tar.gz and puts fastfetch on line 1 of ~/.zshrc)
#
# Steps 2 and 3 only run automatically if a saved Powerlevel10k config can be
# found. Without one, Step 1 runs, then you open Ghostty, complete the
# Powerlevel10k wizard, and run this script again - it will skip what is
# already done and finish Step 3 (see "Re-running" below).
#
# Where the saved config is looked for, in order:
#   1. $P10K_CONFIG                     (path to a p10k.zsh file)
#   2. p10k.zsh next to this script
#   3. ~/scripts/p10k.zsh
#   4. p10k.zsh in this repo            (downloaded from GitHub)
#
# If Ghostty is already installed you are offered a full RESET (everything is
# backed up to ~/.terminal-setup-backup-<timestamp>, nothing is deleted).
#
# Usage - straight from GitHub, no cloning needed:
#   curl -fsSL https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/install-ghostty-terminal.sh | bash
#
# Or download it first:
#   curl -fsSL -o install-ghostty-terminal.sh https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/install-ghostty-terminal.sh
#   chmod +x install-ghostty-terminal.sh
#   ./install-ghostty-terminal.sh
#
# Re-running: if Ghostty is already installed and you answer N to the reset
# question, the script skips Step 1 and carries on with Steps 2 and 3 (useful
# after completing the Powerlevel10k wizard by hand).
#
# Works with the macOS system bash (3.2).
#
set -uo pipefail

REPO_RAW="${REPO_RAW:-https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main}"
P10K_URL="${P10K_URL:-${REPO_RAW}/p10k.zsh}"

info()   { printf '\033[1;34m[INFO]\033[0m %s\n' "$1"; }
ok()     { printf '\033[1;32m[ OK ]\033[0m %s\n' "$1"; }
warn()   { printf '\033[1;33m[WARN]\033[0m %s\n' "$1"; }
err()    { printf '\033[1;31m[FAIL]\033[0m %s\n' "$1" >&2; }
header() { printf '\n\033[1;36m===> %s\033[0m\n' "$1"; }
die()    { err "$1"; exit 1; }
step()   { printf '\n\033[1;36m--> %s (%s/6)\033[0m\n' "$2" "$1"; }

# Prompts read from the terminal so this also works when piped from curl.
ask() {  # ask "Question (y/N): "  -> success only on y/Y
  local reply=""
  printf '%s' "$1" > /dev/tty 2>/dev/null || return 1
  read -r reply < /dev/tty || return 1
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}
ask_exact() {  # ask_exact "Prompt: " WORD  -> success only if reply == WORD
  local reply=""
  printf '%s' "$1" > /dev/tty 2>/dev/null || return 1
  read -r reply < /dev/tty || return 1
  [[ "$reply" == "$2" ]]
}

TMP=""
cleanup() { [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT

ghostty_installed() {
  [[ -d "/Applications/Ghostty.app" ]] && return 0
  command -v brew &>/dev/null && brew list --cask ghostty &>/dev/null
}

# Download URL to file, then sanity-check it.
fetch() {  # fetch URL DEST
  curl -fsSL -o "$2" "$1"
}
valid_script() {  # valid_script FILE
  [[ "$(head -n 1 "$1")" == "#!"* ]] && bash -n "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------
# Step 1 worker: Xcode CLT, Homebrew, Ghostty, Oh My Zsh, Powerlevel10k, Fastfetch.
# Runs in a subshell so 'exit' and 'set -e' behave strictly without ending the
# installer itself; the caller checks the exit code.
# ---------------------------------------------------------------------------
run_base_setup() (
  set -euo pipefail

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
  ok "Fastfetch installed. Run it any time by typing: fastfetch"
  # Deliberately not added to .zshrc - see README for why.
)

# ---------------------------------------------------------------------------
# Find a saved Powerlevel10k config. Sets P10K_SRC (empty if none found).
# ---------------------------------------------------------------------------
P10K_SRC=""
locate_p10k_config() {
  local script_dir=""
  if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  fi

  if [[ -n "${P10K_CONFIG:-}" && -f "${P10K_CONFIG}" ]]; then
    P10K_SRC="${P10K_CONFIG}"
  elif [[ -n "$script_dir" && -f "${script_dir}/p10k.zsh" ]]; then
    P10K_SRC="${script_dir}/p10k.zsh"
  elif [[ -f "${HOME}/scripts/p10k.zsh" ]]; then
    P10K_SRC="${HOME}/scripts/p10k.zsh"
  elif fetch "$P10K_URL" "${TMP}/p10k.zsh" 2>/dev/null; then
    P10K_SRC="${TMP}/p10k.zsh"
  fi

  if [[ -n "$P10K_SRC" ]] && ! grep -q "POWERLEVEL9K" "$P10K_SRC"; then
    warn "${P10K_SRC} does not look like a Powerlevel10k config - ignoring it."
    P10K_SRC=""
  fi
}

# ---------------------------------------------------------------------------
# Step 2: put the saved config in place and make sure ~/.zshrc loads it.
# ---------------------------------------------------------------------------
apply_p10k_config() {
  local stamp zshrc="${HOME}/.zshrc"
  stamp="$(date +%Y%m%d%H%M%S)"

  if [[ -f "${HOME}/.p10k.zsh" ]]; then
    cp "${HOME}/.p10k.zsh" "${HOME}/.p10k.zsh.bak.${stamp}"
    info "Backed up existing ~/.p10k.zsh"
  fi
  cp "$P10K_SRC" "${HOME}/.p10k.zsh" || return 1
  ok "Restored ~/.p10k.zsh"

  # The wizard normally adds this line itself; add it ourselves.
  touch "$zshrc"
  if ! grep -qF ".p10k.zsh" "$zshrc"; then
    cp "$zshrc" "${zshrc}.bak.${stamp}"
    {
      echo ""
      echo '# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.'
      echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'
    } >> "$zshrc"
    ok "Added the ~/.p10k.zsh source line to ~/.zshrc"
  else
    ok "~/.zshrc already sources ~/.p10k.zsh"
  fi
}

# ---------------------------------------------------------------------------
# Step 3: Apple-logo fastfetch theme.
# ---------------------------------------------------------------------------
install_fastfetch_theme() {
  local archive="${TMP}/fastfetch-apple.tar.gz" cfg="${HOME}/.config/fastfetch" zshrc="${HOME}/.zshrc" stamp t
  stamp="$(date +%Y%m%d%H%M%S)"

  if ! command -v fastfetch &>/dev/null; then
    command -v brew &>/dev/null || { err "Homebrew not found."; return 1; }
    info "Installing fastfetch..."
    brew install fastfetch --verbose || return 1
  fi

  if ! fetch "${REPO_RAW}/fastfetch-apple.tar.gz" "$archive" || ! tar -tzf "$archive" &>/dev/null; then
    err "Could not download a valid fastfetch-apple.tar.gz from ${REPO_RAW}"
    return 1
  fi

  mkdir -p "$cfg"
  if [[ -f "${cfg}/config.jsonc" ]]; then
    cp "${cfg}/config.jsonc" "${cfg}/config.jsonc.bak.${stamp}"
    info "Backed up existing fastfetch config.jsonc"
  fi
  tar -xzf "$archive" -C "$cfg" 2>/dev/null || { err "Could not extract the fastfetch theme."; return 1; }

  touch "$zshrc"
  if [[ "$(head -n 1 "$zshrc")" != "fastfetch" ]]; then
    cp "$zshrc" "${zshrc}.bak.${stamp}"
    t="$(mktemp)" || return 1
    { echo "fastfetch"; echo ""; cat "$zshrc"; } > "$t" && mv "$t" "$zshrc" || return 1
  fi

  local good=true
  [[ -f "${cfg}/assets/apple.png" ]]                   && ok "apple.png installed"    || { err "apple.png missing"; good=false; }
  [[ -f "${cfg}/config.jsonc" ]]                       && ok "config.jsonc installed" || { err "config.jsonc missing"; good=false; }
  [[ "$(head -n 1 "$zshrc")" == "fastfetch" ]]         && ok "fastfetch is the first line of ~/.zshrc" || { err "fastfetch is not the first line of ~/.zshrc"; good=false; }
  $good
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
  [[ "$(uname)" == "Darwin" ]] || die "This script only runs on macOS."
  [[ "$EUID" -ne 0 ]]          || die "Do not run this as root - it asks for sudo when needed."

  printf '\n\033[1;32mINSTALL GHOSTTY TERMINAL\033[0m\n'
  TMP="$(mktemp -d)" || die "Could not create a temp folder."

  # Make an existing Homebrew visible to this script (Apple Silicon or Intel).
  if ! command -v brew &>/dev/null; then
    if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -x /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  locate_p10k_config

  local reset=false run_step1=true stamp backup_dir
  stamp="$(date +%Y%m%d%H%M%S)"
  backup_dir="${HOME}/.terminal-setup-backup-${stamp}"

  # ---- Confirmations -------------------------------------------------------
  if ghostty_installed; then
    warn "Ghostty is already installed."
    [[ -d "${HOME}/.oh-my-zsh" ]] && info "Oh My Zsh found."
    command -v brew &>/dev/null && brew list powerlevel10k &>/dev/null && info "Powerlevel10k found."
    echo ""
    if ask "Reset and reinstall Ghostty, Oh My Zsh and Powerlevel10k? (y/N): "; then
      if [[ "${TERM_PROGRAM:-}" == "ghostty" ]]; then
        echo ""
        warn "You are running this INSIDE Ghostty. A reset removes Ghostty and your"
        warn "shell config while it is open. Run it from Terminal.app instead."
        ask "Continue anyway? (y/N): " || { info "Cancelled."; exit 0; }
      fi
      echo ""
      warn "RESET will:"
      echo "  - move ~/.zshrc, ~/.p10k.zsh, ~/.oh-my-zsh and ~/.config/ghostty to"
      echo "    ${backup_dir} (nothing is deleted)"
      echo "  - uninstall Ghostty and Powerlevel10k, then install everything fresh"
      echo ""
      ask_exact "Type YES to continue: " YES || { info "Cancelled - nothing changed."; exit 0; }
      reset=true
    else
      info "Skipping Step 1 (keeping the current install)."
      run_step1=false
    fi
  else
    info "This will install:"
    echo "  - Xcode Command Line Tools and Homebrew (if missing)"
    echo "  - Ghostty (Kitty Default config), Oh My Zsh, Powerlevel10k, Fastfetch"
    if [[ -n "$P10K_SRC" ]]; then
      echo "  - your saved Powerlevel10k config (skips the wizard): ${P10K_SRC}"
      echo "  - the Apple-logo fastfetch theme"
    else
      echo ""
      warn "No saved Powerlevel10k config found - Steps 2 and 3 will be skipped."
    fi
    echo ""
    ask "Continue? (y/N): " || { info "Cancelled."; exit 0; }
  fi

  # ---- Step 1 --------------------------------------------------------------
  if $run_step1; then
    header "Step 1/3: Ghostty, Oh My Zsh & Powerlevel10k"
    if $reset; then
      info "Backing up to ${backup_dir} ..."
      mkdir -p "$backup_dir"
      [[ -d "${HOME}/.config/ghostty" ]] && mv "${HOME}/.config/ghostty" "${backup_dir}/ghostty"
      [[ -f "${HOME}/.zshrc" ]]          && mv "${HOME}/.zshrc"          "${backup_dir}/zshrc"
      [[ -f "${HOME}/.p10k.zsh" ]]       && mv "${HOME}/.p10k.zsh"       "${backup_dir}/p10k.zsh"
      [[ -d "${HOME}/.oh-my-zsh" ]]      && mv "${HOME}/.oh-my-zsh"      "${backup_dir}/oh-my-zsh"
      info "Removing Ghostty and Powerlevel10k..."
      if command -v brew &>/dev/null; then
        brew list --cask ghostty &>/dev/null && brew uninstall --cask ghostty
        brew list powerlevel10k  &>/dev/null && brew uninstall powerlevel10k
      fi
      [[ -d "/Applications/Ghostty.app" ]] && rm -rf "/Applications/Ghostty.app"
      ok "Reset complete. Backups are in ${backup_dir}"
    fi

    info "Installing (you may be asked for your password once)..."
    echo ""
    run_base_setup
    local rc=$?
    echo ""
    if (( rc != 0 )); then
      err "Step 1 exited with an error (code ${rc})."
      $reset && warn "Your previous files are in ${backup_dir}"
      exit "$rc"
    fi

    # Make brew visible again (it may have just been installed).
    if ! command -v brew &>/dev/null; then
      if   [[ -x /opt/homebrew/bin/brew ]]; then eval "$(/opt/homebrew/bin/brew shellenv)"
      elif [[ -x /usr/local/bin/brew ]];    then eval "$(/usr/local/bin/brew shellenv)"
      fi
    fi

    local good=true
    [[ -d "/Applications/Ghostty.app" ]] && ok "Ghostty installed"     || { err "Ghostty.app not found"; good=false; }
    [[ -d "${HOME}/.oh-my-zsh" ]]        && ok "Oh My Zsh installed"    || { err "Oh My Zsh not found"; good=false; }
    brew list powerlevel10k &>/dev/null  && ok "Powerlevel10k installed" || { err "Powerlevel10k not found"; good=false; }
    grep -qF "powerlevel10k.zsh-theme" "${HOME}/.zshrc" 2>/dev/null \
                                         && ok "Powerlevel10k wired into ~/.zshrc" || { err "Powerlevel10k line missing from ~/.zshrc"; good=false; }
    $good || die "Step 1 checks failed - review the output above."
    ok "Step 1 complete."
  fi

  # ---- Steps 2 and 3 -------------------------------------------------------
  local all_done=false
  # When Step 1 was skipped and a config already exists, keep the current one.
  if [[ -n "$P10K_SRC" ]] && { $run_step1 || [[ ! -f "${HOME}/.p10k.zsh" ]]; }; then
    header "Step 2/3: Restore saved Powerlevel10k config"
    info "Using ${P10K_SRC}"
    if apply_p10k_config; then
      header "Step 3/3: Apple-logo fastfetch theme"
      if install_fastfetch_theme; then
        all_done=true
      else
        err "Step 3 did not complete."
      fi
    else
      err "Could not restore the saved config - Steps 2 and 3 skipped."
    fi
  elif [[ -f "${HOME}/.p10k.zsh" ]]; then
    # No saved config, but the wizard has been completed by hand.
    header "Step 3/3: Apple-logo fastfetch theme"
    info "Powerlevel10k is already configured (~/.p10k.zsh found)."
    if ask "Install the Apple-logo fastfetch theme now? (y/N): "; then
      install_fastfetch_theme && all_done=true
    fi
  else
    echo ""
    warn "No saved Powerlevel10k config - Steps 2 and 3 skipped."
  fi

  # ---- Finish --------------------------------------------------------------
  echo ""
  if $all_done; then
    ok "All steps complete. Open Ghostty to see your prompt and the Apple logo."
  else
    warn "NEXT:"
    echo "  1. Open Ghostty and complete the Powerlevel10k wizard."
    echo "  2. Run this script again and answer N to the reset question - it will"
    echo "     install the Apple-logo fastfetch theme."
    echo ""
    info "Tip: save your finished ~/.p10k.zsh as p10k.zsh (in ~/scripts or this repo)"
    info "so the next Mac is fully automatic."
  fi
  echo ""
  if ask "Open Ghostty now? (y/N): "; then
    open -a Ghostty
  fi
}

# Set INSTALL_GT_NO_MAIN=1 to source this file (e.g. for testing) without running it.
[[ -n "${INSTALL_GT_NO_MAIN:-}" ]] || main "$@"
