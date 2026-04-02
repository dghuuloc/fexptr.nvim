-- lua/fexptr/fs.lua
--
-- All filesystem helpers.  Config is read lazily so show_hidden changes
-- (toggled at runtime) are always reflected without reloading the module.

local fn = vim.fn
local uv = vim.loop

local M = {}

local function cfg()
    return require("fexptr.config").values
end

-- --------------------------------------------------------------------------
-- Directory listing
-- --------------------------------------------------------------------------

---Scan a directory and return a sorted list of { name, type } entries.
---Dotfiles are filtered according to config.show_hidden.
---@param path string
---@return { name: string, type: string }[]
function M.scandir(path)
    local handle = uv.fs_scandir(path)
    if not handle then return {} end

    local show_hidden = cfg().show_hidden
    local items = {}
    while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then break end
        if show_hidden or name:sub(1, 1) ~= "." then
            items[#items + 1] = { name = name, type = t }
        end
    end

    -- Directories first, then alphabetically
    table.sort(items, function(a, b)
        if a.type == b.type then return a.name < b.name end
        return a.type == "directory"
    end)

    return items
end

-- --------------------------------------------------------------------------
-- Recursive copy
-- --------------------------------------------------------------------------

---Recursively copy `src` to `dest`.  Handles files and directories.
---@param src  string
---@param dest string
function M.copy_recursive(src, dest)
    local stat = uv.fs_stat(src)
    if not stat then return end

    if stat.type == "file" then
        fn.mkdir(fn.fnamemodify(dest, ":h"), "p")
        local rf = io.open(src, "rb")
        if not rf then
            vim.notify("[fexptr] Cannot read: " .. src, vim.log.levels.ERROR)
            return
        end
        local data = rf:read("*all")
        rf:close()
        local wf = io.open(dest, "wb")
        if not wf then
            vim.notify("[fexptr] Cannot write: " .. dest, vim.log.levels.ERROR)
            return
        end
        wf:write(data)
        wf:close()

    elseif stat.type == "directory" then
        fn.mkdir(dest, "p")
        for _, item in ipairs(M.scandir(src)) do
            M.copy_recursive(src .. "/" .. item.name, dest .. "/" .. item.name)
        end
    end
end

-- --------------------------------------------------------------------------
-- Recursive delete (hard)
-- --------------------------------------------------------------------------

---Delete `path` permanently, recursing into directories.
---@param path string
function M.delete_recursive(path)
    local stat = uv.fs_stat(path)
    if not stat then return end
    if stat.type == "directory" then
        fn.delete(path, "rf")
    else
        uv.fs_unlink(path)
    end
end

-- --------------------------------------------------------------------------
-- Trash (safe delete)
-- --------------------------------------------------------------------------

local _trash_cmd = nil  -- cached: false = unavailable, table = command prefix

local function find_trash_cmd()
    if _trash_cmd ~= nil then return _trash_cmd end

    local override = cfg().trash.cmd
    if override then
        _trash_cmd = override
        return _trash_cmd
    end

    -- Auto-detect common trash utilities
    for _, candidate in ipairs({ "trash-put", "trash", "gio" }) do
        if fn.executable(candidate) == 1 then
            _trash_cmd = candidate == "gio" and { "gio", "trash" } or { candidate }
            return _trash_cmd
        end
    end

    _trash_cmd = false
    return _trash_cmd
end

---Move `path` to the system trash, falling back to hard delete if unavailable.
---@param path string
function M.trash(path)
    local cmd = find_trash_cmd()
    if not cmd then
        vim.notify(
            "[fexptr] No trash utility found — deleting permanently: " .. path,
            vim.log.levels.WARN
        )
        M.delete_recursive(path)
        return
    end

    local args = vim.list_extend(vim.deepcopy(cmd), { path })
    local result = fn.jobwait({ fn.jobstart(args) }, 5000)
    if result[1] ~= 0 then
        vim.notify("[fexptr] Trash failed for: " .. path, vim.log.levels.ERROR)
    end
end

return M
