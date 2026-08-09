# macos-terminal

![Ghostty terminal with Powerlevel10k and fastfetch](screenshot.png)

A single script to set up a beautiful, fast macOS terminal on a brand-new Mac: **Homebrew**, **Ghostty**, **Oh My Zsh**, **Powerlevel10k**, and **Fastfetch** — configured and ready to go with no manual steps.

Based on the walkthrough in [andrewpayne68/macos-terminal-oh-my-ghostty](https://github.com/andrewpayne68/macos-terminal-oh-my-ghostty), turned into a single automated script.

## What it does

Running `setup-ghostty-terminal.sh` on a fresh Mac will:

1. **Prompt once for admin credentials** (`sudo -v`) and keep them cached for the duration of the script, so you're only asked once.
2. **Install Xcode Command Line Tools** (if missing) unattended — using the `softwareupdate` CLI instead of `xcode-select --install`, so no "Install Command Line Tools?" GUI popup appears. Falls back to the GUI popup only if the package can't be auto-detected.
3. **Install Homebrew** and set up its `PATH`/`shellenv` by adding it to `~/.zprofile`, so `brew` works correctly in every new shell on both Apple Silicon (`/opt/homebrew`) and Intel (`/usr/local`) Macs.
4. **Install [Ghostty](https://ghostty.org/)** via `brew install --cask ghostty`, and write a config to `~/.config/ghostty/config` using the **Kitty Default** theme, with a pure black background, `option+backspace` word-delete keybind, and SSH shell-integration features enabled — matching the example config from the source README.
5. **Install [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh)** non-interactively, without changing your login shell or overwriting an existing `.zshrc`.
6. **Install [Powerlevel10k](https://github.com/romkatv/powerlevel10k)** via Homebrew and wire it into `.zshrc` (sourced directly, with Oh My Zsh's `ZSH_THEME` cleared so the two don't conflict). The Powerlevel10k configuration wizard runs automatically the first time you open a new terminal.
7. **Install [Fastfetch](https://github.com/fastfetch-cli/fastfetch)** via Homebrew and add it to the very top of `.zshrc` so a system summary is shown on every new terminal session — it has to run before Oh My Zsh / Powerlevel10k's instant prompt initializes, otherwise Powerlevel10k raises a "console output during zsh initialization detected" warning.
8. **Add a one-time self-heal hook** to `.zshrc`. Powerlevel10k's first-run configuration wizard (`p10k configure`, which launches automatically the first time you open Ghostty) inserts its own instant-prompt block at the very top of `.zshrc` — above the fastfetch line — which undoes the ordering from step 7 and brings the warning back. The hook waits until that wizard has actually completed, then silently re-positions fastfetch above everything else exactly once, and never touches the file again after that.

If you ever see the "console output during zsh initialization detected" warning anyway (e.g. on an existing install from before this fix was added), run `fix-fastfetch-position.sh` once to repair it immediately - no need to wait for a new shell.

All installs run in verbose mode, and a `===> Step X/6` banner marks progress through each stage.

The script backs up any existing `~/.zshrc` and Ghostty config (with a timestamp suffix) before making changes, and is safe to re-run — it skips anything already installed.

### Not installed

`bat`, `eza`, and `zoxide` are intentionally **not** installed by this script (unlike the source walkthrough), so the terminal is left running the default `cat`, `ls`, and `cd`.

## Usage

```bash
chmod +x setup-ghostty-terminal.sh
./setup-ghostty-terminal.sh
```

After it finishes:

1. Quit and reopen Ghostty (or open it for the first time) to pick up the new config.
2. Open a new Ghostty terminal — the Powerlevel10k configuration wizard launches automatically on first prompt load. Run `p10k configure` any time afterward to redo it.

## Ghostty config used

```
theme = Kitty Default
font-size = 14
window-width = 111
window-height = 41
background-opacity = 0.9
background = #000000
keybind = option+backspace=text:\x1b\x7f
shell-integration-features = ssh-terminfo,ssh-env
confirm-close-surface = false
```

## Credit

Setup steps adapted from [andrewpayne68/macos-terminal-oh-my-ghostty](https://github.com/andrewpayne68/macos-terminal-oh-my-ghostty), itself forked from [sudo-conner/oh-my-ghostty](https://github.com/sudo-conner/oh-my-ghostty).
