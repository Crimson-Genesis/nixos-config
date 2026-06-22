{pkgs, ...}: {
  programs.nvf.settings.vim.extraPlugins.recorder = {
    package = pkgs.vimPlugins.nvim-recorder;

    setup = ''
      require("recorder").setup({
        slots = { "a", "s", "d", "f" },

        mapping = {
          startStopRecording = "q",
          playMacro = "Q",
          switchSlot = "<C-q>",
          editMacro = "cq",
          deleteAllMacros = "dq",
          yankMacro = "yq",
          addBreakPoint = "##",
        },

        clear = true,

        logLevel = vim.log.levels.INFO,

        lessNotifications = false,

        useNerdfontIcons = true,

        performanceOpts = {
          countThreshold = 100,
          lazyredraw = true,
          noSystemClipboard = true,

          autocmdEventsIgnore = {
            "TextChangedI",
            "TextChanged",
            "InsertLeave",
            "InsertEnter",
            "InsertCharPre",
          },
        },

        dapSharedKeymaps = false,
      })
    '';
  };
}
