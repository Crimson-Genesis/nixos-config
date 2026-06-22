{
  xdg.configFile."picom/picom.conf".text = ''
    vsync = true;
    unredir-if-possible = true;
    dithered-shadow = true;
    active-opacity = 1.0;
    inactive-opacity = 0.85;

    frame-opacity = 1.0;
    inactive-dim = 0.0;
    backend = "glx";
    opacity-rule = [
      "100:class_g = 'Gimp'",
      "100:class_g = 'Krita'",
      "100:class_g = 'firefox'",
      "100:class_g = 'Inkscape'",
      "100:class_g = 'rnote'"
    ];
  '';
}
