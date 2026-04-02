-- lua/fexptr/actions/fs.lua
--
-- All actions that mutate the filesystem: create, rename, delete, copy, paste.
-- Supports multi-selection for delete / copy / cut / paste.

local fn    = vim.fn
local uv    = vim.loop
local state = require("fexptr.state")
local fs    = require("fexptr.fs")
local nav   = require("fexptr.actions.nav")

local M = {}

local function core() return require("fexptr.core") end

---Return the list of paths to operate on: the selection if non-empty,
---otherwise just the node under the cursor.
---@return string[]
local function targets()
    if next(state.selection) then
        local paths = {}
        for path in pairs(state.selection) do paths[#paths + 1] = path end
        return paths
    end
    local node = nav.get_node()
    return node and { node.path } or {}
end

---Convert a user-supplied path (possibly relative) to an absolute path
---anchored at state.root.
---@param input string
---@return string
local function to_abs(input)
    if input:sub(1, 1) == "/" or input:match("^%a:[\\/]") then
        return input
    end
    return (state.root .. "/" .. input):gsub("[/\\]+", "/")
end

-- --------------------------------------------------------------------------
-- Create
-- --------------------------------------------------------------------------

---Create a file or directory.  Input ending with "/" creates a directory.
function M.create()
    local node = nav.get_node()
    local base = (node and node.is_dir) and node.path or state.root
    base = base:gsub("[/\\]$", "")

    -- Pre-fill with the current directory path relative to root
    local rel = vim.fn.fnamemodify(base, ":."):gsub("\\", "/")

    vim.ui.input({ prompt = "Create (end / = dir): ", default = rel .. "/" }, function(input)
        if not input or input == "" then return end

        local abs = to_abs(input)

        if input:sub(-1) == "/" then
            -- Directory
            fn.mkdir(abs, "p")
        else
            -- File: ensure parent dirs exist, then touch
            fn.mkdir(fn.fnamemodify(abs, ":h"), "p")
            local fd = uv.fs_open(abs, "w", 420)
            if fd then uv.fs_close(fd) end
        end

        core().render()
    end)
end

-- --------------------------------------------------------------------------
-- Rename
-- --------------------------------------------------------------------------

function M.rename()
    local node = nav.get_node()
    if not node then return end

    local rel = vim.fn.fnamemodify(node.path, ":."):gsub("\\", "/")

    vim.ui.input({ prompt = "Rename: ", default = rel }, function(input)
        if not input or input == "" then return end

        local abs_new    = to_abs(input)
        local abs_new_parent = fn.fnamemodify(abs_new, ":h")

        -- Create intermediate directories if needed
        if not uv.fs_stat(abs_new_parent) then
            fn.mkdir(abs_new_parent, "p")
        end

        if uv.fs_stat(abs_new) then
            vim.notify("[fexptr] Target already exists: " .. abs_new, vim.log.levels.ERROR)
            return
        end

        local ok, err = uv.fs_rename(node.path, abs_new)
        if not ok then
            vim.notify("[fexptr] Rename failed: " .. tostring(err), vim.log.levels.ERROR)
            return
        end

        core().render()
    end)
end

-- --------------------------------------------------------------------------
-- Delete / Trash
-- --------------------------------------------------------------------------

function M.delete()
    local t = targets()
    if #t == 0 then return end

    local cfg    = require("fexptr.config").values
    local label  = #t == 1 and fn.fnamemodify(t[1], ":t") or (#t .. " items")
    local action = cfg.trash.enabled and "Trash" or "Delete"

    if fn.confirm(action .. " " .. label .. "?", "&Yes\n&No") ~= 1 then return end

    for _, path in ipairs(t) do
        if cfg.trash.enabled then
            fs.trash(path)
        else
            fs.delete_recursive(path)
        end
    end

    state.selection = {}
    core().render()
end

-- --------------------------------------------------------------------------
-- Copy / Cut
-- --------------------------------------------------------------------------

---Stage paths for copy (`cut = false`) or cut (`cut = true`).
---@param cut boolean
function M.copy(cut)
    local t = targets()
    if #t == 0 then return end
    state.clipboard = { paths = t, cut = cut }
    local verb = cut and "Cut" or "Copied"
    vim.notify(string.format("[fexptr] %s %d item(s)", verb, #t), vim.log.levels.INFO)
end

-- --------------------------------------------------------------------------
-- Paste
-- --------------------------------------------------------------------------

function M.paste()
    if not state.clipboard then
        vim.notify("[fexptr] Nothing in clipboard", vim.log.levels.WARN)
        return
    end

    local node       = nav.get_node()
    local target_dir = (node and node.is_dir) and node.path or state.root

    for _, src in ipairs(state.clipboard.paths) do
        local name = fn.fnamemodify(src, ":t")
        local dest = (target_dir .. "/" .. name):gsub("[/\\]+", "/")

        -- Guard: cannot move a directory into itself
        local src_prefix = src:sub(-1) == "/" and src or src .. "/"
        if state.clipboard.cut and dest:sub(1, #src_prefix) == src_prefix then
            vim.notify("[fexptr] Cannot move '" .. name .. "' into itself", vim.log.levels.ERROR)
        else
            fn.mkdir(fn.fnamemodify(dest, ":h"), "p")

            if state.clipboard.cut then
                local ok = pcall(uv.fs_rename, src, dest)
                if not ok then
                    -- Cross-device move: copy then delete
                    fs.copy_recursive(src, dest)
                    fs.delete_recursive(src)
                end
            else
                fs.copy_recursive(src, dest)
            end
        end
    end

    -- Clear clipboard only after a cut
    if state.clipboard.cut then state.clipboard = nil end
    state.selection = {}
    core().render()
end

return M
