-- ==================================================
-- Neovim Dictionary Browser & Popup Integration (Lua version)
-- Load this module in Neovim: dofile("/home/nico/.config/LSD/dict.lua")
-- ==================================================

local M = {}

-- Session history state
local history = {}
local history_idx = 0
local stack_file = "/tmp/rofi-dict-word-stack"

local state = {
	win = nil,
	buf = nil,
}

-- Clear history stack file on initialization
do
	local f = io.open(stack_file, "w")
	if f then
		f:close()
	end
end

-- --------------------------------------------------
-- 1. Helper for visual selection lookup
-- --------------------------------------------------
local function get_visual_selection()
	local old_v = vim.fn.getreg("v")
	vim.cmd('normal! "vy')
	local selection = vim.fn.getreg("v")
	vim.fn.setreg("v", old_v)
	return selection
end

-- Record search in history stack
local function record_search(word)
	if not word or word == "" then
		return
	end
	word = vim.trim(word)
	if word == "" then
		return
	end

	-- Truncate forward history (grayed out)
	while #history > history_idx do
		table.remove(history)
	end

	-- Add word to history if it is different from current navigated word
	if #history == 0 or history[history_idx] ~= word then
		table.insert(history, word)
		history_idx = #history
	end

	-- Write stack to file
	local f = io.open(stack_file, "w")
	if f then
		for _, w in ipairs(history) do
			f:write(w .. "\n")
		end
		f:close()
	end
end

-- Generate colored title configuration for the window
function M.get_title_config()
	local title = {}
	table.insert(title, { " ", "Normal" })
	for i, word in ipairs(history) do
		if i > 1 then
			local sep_hl = (i <= history_idx) and "Directory" or "Comment"
			table.insert(title, { " -> ", sep_hl })
		end
		local word_hl = (i <= history_idx) and "Identifier" or "Comment"
		table.insert(title, { word, word_hl })
	end
	table.insert(title, { " ", "Normal" })
	return title
end

-- --------------------------------------------------
-- Parse popup content to build footer info
-- --------------------------------------------------
local function parse_content(lines)
	local pos_seen = {}
	local pos_order = { "Noun", "Verb", "Adjective", "Adverb" }
	local pos_short = { Noun = "noun", Verb = "verb", Adjective = "adj", Adverb = "adv" }
	local max_sense = 0

	for _, line in ipairs(lines) do
		-- Detect POS headings: ## Noun, ## Verb, etc.
		local pos = line:match("^## (%a+)")
		if pos and pos_short[pos] then
			pos_seen[pos] = true
		end
		-- Track max sense number seen (#### Sense N appears many times, find the highest N)
		local n = line:match("^#### Sense (%d+)")
		if n then
			local num = tonumber(n)
			if num and num > max_sense then
				max_sense = num
			end
		end
	end

	local pos_parts = {}
	for _, p in ipairs(pos_order) do
		if pos_seen[p] then
			table.insert(pos_parts, pos_short[p])
		end
	end

	local footer_str = ""
	if #pos_parts > 0 then
		footer_str = table.concat(pos_parts, " · ")
	end
	if max_sense > 0 then
		local sense_label = max_sense == 1 and "1 sense" or (max_sense .. " senses")
		if footer_str ~= "" then
			footer_str = footer_str .. " · " .. sense_label
		else
			footer_str = sense_label
		end
	end

	if footer_str ~= "" then
		return { { " " .. footer_str .. " ", "Comment" } }
	end
	return nil
end

-- Namespace for word highlights
local _dict_ns = vim.api.nvim_create_namespace("dict_word_hl")

-- Highlight all occurrences of the looked-up word in a buffer
local function highlight_word(buf, word)
	vim.api.nvim_buf_clear_namespace(buf, _dict_ns, 0, -1)
	if not word or word == "" then
		return
	end

	-- Build a pattern that matches whole words, case-insensitively
	local pattern = word:lower()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	for lnum, line in ipairs(lines) do
		local lower_line = line:lower()
		local search_from = 1
		while true do
			local s, e = lower_line:find(pattern, search_from, true)
			if not s then
				break
			end
			-- Only highlight if at a word boundary
			local before = s > 1 and lower_line:sub(s - 1, s - 1) or " "
			local after = e < #lower_line and lower_line:sub(e + 1, e + 1) or " "
			if not before:match("%a") and not after:match("%a") then
				vim.api.nvim_buf_set_extmark(buf, _dict_ns, lnum - 1, s - 1, {
					end_col = e,
					hl_group = "Search",
					priority = 200,
				})
			end
			search_from = e + 1
		end
	end
end

-- Generate colored winbar history statusline for the viewer window
function M.get_history_statusline()
	local parts = {}
	table.insert(parts, "%#Normal# ")
	for i, word in ipairs(history) do
		if i > 1 then
			local sep_hl = (i <= history_idx) and "Directory" or "Comment"
			table.insert(parts, "%#" .. sep_hl .. "# -> ")
		end
		local word_hl = (i <= history_idx) and "Identifier" or "Comment"
		table.insert(parts, "%#" .. word_hl .. "#" .. word)
	end
	table.insert(parts, "%#Normal# ")
	return table.concat(parts, "")
end

-- --------------------------------------------------
-- 2. Main Lookup Logic (In-place buffer swap)
-- --------------------------------------------------
function M.lookup(word, is_nav)
	if not word or word == "" then
		return
	end
	word = vim.trim(word)
	if word == "" then
		return
	end

	if not is_nav then
		record_search(word)
	end

	vim.api.nvim_echo({ { "WordNet: Looking up '" .. word .. "'...", "Normal" } }, false, {})

	local stdout_lines = {}
	vim.fn.jobstart({ "rofi-dictionary", "--dump", word }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stdout_lines, line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code == 0 and #stdout_lines > 0 then
				local file = vim.trim(stdout_lines[1])
				if file ~= "" then
					vim.cmd("echo ''")
					vim.cmd("edit! " .. vim.fn.fnameescape(file))
				end
			else
				vim.api.nvim_echo({ { "WordNet: Lookup failed for " .. word, "ErrorMsg" } }, false, {})
			end
		end,
	})
