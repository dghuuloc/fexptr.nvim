-- lua/fexptr/core.lua

local api = vim.api
local fn  = vim.fn

local config  = require("fexptr.config")
local state   = require("fexptr.state")
local tree_m  = require("fexptr.tree")
local hl      = require("fexptr.highlight")

local M  = {}
local NS = api.nvim_create_namespace("fexptr_hl")

-- --------------------------------------------------------------------------
-- Indent / connector builder
-- --------------------------------------------------------------------------
local VERT   = "│ "   -- 3 + 1 = 4 bytes
local BLANK  = "  "   -- 2 bytes
local BRANCH = "├─ "  -- 3 + 3 + 1 = 7 bytes
local CORNER = "└─ "  -- 3 + 3 + 1 = 7 bytes

local VERT_B   = #VERT
local BLANK_B  = #BLANK
local BRANCH_B = #BRANCH
local CORNER_B = #CORNER

local function make_indent(node, cfg)
    if not cfg.indent_lines or not node.last_at then
        local s = string.rep("  ", node.depth)
        return s, #s
    end

    -- No connector for depth-0 items — they sit flush at the left margin
    -- just like nvim-tree's top-level entries.
    if node.depth == 0 then
        return "", 0
    end

    local parts      = {}
    local byte_total = 0

    -- Ancestor vertical lines (depths 0 … depth-2)
    for d = 0, node.depth - 2 do
        if node.last_at[d] then
            parts[#parts + 1] = BLANK
            byte_total = byte_total + BLANK_B
        else
            parts[#parts + 1] = VERT
            byte_total = byte_total + VERT_B
        end
    end

    -- Own connector (depth-1 level, based on this node's is_last)
    local is_last = node.last_at[node.depth]
    if is_last then
        parts[#parts + 1] = CORNER
        byte_total = byte_total + CORNER_B
    else
        parts[#parts + 1] = BRANCH
        byte_total = byte_total + BRANCH_B
    end

    return table.concat(parts), byte_total
end

-- --------------------------------------------------------------------------
-- Render
-- --------------------------------------------------------------------------

function M.render()
    if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end

    state.cursor = api.nvim_win_get_cursor(state.win)

    -- Build tree
    local raw_tree = tree_m.build(state.root)

    -- Prepend ".." entry when show_parent is on and we're not at fs root
    local cfg = config.values
    state.tree = {}
    local parent_path = fn.fnamemodify(state.root, ":h")
    if cfg.show_parent and parent_path ~= state.root then
        state.tree[1] = {
            name      = "..",
            path      = parent_path,
            depth     = 0,
            is_dir    = true,
            is_parent = true,
            last_at   = nil,
        }
    end
    for _, n in ipairs(raw_tree) do
        state.tree[#state.tree + 1] = n
    end

    -- Header line
    local header = "  " .. fn.fnamemodify(state.root, ":~"):upper()
    if state.filter then
        header = header .. "  [/" .. state.filter .. "/]"
    end
    local lines = { header }

    -- ── Build lines + collect per-node render data ─────────────────────
    -- We store indent byte lengths so the highlight pass below can slice
    -- correctly without recomputing.
    local indent_bytes_arr = {}

    for _, node in ipairs(state.tree) do
        local icon
        if node.is_parent then
            icon = " "   -- up-arrow for ".."
        elseif node.is_dir then
            icon = state.expanded[node.path]
                and cfg.icons.folder_open
                or  cfg.icons.folder_closed
            local expanded = state.expanded[node.path]
            local indicators = cfg.folder_indicators or {}
            local indicator = expanded and (indicators.open or "") or (indicators.closed or "")
            local folder_icon = expanded and (cfg.icons.folder_open or "") or (cfg.icons.folder_closed or "")
            icon = indicator .. folder_icon
        else
            icon = cfg.icons.file
        end
        node.icon = icon

        local indent_str, indent_b = make_indent(node, cfg)
        indent_bytes_arr[#indent_bytes_arr + 1] = indent_b

        lines[#lines + 1] = indent_str .. icon .. " " .. node.name
    end

    -- Write buffer
    api.nvim_buf_set_option(state.buf, "modifiable", true)
    api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
    api.nvim_buf_set_option(state.buf, "modifiable", false)

    -- ── Highlights ──────────────────────────────────────────────────────
    api.nvim_buf_clear_namespace(state.buf, NS, 0, -1)

    -- Header (line 0)
    api.nvim_buf_add_highlight(state.buf, NS, "FexptrHeader", 0, 0, -1)

    local diag_mod = require("fexptr.diagnostics")

    for i, node in ipairs(state.tree) do
        local line_nr    = i                          -- 0-indexed; header=0
        local indent_b   = indent_bytes_arr[i]
        local icon_b     = #node.icon
        local name_start = indent_b + icon_b + 1     -- +1 = space after icon

        -- Selected background
        if state.selection[node.path] then
            api.nvim_buf_add_highlight(state.buf, NS, "FexptrSelected", line_nr, 0, -1)
        end

        -- ".." parent entry
        if node.is_parent then
            api.nvim_buf_add_highlight(state.buf, NS, "FexptrParent", line_nr, 0, -1)
            goto continue
        end

        -- Indent lines (the │ ├─ └─ prefix region)
        if cfg.indent_lines and indent_b > 0 then
            api.nvim_buf_add_highlight(state.buf, NS, "FexptrIndentLine", line_nr, 0, indent_b)
        end

        -- Icon
        local icon_hl = node.is_dir and "FexptrDirIcon" or "FexptrFileIcon"
        api.nvim_buf_add_highlight(state.buf, NS, icon_hl, line_nr, indent_b, name_start)

        -- Name: diagnostics colour override → dir/file fallback
        local diag = cfg.diagnostics.enabled and diag_mod.get(node.path, node.is_dir)
        local name_hl
        if     diag == "error" then name_hl = "FexptrDiagError"
        elseif diag == "warn"  then name_hl = "FexptrDiagWarn"
        elseif node.is_dir     then name_hl = "FexptrDirName"
        else                        name_hl = "FexptrFileName"
        end
        api.nvim_buf_add_highlight(state.buf, NS, name_hl, line_nr, name_start, -1)

        -- Virtual text: diagnostic icon + git status icon (EOL)
        local virt = {}
        if diag and cfg.diagnostics.enabled then
            local dico = cfg.icons.diagnostics[diag] or "!"
            local dhl  = hl.diag_hl[diag] or "Comment"
            virt[#virt + 1] = { " " .. dico, dhl }
        end
        local git = cfg.git.enabled and state.git_status[node.path]
        if git then
            local gico = (cfg.icons.git_status or {})[git] or git
            local ghl  = hl.git_hl[git] or "Comment"
            virt[#virt + 1] = { " " .. gico, ghl }
        end
        if #virt > 0 then
            api.nvim_buf_set_extmark(state.buf, NS, line_nr, 0, {
                virt_text     = virt,
                virt_text_pos = "eol",
            })
        end

        ::continue::
    end

    -- Statusline
    if state.win and api.nvim_win_is_valid(state.win) then
        local sl = " " .. fn.fnamemodify(state.root, ":~")
        if state.filter then sl = sl .. "  /" .. state.filter .. "/" end
        sl = sl .. "  " .. #state.tree .. " items"
        vim.wo[state.win].statusline = sl
    end

    pcall(api.nvim_win_set_cursor, state.win, state.cursor)
end

function M.render_deferred()
    if _render_scheduled then return end
    _render_scheduled = true
    vim.schedule(function()
        _render_scheduled = false
        if not (state.buf and api.nvim_buf_is_valid(state.buf)) then return end
        if not (state.win and api.nvim_win_is_valid(state.win)) then return end
        local ok, err = pcall(M.render)
        if not ok then
            vim.notify("fexptr render failed: " .. tostring(err), vim.log.levels.WARN)
        end
    end)
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

    if config.values.preview.enabled then
        api.nvim_create_autocmd("CursorMoved", {
            buffer   = buf,
            callback = function()
                local row  = api.nvim_win_get_cursor(0)[1]
                local node = state.tree[row - 1]
                if node and not node.is_parent then
                    require("fexptr.preview").open(node)
                end
            end,
        })
    end
end

-- --------------------------------------------------------------------------
-- Toggle (open / close)
-- --------------------------------------------------------------------------

function M.toggle()
    -- CLOSE
    if state.win and api.nvim_win_is_valid(state.win) then
        M.stop_watcher()
        local wins = api.nvim_tabpage_list_wins(0)
        if #wins == 1 then
            api.nvim_set_current_buf(api.nvim_create_buf(true, false))
        else
            api.nvim_win_close(state.win, true)
        end
        state.win = nil
        state.buf = nil
        return
    end

    -- OPEN
    local buf = api.nvim_create_buf(false, true)
    vim.bo[buf].buftype   = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile  = false
    vim.bo[buf].filetype  = "fexptr"

    local cfg = config.values

    if cfg.float.enabled then
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
        pcall(function()
            _refresh_timer:stop()
            _refresh_timer:close()
        end)
        _refresh_timer = nil
    end

    local timer = vim.loop.new_timer()
    if not timer then return end
    _refresh_timer = timer

    timer:start(400, 0, vim.schedule_wrap(function()
        pcall(function()
            timer:stop()
            timer:close()
        end)
        if _refresh_timer == timer then
            _refresh_timer = nil
        end

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
