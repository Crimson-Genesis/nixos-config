{...}: {
  programs.nvf.settings.vim = {
    options = {
      wrap = false;

      number = true;
      relativenumber = true;

      tabstop = 4;
      shiftwidth = 4;
      softtabstop = 4;
      expandtab = true;
      smartindent = true;

      swapfile = false;
      backup = false;
      undofile = true;

      hlsearch = false;
      incsearch = true;

      termguicolors = true;

      scrolloff = 15;

      signcolumn = "yes";

      updatetime = 50;

      cursorline = true;

      splitright = true;
      splitbelow = true;

      ignorecase = true;
      smartcase = true;

      list = true;

      showmode = false;

      foldcolumn = "1";

      cmdheight = 0;
    };

    diagnostics = {
      enable = true;

      config = {
        virtual_text = false;
        update_in_insert = true;
      };
    };

    luaConfigRC.options = ''
                      vim.g.mapleader = " "

                      vim.g.loaded_netrw = 1
                      vim.g.loaded_netrwPlugin = 1

                      vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir"

                      vim.opt.cursorlineopt = "number"

                      vim.opt.isfname:append("@-@")

                      vim.g.mkdp_auto_close = 0

                      vim.g.lazydev_enabled = true

                      vim.opt.listchars = {
                         trail = "·",
                         nbsp = "␣"
                      }

                      vim.opt.breakindent = true

                      vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

                      function ColorMe()
                          vim.api.nvim_set_hl(0, "Normal", { bg = "none" })
                          vim.api.nvim_set_hl(0, "NormalFloat", { bg = "none" })
                      end

                      ColorMe()

                      vim.cmd([[
                        highlight StatusLine guibg=#000000 guifg=#d5d6db
                      ]])

                      vim.cmd([[
                        highlight StatusLineNC ctermfg=gray ctermbg=black guifg=#888888 guibg=#000000
                      ]])

                      local oil = require("oil")
                      vim.keymap.set("n", "<leader>pv", oil.toggle_float, { desc = "Open parent directory", noremap = true, silent = true })

                        local telescope = require("telescope")
                  local actions = require("telescope.actions")
                  local action_state = require("telescope.actions.state")

                  local open_help_in_vertical_split = function(prompt_bufnr)
                      local selection = action_state.get_selected_entry()
                      actions.close(prompt_bufnr)

                      if selection and selection.value then
                          vim.cmd("vert help " .. selection.value)
                      end
                  end

                  local open_man_pages_in_vertical_split = function(prompt_bufnr)
                      local selection = action_state.get_selected_entry()
                      actions.close(prompt_bufnr)

                      if selection and selection.value then
                          vim.cmd("vert Man " .. selection.value)
                      end
                  end

                  telescope.setup({
                      defaults = {
                          sorting_strategy = "descending",

                          layout_config = {
                            horizontal = {
                            prompt_position = "bottom",
                            },
                          },

                          mappings = {
                              i = {
                                  ["<M-j>"] = actions.move_selection_next,
                                  ["<M-k>"] = actions.move_selection_previous,
                                  ["<C-q>"] = actions.smart_send_to_qflist,
                                  ["<C-Q>"] = actions.smart_add_to_qflist,

                                  ["<C-s>"] = function(prompt_bufnr)
                                      local selection = action_state.get_selected_entry()
                                      if selection and selection.path then
                                          vim.fn.system("nsxiv " .. selection.path)
                                      end
                                  end,

                                  ["<M-CR>"] = actions.file_vsplit,
                              },

                              n = {
                                  ["<M-j>"] = actions.move_selection_next,
                                  ["<M-k>"] = actions.move_selection_previous,
                                  ["<C-q>"] = actions.smart_send_to_qflist,
                                  ["<C-Q>"] = actions.smart_add_to_qflist,

                                  ["<C-s>"] = function(prompt_bufnr)
                                      local selection = action_state.get_selected_entry()
                                      if selection and selection.path then
                                          vim.fn.system("nsxiv " .. selection.path)
                                      end
                                  end,

                                  ["<M-CR>"] = actions.file_vsplit,
                              },
                          },
                      },

                      pickers = {
                          help_tags = {
                              mappings = {
                                  i = {
                                      ["<CR>"] = open_help_in_vertical_split,
                                  },
                                  n = {
                                      ["<CR>"] = open_help_in_vertical_split,
                                  },
                              },
                          },

                          man_pages = {
                              mappings = {
                                  i = {
                                      ["<CR>"] = open_man_pages_in_vertical_split,
                                  },
                                  n = {
                                      ["<CR>"] = open_man_pages_in_vertical_split,
                                  },
                              },
                          },
                      },
                  })


      vim.api.nvim_create_autocmd("TextYankPost", {
          group = vim.api.nvim_create_augroup(
            "highlight_yank",
            { clear = true }
          ),
          callback = function()
            vim.hl.on_yank()
          end,
        })

          vim.opt.runtimepath:append(vim.fn.stdpath("data") .. "/site")

         require("oil").setup({
            default_file_explorer = true,
            columns = {
                "icon",
                "permissions",
                "size",
                -- "mtime",
            },
            buf_options = {
                buflisted = false,
                bufhidden = "hide",
            },
            win_options = {
                wrap = false,
                signcolumn = "no",
                cursorcolumn = false,
                foldcolumn = "0",
                spell = false,
                list = false,
                conceallevel = 3,
                concealcursor = "nvic",
            },
            delete_to_trash = true,
            skip_confirm_for_simple_edits = true,
            prompt_save_on_select_new_entry = true,
            cleanup_delay_ms = 2000,
            lsp_file_methods = {
                enabled = true,
                timeout_ms = 1000,
                autosave_changes = false,
            },
            constrain_cursor = "editable",
            watch_for_changes = false,
            keymaps = {
                ["g?"] = { "actions.show_help", mode = "n" },
                ["<CR>"] = "actions.select",
                ["<C-v>"] = { "actions.select", opts = { vertical = true } },
                ["<C-s>"] = { "actions.select", opts = { horizontal = true } },
                ["<C-t>"] = { "actions.select", opts = { tab = true } },
                ["<C-p>"] = "actions.preview",
                ["<C-c>"] = { "actions.close", mode = "n" },
                ["q"] = { "actions.close", mode = "n" },
                ["<C-l>"] = "actions.refresh",
                ["-"] = { "actions.parent", mode = "n" },
                ["_"] = { "actions.open_cwd", mode = "n" },
                ["`"] = { "actions.cd", mode = "n" },
                ["~"] = { "actions.cd", opts = { scope = "tab" }, mode = "n" },
                ["gs"] = { "actions.change_sort", mode = "n" },
                ["gx"] = "actions.open_external",
                ["."] = { "actions.toggle_hidden", mode = "n" },
                ["gt"] = { "actions.toggle_trash", mode = "n" },
            },
            use_default_keymaps = true,
            view_options = {
                show_hidden = true,
                is_hidden_file = function(name, bufnr)
                    local m = name:match("^%.")
                    return m ~= nil
                end,
                is_always_hidden = function(name, bufnr)
                    return false
                end,
                natural_order = "fast",
                case_insensitive = false,
                sort = {
                    { "type", "asc" },
                    { "name", "asc" },
                },
                highlight_filename = function(entry, is_hidden, is_link_target, is_link_orphan)
                    return nil
                end,
            },
            extra_scp_args = {},
            git = {
                add = function(path)
                    return false
                end,
                mv = function(src_path, dest_path)
                    return false
                end,
                rm = function(path)
                    return false
                end,
            },
            float = {
                padding = 2,
                max_width = 0,
                max_height = 0,
                border = "rounded",
                win_options = {
                    winblend = 0,
                },
                get_win_title = nil,
                preview_split = "auto",
                override = function(conf)
                    return conf
                end,
            },
            preview_win = {
                update_on_cursor_moved = true,
                preview_method = "fast_scratch",
                disable_preview = function(filename)
                    return false
                end,
                win_options = {},
            },
            confirmation = {
                max_width = 0.9,
                min_width = { 40, 0.4 },
                width = nil,
                max_height = 0.9,
                min_height = { 5, 0.1 },
                height = nil,
                border = "rounded",
                win_options = {
                    winblend = 0,
                },
            },
            progress = {
                max_width = 0.9,
                min_width = { 40, 0.4 },
                width = nil,
                max_height = { 10, 0.9 },
                min_height = { 5, 0.1 },
                height = nil,
                border = "rounded",
                minimized_border = "none",
                win_options = {
                    winblend = 0,
                },
            },
            ssh = {
                border = "rounded",
            },
            keymaps_help = {
                border = "rounded",
            },
        })
    '';
  };
}
