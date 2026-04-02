-- lua/fexptr/core.lua
--
-- Owns the explorer window + buffer lifecycle.
-- render()  rebuilds lines, applies all highlight groups, and adds
--           virtual-text for git status and LSP diagnostics.
-- toggle()  opens or closes the explorer, supporting both sidebar and
--           floating window modes.
-- start_watcher() / stop_watcher() manage the libuv fs_event watcher
--           that auto-refreshes on external filesystem changes.

local api = vim.api
local fn  = vim.fn

local config  = require("fexptr.config")
local state   = require("fexptr.state")
local tree_m  = require("fexptr.tree")
local hl      = require("fexptr.highlight")

local M  = {}
local NS = api.nvim_create_namespace("fexptr_hl")

-- --------------------------------------------------------------------------
-- Render
-- --------------------------------------------------------------------------

function M.render()
    if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end

    -- Preserve cursor
    state.cursor = api.nvim_win_get_cursor(state.win)

    -- Rebuild tree
    state.tree = tree_m.build(state.root)

    local cfg  = config.values
    local lines = {}

    -- Header
    local header = "  " .. fn.fnamemodify(state.root, ":~"):upper()
    if state.filter then
        header = header .. "  [/" .. state.filter .. "/]"
    end
    lines[1] = header

    -- Build lines and cache icon on each node
    for _, node in ipairs(state.tree) do
        local indent = string.rep("  ", node.depth)
        local icon
        if node.is_dir then
            icon = state.expanded[node.path]
                and cfg.icons.folder_open
                or  cfg.icons.folder_closed
        else
            icon = cfg.icons.file
        end
        node.icon   = icon
        lines[#lines + 1] = indent .. icon .. " " .. node.name
    end

    -- Write buffer
    api.nvim_buf_set_option(state.buf, "modifiable", true)
    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    api.nvim_buf_set_option(state.buf, "modifiable", false)

    -- ── Highlights ──────────────────────────────────────────────────────
    api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)

    -- Header
    api.nvim_buf_add_highlight(state.buf, NS, "FexptrHeader", 0, 0, -1)

    local diag_mod = require("fexptr.diagnostics")

    for i, node in ipairs(state.tree) do
        local line_nr = i   -- 0-indexed; header is line 0, nodes start at 1

        -- Selected row background (drawn first so icon/name colours win)
        if state.selection[node.path] then
            api.nvim_buf_add_highlight(state.buf, NS, "FexptrSelected", line_nr, 0, -1)
        end

        local indent_bytes = node.depth * 2           -- each level = 2 spaces
        local icon_bytes   = #node.icon               -- byte length of the icon char
        local name_start   = indent_bytes + icon_bytes + 1   -- +1 = space after icon

        -- Icon
        local icon_hl = node.is_dir and "FexptrDirIcon" or "FexptrFileIcon"
        api.nvim_buf_add_highlight(state.buf, NS, icon_hl, line_nr, indent_bytes, name_start)

        -- Name colour: diagnostics override the normal dir/file colour
        local diag     = cfg.diagnostics.enabled and diag_mod.get(node.path, node.is_dir)
        local name_hl
        if diag == "error" then
            name_hl = "FexptrDiagError"
        elseif diag == "warn" then
            name_hl = "FexptrDiagWarn"
        elseif node.is_dir then
            name_hl = "FexptrDirName"
        else
            name_hl = "FexptrFileName"
        end
        api.nvim_buf_add_highlight(state.buf, NS, name_hl, line_nr, name_start, -1)

        -- Virtual text: diagnostics icon  +  git status icon  (eol)
        local virt = {}

        if diag and cfg.diagnostics.enabled then
            local dico = cfg.icons.diagnostics[diag] or "!"
            local dhl  = hl.diag_hl[diag] or "Comment"
            table.insert(virt, { " " .. dico, dhl })
        end

        local git = cfg.git.enabled and state.git_status[node.path]
        if git then
            local gico = (cfg.icons.git_status or {})[git] or git
            local ghl  = hl.git_hl[git] or "Comment"
            table.insert(virt, { " " .. gico, ghl })
        end

        if #virt > 0 then
            api.nvim_buf_set_extmark(state.buf, NS, line_nr, 0, {
                virt_text     = virt,
                virt_text_pos = "eol",
            })
        end
    end

    -- Statusline for the explorer window
    if state.win and api.nvim_win_is_valid(state.win) then
        local sl = " " .. fn.fnamemodify(state.root, ":~")
        if state.filter then sl = sl .. "  /" .. state.filter .. "/" end
        sl = sl .. "  " .. #state.tree .. " items"
        vim.wo[state.win].statusline = sl
    end

    pcall(api.nvim_win_set_cursor, state.win, state.cursor)
end

-- --------------------------------------------------------------------------
-- Keymaps
-- --------------------------------------------------------------------------

