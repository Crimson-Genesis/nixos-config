{config, ...}: {
  xdg.configFile."flameshot/flameshot.ini".text = ''
    [General]
    contrastOpacity=188
    disabledTrayIcon=true
    saveAsFileExtension=jpeg
    savePath=${config.home.homeDirectory}/Photos
    uiColor=#670086
  '';
}
