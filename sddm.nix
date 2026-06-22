{pkgs, ...}: let
  astronautTheme =
    (pkgs.sddm-astronaut.override {
      embeddedTheme = "astronaut";

      themeConfig = {
        Background = "Backgrounds/login.mp4";

        PartialBlur = "false";
        FullBlur = "false";

        RoundCorners = "0";

        DimBackground = "0.25";

        FormPosition = "right";

        FormBackgroundColor = "#000000";
        BackgroundColor = "#000000";
        DimBackgroundColor = "#000000";

        LoginFieldBackgroundColor = "#111111";
        PasswordFieldBackgroundColor = "#111111";

        LoginFieldTextColor = "#ffffff";
        PasswordFieldTextColor = "#ffffff";

        HighlightBackgroundColor = "#404040";
        HighlightBorderColor = "#606060";

        ForceLastUser = "true";
        PasswordFocus = "true";

        HeaderText = " ";
        HideVirtualKeyboard = "true";

        DateTextColor = "#ffffff";
        TimeTextColor = "#ffffff";

        LoginButtonBackgroundColor = "#202020";
        DropdownBackgroundColor = "#111111";
        DropdownSelectedBackgroundColor = "#404040";
      };
    }).overrideAttrs (old: {
      installPhase =
        old.installPhase
        + ''
          chmod -R u+w $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds

          cp ${./asset/wallpapers/login.mp4} \
            $out/share/sddm/themes/sddm-astronaut-theme/Backgrounds/login.mp4
        '';
    });
in {
  environment.systemPackages = [
    astronautTheme
  ];
}
