{pkgs, ...}: {
  imports = [
    ./options.nix
    ./keymaps.nix
    ./lsp.nix
    ./telescope.nix
    ./git.nix
  ];
  programs.nvf = {
    enable = true;

    settings.vim = {
      theme = {
        enable = true;
        name = "tokyonight";
        style = "night";
        transparent = true;
      };

      telescope.enable = true;

      treesitter.enable = true;

      autocomplete.blink-cmp = {
        enable = true;
        setupOpts.signature.enabled = true;
      };

      diagnostics.enable = true;

      git = {
        enable = true;
        gitsigns.enable = true;
      };

      comments.comment-nvim.enable = true;

      utility = {
        oil-nvim.enable = true;
      };

      notify.nvim-notify = {
        enable = true;

        setupOpts = {
          background_colour = "NotifyBackground";
          minimum_width = 50;
          render = "compact";
          timeout = 30;
          position = "top_right";
        };
      };

      mini = {
        surround.enable = true;
        pairs.enable = true;
      };

      autocomplete.nvim-cmp.enable = false;

      extraPlugins = {
        colorizer = {
          package = pkgs.vimPlugins.nvim-colorizer-lua;
        };

        render-markdown = {
          package = pkgs.vimPlugins.render-markdown-nvim;
        };

        csvview = {
          package = pkgs.vimPlugins.csvview-nvim;
        };

        # recorder = {
        #   package = pkgs.vimPlugins.nvim-recorder;
        # };

        trouble = {
          package = pkgs.vimPlugins.trouble-nvim;
        };
      };
    };
  };
}