end

-- --------------------------------------------------
-- 3. Toggle between current.md and last.md
-- --------------------------------------------------
function M.toggle()
	local current_name = vim.fn.expand("%:t")
	if current_name == "current.md" then
		local last_file = "/tmp/rofi-dictionary/last.md"
		if vim.fn.filereadable(last_file) == 1 then
			vim.cmd("edit " .. vim.fn.fnameescape(last_file))
		else
			vim.api.nvim_echo({ { "WordNet: No previous lookup available", "WarningMsg" } }, false, {})
		end
	else
		vim.cmd("edit /tmp/rofi-dictionary/current.md")
	end
end

-- --------------------------------------------------
-- 4. Neovim Floating Popup Window for General Editing
-- --------------------------------------------------
function M.popup(word, is_nav)
	if not word or word == "" then
		return
	end
	word = vim.trim(word)
	if word == "" then
		return
	end

	if not is_nav then
		record_search(word)
	end

	vim.api.nvim_echo({ { "WordNet: Looking up '" .. word .. "'...", "Normal" } }, false, {})

	local stdout_lines = {}
	vim.fn.jobstart({ "rofi-dictionary", "--dump", word }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					if line ~= "" then
						table.insert(stdout_lines, line)
					end
				end
			end
		end,
		on_exit = function(_, exit_code)
			if exit_code ~= 0 or #stdout_lines == 0 then
				vim.api.nvim_echo({ { "WordNet: Lookup failed for " .. word, "ErrorMsg" } }, false, {})
				return
			end

			local file = vim.trim(stdout_lines[1])
			if file == "" or file:match("No results found") then
				vim.api.nvim_echo({ { "WordNet: No results found for " .. word, "WarningMsg" } }, false, {})
				return
			end

			-- Read file lines
			local lines = {}
			local f = io.open(file, "r")
			if f then
				for line in f:lines() do
					table.insert(lines, line)
				end
				f:close()
			end

			if #lines == 0 then
				return
			end

			vim.cmd("echo ''")

			local win_exists = state.win and vim.api.nvim_win_is_valid(state.win)
			local buf_exists = state.buf and vim.api.nvim_buf_is_valid(state.buf)

			if win_exists and buf_exists then
				-- Reuse existing popup buffer and window
				vim.api.nvim_buf_set_option(state.buf, "modifiable", true)
				vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
				vim.api.nvim_buf_set_option(state.buf, "modifiable", false)

				-- Re-highlight the new word
				highlight_word(state.buf, word)

				-- Make it responsive
				local width = math.min(150, math.floor(vim.o.columns * 0.9))
				local height = math.min(45, math.floor(vim.o.lines * 0.9))
				local row = math.floor((vim.o.lines - height) / 2)
				local col = math.floor((vim.o.columns - width) / 2)

				local footer = parse_content(lines)
				local cfg = {
					relative = "editor",
					width = width,
					height = height,
					row = row,
					col = col,
					title = M.get_title_config(),
				}
				if footer then
					cfg.footer = footer
					cfg.footer_pos = "right"
				end
				vim.api.nvim_win_set_config(state.win, cfg)
				return
			end

			-- Create new buffer
			local buf = vim.api.nvim_create_buf(false, true)
			vim.api.nvim_buf_set_option(buf, "bufhidden", "wipe")
			vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
			vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
			vim.api.nvim_buf_set_option(buf, "modifiable", false)
			state.buf = buf

			-- Highlight the searched word throughout the buffer
			highlight_word(buf, word)

			-- Calculate responsive dimensions
			local width = math.min(150, math.floor(vim.o.columns * 0.9))
			local height = math.min(45, math.floor(vim.o.lines * 0.9))
			local row = math.floor((vim.o.lines - height) / 2)
			local col = math.floor((vim.o.columns - width) / 2)

			-- Build footer from parsed content
			local footer = parse_content(lines)
			local win_cfg = {
				relative = "editor",
				width = width,
				height = height,
				row = row,
				col = col,
				style = "minimal",
				border = "rounded",
				title = M.get_title_config(),
				title_pos = "center",
			}
			if footer then
				win_cfg.footer = footer
				win_cfg.footer_pos = "right"
			end

			local win = vim.api.nvim_open_win(buf, true, win_cfg)
			state.win = win

			-- Window settings
			vim.api.nvim_win_set_option(win, "wrap", true)
			vim.api.nvim_win_set_option(win, "linebreak", true)
			vim.api.nvim_win_set_option(win, "conceallevel", 0)

			-- Local maps to close the popup
			M.setup_popup_mappings(buf)
		end,
	})
