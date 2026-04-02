-- lua/fexptr/actions/nav.lua
--
-- Navigation and UI actions (no filesystem writes).

local api   = vim.api
local state = require("fexptr.state")

local M = {}

local function core() return require("fexptr.core") end

-- --------------------------------------------------------------------------
-- Helpers
-- --------------------------------------------------------------------------

---Return the ExplorerNode under the cursor, or nil if on the header.
---@return ExplorerNode|nil
function M.get_node()
    local row = api.nvim_win_get_cursor(0)[1]
    if row <= 1 then return nil end
    return state.tree[row - 1]
end

---Open `path` in the best available editing window.
---@param path string
local function open_file(path)
    -- Find a non-explorer window
    local target = nil
    for _, w in ipairs(api.nvim_tabpage_list_wins(0)) do
        if w ~= state.win then
            target = w
            break
        end
    end

    if target then
        api.nvim_set_current_win(target)
    else
        -- Only the explorer is open → create a split to the right
        vim.cmd("wincmd l")
        if api.nvim_get_current_win() == state.win then
            vim.cmd("vsplit")
        end
    end

    vim.cmd("edit " .. vim.fn.fnameescape(path))
end

-- --------------------------------------------------------------------------
-- Open / expand
-- --------------------------------------------------------------------------

function M.open()
    local node = M.get_node()
    if not node then return end

    if node.is_dir then
        state.expanded[node.path] = not state.expanded[node.path]
        vim.g.fexptr_expanded = state.expanded
        core().render()
    else
        open_file(node.path)
    end
end

-- --------------------------------------------------------------------------
-- Root navigation
-- --------------------------------------------------------------------------

---Change explorer root to the selected directory (or parent dir of a file).
function M.cd()
    local node = M.get_node()
    if not node then return end
    local new_root = node.is_dir and node.path
        or vim.fn.fnamemodify(node.path, ":h")
    state.root      = new_root
    state.expanded  = {}
    state.selection = {}
    state.filter    = nil
    core().start_watcher()
    require("fexptr.git").refresh(function()
        require("fexptr.diagnostics").refresh()
        core().render()
    end)
end

---Go up one directory.
function M.parent()
    local parent = vim.fn.fnamemodify(state.root, ":h")
    if parent == state.root then return end  -- already at filesystem root
    state.root      = parent
    state.selection = {}
    state.filter    = nil
    core().start_watcher()
    require("fexptr.git").refresh(function()
        require("fexptr.diagnostics").refresh()
        core().render()
    end)
end

-- --------------------------------------------------------------------------
-- Selection
-- --------------------------------------------------------------------------

---Toggle selection of node under cursor and advance one line.
function M.select()
    local node = M.get_node()
    if not node then return end

    if state.selection[node.path] then
        state.selection[node.path] = nil
    else
        state.selection[node.path] = true
    end
    core().render()

    local row = api.nvim_win_get_cursor(0)[1]
    pcall(api.nvim_win_set_cursor, 0, { row + 1, 0 })
end

---Toggle select-all / deselect-all.
function M.select_all()
    if next(state.selection) then
        state.selection = {}
    else
        for _, node in ipairs(state.tree) do
            state.selection[node.path] = true
        end
    end
    core().render()
end

-- --------------------------------------------------------------------------
-- Visibility
-- --------------------------------------------------------------------------

---Toggle show/hide hidden files.
function M.toggle_hidden()
    local cfg = require("fexptr.config")
    cfg.values.show_hidden = not cfg.values.show_hidden
    core().render()
end

-- --------------------------------------------------------------------------
-- Clipboard helpers
-- --------------------------------------------------------------------------

---Copy absolute path of node to system clipboard.
function M.copy_path()
    local node = M.get_node()
    if not node then return end
    vim.fn.setreg("+", node.path)
    vim.fn.setreg('"', node.path)
    vim.notify("[fexptr] Copied path: " .. node.path, vim.log.levels.INFO)
end

---Copy just the filename/dirname to system clipboard.
function M.copy_name()
    local node = M.get_node()
    if not node then return end
    local name = vim.fn.fnamemodify(node.name, ":t")
    vim.fn.setreg("+", name)
    vim.fn.setreg('"', name)
    vim.notify("[fexptr] Copied name: " .. name, vim.log.levels.INFO)
end

-- --------------------------------------------------------------------------
-- System open
-- --------------------------------------------------------------------------

---Open the file/directory with the OS default application.
function M.system_open()
    local node = M.get_node()
    if not node then return end

    local cmd
    if vim.fn.has("mac")   == 1 then cmd = "open"
    elseif vim.fn.has("win32") == 1 then cmd = "explorer"
    else cmd = "xdg-open"
    end

    vim.fn.jobstart({ cmd, node.path }, { detach = true })
end

-- --------------------------------------------------------------------------
-- Live filter
-- --------------------------------------------------------------------------

function M.filter()
    vim.ui.input({ prompt = "Filter: ", default = state.filter or "" }, function(input)
        if input == nil then return end   -- cancelled
        state.filter = input ~= "" and input or nil
        core().render()
    end)
end

function M.clear_filter()
    state.filter = nil
    core().render()
end

-- --------------------------------------------------------------------------
-- Preview
-- --------------------------------------------------------------------------

function M.preview()
    local node = M.get_node()
    require("fexptr.preview").open(node)
end

-- --------------------------------------------------------------------------
-- Refresh
-- --------------------------------------------------------------------------

function M.refresh()
    require("fexptr.git").refresh(function()
        require("fexptr.diagnostics").refresh()
        core().render()
    end)
end

return M
