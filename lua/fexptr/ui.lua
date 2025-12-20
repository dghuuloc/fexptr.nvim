-- lua/fexptr/ui.lua
local config = require("fexptr.config")

local M = {}

function M.root_label(path)
    return " " .. vim.fn.fnamemodify(path, ":t"):upper()
end

function M.render_node(node)
    local indent = string.rep("  ", node.depth)
    local icon

    if node.is_dir then
        icon = config.options.icons.folder_closed
    else
        icon = config.options.icons.file
    end

    return indent .. icon .. " " .. node.name
end

return M
