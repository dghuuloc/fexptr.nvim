-- lua/fexptr/tree.lua
local uv = vim.loop
local state = require("fexptr.state")
local config = require("fexptr.config")

local M = {}

function M.scandir(path)
    local handle = uv.fs_scandir(path)
    if not handle then return {} end

    local items = {}
    while true do
        local name, t = uv.fs_scandir_next(handle)
        if not name then break end

        if not config.options.filters.dotfiles and name:sub(1,1) == "." then
            goto continue
        end

        table.insert(items, { name = name, type = t })
        ::continue::
    end

    table.sort(items, function(a,b)
        if a.type == b.type then return a.name < b.name end
        return a.type == "directory"
    end)

    return items
end

function M.build(path, depth)
    depth = depth or 0
    local nodes = {}

    for _, item in ipairs(M.scandir(path)) do
        local full = path .. "/" .. item.name
        local node = {
            name = item.name,
            path = full,
            depth = depth,
            is_dir = item.type == "directory",
        }

        table.insert(nodes, node)

        if node.is_dir and state.expanded[full] then
            vim.list_extend(nodes, M.build(full, depth + 1))
        end
    end

    return nodes
end

return M