local function setup_keymaps(buf)
    local km    = config.values.keymaps
    local a_nav = require("fexptr.actions.nav")
    local a_fs  = require("fexptr.actions.fs")

    local function map(lhs, rhs)
        if not lhs then return end
        local keys = type(lhs) == "table" and lhs or { lhs }
        for _, k in ipairs(keys) do
            vim.keymap.set("n", k, rhs, { buffer = buf, silent = true, noremap = true })
        end
    end

    map(km.open,          a_nav.open)
    map(km.create,        a_fs.create)
    map(km.rename,        a_fs.rename)
    map(km.delete,        a_fs.delete)
    map(km.copy,          function() a_fs.copy(false) end)
    map(km.cut,           function() a_fs.copy(true)  end)
    map(km.paste,         a_fs.paste)
    map(km.quit,          M.toggle)
    map(km.toggle_hidden, a_nav.toggle_hidden)
    map(km.cd,            a_nav.cd)
    map(km.parent,        a_nav.parent)
    map(km.select,        a_nav.select)
    map(km.select_all,    a_nav.select_all)
    map(km.copy_path,     a_nav.copy_path)
    map(km.copy_name,     a_nav.copy_name)
    map(km.system_open,   a_nav.system_open)
    map(km.filter,        a_nav.filter)
    map(km.clear_filter,  a_nav.clear_filter)
    map(km.refresh,       a_nav.refresh)
    map(km.preview,       a_nav.preview)

    -- Auto-preview on cursor movement (when preview.enabled = true)
    if config.values.preview.enabled then
        api.nvim_create_autocmd("CursorMoved", {
            buffer   = buf,
            callback = function()
                local row = api.nvim_win_get_cursor(0)[1]
                local node = state.tree[row - 1]
                if node then require("fexptr.preview").open(node) end
            end,
        })
    end
end

-- --------------------------------------------------------------------------
-- Toggle (open / close)
-- --------------------------------------------------------------------------

function M.toggle()
    -- ── CLOSE ───────────────────────────────────────────────────────────
    if state.win and api.nvim_win_is_valid(state.win) then
        M.stop_watcher()
        local wins = api.nvim_tabpage_list_wins(0)
        if #wins == 1 then
            -- Last window: replace buffer instead of quitting Neovim
            api.nvim_set_current_buf(api.nvim_create_buf(true, false))
        else
            api.nvim_win_close(state.win, true)
        end
        state.win = nil
        state.buf = nil
        return
    end

    -- ── OPEN ────────────────────────────────────────────────────────────
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].buftype   = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile  = false
    vim.bo[buf].filetype  = "fexptr"

    local cfg = config.values

    if cfg.float.enabled then
        -- Floating window
        local width  = math.floor(vim.o.columns * cfg.float.width)
        local height = math.floor(vim.o.lines   * cfg.float.height)
        local row    = math.floor((vim.o.lines   - height) / 2)
        local col    = math.floor((vim.o.columns - width)  / 2)

        state.win = api.nvim_open_win(buf, true, {
            relative  = "editor",
            width     = width,
            height    = height,
            row       = row,
            col       = col,
            style     = "minimal",
            border    = cfg.float.border,
            title     = " fexptr ",
            title_pos = "center",
        })
    else
        -- Sidebar
        vim.cmd("topleft " .. cfg.width .. "vsplit")
        state.win = api.nvim_get_current_win()
        api.nvim_win_set_buf(state.win, buf)
    end

    state.buf = buf

    -- Window options
    local wo = vim.wo[state.win]
    wo.number         = false
    wo.relativenumber = false
    wo.signcolumn     = "no"
    wo.wrap           = false
    wo.cursorline     = true
    wo.winfixwidth    = not cfg.float.enabled
    wo.fillchars      = "eob: "

    setup_keymaps(buf)

    -- Clean up state when the buffer is wiped externally
    api.nvim_create_autocmd("BufDelete", {
        buffer   = buf,
        once     = true,
        callback = function()
            M.stop_watcher()
            state.win = nil
            state.buf = nil
        end,
    })

    -- Start filesystem watcher and do initial render
    M.start_watcher()
    require("fexptr.git").refresh(function()
        require("fexptr.diagnostics").refresh()
        M.render()
    end)
end

-- --------------------------------------------------------------------------
-- Filesystem watcher with debounce
-- --------------------------------------------------------------------------

local _watcher      = nil
local _refresh_timer = nil

---Debounced refresh: waits 400 ms after the last fs event before re-rendering.
local function schedule_refresh()
    if _refresh_timer then
        _refresh_timer:stop()
        _refresh_timer:close()
    end
    _refresh_timer = vim.loop.new_timer()
    _refresh_timer:start(400, 0, vim.schedule_wrap(function()
        _refresh_timer:close()
        _refresh_timer = nil
        if state.buf and api.nvim_buf_is_valid(state.buf) then
            require("fexptr.git").refresh(function()
                M.render()
            end)
        end
    end))
end

function M.start_watcher()
    M.stop_watcher()
    _watcher = vim.loop.new_fs_event()
    if not _watcher then return end

    local function on_event(err)
        if err then return end
        if state.buf and api.nvim_buf_is_valid(state.buf) then
            schedule_refresh()
        else
            M.stop_watcher()
        end
    end

    -- Try recursive first (not available everywhere), fall back to flat
    local ok = pcall(function()
        _watcher:start(state.root, { recursive = true }, vim.schedule_wrap(on_event))
    end)
    if not ok then
        pcall(function()
            _watcher:start(state.root, {}, vim.schedule_wrap(on_event))
        end)
    end
end

function M.stop_watcher()
    if _watcher then
        pcall(function() _watcher:stop() end)
        _watcher = nil
    end
    if _refresh_timer then
        pcall(function()
            _refresh_timer:stop()
            _refresh_timer:close()
        end)
        _refresh_timer = nil
    end
end

return M
