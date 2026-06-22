{...}: {
  programs.nvf.settings.vim.keymaps = [
    # other
    {
      key = "<leader>vv";
      mode = "n";
      action = "<cmd>CsvViewToggle<CR>";
      silent = true;
    }
    {
      key = "<leader>as";
      mode = "n";
      action = "<cmd>ggVG<CR>";
      silent = true;
    }

    {
      key = "<leader>ay";
      mode = "n";
      action = "<cmd>normal! maggVGy`a<CR>";
      silent = true;
    }

    # Splits
    {
      key = "<leader>ss";
      mode = "n";
      action = "<cmd>sp<CR>";
      silent = true;
    }

    {
      key = "<leader>sv";
      mode = "n";
      action = "<cmd>vsp<CR>";
      silent = true;
    }

    {
      key = "<leader>wc";
      mode = "n";
      action = "<cmd>close<CR>";
      silent = true;
    }

    # Window navigation
    {
      key = "<leader>wh";
      mode = "n";
      action = "<cmd>wincmd h<CR>";
      silent = true;
    }

    {
      key = "<leader>wj";
      mode = "n";
      action = "<cmd>wincmd j<CR>";
      silent = true;
    }

    {
      key = "<leader>wk";
      mode = "n";
      action = "<cmd>wincmd k<CR>";
      silent = true;
    }

    {
      key = "<leader>wl";
      mode = "n";
      action = "<cmd>wincmd l<CR>";
      silent = true;
    }

    # Center cursor
    {
      key = "G";
      mode = ["n" "v"];
      action = "Gzz";
      silent = true;
    }

    # Lazy
    {
      key = "<leader>pl";
      mode = "n";
      action = "<cmd>Lazy<CR>";
      silent = true;
    }

    # Delete all
    {
      key = "<leader>da";
      mode = "n";
      action = "GVggd";
      silent = true;
    }

    # Select all
    {
      key = "<leader>sa";
      mode = ["n" "v"];
      action = "ggVG";
      silent = true;
    }

    # Clipboard
    {
      key = "yy";
      mode = "n";
      action = "V\"+y";
      silent = true;
    }

    {
      key = "y";
      mode = "v";
      action = "\"+y";
      silent = true;
    }

    {
      key = "yiw";
      mode = "n";
      action = "\"+yiw";
      silent = true;
    }

    {
      key = "Y";
      mode = "n";
      action = "v$\"+y";
      silent = true;
    }

    {
      key = "P";
      mode = "n";
      action = "Vp";
      silent = true;
    }

    # Delete word
    {
      key = "<M-BS>";
      mode = "n";
      action = "diw";
      silent = true;
    }

    # Wrap toggle
    {
      key = "<leader>tw";
      mode = "n";
      action = "<cmd>set wrap!<CR>";
      silent = true;
    }

    # Quickfix
    {
      key = "<M-n>";
      mode = "n";
      action = "<cmd>cnext<CR>zz";
      silent = true;
    }

    {
      key = "<M-p>";
      mode = "n";
      action = "<cmd>cprev<CR>zz";
      silent = true;
    }

    {
      key = "<leader>qn";
      mode = "n";
      action = "<cmd>cnewer<CR>";
      silent = true;
    }

    {
      key = "<leader>qp";
      mode = "n";
      action = "<cmd>colder<CR>";
      silent = true;
    }

    # Ctrl-C -> Escape
    {
      key = "<C-c>";
      mode = "";
      action = "<Esc>";
      silent = true;
    }

    # Resize
    {
      key = "<leader>sk";
      mode = "n";
      action = "<cmd>resize +5<CR>";
      silent = true;
    }

    {
      key = "<leader>sj";
      mode = "n";
      action = "<cmd>resize -5<CR>";
      silent = true;
    }

    {
      key = "<leader>sh";
      mode = "n";
      action = "<cmd>vertical resize +5<CR>";
      silent = true;
    }

    {
      key = "<leader>sl";
      mode = "n";
      action = "<cmd>vertical resize -5<CR>";
      silent = true;
    }

    # Telescope
    {
      key = "<leader>pf";
      mode = "n";
      action = "<cmd>Telescope find_files<CR>";
      silent = true;
    }

    {
      key = "<leader>pg";
      mode = "n";
      action = "<cmd>Telescope live_grep<CR>";
      silent = true;
    }

    {
      key = "<leader>fb";
      mode = "n";
      action = "<cmd>Telescope buffers<CR>";
      silent = true;
    }

    {
      key = "<leader>fh";
      mode = "n";
      action = "<cmd>Telescope help_tags<CR>";
      silent = true;
    }

    {
      key = "<leader>fc";
      mode = "n";
      action = "<cmd>Telescope commands<CR>";
      silent = true;
    }

    {
      key = "<leader>fk";
      mode = "n";
      action = "<cmd>Telescope keymaps<CR>";
      silent = true;
    }

    {
      key = "<leader>fd";
      mode = "n";
      action = "<cmd>Telescope diagnostics<CR>";
      silent = true;
    }

    {
      key = "<leader>fq";
      mode = "n";
      action = "<cmd>Telescope quickfix<CR>";
      silent = true;
    }

    {
      key = "<leader>fg";
      mode = "n";
      action = "<cmd>Telescope git_status<CR>";
      silent = true;
    }

    {
      key = "<leader>z";
      mode = "n";
      action = "<cmd>Telescope spell_suggest<CR>";
      silent = true;
    }

    {
      key = "<leader>nm";
      mode = "n";
      action = "<cmd>Telescope notify<CR>";
      silent = true;
    }

    {
      key = "<leader>fm";
      mode = "n";
      action = "<cmd>Telescope man_pages<CR>";
      silent = true;
    }

    {
      key = "<leader>fM";
      mode = "n";
      action = "<cmd>Telescope marks<CR>";
      silent = true;
    }

    # Trouble
    {
      key = "<leader>xx";
      mode = "n";
      action = "<cmd>Trouble diagnostics toggle<CR>";
      silent = true;
    }

    {
      key = "<leader>xX";
      mode = "n";
      action = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>";
      silent = true;
    }

    {
      key = "<leader>cs";
      mode = "n";
      action = "<cmd>Trouble symbols toggle focus=false<CR>";
      silent = true;
    }

    {
      key = "<leader>cl";
      mode = "n";
      action = "<cmd>Trouble lsp toggle focus=false win.position=right<CR>";
      silent = true;
    }

    {
      key = "<leader>xL";
      mode = "n";
      action = "<cmd>Trouble loclist toggle<CR>";
      silent = true;
    }

    {
      key = "<leader>xQ";
      mode = "n";
      action = "<cmd>Trouble qflist toggle<CR>";
      silent = true;
    }

    # Session
    {
      key = "<leader>wr";
      mode = "n";
      action = "<cmd>SessionSearch<CR>";
      silent = true;
    }

    {
      key = "<leader>ws";
      mode = "n";
      action = "<cmd>SessionSave<CR>";
      silent = true;
    }

    {
      key = "<leader>wa";
      mode = "n";
      action = "<cmd>SessionToggleAutoSave<CR>";
      silent = true;
    }

    # Mason
    {
      key = "<leader>pm";
      mode = "n";
      action = "<cmd>Mason<CR>";
      silent = true;
    }

    # Notify
    {
      key = "<leader>nd";
      mode = "n";
      action = "<cmd>lua require('notify').dismiss()<CR>";
      silent = true;
    }

    # Markdown
    {
      key = "<leader>md";
      mode = "n";
      action = "<cmd>RenderMarkdown toggle<CR>";
      silent = true;
    }
  ];
}
