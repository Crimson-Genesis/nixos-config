{
  config,
  pkgs,
  inputs,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ./keyd.nix
    ./nvidia.nix
    # ./sddm.nix
  ];

  boot = {
    loader = {
      efi.canTouchEfiVariables = true;
      timeout = 5;
      systemd-boot = {
        enable = true;
        configurationLimit = 20;
        editor = false;
      };
    };
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "loglevel=0"
      "rd.systemd.show_status=false"
      "systemd.show_status=false"
      "vt.global_cursor_default=0"
      "8250.nr_uarts=0"
    ];
  };

  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/5a1c47d1-6160-4000-ad22-d5418bf7e56a";
    fsType = "ext4";
  };

  networking.hostName = "nixos";
  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Kolkata";

  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  programs = {
    zsh = {
      enable = true;
    };
    dconf = {
      enable = true;
    };
    thunar = {
      enable = true;
    };
    xfconf = {
      enable = true;
    };
  };

  services = {
    blueman = {
      enable = true;
    };

    gvfs = {
      enable = true;
    };

    tumbler = {
      enable = true;
    };

    libinput = {
      enable = true;
      touchpad = {
        tapping = true;
        naturalScrolling = true;
      };
    };

    displayManager = {
      # sddm = {
      #   enable = true;
      #   package = pkgs.kdePackages.sddm;
      #   theme = "sddm-astronaut-theme";
      # };
      ly = {
          enable = true;
	  settings = {
	  animate = true;
	  animation = "matrix";
	  clock = "%c";
	  hide_borders = true;
	  };
      };
    };

    picom = {
      enable = true;
      vSync = true;
      settings = {
        unredir-if-possible = true;
        dithered-shadow = true;
        active-opacity = 1.0;
        inactive-opacity = 0.85;
        frame-opacity = 1.0;
        inactive-dim = 0.0;
        backend = "glx";
        opacity-rule = [
          "100:class_g = 'Gimp'"
          "100:class_g = 'Krita'"
          "100:class_g = 'firefox'"
          "100:class_g = 'Inkscape'"
          "100:class_g = 'rnote'"
        ];
      };
    };

    xserver = {
      enable = true;
      desktopManager.xfce.enable = false;
      windowManager.xmonad = {
        enable = true;
        enableContribAndExtras = true;
        extraPackages = hPkgs: [hPkgs.xmonad hPkgs.xmonad-contrib];
      };
      xkb = {
        layout = "us";
        variant = "";
      };
    };
  };

  xdg.portal = {
    enable = true;

    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  users.users."nico" = {
    isNormalUser = true;
    description = "nico";
    shell = pkgs.zsh;
    extraGroups = ["networkmanager" "wheel"];
  };

  nixpkgs.config.allowUnfree = true;

  security = {
    pam.services.i3lock = {
      enable = true;
    };
    polkit = {
      enable = true;
    };
  };

  environment.systemPackages = with pkgs; [
    feh
    file
    binutils
    mpvpaper
    hsetroot
    # kdePackages.sddm
    # sddm-astronaut
    kdePackages.qtmultimedia

    net-tools
    alacritty
    picom
    ghc

    haskell-language-server
    cabal-install
    xclip
    tmux

    mpv
    brightnessctl
    dunst
    libnotify
    qbittorrent
    pciutils
    steam-run
    nvtopPackages.nvidia
    neovim
    yad

    lua-language-server
    clang-tools
    rust-analyzer
    pyright
    gopls
    asm-lsp

    python3
    nodejs
    rustc
    cargo
    tree
    toipe
    pavucontrol

    adwaita-icon-theme
    gnome-themes-extra
    papirus-icon-theme
    bibata-cursors

    wmctrl

    hlint
    betterlockscreen
    bc
    jq
    playerctl
    ffmpeg
    tailscale
    screenkey
    pamixer
    libnotify
    blueman
    polkit_gnome
    ngrok
    xwininfo

    qt6Packages.qt6ct
    qt6Packages.qtstyleplugin-kvantum

    inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default

    (writeShellScriptBin "rofi-man" (builtins.readFile ./scripts/rofi-man.sh))
    (writeShellScriptBin "toipe-toggle" (builtins.readFile ./scripts/toipe-toggle.sh))
    (writeShellScriptBin "screenkey-toggle" (builtins.readFile ./scripts/screenkey-toggle.sh))
    (writeShellScriptBin "toggle_btop_nvtop" (builtins.readFile ./scripts/toggle_btop_nvtop.sh))
    (writeShellScriptBin "vol_brigh_control" (builtins.readFile ./scripts/vol_brigh_control.sh))
    (writeShellScriptBin "rofi-search" (builtins.readFile ./scripts/rofi-search.sh))
    (writeShellScriptBin "rofi-tmux" (builtins.readFile ./scripts/rofi-tmux.sh))
  ];

  qt = {
    enable = true;
    platformTheme = "qt5ct";
    style = "adwaita-dark";
  };

  environment.sessionVariables = {
    GTK_THEME = "Adwaita-dark";
    QT_QPA_PLATFORMTHEME = "qt5ct";
  };

  fonts.packages = with pkgs; [
    nerd-fonts.jetbrains-mono
    noto-fonts-color-emoji
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  hardware = {
    bluetooth.enable = true;
    opentabletdriver.enable = true;
  };

  system.stateVersion = "26.05";
}
