-- lua/fextr/config.lua
local M = {}

M.values = {
    width = 30,
    show_hidden = false,
    icons = {
        folder_closed = "",
        folder_open   = "",
        file          = "󰈙",
    },
}

function M.setup(opts)
  M.values = vim.tbl_deep_extend("force", M.values, opts or {})
end

return M
