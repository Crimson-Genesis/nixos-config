{pkgs, ...}: {
  programs.alacritty = {
    enable = true;

    settings = {
      terminal = {
        shell = {
          program = "${pkgs.zsh}/bin/zsh";
        };

        osc52 = "CopyPaste";
      };

      cursor = {
        blink_interval = 500;
        unfocused_hollow = false;
        thickness = 0.15;

        style = {
          blinking = "On";
          shape = "Block";
        };
      };

      selection = {
        save_to_clipboard = true;
      };

      window = {
        opacity = 0.9;
        startup_mode = "Maximized";
        decorations = "none";
        dynamic_title = true;
        dynamic_padding = true;

        padding = {
          x = 15;
          y = 10;
        };
      };

      font = {
        size = 6.0;
      };

      scrolling = {
        history = 10000;
        multiplier = 3;
      };

      bell = {
        animation = "Linear";
        duration = 0;
      };

      colors = {
        primary = {
          background = "#000000";
        };

        transparent_background_colors = true;
        draw_bold_text_with_bright_colors = true;
      };

      mouse = {
        hide_when_typing = true;
      };

      keyboard.bindings = [
        {
          key = "J";
          mods = "Alt|Shift";
          action = "ScrollLineDown";
        }
        {
          key = "K";
          mods = "Alt|Shift";
          action = "ScrollLineUp";
        }
        {
          key = "V";
          mods = "Alt";
          action = "ToggleViMode";
        }
        {
          key = "Space";
          mods = "Control|Shift";
          action = "None";
        }
        {
          key = "F12";
          mods = "Super";
          action = "None";
        }
      ];
    };
  };
  xdg.configFile."alacritty/font.toml".source = ./fonts.toml;
  xdg.configFile."alacritty/tokyo-night.toml".source = ./tokyo-night.toml;
}
