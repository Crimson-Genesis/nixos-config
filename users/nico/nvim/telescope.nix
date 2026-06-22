{...}: {
  programs.nvf.settings.vim.telescope = {
    enable = true;

    setupOpts = {
      defaults = {
        vimgrep_arguments = [
          "rg"
          "--no-heading"
          "--with-filename"
          "--line-number"
          "--column"
          "--smart-case"
          "--no-ignore"
        ];
      };

      pickers = {
        find_files.find_command = [
          "rg"
          "--files"
          "--hidden"
          "--no-ignore"
          "--max-depth=6"
        ];
      };
    };
  };
}
