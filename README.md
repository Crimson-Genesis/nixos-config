# NixOS + XMonad + Rofi + Neovim: Keyboard-Centric Development Desktop

Welcome to this hyper-productive NixOS configuration. This system is designed as a distraction-free, keyboard-only environment. By combining XMonad (window manager), Rofi (dynamic menu launcher), Neovim (nvf-based editor), and Keyd (system-wide home-row layout), the configuration eliminates mouse reliance in favor of high-speed keyboard operations.

---

## Architecture Principles

1. **Keyboard First**: Every system component—including window layout, system menus, text editing, terminal navigation, and media control—is mapped to keyboard shortcuts.
2. **No Status Bar clutter**: The environment operates without status bars (like xmobar). Window states are managed dynamically through BSP or Tabbed layouts, leveraging window-swallowing to keep terminals tidy.
3. **High Input Sensitivity**: The system initializes keyboard repeat rates to `125 ms` delay and `120 Hz` repeat rate on startup for instant typing response.
4. **Semantic Workspaces**: Applications auto-route to designated workspaces, eliminating manual layout management.

---

## Core Components

### 1. XMonad Window Management
The window manager uses a borderless, tiling layout setup with window-swallowing enabled for Alacritty.

#### Window Navigation
* **`Super + h / j / k / l`**: Move focus Left, Down, Up, or Right (Vim directions).
* **`Super + Shift + h / j / k / l`**: Swap focused window Position Left, Down, Up, or Right.
* **`Super + Alt + h / j / k / l`**: Resize (Expand/Shrink) windows Left, Down, Up, or Right.
* **`Super + r`**: Rotate Binary Space Partitioning (BSP) layouts.
* **`Super + Space`**: Toggle current window between Floating and Tiled states.
* **`Super + Tab`**: Toggle between BSP and Tabbed layouts.
* **`Super + f`**: Toggle fullscreen layout (borderless).

#### Scratchpads & System Utilities
Floating workspaces are mapped to toggle hotkeys:
* **`Super + s + i`**: Toggle scratchpad terminal (floating Alacritty session).
* **`Super + s + e`**: Toggle scratchpad calculator (Qalculate).
* **`Super + [` / `Super + ]`**: Open system monitor (`btop`) or GPU monitor (`nvtop`) in terminal.
* **`Alt + S + ]`**: Toggle split overlay panel showing both `btop` and `nvtop` simultaneously.

#### Workspace Auto-Routing Rules
Workspaces are semantic-first. Applications are automatically targeted to specific layouts upon launch:

| Workspace | Workspace Name | Mapped Applications |
|:---|:---:|:---|
| 0 | ` dev ` | Alacritty (Default Terminal) |
| 1 | ` www ` | Zen Browser |
| 2 | ` sys ` | Double Commander |
| 3 | ` vid ` | MPV Media Player |
| 4 | ` pen ` | Rnote, Inkscape |
| 5 | ` studio ` | DaVinci Resolve, OBS |
| 6 | ` qbit ` | qBittorrent |
| 7 | ` mail ` | Thunderbird Email |
| 8 | ` vm ` | VirtualBox |
| 9 | ` mus ` | LibreOffice |

* **`Super + i` / `o` / `p` / `n` / `m`**: Switch focus to workspaces 0 to 4.
* **`Super + Shift + i` / `o` / `p` / `n` / `m`**: Switch focus to workspaces 5 to 9.
* **`Super + Shift + [1-9]`**: Move focused window to targeted workspace.

---

### 2. Rofi Central Command Launcher
Rofi serves as the launcher, runner, and interactive interface for custom system scripts.

