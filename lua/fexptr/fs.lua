-- lua/fexptr/fs.lua
local fn = vim.fn
local uv = vim.loop

local config = require("fexptr.config").values

local M = {}

-- FS Helpers

---@param path string
---@return { name: string, type: string }[]
function M.scandir(path)
    local handle = uv.fs_scandir(path)
    if not handle then return {} end

    local items = {}
    while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then break end
        if config.show_hidden or name:sub(1,1) ~= "." then
            items[#items+1] = { name = name, type = t }
        end
    end

    table.sort(items, function(a,b)
        if a.type == b.type then return a.name < b.name end
        return a.type == "directory"
    end)

    return items
end

-- Recursive copy (Windows-safe)

---@param src string
---@param dest string
function M.copy_recursive(src, dest)
    local stat = uv.fs_stat(src)
    if not stat then return end

    if stat.type == "file" then
        fn.mkdir(fn.fnamemodify(dest, ":h"), "p")
        local data = assert(io.open(src, "rb")):read("*all")
        local f = assert(io.open(dest, "wb"))
        f:write(data)
        f:close()
    elseif stat.type == "directory" then
        fn.mkdir(dest, "p")
        for _, item in ipairs(scandir(src)) do
            copy_recursive(src .. "/" .. item.name, dest .. "/" .. item.name)
        end
    end
end

return M
