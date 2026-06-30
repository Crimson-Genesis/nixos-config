{pkgs, ...}: {
  home.packages = with pkgs; [
    git
    git-lfs
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
    alsa-tools
    wordnet
    haskellPackages.greenclip

    alacritty
    mpv
    dunst
    qbittorrent

    papirus-icon-theme
    qalculate-gtk
    thunderbird
    android-studio
    codex

    tmux

    rofimoji

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

    # LaTeX editor / LSP
    texlab
    pstree
    texlivePackages.chktex
    texliveFull
    zathura
    pandoc
    poppler-utils
    python3Packages.python-pptx
    tesseract
  ];
}
