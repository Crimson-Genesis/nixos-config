{
  xsession.windowManager.xmonad = {
    enable = true;
    enableContribAndExtras = true;
    extraPackages = hPkgs: [hPkgs.xmonad hPkgs.xmonad-contrib];
  };
  xdg.configFile."xmonad".source = ./config;
}
