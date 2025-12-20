-- lua/fexptr/utils.lua
local uv = vim.loop
local fn = vim.fn

local M = {}

function M.normalize(path)
    return path:gsub("\\", "/"):gsub("/+$", "")
end

function M.ensure_parent(path)
    fn.mkdir(fn.fnamemodify(path, ":h"), "p")
end

function M.copy_recursive(src, dest)
    local stat = uv.fs_stat(src)
    if not stat then return end

    if stat.type == "file" then
        M.ensure_parent(dest)
        local data = assert(io.open(src, "rb")):read("*all")
        local f = assert(io.open(dest, "wb"))
        f:write(data)
        f:close()
    else
        fn.mkdir(dest, "p")
        for name, t in vim.fs.dir(src) do
            M.copy_recursive(src .. "/" .. name, dest .. "/" .. name)
        end
    end
end

return M
