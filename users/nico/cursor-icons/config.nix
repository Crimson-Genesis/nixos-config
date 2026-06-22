{pkgs, ...}: {
  home.pointerCursor = {
    name = "Acheron";
    size = 24;

    x11.enable = true;
    gtk.enable = true;

    package = pkgs.runCommand "custom-cursors" {} ''
      mkdir -p $out/share/icons
      cp -r ${./icons}/* $out/share/icons/
    '';
  };
}
