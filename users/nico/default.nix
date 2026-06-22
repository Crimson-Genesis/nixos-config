{
  pkgs,
  inputs,
  ...
}: {
  imports = [
    inputs.nvf.homeManagerModules.default

    ./packages.nix
    ./alacritty/config.nix
    ./git.nix
    ./zsh.nix
    ./nvim/init.nix
    ./rofi/config.nix
    ./dunst.nix
    ./xmonad/config.nix
    ./btop/config.nix
    ./flameshot.nix
    ./htop.nix
    ./mpv/config.nix
    ./picom.nix
    ./qbittorrent/config.nix
    ./tmux/config.nix
    ./yazi/config.nix
    ./cursor-icons/config.nix
    ./doublecmd/config.nix
  ];

  home = {
    username = "nico";
    homeDirectory = "/home/nico";
    stateVersion = "26.05";
    sessionPath = [
      "$HOME/.local/bin"
    ];
  };

  programs.home-manager.enable = true;

  gtk = {
    enable = true;
    iconTheme = {
      name = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };

    theme = {
      name = "Adwaita-dark";
      package = pkgs.gnome-themes-extra;
    };
  };
}
