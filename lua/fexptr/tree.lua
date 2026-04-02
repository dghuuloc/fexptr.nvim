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

---Recursively build the flat node list.
---@param path  string
---@param depth number
---@return ExplorerNode[]
function M.build(path, depth)
    depth = depth or 0
    local nodes  = {}
    local filter = state.filter and state.filter:lower()

    local ok, items = pcall(fs.scandir, path)
    if not ok or not items then return nodes end

    for _, item in ipairs(items) do
        local full = path .. "/" .. item.name

        if item.type == "directory" then
            -- ── Path collapsing ──────────────────────────────────────────
            -- Walk down while the directory has exactly one child that is
            -- also a directory; merge the names with "/".
            local current = full
            local names   = { item.name }

            while true do
                local children = fs.scandir(current)
                if #children ~= 1 or children[1].type ~= "directory" then break end
                current = current .. "/" .. children[1].name
                names[#names + 1] = children[1].name
            end

            local display = table.concat(names, "/")

            -- ── Filter ───────────────────────────────────────────────────
            if filter then
                local name_match = display:lower():find(filter, 1, true)
                local child_match = name_match or has_match(current, filter)
                if not child_match then goto continue end
            end

            nodes[#nodes + 1] = {
                name   = display,
                path   = current,
                depth  = depth,
                is_dir = true,
            }

            if state.expanded[current] then
                vim.list_extend(nodes, M.build(current, depth + 1))
            end

        else
            -- ── Filter ───────────────────────────────────────────────────
            if filter and not item.name:lower():find(filter, 1, true) then
                goto continue
            end

            nodes[#nodes + 1] = {
                name   = item.name,
                path   = full,
                depth  = depth,
                is_dir = false,
            }
        end

        ::continue::
    end

    return nodes
end

return M
