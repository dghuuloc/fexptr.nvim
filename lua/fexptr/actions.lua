-- lua/fexptr/actions.lua

local api = vim.api
local fn = vim.fn
local uv = vim.loop

local state = require("fexptr.state")
-- local core = require("fexptr.core")
local fs = require("fexptr.fs")

local M = {}

local function core()
    return require("fexptr.core")
end

---@return ExplorerNode|nil
local function get_node()
    local row = api.nvim_win_get_cursor(0)[1]
    if row <= 1 then return nil end
    return state.tree[row - 1]
end

local function open_file(path)
    api.nvim_set_current_win(state.win)
    vim.cmd("wincmd l")
    if api.nvim_get_current_win() == state.win then
        vim.cmd("vsplit | wincmd l")
    end
    vim.cmd("edit " .. fn.fnameescape(path))

end

function M.open()
    local node = get_node()
    if not node then return end

    if node.is_dir then
        state.expanded[node.path] = not state.expanded[node.path]
        vim.g.fexptr_expanded = state.expanded
        core().render()
    else
        open_file(node.path)
    end
end

function M.create_()
    local node = get_node()
    local base

    if node and node.is_dir then
        base = node.path
    else
        base = state.root
    end

    -- Ensure base path ends without trailing slash
    base = base:gsub("[/\\]$", "")

     -- Convert to path relative to root for display in input
    local rel_base = vim.fn.fnamemodify(base, ":.")
    rel_base = rel_base:gsub("\\", "/")

    -- Pre-fill input with the current node's full path + "/"
    local input = fn.input("Create: ", rel_base .. "/")
    if input == "" then return end

    -- Convert input back to absolute path
    local abs_path = state.root .. "/" .. input
    abs_path = abs_path:gsub("[/\\]+", "/") -- normalize slashes

    -- If ends with "/", create directory
    if input:sub(-1) == "/" then
        fn.mkdir(input, "p")
    else
        fn.mkdir(fn.fnamemodify(input, ":h"), "p")
        local fd = uv.fs_open(input, "w", 420)
        if fd then uv.fs_close(fd) end
    end

    core().render()
end

function M.rename_()
    local node = get_node()
    if not node then return end

    local rel_path = vim.fn.fnamemodify(node.path, ":.")
    rel_path = rel_path:gsub("\\", "/")
    local input = vim.fn.input("Rename: ", rel_path)
    if input == "" then return end

     -- Normalize paths
    local abs_old = node.path:gsub("\\", "/")
    local abs_new = (state.root .. "/" .. input):gsub("\\", "/"):gsub("/+", "/")

    local abs_new_parent = vim.fn.fnamemodify(abs_new, ":h")
    if not vim.loop.fs_stat(abs_new_parent) then
        vim.fn.mkdir(abs_new_parent, "p")
    end

    if vim.loop.fs_stat(abs_new) then
        vim.notify("Target already exists: " .. abs_new, vim.log.levels.ERROR)
        return
    end

    -- Attempt to rename (works for files and empty directories)
    local ok, err = uv.fs_rename(abs_old, abs_new)
    if not ok then
        vim.notify("Rename failed: " .. tostring(err), vim.log.levels.ERROR)
        return
    end

    core().render()
end

function M.delete_()
    local node = get_node()
    if not node then return end
    if fn.confirm("Delete "..node.name.."?", "&Yes\n&No") ~= 1 then return end
    if node.is_dir then fn.delete(node.path, "rf") else uv.fs_unlink(node.path) end

    core().render()
end

function M.copy_(cut)
    local node = get_node()
    if node then state.clipboard = { path=node.path, cut=cut } end
end

function M.paste_()
    if not state.clipboard then return end

    -- Pre-fill target input with current node path relative to root
    local node = get_node()
    local target_base = node and node.is_dir and node.path or state.root
    local rel_target = vim.fn.fnamemodify(target_base, ":.")
    rel_target = rel_target:gsub("\\", "/")

    local input = fn.input("Paste to: ", rel_target .. "/")
    if input == "" then return end

    -- Absolute path
    local target_dir = state.root .. "/" .. input
    target_dir = target_dir:gsub("[/\\]+", "/")

    -- Target full path
    local target = target_dir .. "/" .. fn.fnamemodify(state.clipboard.path, ":t")
    target = target:gsub("[/\\]+", "/")

    -- Prevent moving folder into itself
    if state.clipboard.cut and target:sub(1,#state.clipboard.path) == state.clipboard.path then
        vim.notify("Cannot move directory into itself", vim.log.levels.ERROR)
        return
    end

    fn.mkdir(fn.fnamemodify(target, ":h"), "p")

    if state.clipboard.cut then
        local ok, err = pcall(uv.fs_rename, state.clipboard.path, target)
        if not ok then
            vim.notify("Move failed: " .. err .. "\nTrying copy + delete...", vim.log.levels.WARN)
            -- fallback: copy + delete
            fs.copy_recursive(state.clipboard.path, target)
            uv.fs_rmdir(state.clipboard.path)
        end
        state.clipboard = nil
    else
        fs.copy_recursive(state.clipboard.path, target)
    end

end

return M
