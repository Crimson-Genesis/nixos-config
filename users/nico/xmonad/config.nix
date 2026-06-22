{
  xsession.windowManager.xmonad = {
    enable = true;
    enableContribAndExtras = true;
    extraPackages = hPkgs: [hPkgs.xmobar hPkgs.xmonad hPkgs.xmonad-contrib];
  };
  xdg.configFile."xmonad".source = ./config;
}
