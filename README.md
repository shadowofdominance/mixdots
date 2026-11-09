# mixdots

Wayland dotfiles for **three window managers in one repo**: [Sway](https://swaywm.org), [Mango](https://github.com/mangowm/mango) and [Niri](https://github.com/YaLTeR/niri). Pick one, or install all three and switch from your login screen.

Everything is managed with [GNU Stow](https://www.gnu.org/software/stow/), so your configs live in this repo and are symlinked into `~/.config`. Edit a config normally and the change shows up in `git status`.

> **Heads up:** the **keybinds are personal**. They match how I work, not a sensible default, so read them before you rely on them. See [Keybinds](#keybinds-are-personal).

<!-- Add screenshots here, e.g. ![Mango](screenshots/mango.png) -->

## What's included

| Folder | What it configures |
|---|---|
| `sway/` | Sway compositor |
| `mango/` | Mango compositor |
| `niri/` | Niri compositor |
| `quickshell/` | Quickshell widgets/bar |
| `noctalia/` | Noctalia shell |
| `alacritty/` | Alacritty terminal (main) |
| `kitty/` | Kitty terminal (occasional use) |
| `rofi/` | Rofi launcher |
| `nvim/` | Neovim |
| `zsh/` | `.zshrc` (uses Oh My Zsh) |
| `fastfetch/` | Fastfetch |
| `scripts/` | Helper scripts in `~/.local/bin`, including a `screenshot` script that works on Sway, Hyprland and Mango |

Each folder mirrors the paths under your home directory (for example `mango/.config/mango/config.conf` becomes `~/.config/mango/config.conf`).

## Quick install

```bash
git clone https://github.com/shadowofdominance/mixdots.git ~/mixdots
cd ~/mixdots
chmod +x install.sh
./install.sh
```

The script asks which window managers you want, installs packages, and links the configs. Useful options:

```bash
./install.sh --wm mango            # only Mango (also: sway, niri, or sway,niri)
./install.sh --wm all -y           # everything, no questions
./install.sh --link-only           # only symlink configs, install nothing
./install.sh --dry-run             # show what would happen, change nothing
./install.sh --help
```

**Your existing configs are not deleted.** Anything that would be overwritten is moved to `~/.dotfiles-backup/<timestamp>/`.

### What the script does and doesn't do

| Distro | Packages | Sway | Niri | Mango |
|---|---|---|---|---|
| Debian / Ubuntu | apt | from apt | not in repos; build it ([guide](https://github.com/YaLTeR/niri/wiki/Getting-Started)) | built from source (wlroots + scenefx + mango) |
| Arch | pacman | from pacman | from pacman | install manually ([guide](https://github.com/mangowm/mango/wiki/installation)) |
| Fedora | dnf | from dnf | from dnf | install manually ([guide](https://github.com/mangowm/mango/wiki/installation)) |

- **Quickshell and Noctalia are not installed by the script.** It links their configs, but you need to install the programs yourself from their official docs.
- Package names differ between distros and releases. If one fails, the script warns and continues, so install anything it missed by hand.
- The Mango build pins specific wlroots and scenefx versions at the top of `install.sh`. These change over time, so check the [Mango install guide](https://github.com/mangowm/mango/wiki/installation) if the build fails.
- Mango and Niri don't need to be installed to use the others. Choose only the WMs you want with `--wm`.

## Manual install

If you'd rather not run the script:

```bash
sudo apt install git stow jq curl zsh neovim alacritty rofi fastfetch thunar grim slurp wl-clipboard libnotify-bin wlr-randr
cd ~/mixdots
stow alacritty rofi nvim fastfetch zsh scripts   # shared configs
stow mango                                      # and/or sway, niri
```

Stow refuses to overwrite files that already exist, so move or delete a conflicting `~/.config/<app>` first.

To remove a package's links: `stow -D <name>`.

## Keybinds are personal

I use these configs daily, and the keybinds are tuned to my habits and my keyboard. Before first use, open your compositor's config and read the bindings:

| WM | Config file |
|---|---|
| Sway | `~/.config/sway/config` |
| Mango | `~/.config/mango/config.conf` |
| Niri | `~/.config/niri/config.kdl` |

Change them freely. They are plain text, and because the files are symlinked, your edits are tracked by git.

Also here are some common keybinds across all three wms:

| **Keybind** | **Function** |
|---|---|
| **SUPER+Return** | Spawns terminal(alacritty by default) |
| **SUPER+Q** | Quits selected window |
| **SUPER+SHIFT+E** | Exits current session |

And here are some quick commands for configuration(if you used my .zshrc)

| **Command** | **Function** |
|---|---|
| **zshconf** | Opens .zshrc configuration inside neovim |
| **niriconf** | Opens niri configuration inside neovim |
| **mangoconf** | Opens mango configuration inside neovim |
| **swayconf** | Opens sway configuration inside neovim |

For more commands run zshconf you will find aliases at the end of the .zshrc

## Set up your monitors

Monitor setup is machine-specific, so edit it for your hardware. Run `wlr-randr` inside a session to get output names (like `eDP-1` or `HDMI-A-1`), then set them in your WM config.

**Mango** (`~/.config/mango/config.conf`):

```ini
monitorrule=name:eDP-1,width:1920,height:1080,refresh:60,x:0,y:0
monitorrule=name:HDMI-A-1,width:2560,height:1440,refresh:144,x:1920,y:0
```

Avoid negative coordinates in Mango (a known XWayland bug); start at `0,0` and extend into positive values.

**Sway** (`~/.config/sway/config`):

```
output eDP-1 resolution 1920x1080 position 0,0
```

**Niri** (`~/.config/niri/config.kdl`) has an `output "name" { ... }` block; see the [Niri docs](https://github.com/YaLTeR/niri/wiki) for the options.

## Screenshots

`scripts/.local/bin/screenshot` takes `full`, `window` and `region` screenshots, saves them to `~/Pictures/Screenshots`, and copies them to the clipboard. It needs `grim`, `slurp`, `wl-clipboard`, `jq` and `notify-send`. Window mode works on Sway, Hyprland and Mango; on other compositors it falls back to region select.

## Updating

```bash
cd ~/mixdots
git pull
stow -R <package>    # re-link a package if files were added or removed
```

## Forking and sharing

Feel free to fork, copy and remix any part of this. To make it yours:

1. Fork the repo and clone your fork.
2. Edit the configs (keybinds, colors, monitors).
3. Commit and push. Your changes are tracked because the configs are symlinked.

Before pushing, check that you haven't committed secrets such as API keys or tokens (`.zshrc` is a common place for them).

Issues and pull requests are welcome, especially fixes for other distros.

## License

Add a license file (MIT is a common choice for dotfiles) so others know how they can reuse this.

## Credits

Built on the work of the [Sway](https://swaywm.org), [Mango](https://github.com/mangowm/mango), [Niri](https://github.com/YaLTeR/niri), [Quickshell](https://quickshell.org) and Noctalia projects.
