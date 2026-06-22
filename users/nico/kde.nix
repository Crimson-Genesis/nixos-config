{pkgs, ...}: {
  xdg.configFile."kdeglobals".text = ''
    [General]
    ColorScheme=BreezeDark
    Name=Breeze Dark
  '';
  home.file.".local/share/color-schemes/BreezeDark.colors".source = "${pkgs.kdePackages.breeze}/share/color-schemes/BreezeDark.colors";
}
