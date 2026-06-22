{pkgs, ...}: {
  home.packages = with pkgs; [
    git
    wget
    fzf
    bat
    htop
    eza
    yazi
    btop
    ripgrep
    fd
    tree-sitter
    unzip
    home-manager
    neovim
    gnupg
    trash-cli
    pinentry-qt
    doublecmd

    alacritty
    mpv
    dunst
    qbittorrent

    papirus-icon-theme
    qalculate-gtk
    thunderbird

    tmux

    rofimoji
    copyq

    flameshot
    xcolor
    gcolor3
    xdotool
    audacity
    libreoffice-qt
    obs-studio
    opencode
    wireshark
    rnote
    krita
    ueberzugpp

    unrar
    p7zip

    davinci-resolve

    inkscape-with-extensions
    inkscape-extensions.hexmap
    inkscape-extensions.inkcut
    inkscape-extensions.textext
    inkscape-extensions.inkstitch
    inkscape-extensions.silhouette
    inkscape-extensions.applytransforms
  ];
}
