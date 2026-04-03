-- lua/fexptr/tree.lua
--
-- Builds a *flat* list of ExplorerNode from the filesystem.
-- Flat means one entry per visible item, so line N in the buffer maps
-- directly to tree[N-1] (line 1 is the header).
--
-- Features:
--  • Single-child directory collapsing  ("src/main/java" instead of 3 rows)
--  • Expansion state from state.expanded
--  • Live filter:  only nodes whose name matches state.filter are included.
--    Parent directories that contain matching children are still shown.

local fs    = require("fexptr.fs")
local state = require("fexptr.state")

local M = {}

---Check whether any descendant of `path` matches `filter`.
---Used to decide whether to show a directory even when it doesn't match.
---@param path   string
---@param filter string   lower-case filter pattern
---@return boolean
local function has_match(path, filter)
    for _, item in ipairs(fs.scandir(path)) do
        local full = path .. "/" .. item.name
        if item.type == "directory" then
            if item.name:lower():find(filter, 1, true) then return true end
            if has_match(full, filter) then return true end
        else
            if item.name:lower():find(filter, 1, true) then return true end
        end
    end
    return false
end

local function collapse(path, name)
    local current = path
    local names   = { name }
    while true do
        local children = fs.scandir(current)
        if #children ~= 1 or children[1].type ~= "directory" then break end
        current = current .. "/" .. children[1].name
        names[#names + 1] = children[1].name
    end
    return current, table.concat(names, "/")
end

---Recursively build the flat node list.
---@param path  string
---@param depth number
---@param last_at table<number,boolean>
---@return ExplorerNode[]
function M.build(path, depth, last_at)
    depth   = depth   or 0
    last_at = last_at or {}

    local nodes  = {}
    local filter = state.filter and state.filter:lower()

    local ok, items = pcall(fs.scandir, path)
    if not ok or not items then return nodes end

    -- Pass 1: collect visible items so we know is_last accurately.
    local visible = {}
    for _, item in ipairs(items) do
        local full = path .. "/" .. item.name
        if item.type == "directory" then
            local current, display = collapse(full, item.name)
            local include = true
            if filter then
                include = display:lower():find(filter, 1, true)
                    or has_match(current, filter)
            end
            if include then
                visible[#visible + 1] = {
                    kind = "dir", item = item,
                    full = full, current = current, display = display,
                }
            end
        else
            local include = true
            if filter then
                include = item.name:lower():find(filter, 1, true)
            end
            if include then
                visible[#visible + 1] = {
                    kind = "file", item = item,
                    full = full, display = item.name,
                }
            end
        end
    end

    -- Pass 2: build nodes with last_at propagated.
    for i, v in ipairs(visible) do
        local is_last      = (i == #visible)
        local node_last_at = vim.tbl_extend("force", last_at, { [depth] = is_last })

        if v.kind == "dir" then
            nodes[#nodes + 1] = {
                name    = v.display,
                path    = v.current,
                depth   = depth,
                is_dir  = true,
                last_at = node_last_at,
            }
            if state.expanded[v.current] then
                vim.list_extend(nodes, M.build(v.current, depth + 1, node_last_at))
            end
        else
            nodes[#nodes + 1] = {
                name    = v.item.name,
                path    = v.full,
                depth   = depth,
                is_dir  = false,
                last_at = node_last_at,
            }
        end
    end

    return nodes
end

return M
