{config, ...}: {
  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    contrastOpacity=188
    disabledTrayIcon=true
    saveAsFileExtension=jpeg
    savePath=${config.home.homeDirectory}/Downloads
    uiColor=#670086
  '';
}