end

-- Wrapper for visual popup lookup
function M.popup_visual()
	local selection = get_visual_selection()
	M.popup(selection)
end

-- Mappings within the floating popup window
function M.setup_popup_mappings(buf)
	local opts = { buffer = buf, silent = true, noremap = true }

	-- Disable edit commands to prevent 'modifiable is off' warnings
	local normal_nop = {
		"i",
		"I",
		"a",
		"A",
		"o",
		"O",
		"gi",
		"gI",
		"<C-r>",
		".",
	}
	local visual_nop = {
		"I",
		"A",
	}
	local both_nop = {
		"c",
		"C",
		"d",
		"D",
		"x",
		"X",
		"p",
		"P",
		"s",
		"S",
		"r",
		"U",
		"J",
		"gJ",
		"~",
		"g~",
		"gu",
		"gU",
		">",
		"<",
		"=",
		"gq",
		"gw",
		"<Del>",
		"<C-a>",
		"<C-x>",
		"gc",
		"gb",
	}
	for _, key in ipairs(normal_nop) do
		vim.keymap.set("n", key, "<Nop>", opts)
	end
	for _, key in ipairs(visual_nop) do
		vim.keymap.set("x", key, "<Nop>", opts)
	end
	for _, key in ipairs(both_nop) do
		vim.keymap.set("n", key, "<Nop>", opts)
		vim.keymap.set("x", key, "<Nop>", opts)
	end

	-- <Leader>K opens prompt in the bottom to input search word recursively inside popup
	vim.keymap.set("n", "<Leader>K", function()
		vim.ui.input({ prompt = "Search word: " }, function(input)
			if input and vim.trim(input) ~= "" then
				M.popup(input)
			end
		end)
	end, opts)

	-- <Leader>k searches cursor word / selection recursively inside popup
	vim.keymap.set("n", "<Leader>k", function()
		M.popup(vim.fn.expand("<cword>"))
	end, opts)

	vim.keymap.set("x", "<Leader>k", function()
		local selection = get_visual_selection()
		M.popup(selection)
	end, opts)

	-- History navigation using u (back) and R (forward)
	local function go_back()
		if history_idx > 1 then
			history_idx = history_idx - 1
			M.popup(history[history_idx], true)
		end
	end
	vim.keymap.set("n", "u", go_back, opts)

	local function go_forward()
		if history_idx < #history then
			history_idx = history_idx + 1
			M.popup(history[history_idx], true)
		end
	end
	vim.keymap.set("n", "R", go_forward, opts)

	-- Quit popup mappings
	vim.keymap.set("n", "q", ":close<CR>", opts)
	vim.keymap.set("n", "<ESC>", ":close<CR>", opts)
end

