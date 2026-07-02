{...}: {
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = ["*"];

      settings = {
        main = {
          capslock = "layer(nav)";
        };

        nav = {
          #
          # Navigation
          #
          h = "left";
          j = "down";
          k = "up";
          l = "right";

          #
          # Select (Shift + movement)
          #
          H = "S-left";
          J = "S-down";
          K = "S-up";
          L = "S-right";

          #
          # Word movement
          #
          n = "C-left";
          m = "C-right";

          #
          # Select by word
          #
          N = "C-S-left";
          M = "C-S-right";

          #
          # Line movement
          #
          b = "home";
          e = "end";

          #
          # Page movement
          #
          u = "pageup";
          d = "pagedown";

          #
          # Editing
          #
          i = "backspace";
          o = "delete";
          p = "enter";
          t = "tab";
          q = "esc";
          f = "insert";

          #
          # Delete words
          #
          w = "C-backspace";
          r = "C-delete";

          #
          # Clipboard
          #
          a = "C-a";
          c = "C-c";
          v = "C-v";
          x = "C-x";
          z = "C-z";
          y = "C-y";

          #
          # Common shortcuts
          #
          s = "C-s"; # Save
          "/" = "C-f"; # Find

          #
          # Browser/File navigation
          #
          "," = "A-left";
          "." = "A-right";

          #
          # Function keys
          #
          "1" = "F1";
          "2" = "F2";
          "3" = "F3";
          "4" = "F4";
          "5" = "F5";
          "6" = "F6";
          "7" = "F7";
          "8" = "F8";
          "9" = "F9";
          "0" = "F10";
        };
      };
    };
  };
}