#### System Menu Shortcuts
* **`Alt + Space`**: Open Application Launcher (`drun` mode)
* **`Alt + '` then `r`**: Run a terminal command
* **`Alt + '` then `w`**: Fuzzy find and switch to active windows
* **`Alt + '` then `c`**: Calculator shell
* **`Alt + '` then `m`**: View manual pages using fuzzy filter ([rofi-man.sh](file:///mnt/data/nixos-config/scripts/rofi-man.sh))
* **`Alt + '` then `s`**: Web search input query ([rofi-search.sh](file:///mnt/data/nixos-config/scripts/rofi-search.sh))
* **`Alt + '` then `e`**: Emoji picker
* **`Alt + '` then `i`**: Nerd Font character selector

#### Rofi-Tmux Terminal Workflow
My custom Tmux controller [rofi-tmux.sh](file:///mnt/data/nixos-config/scripts/rofi-tmux.sh) is mapped to quick keyboard triggers:
* **`Alt + ;` then `s`**: Create or switch Tmux sessions.
* **`Alt + ;` then `w`**: Switch windows within the active session.
* **`Alt + ;` then `k`**: Kill a running session.
* **`Alt + ;` then `S + k`**: Kill all running sessions.
* **`Alt + ;` then `e`**: Rename the active session.

---

### 3. Neovim configuration via `nvf`
Editor settings are managed programmatically via the `nvf` flake framework ([users/nico/nvim/init.nix](file:///mnt/data/nixos-config/users/nico/nvim/init.nix)):
* **Theme**: TokyoNight (Night style) with transparency enabled.
* **Autocomplete & LSP**: Blink-cmp integration providing code completion, signature-help, diagnostics, and language servers (Haskell, Lua, C/C++, Rust, Python, Go, and Assembly).
* **Navigation**: File explorer via `oil.nvim` to edit directories directly like a text buffer.
* **Tools**: Integrated `telescope` for fuzzy file matching, `trouble.nvim` for diagnostic list compilation, and `gitsigns` for git diff visualization.

---

### 4. Keyd CapsLock navigation layer
CapsLock is mapped system-wide to activate a cursor movement layer when held down, allowing home-row navigation (configured in [keyd.nix](file:///mnt/data/nixos-config/keyd.nix)):

* **`CapsLock + h` / `j` / `k` / `l`**: Cursor Left / Down / Up / Right (Vim arrows)
* **`CapsLock + b` / `e`**: Home / End
* **`CapsLock + u` / `d`**: Page Up / Page Down
* **`CapsLock + n` / `m`**: Jump left/right by whole words (`Ctrl + Left/Right`)

---

### 5. Zsh Environment
Zsh ([users/nico/zsh.nix](file:///mnt/data/nixos-config/users/nico/zsh.nix)) integrates with Starship and provides terminal binds:
* **`Alt + c`**: Fuzzy search directories with `fzf` and change shell path automatically.
* **`Alt + f`**: Launch Yazi file explorer and `cd` directly into the path on exit.
* **`Ctrl + g`**: Launch Lazygit in place.
* **`Ctrl + Space`**: Accept autocomplete suggestions.
* **Aliases**: `ls`/`lss` mapped to `eza` with icons, and `rm` mapped to `trash-cli` for safe deletion.

---

## Repository Structure

```text
nixos-config/
├── flake.nix                  # Flake entrypoint & dependency definitions
├── flake.lock                 # Lockfile for pin versions
├── configuration.nix          # Core system-wide configuration
├── hardware-configuration.nix # Hardware scan properties
├── nvidia.nix                 # Nvidia GPU graphics and PRIME offload setup
├── keyd.nix                   # CapsLock navigation layer overrides
├── sddm.nix                   # SDDM login manager with animated video theme
├── asset/                     # System assets (wallpapers, videos, login assets)
│   └── wallpapers/            # Wallpapers including the SDDM login.mp4 video
├── common/                    # Shared configurations
│   ├── git.nix
│   └── zsh.nix
├── scripts/                   # Custom utility shell scripts
└── users/                     # User directories
    └── nico/                  # Main user configurations (Home Manager modules)
        ├── default.nix        # Main Home Manager entrypoint for nico
        ├── packages.nix       # User-level packages
        ├── alacritty/         # Alacritty configuration
        ├── btop/              # Btop monitor configuration
        ├── nvim/              # Neovim (nvf) settings & plugins
        ├── rofi/              # Rofi application launcher config
        ├── tmux/              # Tmux multiplexer config
        ├── xmonad/            # XMonad custom configs & xmonad.hs
        └── zsh.nix            # User-level Zsh environment & binds
```

---

## Custom Utility Scripts
Custom system scripts located in [scripts/](file:///mnt/data/nixos-config/scripts) are built as packages during installation:

* **[rofi-man.sh](file:///mnt/data/nixos-config/scripts/rofi-man.sh)**: Fuzzy search and read manpages inside rofi.
* **[rofi-search.sh](file:///mnt/data/nixos-config/scripts/rofi-search.sh)**: Quick web and directory lookup through rofi.
* **[rofi-tmux.sh](file:///mnt/data/nixos-config/scripts/rofi-tmux.sh)**: An extensive session, window, and workflow manager for tmux controlled by rofi.
* **[screenkey-toggle.sh](file:///mnt/data/nixos-config/scripts/screenkey-toggle.sh)**: Toggles visual keyboard overlay representation.
* **[toggle_btop_nvtop.sh](file:///mnt/data/nixos-config/scripts/toggle_btop_nvtop.sh)**: Easily swap between standard resource monitor (btop) and Nvidia GPU monitor (nvtop).
* **[toipe-toggle.sh](file:///mnt/data/nixos-config/scripts/toipe-toggle.sh)**: Instantly run or toggle typing trainer games in a clean pane.
* **[vol_brigh_control.sh](file:///mnt/data/nixos-config/scripts/vol_brigh_control.sh)**: Volume and screen backlight controls with immediate visual notifications.

---

## Installation & Rebuilds

> [!CAUTION]
> This config contains custom hardware definitions (specifically Intel/Nvidia bus offsets in [nvidia.nix](file:///mnt/data/nixos-config/nvidia.nix) and disk UUIDs in [configuration.nix](file:///mnt/data/nixos-config/configuration.nix)). Ensure you verify compatibility before installing on a new machine.

To rebuild the NixOS system and apply flake configurations:

```bash
# Rebuild the system configuration using this flake
sudo nixos-rebuild switch --flake .#nixos
```

To update input pins and dependencies:

```bash
# Update flake lock dependencies
nix flake update
```
