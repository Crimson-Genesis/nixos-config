{...}: {
  services.keyd = {
    enable = true;

    keyboards.default = {
      ids = ["*"];

      settings = {
        main = {
          # capslock = "overload(nav, capslock)";
          capslock = "layer(nav)";
        };

        nav = {
          h = "left";
          j = "down";
          k = "up";
          l = "right";

          b = "home";
          e = "end";

          u = "pageup";
          d = "pagedown";

          n = "C-left";
          m = "C-right";
        };
      };
    };
  };
}
