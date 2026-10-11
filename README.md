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
7. **Install [Fastfetch](https://github.com/fastfetch-cli/fastfetch)** via Homebrew. It is *not* run automatically on new shells (see below) — run it manually any time with `fastfetch`.

All installs run in verbose mode, and a `===> Step X/6` banner marks progress through each stage.

The script backs up any existing `~/.zshrc` and Ghostty config (with a timestamp suffix) before making changes, and is safe to re-run — it skips anything already installed.

### Optional: run fastfetch automatically on every new terminal

By default fastfetch is just installed, not wired into `.zshrc`. If you'd like it to run automatically every time you open a new terminal — with an Apple-logo themed layout — run:

```bash
chmod +x enable-fastfetch.sh
./enable-fastfetch.sh
```

Or run it directly from GitHub without cloning the repo — since it depends on the binary `fastfetch-apple.tar.gz` sitting next to it, this needs two quick downloads rather than a single piped one-liner:

```bash
curl -fsSL -o enable-fastfetch.sh https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/enable-fastfetch.sh
curl -fsSL -o fastfetch-apple.tar.gz https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/fastfetch-apple.tar.gz
chmod +x enable-fastfetch.sh
./enable-fastfetch.sh
```

This must be run from the same folder as `fastfetch-apple.tar.gz`. It will:

- Install fastfetch via Homebrew if it isn't already installed.
- Extract `fastfetch-apple.tar.gz` to `~/.config/fastfetch/` — fastfetch's default config location — including the `assets/` subfolder and its `apple.png` logo, which the bundled `config.jsonc` references directly. Any existing `config.jsonc` is backed up first.
- Insert `fastfetch` as the literal first line of `~/.zshrc`.

Run it any time after `setup-ghostty-terminal.sh` has finished — ideally after Powerlevel10k's `p10k configure` wizard has already run once (it launches automatically the first time you open Ghostty), so nothing gets inserted above it afterward and it stays at the top for good.

This was previously wired in automatically during setup, but Powerlevel10k's first-run configuration wizard rewrites `.zshrc` to insert its own instant-prompt block at the very top of the file, which reliably undid that ordering and caused warnings (and, in one case, a corrupted `.zshrc`). Making it an opt-in manual step avoids that fragility entirely.

### Not installed

`bat`, `eza`, and `zoxide` are intentionally **not** installed by this script (unlike the source walkthrough), so the terminal is left running the default `cat`, `ls`, and `cd`.

## Usage

Run directly from GitHub, no cloning needed:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/setup-ghostty-terminal.sh | bash
```

Or download it first if you'd rather review it before running:

```bash
curl -fsSL -o setup-ghostty-terminal.sh https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/setup-ghostty-terminal.sh
chmod +x setup-ghostty-terminal.sh
./setup-ghostty-terminal.sh
```

After it finishes:

1. Quit and reopen Ghostty (or open it for the first time) to pick up the new config.
2. Open a new Ghostty terminal — the Powerlevel10k configuration wizard launches automatically on first prompt load. Run `p10k configure` any time afterward to redo it.

If you installed an earlier version of this script that did add fastfetch to `.zshrc` automatically, run `revert-fastfetch-zshrc.sh` once to strip that out cleanly, then optionally use `enable-fastfetch.sh` (see above) if you still want it running automatically.

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

## Direct Installation from GitHub

One command does everything — Ghostty, Oh My Zsh, Powerlevel10k, and the Apple-logo fastfetch theme — straight from this repo, no cloning needed:

```bash
curl -fsSL https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/install-ghostty-terminal.sh | bash
```

This is `install-ghostty-terminal.sh`, a guided installer that walks through the whole thing for you:

- Confirms what it's about to do before touching anything.
- Installs Ghostty, Oh My Zsh, and Powerlevel10k (Step 1).
- If a saved Powerlevel10k config is found (see below), restores it to `~/.p10k.zsh` so the **first-run configuration wizard is skipped entirely** (Step 2), then installs the Apple-logo fastfetch theme (Step 3) — fully automatic, start to finish.
- If no saved config is found, it installs Ghostty/Oh My Zsh/Powerlevel10k, then tells you to open Ghostty, complete the Powerlevel10k wizard by hand, and run the command again — it detects what's already done and finishes the fastfetch theme for you.
- If Ghostty is already installed, it offers a full **reset**: everything (`~/.zshrc`, `~/.p10k.zsh`, `~/.oh-my-zsh`, `~/.config/ghostty`) is moved — never deleted — to a timestamped backup folder before reinstalling. Requires typing `YES` to confirm.

Prompts are read directly from the terminal, so the piped `curl | bash` form above works fine interactively.

![Ghostty terminal with the Apple-logo fastfetch theme](terminal-macbook.png)

### Saving your Powerlevel10k config (optional, recommended)

Powerlevel10k's wizard asks the same style questions every time, and a `.zshrc` copied between Macs is unreliable (different usernames, different installed pieces). The fix is to save just `~/.p10k.zsh` — it's portable and has no secrets — as `p10k.zsh` in this repo (or in `~/scripts/p10k.zsh` locally, or point `$P10K_CONFIG` at it). Once that's there, `install-ghostty-terminal.sh` finds it automatically and every future Mac skips the wizard completely.

```bash
cp ~/.p10k.zsh /path/to/this/repo/p10k.zsh
```

Then push it up with `push-to-github.sh` like any other file in this repo.

### Manual installation (step by step)

If you'd rather run each part yourself instead of the guided installer above:

**1. Install Ghostty, Oh My Zsh, and Powerlevel10k:**

```bash
curl -fsSL https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/setup-ghostty-terminal.sh | bash
```

Once that finishes, close the default macOS Terminal app and open **Ghostty** instead. The Powerlevel10k configuration wizard will launch automatically the first time you open a new Ghostty window — complete the wizard's on-screen questions to set up your prompt style.

**2. Once the wizard is done, install the Apple-logo fastfetch theme:**

```bash
curl -fsSL -o enable-fastfetch.sh https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/enable-fastfetch.sh
curl -fsSL -o fastfetch-apple.tar.gz https://raw.githubusercontent.com/andrewpayne68/macos-terminal/main/fastfetch-apple.tar.gz
chmod +x enable-fastfetch.sh
./enable-fastfetch.sh
```

Open a new Ghostty window/tab afterward to see the Apple logo and system summary on every new terminal.

## Credit

Setup steps adapted from [andrewpayne68/macos-terminal-oh-my-ghostty](https://github.com/andrewpayne68/macos-terminal-oh-my-ghostty), itself forked from [sudo-conner/oh-my-ghostty](https://github.com/sudo-conner/oh-my-ghostty).