-- --------------------------------------------------
-- 5. Buffer Local Mappings for the Full Dictionary Viewer
-- --------------------------------------------------
function M.setup_viewer()
	vim.opt_local.filetype = "markdown"
	vim.opt_local.buftype = "nowrite"
	vim.opt_local.bufhidden = "wipe"
	vim.opt_local.swapfile = false
	vim.opt_local.wrap = true
	vim.opt_local.linebreak = true
	vim.opt_local.breakindent = true
	vim.opt_local.conceallevel = 0

	-- Set local winbar to display history breadcrumbs
	vim.opt_local.winbar = M.get_history_statusline()

	local opts = { buffer = true, silent = true, noremap = true }

	-- Disable edit commands to prevent 'modifiable is off' warnings
	local normal_nop = {
		"i",
		"I",
		"a",
		"A",
		"o",
		"O",
		"gi",
		"gI",
		"<C-r>",
		".",
	}
	local visual_nop = {
		"I",
		"A",
	}
	local both_nop = {
		"c",
		"C",
		"d",
		"D",
		"x",
		"X",
		"p",
		"P",
		"s",
		"S",
		"r",
		"U",
		"J",
		"gJ",
		"~",
		"g~",
		"gu",
		"gU",
		">",
		"<",
		"=",
		"gq",
		"gw",
		"<Del>",
		"<C-a>",
		"<C-x>",
		"gc",
		"gb",
	}
	for _, key in ipairs(normal_nop) do
		vim.keymap.set("n", key, "<Nop>", opts)
	end
	for _, key in ipairs(visual_nop) do
		vim.keymap.set("x", key, "<Nop>", opts)
	end
	for _, key in ipairs(both_nop) do
		vim.keymap.set("n", key, "<Nop>", opts)
		vim.keymap.set("x", key, "<Nop>", opts)
	end

	-- <Leader>K opens prompt in the bottom to input search word recursively inside viewer
	vim.keymap.set("n", "<Leader>K", function()
		vim.ui.input({ prompt = "Search word: " }, function(input)
			if input and vim.trim(input) ~= "" then
				M.lookup(input)
			end
		end)
	end, opts)

	-- <Leader>k searches cursor word / selection recursively in viewer
	vim.keymap.set("n", "<Leader>k", function()
		M.lookup(vim.fn.expand("<cword>"))
	end, opts)

	vim.keymap.set("x", "<Leader>k", function()
		local selection = get_visual_selection()
		M.lookup(selection)
	end, opts)

	-- History navigation using u (back) and R (forward)
	local function go_back()
		if history_idx > 1 then
			history_idx = history_idx - 1
			M.lookup(history[history_idx], true)
		end
	end
	vim.keymap.set("n", "u", go_back, opts)

	local function go_forward()
		if history_idx < #history then
			history_idx = history_idx + 1
			M.lookup(history[history_idx], true)
		end
	end
	vim.keymap.set("n", "R", go_forward, opts)

	-- Toggle between current.md and last.md using "b"
	vim.keymap.set("n", "b", M.toggle, opts)

	-- Mappings to quit Neovim cleanly
	vim.keymap.set("n", "q", ":qa!<CR>", opts)
	vim.keymap.set("x", "q", "<ESC>:qa!<CR>", opts)
end

-- --------------------------------------------------
-- 6. Initialization and Auto-commands
-- --------------------------------------------------
function M.setup()
	local group = vim.api.nvim_create_augroup("DictViewer", { clear = true })
	vim.api.nvim_create_autocmd("BufReadPost", {
		group = group,
		pattern = { "**/current.md", "**/last.md" },
		callback = M.setup_viewer,
	})

	-- Apply immediately if we are already viewing the cache files
	local current_name = vim.fn.expand("%:t")
	if current_name == "current.md" or current_name == "last.md" then
		M.setup_viewer()
	end

	-- Global keybindings for popup lookup in code editing sessions
	vim.keymap.set("n", "<Leader>k", function()
		M.popup(vim.fn.expand("<cword>"))
	end, { silent = true })
	vim.keymap.set("x", "<Leader>k", M.popup_visual, { silent = true })

	-- <Leader>K in normal mode prompts at the bottom to search for typed input
	vim.keymap.set("n", "<Leader>K", function()
		vim.ui.input({ prompt = "Search word: " }, function(input)
			if input and vim.trim(input) ~= "" then
				M.popup(input)
			end
		end)
	end, { silent = true })
end

-- Auto-run setup when this module is loaded
M.setup()

return M
