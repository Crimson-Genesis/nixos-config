{pkgs, ...}: {
  programs.rofi = {
    enable = true;

    plugins = with pkgs; [
      rofi-calc
      rofi-nerdy
    ];
    theme = ./theam.rasi;
  };

  xdg.configFile."rofi/theam.rasi".source = ./theam.rasi;
}
