{pkgs, ...}: {
  programs.git = {
    enable = true;
    lfs.enable = true;

    settings = {
      user = {
        name = "Crimson-genesis";
        email = "nico.zero.0x@gmail.com";
      };

      init.defaultBranch = "main";
      pull.rebase = false;
      push.autoSetupRemote = true;

      gpg.format = "openpgp";

      user.signingkey = "C648A420A50238B8";

      commit.gpgsign = true;
      tag.gpgsign = true;
    };
  };

  services.gpg-agent = {
    enable = true;
    enableSshSupport = true;
    pinentry.package = pkgs.pinentry-qt;

    defaultCacheTtl = 1800;
    maxCacheTtl = 7200;
  };
}
