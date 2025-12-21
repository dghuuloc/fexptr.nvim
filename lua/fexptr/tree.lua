-- lua/fexptr/tree.lua
local fs = require("fexptr.fs")
local state = require("fexptr.state")

local M = {}

---@param path string
---@param depth number
---@return ExplorerNode[]
function M.build(path, depth)
    depth = depth or 0
    local nodes = {}

    local ok, items = pcall(fs.scandir, path)
    if not ok or not items then return nodes end

    for _, item in ipairs(items) do
        local full = path .. "/" .. item.name

        if item.type == "directory" then
            local current = full
            local names = { item.name }

            while true do
                local children = fs.scandir(current)
                if #children ~= 1 or children[1].type ~= "directory" then break end
                current = current .. "/" .. children[1].name
                names[#names+1] = children[1].name
            end

            nodes[#nodes+1] = {
                name = table.concat(names, "/"),
                path = current,
                depth = depth,
                is_dir = true,
            }

            if state.expanded[current] then
                vim.list_extend(nodes, M.build(current, depth + 1))
            end
        else
            nodes[#nodes+1] = {
                name = item.name,
                path = full,
                depth = depth,
                is_dir = false,
            }
        end
    end

    return nodes
end

return M
