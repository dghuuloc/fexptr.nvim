-- lua/fexptr/actions.lua
local uv = vim.loop
local fn = vim.fn

local state  = require("fexptr.state")
local core   = require("fexptr.core")
local utils  = require("fexptr.utils")

local M = {}

-- -------------------------
-- OPEN / TOGGLE DIR
-- -------------------------
function M.open()
    local node = core.get_node()
    if not node then return end

    if node.is_dir then
        state.expanded[node.path] = not state.expanded[node.path]
        core.render()
    else
        vim.cmd("edit " .. fn.fnameescape(node.path))
    end
end

-- -------------------------
-- RENAME (SAFE)
-- -------------------------
function M.rename()
    local node = core.get_node()
    if not node then return end

    local rel = fn.fnamemodify(node.path, ":."):gsub("\\","/")
    local input = fn.input("Rename: ", rel)
    if input == "" then return end

    local src = utils.normalize(node.path)
    local dst = utils.normalize(state.root .. "/" .. input)

    if src == dst then return end

    utils.ensure_parent(dst)

    local ok = pcall(uv.fs_rename, src, dst)
    if not ok then
        -- Windows fallback
        utils.copy_recursive(src, dst)
        fn.delete(src, "rf")
    end

    core.render()
end

-- -------------------------
-- COPY / CUT
-- -------------------------
function M.copy()
    local node = core.get_node()
    if not node then return end
    state.clipboard = { path = node.path, cut = false }
end

function M.cut()
    local node = core.get_node()
    if not node then return end
    state.clipboard = { path = node.path, cut = true }
end

-- -------------------------
-- PASTE (SAFE)
-- -------------------------
function M.paste()
    if not state.clipboard then return end

    local node = core.get_node()
    local base = node and node.is_dir and node.path or state.root

    local rel = fn.fnamemodify(base, ":."):gsub("\\","/")
    local input = fn.input("Paste to: ", rel .. "/")
    if input == "" then return end

    local src = utils.normalize(state.clipboard.path)
    local dst = utils.normalize(state.root .. "/" .. input .. "/" .. fn.fnamemodify(src, ":t"))

    -- Prevent move into itself
    if state.clipboard.cut and dst:sub(1, #src) == src then
        vim.notify("Cannot move directory into itself", vim.log.levels.ERROR)
        return
    end

    utils.ensure_parent(dst)

    if state.clipboard.cut then
        local ok = pcall(uv.fs_rename, src, dst)
        if not ok then
            utils.copy_recursive(src, dst)
            fn.delete(src, "rf")
        end
        state.clipboard = nil
    else
        utils.copy_recursive(src, dst)
    end

    core.render()
end

-- -------------------------
-- DELETE
-- -------------------------
function M.delete()
    local node = core.get_node()
    if not node then return end

    local confirm = fn.confirm("Delete " .. node.name .. "?", "&Yes\n&No")
    if confirm ~= 1 then return end

    fn.delete(node.path, "rf")
    core.render()
end

return M
