{...}: {
  programs.nvf.settings.vim = {
    autocomplete.blink-cmp = {
      enable = true;
      sourcePlugins.spell.enable = true;
      setupOpts = {
        sources = {
          default = [
            "lsp"
            "snippets"
            "path"
            "buffer"
            "cmdline"
            "spell"
          ];

          per_filetype = {
            tex = [
              "omni"
              "lsp"
              "buffer"
              "path"
              "spell"
              "snippets"
            ];
            plaintex = [
              "omni"
              "lsp"
              "buffer"
              "path"
              "spell"
              "snippets"
            ];
          };

          providers.omni = {
            name = "Omni";
            module = "blink.cmp.sources.complete_func";
            score_offset = 100;
          };
        };
        keymap = {
          preset = "default";

          "<CR>" = ["accept" "fallback"];
          "<M-j>" = ["select_next" "snippet_forward" "fallback"];
          "<M-k>" = ["select_prev" "snippet_backward" "fallback"];

          "<S-k>" = ["scroll_documentation_up" "fallback"];
          "<S-j>" = ["scroll_documentation_down" "fallback"];

          "<C-Space>" = [
            "show"
            "show_documentation"
            "hide_documentation"
          ];
        };

        completion = {
          keyword.range = "full";

          documentation = {
            auto_show = true;
            auto_show_delay_ms = 100;
          };

          ghost_text.enabled = true;

          list = {
            max_items = 200;

            selection = {
              preselect = true;
              auto_insert = false;
            };

            cycle = {
              from_bottom = true;
              from_top = true;
            };
          };
        };

        cmdline = {
          enabled = true;

          keymap = {
            preset = "inherit";
          };

          completion = {
            list.selection = {
              preselect = false;
              auto_insert = true;
            };

            menu.auto_show = true;
          };
        };
      };
    };
    diagnostics = {
      enable = true;
    };

    lsp = {
      enable = true;
      formatOnSave = true;
      lightbulb.enable = true;
      trouble.enable = true;
      lspSignature.enable = false;
    };

    languages = {
      enableTreesitter = true;
      enableFormat = true;
      enableExtraDiagnostics = true;

      nix = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      bash = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      lua = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      python = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      rust = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      clang = {
        enable = true;
        lsp.enable = true;
      };

      markdown = {
        enable = true;
        lsp.enable = true;
      };

      html = {
        enable = true;
        lsp.enable = true;
      };

      css = {
        enable = true;
        lsp.enable = true;
      };

      json = {
        enable = true;
        lsp.enable = true;
      };

      yaml = {
        enable = true;
        lsp.enable = true;
      };

      typescript = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };

      tsx = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };
      haskell = {
        enable = true;
        lsp.enable = true;
      };
      tex = {
        enable = true;
        lsp.enable = true;
        format.enable = true;
      };
    };
  };
}
